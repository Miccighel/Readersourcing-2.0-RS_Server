require "test_helper"
require "tmpdir"
require "timeout"

class PublicationCopyConcurrencyTest < ActiveSupport::TestCase

  self.use_transactional_tests = false

  setup do
    @publication = publications(:one)
    @user = users(:one)
    @storage_root = Dir.mktmpdir("rs-copy-concurrency-")
    @previous_storage_root = ENV["RS_PDF_STORAGE_ROOT"]
    ENV["RS_PDF_STORAGE_ROOT"] = @storage_root
    @root = PublicationCopy.root_for(@publication, @user)
    @threads = []
  end

  teardown do
    @threads.each do |thread|
      thread.kill if thread.alive?
      thread.join
    end
    @previous_storage_root.nil? ? ENV.delete("RS_PDF_STORAGE_ROOT") : ENV["RS_PDF_STORAGE_ROOT"] = @previous_storage_root
    FileUtils.remove_entry_secure(@storage_root)
  end

  test "the pair becomes current only after the outer transaction commits" do
    copy = nil
    Publication.transaction do |transaction|
      copy = prepare("Reader.pdf", transaction)
      assert copy.available?("original")
      assert copy.available?("annotated")
      assert_not @root.join("current").exist?
      assert_not @publication.is_saved_for_later(@user)
    end

    assert_equal copy.generation, PublicationCopy.current(publication: @publication, user: @user).generation
    assert @publication.is_saved_for_later(@user)
  end

  test "an outer rollback removes its staged pair and retains the previous current copy" do
    previous = nil
    Publication.transaction { |transaction| previous = prepare("Previous.pdf", transaction) }
    rejected = nil

    Publication.transaction do |transaction|
      rejected = prepare("Rejected.pdf", transaction)
      raise ActiveRecord::Rollback
    end

    assert_not rejected.directory.exist?
    assert previous.available?("original")
    assert previous.available?("annotated")
    assert_equal previous.generation, PublicationCopy.current(publication: @publication, user: @user).generation
  end

  test "simultaneous preparations publish complete pairs and preserve both generation references" do
    ready = Queue.new
    start = Queue.new
    @threads = ["First.pdf", "Second.pdf"].map do |filename|
      Thread.new do
        Thread.current.report_on_exception = false
        ActiveRecord::Base.connection_pool.with_connection do
          copy = nil
          Publication.transaction do |transaction|
            copy = prepare(filename, transaction) do
              ready << true
              Timeout.timeout(5) { start.pop }
            end
          end
          copy
        end
      end
    end
    Timeout.timeout(5) { 2.times { ready.pop } }
    2.times { start << true }
    copies = @threads.map do |thread|
      raise "Copy worker did not finish" unless thread.join(10)
      thread.value
    end

    assert_equal 2, copies.map(&:generation).uniq.length
    copies.each do |copy|
      assert_equal "original #{copy.filename}", copy.path("original").read
      assert_equal "annotated #{copy.filename}", copy.path("annotated").read
      reference = PublicationDownloadReference.issue(
        user: @user, publication: @publication, generation: copy.generation,
        filename: copy.filename, variant: "original"
      )
      resolved = PublicationDownloadReference.resolve_copy(reference, publication: @publication, filename: copy.filename, variant: "original")
      assert_equal copy.generation, resolved.generation
    end
    current = PublicationCopy.current(publication: @publication, user: @user)
    assert_includes copies.map(&:generation), current.generation
    assert current.available?("original")
    assert current.available?("annotated")
    assert_empty @root.glob("rs-copy-*")
  end

  private

  def prepare(filename, transaction)
    PublicationCopyStore.new(@root).prepare(publication: @publication, user: @user, filename: filename, transaction: transaction) do |staged|
      File.write(staged.path("original"), "original #{filename}")
      File.write(staged.path("annotated"), "annotated #{filename}")
      yield if block_given?
    end
  end

end
