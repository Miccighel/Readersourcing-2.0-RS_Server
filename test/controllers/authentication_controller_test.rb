require "test_helper"

class AuthenticationControllerTest < ActionDispatch::IntegrationTest
  test "authenticate returns an IP-bound signed token for valid credentials" do
    get root_path
    initial_session_id = session.id

    post authenticate_path, params: {
      email: users(:one).email,
      password: "password"
    }, headers: {"REMOTE_ADDR" => "127.0.0.1"}, as: :json

    assert_response :success
    decoded_token = JsonWebToken.decode(response.parsed_body.fetch("auth_token"))
    assert_equal users(:one).id, decoded_token[:user_id]
    assert_equal "127.0.0.1", decoded_token[:ip_address]
    assert_not_equal initial_session_id, session.id
    assert_equal response.parsed_body.fetch("auth_token"), session[:auth_token]
  end

  test "authenticate rejects invalid credentials" do
    post authenticate_path, params: {
      email: users(:one).email,
      password: "incorrect"
    }, as: :json

    assert_response :unauthorized
  end

  test "logout clears and renews the server session" do
    post authenticate_path, params: {
      email: users(:one).email,
      password: "password"
    }, headers: {"REMOTE_ADDR" => "127.0.0.1"}, as: :json
    authenticated_session_id = session.id

    post logout_path(format: :json), as: :json

    assert_response :success
    assert_nil session[:auth_token]
    assert_not_equal authenticated_session_id, session.id
  end

  test "logout is not available through GET" do
    assert_raises(ActionController::RoutingError) do
      get "/logout"
    end
  end
end
