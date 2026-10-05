require "rbconfig"
require_relative "../../lib/pdf_inspection_protocol"

class PdfInspector

  class Error < RuntimeError; end
  class MalformedPdf < Error; end
  class EncryptedPdf < Error; end
  class UnsupportedPdf < Error; end
  class AlreadyAnnotated < Error; end
  class InspectionTimeout < Error; end

  Document = Struct.new(:metadata, :page_count, keyword_init: true)

  DEFAULT_TIMEOUT = 15

  def initialize(timeout: ENV.fetch("RS_PDF_INSPECTION_TIMEOUT", DEFAULT_TIMEOUT), process: PdfProcess.new, command_prefix: nil)
    @timeout = timeout
    @process = process
    @command_prefix = command_prefix || [RbConfig.ruby, Rails.root.join("lib", "pdf_inspection_worker.rb").to_s]
  end

  def call(path, allow_annotated: false, deadline: PdfOperationDeadline.new)
    result = @process.call(@command_prefix + [path.to_s, allow_annotated.to_s], deadline: deadline.limit(@timeout))
    payload = JSON.parse(result.stdout)
    raise MalformedPdf, "Invalid PDF inspection response" unless payload.is_a?(Hash)

    errors = [MalformedPdf, EncryptedPdf, UnsupportedPdf, AlreadyAnnotated]
    error_class = errors.find { |type| type.name.split("::").last == payload["error"] }
    raise error_class, payload["message"].to_s if error_class
    raise MalformedPdf, "PDF inspection failed" unless result.status.success?

    metadata = PdfInspectionProtocol.decode(payload.fetch("metadata"))
    page_count = payload.fetch("page_count")
    unless metadata.is_a?(Hash) && page_count.is_a?(Integer) && page_count >= 0
      raise MalformedPdf, "Invalid PDF inspection response"
    end
    raise AlreadyAnnotated, "The publication already contains a Readersourcing rating URL" if !allow_annotated && metadata.key?(:BaseUrl)
    deadline.check!
    Document.new(metadata: metadata, page_count: page_count)
  rescue PdfOperationDeadline::Exceeded => error
    raise InspectionTimeout, error.message
  rescue JSON::ParserError, KeyError, ArgumentError, PdfProcess::OutputTooLarge, Errno::ENOENT => error
    raise MalformedPdf, "PDF inspection failed: #{error.message}"
  end

  def self.read(path, allow_annotated: false, reader_class: PDF::Reader)
    reader = reader_class.new(path)
    metadata = reader.info
    if !allow_annotated && metadata.key?(:BaseUrl)
      raise AlreadyAnnotated, "The publication already contains a Readersourcing rating URL"
    end

    Document.new(metadata: metadata, page_count: reader.page_count)
  rescue PDF::Reader::EncryptedPDFError => error
    raise EncryptedPdf, error.message
  rescue PDF::Reader::UnsupportedFeatureError => error
    raise UnsupportedPdf, error.message
  rescue PDF::Reader::MalformedPDFError, PDF::Reader::InvalidObjectError,
         PDF::Reader::InvalidPageError, ArgumentError => error
    raise MalformedPdf, error.message
  end

end
