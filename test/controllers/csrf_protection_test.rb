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

  test "unsubscribe confirmation protects the profile change" do
    authenticate

    assert_raises(ActionController::InvalidAuthenticityToken) do
      post unsubscribe_path(users(:one))
    end
    assert users(:one).reload.subscribe

    get unsubscribe_path(users(:one))
    authenticity_token = css_select("input[name='authenticity_token']").first["value"]
    post unsubscribe_path(users(:one)), params: {authenticity_token: authenticity_token}

    assert_response :success
    assert_not users(:one).reload.subscribe
  end

  test "session-authenticated JSON requests reject a missing CSRF token" do
    authenticate

    assert_raises(ActionController::InvalidAuthenticityToken) do
      post info_users_path(format: :json), as: :json
    end
  end

  test "session-authenticated JSON requests accept the page CSRF token" do
    authenticate
    get root_path
    authenticity_token = css_select("meta[name='csrf-token']").first["content"]

    post info_users_path(format: :json),
      headers: {"X-CSRF-Token" => authenticity_token},
      as: :json

    assert_response :success
    assert_equal users(:one).id, response.parsed_body.fetch("id")
  end

  test "bearer-authenticated JSON requests remain stateless" do
    authenticate
    bearer_headers = api_headers_for(users(:one))

    post info_users_path(format: :json), headers: bearer_headers, as: :json

    assert_response :success
    assert_equal users(:one).id, response.parsed_body.fetch("id")
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
