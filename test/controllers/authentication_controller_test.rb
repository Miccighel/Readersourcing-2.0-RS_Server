require "test_helper"

class AuthenticationControllerTest < ActionDispatch::IntegrationTest
  test "authenticate returns an IP-bound signed token for valid credentials" do
    post authenticate_path, params: {
      email: users(:one).email,
      password: "password"
    }, headers: {"REMOTE_ADDR" => "127.0.0.1"}

    assert_response :success
    decoded_token = JsonWebToken.decode(response.parsed_body.fetch("auth_token"))
    assert_equal users(:one).id, decoded_token[:user_id]
    assert_equal "127.0.0.1", decoded_token[:ip_address]
  end

  test "authenticate rejects invalid credentials" do
    post authenticate_path, params: {
      email: users(:one).email,
      password: "incorrect"
    }

    assert_response :unauthorized
  end
end
