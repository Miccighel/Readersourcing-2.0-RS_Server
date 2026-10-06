require "test_helper"

class RequestRateLimitingTest < ActionDispatch::IntegrationTest

  setup do
    @ip_address = "127.0.0.1"
  end

  test "limits authentication attempts by IP address" do
    policy = RequestRateLimit::AUTHENTICATION
    exhaust(policy, scope: "authentication", identity: RequestRateLimit.for_ip(request_from(@ip_address)))

    assert_no_difference("AuthenticationToken.count") do
      post authenticate_path,
        params: {email: users(:one).email, password: "password"},
        headers: {"REMOTE_ADDR" => @ip_address},
        as: :json
    end

    assert_rate_limited(policy)
  end

  test "limits password recovery by account without sending another email" do
    policy = RequestRateLimit::PASSWORD_RECOVERY_ACCOUNT
    exhaust(policy, scope: "passwords", identity: RequestRateLimit.for_account(users(:one).email))

    assert_no_emails do
      post forgot_path(format: :json),
        params: {email: users(:one).email},
        headers: {"REMOTE_ADDR" => @ip_address}
    end

    assert_rate_limited(policy)
  end

  test "limits password recovery by IP address across accounts" do
    policy = RequestRateLimit::PASSWORD_RECOVERY_IP
    exhaust(policy, scope: "passwords", identity: RequestRateLimit.for_ip(request_from(@ip_address)))

    assert_no_emails do
      post forgot_path(format: :json),
        params: {email: "another-reader@example.test"},
        headers: {"REMOTE_ADDR" => @ip_address}
    end

    assert_rate_limited(policy)
  end

  test "does not count the password recovery form as a recovery request" do
    ip_policy = RequestRateLimit::PASSWORD_RECOVERY_IP
    account_policy = RequestRateLimit::PASSWORD_RECOVERY_ACCOUNT
    exhaust(ip_policy, scope: "passwords", identity: RequestRateLimit.for_ip(request_from(@ip_address)))
    exhaust(account_policy, scope: "passwords", identity: RequestRateLimit.for_account(users(:one).email))

    get forgot_path,
      params: {email: users(:one).email},
      headers: {"REMOTE_ADDR" => @ip_address}

    assert_response :success
    assert_select "#password-forgot-form"
  end

  test "limits contact messages by IP address" do
    policy = RequestRateLimit::CONTACT
    exhaust(policy, scope: "application", identity: RequestRateLimit.for_ip(request_from(@ip_address)))

    assert_no_emails do
      post ask_path(format: :json),
        params: {email: "reader@example.test", message: "Hello"},
        headers: {"REMOTE_ADDR" => @ip_address},
        as: :json
    end

    assert_rate_limited(policy)
  end

  test "shares the PDF processing limit across expensive publication actions" do
    user = users(:one)
    policy = RequestRateLimit::PDF_PROCESSING
    exhaust(policy, scope: "publication_processing", identity: RequestRateLimit.for_user(user))

    post is_fetchable_publications_path(format: :json),
      params: {publication: {pdf_url: publications(:one).pdf_url}},
      headers: api_headers_for(user),
      as: :json

    assert_rate_limited(policy)
  end

  test "limits registration by IP before creating an account or sending mail" do
    policy = RequestRateLimit::REGISTRATION_IP
    exhaust(policy, scope: "users", identity: RequestRateLimit.for_ip(request_from(@ip_address)))

    assert_no_difference("User.count") do
      assert_no_emails do
        post users_url(format: :json),
          params: {user: {email: "new-reader@example.test", password: "password", password_confirmation: "password"}},
          headers: {"REMOTE_ADDR" => @ip_address},
          as: :json
      end
    end

    assert_rate_limited(policy)
  end

  test "limits registration by normalized address across IP addresses" do
    policy = RequestRateLimit::REGISTRATION_ACCOUNT
    exhaust(policy, scope: "users", identity: RequestRateLimit.for_account("reader@example.test"))

    assert_no_difference("User.count") do
      assert_no_emails do
        post users_url(format: :json),
          params: {user: {email: " Reader@Example.Test ", password: "password", password_confirmation: "password"}},
          headers: {"REMOTE_ADDR" => "192.0.2.25"},
          as: :json
      end
    end

    assert_rate_limited(policy)
  end

  test "does not count signup forms or confirmation links as registration attempts" do
    reader = users(:one)
    reader.update!(email_confirmed: false, confirm_token: "pending-confirmation-token")
    exhaust(RequestRateLimit::REGISTRATION_IP, scope: "users", identity: RequestRateLimit.for_ip(request_from(@ip_address)))
    exhaust(RequestRateLimit::REGISTRATION_ACCOUNT, scope: "users", identity: RequestRateLimit.for_account(reader.email))

    get sign_up_path, headers: {"REMOTE_ADDR" => @ip_address}
    assert_response :success
    assert_select "#sign-up-form"

    get confirm_path(reader.id, reader.confirm_token), headers: {"REMOTE_ADDR" => @ip_address}
    assert_response :created
    assert reader.reload.email_confirmed
  end

  test "stops pending confirmation resends when the authentication budget is exhausted" do
    reader = users(:one)
    reader.update!(email_confirmed: false, confirm_token: "pending-confirmation-token")
    policy = RequestRateLimit::AUTHENTICATION
    exhaust(policy, scope: "authentication", identity: RequestRateLimit.for_ip(request_from(@ip_address)))

    assert_no_difference("AuthenticationToken.count") do
      assert_no_emails do
        post authenticate_path,
          params: {email: reader.email, password: "password"},
          headers: {"REMOTE_ADDR" => @ip_address},
          as: :json
      end
    end

    assert_rate_limited(policy)
    assert_equal "pending-confirmation-token", reader.reload.confirm_token
    assert_not reader.email_confirmed
  end

  test "counts actual registration attempts and accepts them again after expiration" do
    policy = RequestRateLimit::REGISTRATION_ACCOUNT
    reader = users(:one)

    assert_no_emails do
      policy.requests.times do
        post users_url(format: :json),
          params: {user: {email: reader.email, password: "password", password_confirmation: "password"}},
          as: :json
        assert_response :unprocessable_entity
      end
      post users_url(format: :json), params: {user: {email: reader.email}}, as: :json
      assert_rate_limited(policy)

      travel policy.period + 1.second do
        post users_url(format: :json),
          params: {user: {email: reader.email, password: "password", password_confirmation: "password"}},
          as: :json
        assert_response :unprocessable_entity
      end
    end
  end

  private

  def assert_rate_limited(policy)
    assert_response :too_many_requests
    assert_equal policy.period.to_i.to_s, response.headers.fetch("Retry-After")
    assert_equal [I18n.t("errors.messages.too_many_requests")], response.parsed_body.fetch("errors")
  end

  def exhaust(policy, scope:, identity:)
    key = policy.cache_key(scope: scope, identity: identity)
    RequestRateLimit.store.write(key, policy.requests, expires_in: policy.period)
  end

  def request_from(ip_address)
    Struct.new(:remote_ip).new(ip_address)
  end

end
