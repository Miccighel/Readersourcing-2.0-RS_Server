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
