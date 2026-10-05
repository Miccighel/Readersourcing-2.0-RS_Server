require "test_helper"

class PublicationPreparationErrorTest < ActiveSupport::TestCase

  test "preserves a stable state and HTTP status for the user interface" do
    authentication_error = PublicationPreparationError.wrap(
      PdfFetcher::AuthenticationRequired.new("remote detail")
    )
    size_error = PublicationPreparationError.wrap(
      PdfUpload::UploadTooLarge.new("remote detail")
    )

    assert_equal :authentication_required, authentication_error.code
    assert_equal :unprocessable_entity, authentication_error.http_status
    assert_equal :too_large, size_error.code
    assert_equal :payload_too_large, size_error.http_status
    assert_not_includes authentication_error.message, "remote detail"
  end

  test "reports the same timeout state regardless of the phase that exhausted its budget" do
    [PdfOperationDeadline::Exceeded, PdfFetcher::DownloadTimeout, PdfInspector::InspectionTimeout, RsPdfRunner::ExecutionTimeout].each do |type|
      error = PublicationPreparationError.wrap(type.new("internal detail"))
      assert_equal :processing_timeout, error.code
      assert_equal :unprocessable_entity, error.http_status
      assert_equal I18n.t("errors.messages.publication_processing_timeout"), error.message
      assert_not_includes error.message, "internal detail"
    end
  end

end
