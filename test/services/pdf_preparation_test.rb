require "test_helper"
require "tmpdir"

class PdfPreparationTest < ActiveSupport::TestCase

  setup do
    @storage = Dir.mktmpdir("rs-preparation-pair-")
    @original = File.join(@storage, "original.pdf")
    @annotated = File.join(@storage, "annotated.pdf")
    @download = Struct.new(:io).new(Struct.new(:path).new(file_fixture("Reader.pdf").to_s))
    @inspector = Object.new
    @inspector.define_singleton_method(:call) { |_, **_| PdfInspector::Document.new(metadata: {Title: "Reader"}, page_count: 8) }
    @runner = Object.new
    @runner.define_singleton_method(:call) do |expected_output:, **_arguments|
      File.write(expected_output, "verified annotated PDF")
      RsPdfRunner::Result.new(stdout: "converted")
    end
    @verifier = Object.new
    @verifier.define_singleton_method(:call) { |*_, **_| true }
  end

  teardown do
    FileUtils.remove_entry_secure(@storage)
  end

  test "retains exactly the source bytes and promotes the annotated file after verification" do
    metadata = nil
    result = prepare { |value| metadata = value }

    assert_equal File.binread(file_fixture("Reader.pdf")), File.binread(@original)
    assert_equal "verified annotated PDF", File.read(@annotated)
    assert_equal({Title: "Reader"}, metadata)
    assert_equal "converted", result.stdout
    assert_empty Dir.glob(File.join(@storage, "rs-pdf-*"))
  end

  test "a failed final verification does not change targets or publication metadata" do
    File.write(@original, "previous original")
    File.write(@annotated, "previous annotated")
    metadata = []
    @verifier.define_singleton_method(:call) { |*_, **_| raise AnnotatedPdfVerifier::VerificationError, "Verification failed" }

    assert_raises(AnnotatedPdfVerifier::VerificationError) { prepare { |value| metadata << value } }

    assert_equal "previous original", File.read(@original)
    assert_equal "previous annotated", File.read(@annotated)
    assert_empty metadata
    assert_empty Dir.glob(File.join(@storage, "rs-pdf-*"))
  end

  test "successive phases consume the same deadline without promoting an expired pair" do
    now = 0.0
    deadline = PdfOperationDeadline.new(timeout: 10, clock: -> { now })
    @inspector.define_singleton_method(:call) do |_, deadline:|
      now += 4
      deadline.check!
      PdfInspector::Document.new(metadata: {Title: "Reader"}, page_count: 8)
    end
    @runner.define_singleton_method(:call) do |expected_output:, deadline:, **_|
      now += 4
      deadline.check!
      File.write(expected_output, "annotated PDF")
      RsPdfRunner::Result.new(stdout: "converted")
    end
    @verifier.define_singleton_method(:call) do |_, deadline:, **_|
      now += 4
      deadline.check!
    end
    metadata = []
    File.write(@original, "previous original")
    File.write(@annotated, "previous annotated")

    assert_raises(PdfOperationDeadline::Exceeded) do
      prepare(deadline: deadline) { |value| metadata << value }
    end

    assert_empty metadata
    assert_equal "previous original", File.read(@original)
    assert_equal "previous annotated", File.read(@annotated)
    assert_empty Dir.glob(File.join(@storage, "rs-pdf-*"))
  end

  private

  def prepare(deadline: PdfOperationDeadline.new, &block)
    PdfPreparation.new(runner: @runner, inspector: @inspector, verifier: @verifier).call(
      download: @download, storage_path: @storage, original_path: @original,
      target_path: @annotated, rate_path: "https://example.test/rate/1/reference", deadline: deadline, &block
    )
  end

end
