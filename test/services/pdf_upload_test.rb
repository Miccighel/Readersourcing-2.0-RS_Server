require "test_helper"
require "tempfile"

class PdfUploadTest < ActiveSupport::TestCase

  UploadedFile = Struct.new(:tempfile, :original_filename, :content_type)

  test "copies a PDF into a bounded server owned temporary file" do
    source = Tempfile.new(["source", ".pdf"])
    source.binmode
    source.write("%PDF-1.7")
    source.rewind
    file = UploadedFile.new(source, "../../Reader notes.PDF", "application/octet-stream")

    download = PdfUpload.new(file).fetch

    assert_equal "%PDF-1.7", download.io.read
    assert_equal "Reader-notes.pdf", download.filename
    assert_equal 8, download.content_length
  ensure
    download&.close
    source&.close!
  end

  test "rejects missing, oversized, and non PDF uploads" do
    assert_raises(PdfUpload::MissingFile) { PdfUpload.new(nil).fetch }

    oversized = uploaded_file("%PDF-123", "large.pdf")
    assert_raises(PdfUpload::UploadTooLarge) do
      PdfUpload.new(oversized, max_bytes: 7).fetch
    end

    invalid = uploaded_file("not a pdf", "notes.txt")
    assert_raises(PdfUpload::NotPdf) { PdfUpload.new(invalid).fetch }
  ensure
    oversized&.tempfile&.close!
    invalid&.tempfile&.close!
  end

  private

  def uploaded_file(content, name)
    tempfile = Tempfile.new("pdf-upload-test")
    tempfile.binmode
    tempfile.write(content)
    tempfile.rewind
    UploadedFile.new(tempfile, name, "application/pdf")
  end

end
