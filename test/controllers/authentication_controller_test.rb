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
    assert decoded_token[:jti].present?
    assert AuthenticationToken.exists?(jti: decoded_token[:jti], user: users(:one))
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
    auth_token = response.parsed_body.fetch("auth_token")
    jti = JsonWebToken.decode(auth_token)[:jti]
    authenticated_session_id = session.id

    post logout_path(format: :json), as: :json

    assert_response :success
    assert_nil session[:auth_token]
    assert_not_equal authenticated_session_id, session.id
    assert_not AuthenticationToken.exists?(jti: jti)
    assert_nil Authorizer.new(auth_token, "127.0.0.1").call.result
  end

  test "logout revokes only the supplied token" do
    first_token = api_token_for(users(:one))
    second_token = api_token_for(users(:one))
    first_jti = JsonWebToken.decode(first_token)[:jti]
    second_jti = JsonWebToken.decode(second_token)[:jti]

    post logout_path(format: :json),
      headers: {
        "Authorization" => "Bearer #{first_token}",
        "REMOTE_ADDR" => "127.0.0.1"
      },
      as: :json

    assert_response :success
    assert_not AuthenticationToken.exists?(jti: first_jti)
    assert AuthenticationToken.exists?(jti: second_jti)
    assert_equal users(:one).id, JsonWebToken.decode(first_token)[:user_id]
    assert_nil Authorizer.new(first_token, "127.0.0.1").call.result
    assert_equal users(:one), Authorizer.new(second_token, "127.0.0.1").call.result
  end

  test "logout is not available through GET" do
    assert_raises(ActionController::RoutingError) do
      get "/logout"
    end
  end
end
