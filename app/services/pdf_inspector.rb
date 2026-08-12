class PdfInspector

  class Error < RuntimeError; end
  class MalformedPdf < Error; end
  class EncryptedPdf < Error; end
  class UnsupportedPdf < Error; end
  class AlreadyAnnotated < Error; end

  Document = Struct.new(:metadata, :page_count, keyword_init: true)

  def initialize(reader_class: PDF::Reader)
    @reader_class = reader_class
  end

  def call(path, allow_annotated: false)
    reader = @reader_class.new(path)
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
