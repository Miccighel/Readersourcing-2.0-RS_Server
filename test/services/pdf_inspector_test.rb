require "test_helper"
require "tempfile"

class PdfInspectorTest < ActiveSupport::TestCase

  test "reads metadata and page count from a valid PDF" do
    document = PdfInspector.new.call(file_fixture("Reader.pdf"))

    assert_equal 7, document.page_count
    assert_equal "Readersourcing\x84a manifesto".b, document.metadata[:Title].b
  end

  test "rejects a publication that already contains a rating URL" do
    process = Object.new
    payload = JSON.generate(metadata: PdfInspectionProtocol.encode({BaseUrl: "https://example.test/rate"}), page_count: 3)
    process.define_singleton_method(:call) { |*_, **_| PdfProcess::Result.new(stdout: payload, status: Struct.new(:success?).new(true)) }

    assert_raises(PdfInspector::AlreadyAnnotated) do
      PdfInspector.new(process: process).call("publication.pdf")
    end
  end

  test "terminates an inspection process that cannot finish within its phase limit" do
    inspector = PdfInspector.new(timeout: 0.2, command_prefix: [RbConfig.ruby, "-e", "sleep 20", "--"])

    assert_raises(PdfInspector::InspectionTimeout) { inspector.call(file_fixture("Reader.pdf")) }
  end

  test "uses the remaining operation time even when the inspection limit is longer" do
    inspector = PdfInspector.new(timeout: 15, command_prefix: [RbConfig.ruby, "-e", "sleep 20", "--"])
    deadline = PdfOperationDeadline.new(timeout: 0.2)

    assert_raises(PdfInspector::InspectionTimeout) { inspector.call(file_fixture("Reader.pdf"), deadline: deadline) }
  end

  test "rejects an invalid response from the inspection worker" do
    inspector = PdfInspector.new(command_prefix: [RbConfig.ruby, "-e", "puts '{}'", "--"])

    assert_raises(PdfInspector::MalformedPdf) { inspector.call(file_fixture("Reader.pdf")) }
  end

  test "rejects a malformed PDF after the header check" do
    tempfile = Tempfile.new(["malformed", ".pdf"])
    tempfile.write("%PDF-this is not a document")
    tempfile.close

    assert_raises(PdfInspector::MalformedPdf) { PdfInspector.new.call(tempfile.path) }
  ensure
    tempfile&.unlink
  end

end
