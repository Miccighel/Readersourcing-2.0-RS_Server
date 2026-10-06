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
    assert_includes response.headers.fetch("Set-Cookie").downcase, "httponly"
    assert_predicate cookies[:authToken], :blank?
  end

  test "server-rendered pages expose only the session authentication state" do
    get login_path
    assert_select "meta[name='rs-authenticated'][content='false']"

    post authenticate_path, params: {
      email: users(:one).email,
      password: "password"
    }, headers: {"REMOTE_ADDR" => "127.0.0.1"}, as: :json
    get root_path

    assert_select "meta[name='rs-authenticated'][content='true']"
    assert_predicate cookies[:authToken], :blank?
  end

  test "legacy JavaScript authentication cookies are discarded" do
    cookies[:authToken] = "legacy-token"

    get root_path

    assert_predicate cookies[:authToken], :blank?
  end

  test "authenticate rejects invalid credentials" do
    post authenticate_path, params: {
      email: users(:one).email,
      password: "incorrect"
    }, as: :json

    assert_response :unauthorized
  end

  test "does not send a confirmation email for incorrect pending account credentials" do
    reader = users(:one)
    reader.update!(email_confirmed: false, confirm_token: "pending-confirmation-token")
    original_attributes = reader.attributes

    ["incorrect", nil, ""].each do |password|
      assert_no_difference("AuthenticationToken.count") do
        assert_no_emails do
          post authenticate_path, params: {email: reader.email, password: password}, as: :json
        end
      end
      assert_response :unauthorized
      assert_equal [I18n.t("errors.messages.invalid_credentials")], response.parsed_body.fetch("errors")
      assert_equal original_attributes, reader.reload.attributes
    end
  end

  test "resends the same pending confirmation only after checking the password" do
    reader = users(:one)
    reader.update!(email_confirmed: false, confirm_token: "pending-confirmation-token")

    assert_no_difference("AuthenticationToken.count") do
      assert_emails 1 do
        post authenticate_path, params: {email: reader.email, password: "password"}, as: :json
      end
    end

    assert_response :unauthorized
    assert_equal [I18n.t("errors.messages.unconfirmed_mail")], response.parsed_body.fetch("errors")
    assert_equal "pending-confirmation-token", reader.reload.confirm_token
    assert_not reader.email_confirmed
    assert_nil session[:auth_token]
  end

  test "reports confirmation delivery failure without authenticating or changing the pending reference" do
    reader = users(:one)
    reader.update!(email_confirmed: false, confirm_token: "pending-confirmation-token")
    delivery = Object.new
    delivery.define_singleton_method(:deliver_now) { raise Net::SMTPFatalError, "Private SMTP details" }

    assert_no_difference("AuthenticationToken.count") do
      UserMailer.stub(:registration_confirmation, ->(*) { delivery }) do
        assert_no_emails do
          post authenticate_path, params: {email: reader.email, password: "password"}, as: :json
        end
      end
    end

    assert_response :service_unavailable
    assert_equal "confirmation_delivery_failed", response.parsed_body.fetch("status")
    assert_equal [I18n.t("errors.messages.confirmation_delivery_unavailable")], response.parsed_body.fetch("errors")
    refute_includes response.body, "Private SMTP details"
    refute_includes response.body, "pending-confirmation-token"
    assert_nil session[:auth_token]
    assert_not reader.reload.email_confirmed
    assert_equal "pending-confirmation-token", reader.confirm_token
  end

  test "supplies a confirmation reference for a pending account without one" do
    reader = users(:one)
    reader.update!(email_confirmed: false, confirm_token: nil)

    assert_emails 1 do
      post authenticate_path, params: {email: reader.email, password: "password"}, as: :json
    end

    assert_response :unauthorized
    assert_predicate reader.reload.confirm_token, :present?
    assert_not reader.email_confirmed
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
