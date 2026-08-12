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

end
