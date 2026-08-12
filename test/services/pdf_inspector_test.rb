require "test_helper"
require "tempfile"

class PdfInspectorTest < ActiveSupport::TestCase

  test "reads metadata and page count from a valid PDF" do
    document = PdfInspector.new.call(file_fixture("Reader.pdf"))

    assert_equal 7, document.page_count
    assert_equal "Readersourcing\x84a manifesto".b, document.metadata[:Title].b
  end

  test "rejects a publication that already contains a rating URL" do
    reader = Struct.new(:info, :page_count).new({BaseUrl: "https://example.test/rate"}, 3)
    reader_class = Object.new
    reader_class.define_singleton_method(:new) { |_path| reader }

    assert_raises(PdfInspector::AlreadyAnnotated) do
      PdfInspector.new(reader_class: reader_class).call("publication.pdf")
    end
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
