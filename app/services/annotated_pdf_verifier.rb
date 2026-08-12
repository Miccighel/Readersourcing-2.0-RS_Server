class AnnotatedPdfVerifier

  class VerificationError < RuntimeError; end

  def initialize(inspector: PdfInspector.new)
    @inspector = inspector
  end

  def call(path, source_page_count:, expected_url:)
    document = @inspector.call(path, allow_annotated: true)
    unless document.page_count == source_page_count + 1
      raise VerificationError, "The annotated publication does not contain the expected rating page"
    end
    unless document.metadata[:BaseUrl] == expected_url
      raise VerificationError, "The annotated publication does not contain the expected rating URL"
    end

    true
  rescue PdfInspector::Error => error
    raise VerificationError, "The annotated publication is not a valid PDF: #{error.message}"
  end

end
