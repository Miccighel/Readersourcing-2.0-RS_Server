require "test_helper"

class CsrfProtectionTest < ActionDispatch::IntegrationTest
  setup do
    @previous_forgery_protection = ApplicationController.allow_forgery_protection
    ApplicationController.allow_forgery_protection = true
  end

  teardown do
    ApplicationController.allow_forgery_protection = @previous_forgery_protection
  end

  test "JSON API requests remain available without a CSRF token" do
    post authenticate_path, params: {
      email: users(:one).email,
      password: "password"
    }, headers: {"REMOTE_ADDR" => "127.0.0.1"}, as: :json

    assert_response :success
  end

  test "JSON request bodies remain available on the legacy extensionless path" do
    post authenticate_path,
      params: {
        email: users(:one).email,
        password: "password"
      }.to_json,
      headers: {
        "CONTENT_TYPE" => "application/json",
        "REMOTE_ADDR" => "127.0.0.1"
      }

    assert_response :success
  end

  test "a form-encoded request cannot bypass CSRF through a JSON path" do
    assert_raises(ActionController::InvalidAuthenticityToken) do
      post authenticate_path(format: :json), params: {
        email: users(:one).email,
        password: "password"
      }
    end
  end

  test "HTML state changes reject a missing CSRF token" do
    authenticate

    assert_raises(ActionController::InvalidAuthenticityToken) do
      post logout_path(format: :html)
    end
  end

  test "HTML state changes accept the session CSRF token" do
    authenticate
    get root_path
    authenticity_token = css_select("meta[name='csrf-token']").first["content"]

    post logout_path(format: :html), params: {authenticity_token: authenticity_token}

    assert_redirected_to root_path
    assert_nil session[:auth_token]
  end

  private

  def authenticate
    post authenticate_path, params: {
      email: users(:one).email,
      password: "password"
    }, headers: {"REMOTE_ADDR" => "127.0.0.1"}, as: :json
    assert_response :success
  end
end
