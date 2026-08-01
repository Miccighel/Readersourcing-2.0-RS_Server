require "test_helper"
require "uri"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @headers = api_headers_for(@user)
    ActionMailer::Base.deliveries.clear
  end

  test "update verifies the current password through has_secure_password" do
    assert_emails 1 do
      post password_update_path(format: :json), params: {
        current_password: "password",
        new_password: "Updated-password-1",
        new_password_confirmation: "Updated-password-1"
      }, headers: @headers
    end

    assert_response :success
    assert @user.reload.authenticate("Updated-password-1")
  end

  test "update rejects an incorrect current password" do
    post password_update_path(format: :json), params: {
      current_password: "incorrect",
      new_password: "Updated-password-1",
      new_password_confirmation: "Updated-password-1"
    }, headers: @headers

    assert_response :unprocessable_entity
    assert @user.reload.authenticate("password")
    assert_empty ActionMailer::Base.deliveries
  end

  test "forgot sends a one-time reset link without revealing the stored token" do
    post forgot_path(format: :json), params: {email: @user.email}

    assert_response :success
    assert_equal 1, ActionMailer::Base.deliveries.length

    reset_token = reset_token_from(ActionMailer::Base.deliveries.last)
    assert reset_token.present?
    assert_not_equal reset_token, @user.reload.reset_password_token
    assert_equal User.password_token_digest(reset_token), @user.reset_password_token
  end

  test "forgot does not disclose whether an email address is registered" do
    post forgot_path(format: :json), params: {email: "missing@example.test"}

    assert_response :success
    assert_equal I18n.t("confirmations.messages.reset_mail_sent"), response.parsed_body.fetch("message")
    assert_empty ActionMailer::Base.deliveries
  end

  test "reset lets the reader choose a password and consumes the token" do
    reset_token = @user.generate_password_token!

    get reset_path(email: @user.email, reset_token: reset_token)

    assert_response :success
    assert_select "form[action='#{reset_path}'][method='post']"
    assert_select "input[name='new_password']"
    assert_select "input[name='new_password_confirmation']"

    new_password = "New-password-1"
    assert_emails 1 do
      post reset_path, params: {
        email: @user.email,
        reset_token: reset_token,
        new_password: new_password,
        new_password_confirmation: new_password
      }
    end

    assert_response :success
    assert @user.reload.authenticate(new_password)
    assert_nil @user.reset_password_token
    assert_nil @user.reset_password_sent_at
    assert_not_includes ActionMailer::Base.deliveries.last.body.decoded, new_password

    post reset_path, params: {
      email: @user.email,
      reset_token: reset_token,
      new_password: "Another-password-1",
      new_password_confirmation: "Another-password-1"
    }

    assert_response :not_found
  end

  test "reset preserves a valid token when the passwords do not match" do
    reset_token = @user.generate_password_token!

    post reset_path, params: {
      email: @user.email,
      reset_token: reset_token,
      new_password: "New-password-1",
      new_password_confirmation: "Different-password-1"
    }

    assert_response :unprocessable_entity
    assert @user.reload.authenticate("password")
    assert_equal User.password_token_digest(reset_token), @user.reset_password_token
    assert_empty ActionMailer::Base.deliveries
  end

  test "reset rejects an expired token" do
    reset_token = @user.generate_password_token!
    @user.update_column(:reset_password_sent_at, 5.hours.ago)

    get reset_path(email: @user.email, reset_token: reset_token)

    assert_response :not_found
  end

  private

  def reset_token_from(mail)
    reset_url = mail.body.decoded[%r{href="([^"]+/password/reset\?[^"]+)"}, 1]
    Rack::Utils.parse_nested_query(URI.parse(reset_url).query).fetch("reset_token")
  end
end
