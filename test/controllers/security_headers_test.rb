require "test_helper"

class SecurityHeadersTest < ActionDispatch::IntegrationTest
  test "HTML responses enforce the application security policy" do
    get root_path

    assert_response :success
    assert_security_headers
    assert_local_browser_dependencies
    assert_select "script[src*='table_export']", count: 0
  end

  test "JSON responses enforce the application security policy" do
    post authenticate_path,
      params: {
        email: users(:one).email,
        password: "incorrect"
      },
      headers: {"REMOTE_ADDR" => "127.0.0.1"},
      as: :json

    assert_response :unauthorized
    assert_security_headers
  end

  test "the table export exception is limited to authenticated list pages" do
    authenticate

    get publications_list_path

    assert_response :success
    assert_security_headers(allow_dynamic_evaluation: true)
    assert_local_browser_dependencies
    assert_select "script[src*='table_export']", count: 1

    post logout_path(format: :json), as: :json
    assert_response :success
  end

  private

  def assert_security_headers(allow_dynamic_evaluation: false)
    policy = response.headers.fetch("Content-Security-Policy")

    assert_includes policy, "default-src 'self'"
    assert_includes policy, "base-uri 'self'"
    assert_includes policy, "connect-src 'self'"
    assert_includes policy, "font-src 'self' data:"
    assert_includes policy, "form-action 'self'"
    assert_includes policy, "frame-ancestors 'none'"
    assert_includes policy, "object-src 'none'"
    assert_includes policy, "style-src 'self' 'unsafe-inline'"
    if allow_dynamic_evaluation
      assert_includes policy, "script-src 'self' 'unsafe-eval'"
    else
      assert_includes policy, "script-src 'self'"
      assert_not_includes policy, "'unsafe-eval'"
    end
    assert_not_includes policy, "cdnjs.cloudflare.com"
    assert_not_includes policy, "cdn.datatables.net"
    assert_not_includes policy, "fonts.googleapis.com"
    assert_not_includes policy, "use.fontawesome.com"

    assert_equal "DENY", response.headers["X-Frame-Options"]
    assert_equal "nosniff", response.headers["X-Content-Type-Options"]
    assert_equal "same-origin", response.headers["Referrer-Policy"]
    assert_equal "camera=(), display-capture=(), geolocation=(), microphone=(), payment=(), usb=()",
      response.headers["Permissions-Policy"]
  end

  def assert_local_browser_dependencies
    assert_select "link[rel='stylesheet'][href*='browser_dependencies']", count: 1
    assert_select "script[src*='browser_dependencies']", count: 1
    assert_select "link[rel='stylesheet'][href^='https://']", count: 0
    assert_select "script[src^='https://']", count: 0
  end

  def authenticate
    post authenticate_path,
      params: {
        email: users(:one).email,
        password: "password"
      },
      headers: {"REMOTE_ADDR" => "127.0.0.1"},
      as: :json

    assert_response :success
  end
end
