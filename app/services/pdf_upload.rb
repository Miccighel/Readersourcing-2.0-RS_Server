require "tempfile"

class PdfUpload

  class Error < RuntimeError; end
  class MissingFile < Error; end
  class UploadTooLarge < Error; end
  class NotPdf < Error; end

  DEFAULT_MAX_BYTES = PdfFetcher::DEFAULT_MAX_BYTES
  BUFFER_SIZE = 16 * 1024

  def initialize(file, max_bytes: Integer(ENV.fetch("RS_PDF_MAX_DOWNLOAD_BYTES", DEFAULT_MAX_BYTES)))
    @file = file
    @max_bytes = max_bytes
  end

  def fetch
    raise MissingFile, "No publication file was uploaded" if @file.blank?

    tempfile = Tempfile.new(["rs-server-upload-", ".pdf"])
    tempfile.binmode
    bytes_written = copy_to(tempfile)

    raise NotPdf, "The uploaded file is empty" if bytes_written.zero?

    tempfile.flush
    tempfile.rewind
    unless tempfile.read(1024).include?("%PDF-")
      raise NotPdf, "The uploaded file does not contain a PDF header"
    end
    tempfile.rewind

    PdfFetcher::Download.new(
      io: tempfile,
      content_type: @file.content_type.to_s,
      content_length: bytes_written,
      filename: safe_filename,
      source_url: nil
    )
  rescue
    tempfile&.close! unless tempfile&.closed?
    raise
  end

  private

  def copy_to(tempfile)
    source = @file.tempfile
    source.binmode
    source.rewind
    bytes_written = 0

    while (chunk = source.read(BUFFER_SIZE))
      bytes_written += chunk.bytesize
      if bytes_written > @max_bytes
        raise UploadTooLarge, "The uploaded publication exceeds the configured size limit"
      end
      tempfile.write(chunk)
    end

    bytes_written
  ensure
    source&.rewind
  end

  def safe_filename
    "#{Publication.safe_pdf_stem(@file.original_filename)}.pdf"
  end

end
