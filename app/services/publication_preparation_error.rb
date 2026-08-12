class PublicationPreparationError < RuntimeError

  attr_reader :code, :http_status

  def initialize(code:, message:, http_status: :unprocessable_entity)
    @code = code
    @http_status = http_status
    super(message)
  end

  def self.wrap(error)
    code, message_key, http_status = details_for(error)
    new(
      code: code,
      message: I18n.t("errors.messages.#{message_key}"),
      http_status: http_status
    )
  end

  def self.details_for(error)
    case error
    when PdfFetcher::InvalidUrl
      [:invalid_url, :invalid_publication_url, :unprocessable_entity]
    when PdfFetcher::UnsafeAddress
      [:unsafe_url, :unsafe_publication_url, :unprocessable_entity]
    when PdfFetcher::AuthenticationRequired
      [:authentication_required, :publication_authentication_required, :unprocessable_entity]
    when PdfFetcher::DownloadTooLarge, PdfUpload::UploadTooLarge
      [:too_large, :publication_too_large, :payload_too_large]
    when PdfFetcher::NotPdf, PdfUpload::NotPdf
      [:not_pdf, :publication_not_pdf, :unsupported_media_type]
    when PdfFetcher::DownloadUnavailable, PdfFetcher::InvalidResponse
      [:download_failed, :publication_download_failed, :unprocessable_entity]
    when PdfUpload::MissingFile
      [:upload_missing, :pdf_not_uploaded, :unprocessable_entity]
    when PdfInspector::EncryptedPdf
      [:encrypted_pdf, :publication_encrypted_pdf, :unprocessable_entity]
    when PdfInspector::UnsupportedPdf
      [:unsupported_pdf, :publication_unsupported_pdf, :unprocessable_entity]
    when PdfInspector::MalformedPdf
      [:malformed_pdf, :publication_malformed_pdf, :unprocessable_entity]
    when PdfInspector::AlreadyAnnotated
      [:already_annotated, :publication_already_fetched, :unprocessable_entity]
    when RsPdfRunner::ExecutionError
      [:annotation_failed, :publication_annotation_failed, :unprocessable_entity]
    when AnnotatedPdfVerifier::VerificationError
      [:verification_failed, :publication_verification_failed, :unprocessable_entity]
    else
      raise error
    end
  end

  private_class_method :details_for

end
