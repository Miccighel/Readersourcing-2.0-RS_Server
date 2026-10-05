require "test_helper"
require "tmpdir"

class PublicationCopyStoreTest < ActiveSupport::TestCase

  include ActiveSupport::Testing::TimeHelpers

  setup do
    @publication = publications(:one)
    @user = users(:one)
    @storage_root = Dir.mktmpdir("rs-publication-copies-")
    @previous_storage_root = ENV["RS_PDF_STORAGE_ROOT"]
    ENV["RS_PDF_STORAGE_ROOT"] = @storage_root
  end

  teardown do
    @previous_storage_root.nil? ? ENV.delete("RS_PDF_STORAGE_ROOT") : ENV["RS_PDF_STORAGE_ROOT"] = @previous_storage_root
    FileUtils.remove_entry_secure(@storage_root)
  end

  test "publishes the original and annotated PDF as one complete private copy" do
    copy = prepare_copy("Reader.pdf")

    assert_equal copy.generation, current_copy.generation
    assert copy.available?("original")
    assert copy.available?("annotated")
    assert_equal "original Reader.pdf", copy.path("original").read
    assert_equal "annotated Reader.pdf", copy.path("annotated").read
    assert copy.directory.to_s.start_with?(@storage_root)
    assert_equal ["generations", "current", ".lock"].sort, copy.root.children.map { |path| path.basename.to_s }.sort
  end

  test "two readers retain independent filenames for the same publication" do
    first = prepare_copy("First.pdf")
    second = prepare_copy("Second.pdf", user: users(:two))

    assert_equal "First.pdf", current_copy.name("original")
    assert_equal "Second.pdf", PublicationCopy.current(publication: @publication, user: users(:two)).name("original")
    assert_not_equal first.directory, second.directory
    assert_equal "original First.pdf", first.path("original").read
    assert_equal "annotated Second.pdf", second.path("annotated").read
    assert_equal "readersourcing-one.pdf", @publication.reload.pdf_name
  end

  test "a failure after staging one file leaves the previous pair and pointer unchanged" do
    previous = prepare_copy("Previous.pdf")
    store = PublicationCopyStore.new(previous.root)

    assert_raises(IOError) do
      Publication.transaction(requires_new: true) do |transaction|
        store.prepare(publication: @publication, user: @user, filename: "Failed.pdf", transaction: transaction) do |staged|
          File.write(staged.path("original"), "partial")
          raise IOError, "Annotation failed"
        end
      end
    end

    assert_equal previous.generation, current_copy.generation
    assert_equal "original Previous.pdf", previous.path("original").read
    assert_equal "annotated Previous.pdf", previous.path("annotated").read
    assert_equal [previous.generation], previous.root.join("generations").children.map { |path| path.basename.to_s }
    assert_empty previous.root.glob("rs-copy-*")
  end

  test "an incomplete pair is not published" do
    root = PublicationCopy.root_for(@publication, @user)

    assert_raises(RuntimeError) do
      Publication.transaction(requires_new: true) do |transaction|
        PublicationCopyStore.new(root).prepare(publication: @publication, user: @user, filename: "Partial.pdf", transaction: transaction) do |staged|
          File.write(staged.path("annotated"), "partial")
        end
      end
    end

    assert_not root.join("current").exist?
    assert_empty root.join("generations").children
  end

  test "download references still select the precise generation after a refresh" do
    previous = prepare_copy("Previous.pdf")
    reference = PublicationDownloadReference.issue(
      user: @user, publication: @publication, variant: "annotated",
      filename: previous.name("annotated"), generation: previous.generation
    )
    replacement = prepare_copy("Replacement.pdf")

    resolved = PublicationDownloadReference.resolve_copy(reference, publication: @publication, variant: "annotated", filename: previous.name("annotated"))
    assert_equal previous.generation, resolved.generation
    assert_equal "annotated Previous.pdf", resolved.path("annotated").read
    assert_equal replacement.generation, current_copy.generation
  end

  test "retired copies are cleaned only after their longest issued reference has expired" do
    first = prepare_copy("First.pdf")
    PublicationDownloadReference.issue(
      user: @user, publication: @publication, variant: "original", filename: first.filename,
      generation: first.generation, expires_in: 30.minutes
    )
    PublicationDownloadReference.issue(
      user: @user, publication: @publication, variant: "annotated", filename: first.name("annotated"),
      generation: first.generation, expires_in: 1.minute
    )
    second = prepare_copy("Second.pdf")
    travel 10.minutes
    third = prepare_copy("Third.pdf")
    assert first.directory.directory?
    assert second.directory.directory?

    travel 22.minutes
    fourth = prepare_copy("Fourth.pdf")
    assert_not first.directory.exist?
    assert_not second.directory.exist?
    assert third.directory.directory?
    assert_equal fourth.generation, current_copy.generation
  end

  test "a legacy annotated copy is found using the reader's own filename" do
    legacy = PublicationCopy.legacy(publication: @publication, user: @user)
    FileUtils.mkdir_p(legacy.directory)
    File.write(legacy.directory.join("Own-Name-Link.pdf"), "old annotated copy")

    copy = current_copy
    assert_nil copy.generation
    assert_equal "Own-Name-Link.pdf", copy.name("annotated")
    assert copy.available?("annotated")
    assert_not copy.available?("original")
    assert_nil @publication.pdf_download_url("https://example.test", @user)
    assert @publication.pdf_download_url_link("https://example.test", @user)
  end

  test "legacy download references retain access after a new copy is prepared" do
    legacy = PublicationCopy.legacy(publication: @publication, user: @user)
    FileUtils.mkdir_p(legacy.directory)
    File.write(legacy.path("annotated"), "legacy annotated")
    reference = PublicationDownloadReference.issue(user: @user, publication: @publication, variant: "annotated", filename: legacy.name("annotated"))
    prepare_copy("New.pdf")

    resolved = PublicationDownloadReference.resolve_copy(reference, publication: @publication, variant: "annotated", filename: legacy.name("annotated"))
    assert_nil resolved.generation
    assert_equal "legacy annotated", resolved.path("annotated").read
  end

  test "copy identifiers and metadata cannot select files outside their reader and publication" do
    copy = prepare_copy("Reader.pdf")

    assert_nil PublicationCopy.find(publication: @publication, user: @user, generation: "../../other")
    assert_nil PublicationCopy.find(publication: @publication, user: users(:two), generation: copy.generation)
    assert_nil PublicationCopy.find(publication: publications(:two), user: @user, generation: copy.generation)
    assert_nil PublicationCopy.legacy(publication: @publication, user: @user, filename: "../../Reader.pdf", variant: "original")
    File.write(copy.directory.join("copy.json"), JSON.generate(version: 1, filename: "../Reader.pdf"))
    assert_nil PublicationCopy.find(publication: @publication, user: @user, generation: copy.generation)
    assert_nil current_copy
  end

  private

  def current_copy
    PublicationCopy.current(publication: @publication, user: @user)
  end

  def prepare_copy(filename, user: @user)
    copy = nil
    Publication.transaction(requires_new: true) do |transaction|
      store = PublicationCopyStore.new(PublicationCopy.root_for(@publication, user))
      copy = store.prepare(publication: @publication, user: user, filename: filename, transaction: transaction) do |staged|
        File.write(staged.path("original"), "original #{filename}")
        File.write(staged.path("annotated"), "annotated #{filename}")
      end
    end
    copy
  end

end
