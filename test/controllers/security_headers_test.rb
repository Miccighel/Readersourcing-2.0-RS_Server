require "test_helper"

class SecurityHeadersTest < ActionDispatch::IntegrationTest
  test "HTML responses enforce the application security policy" do
    get root_path

    assert_response :success
    assert_security_headers
    assert_select "script[src*='pdfmake']", count: 0
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
    assert_select "script[src*='pdfmake']", count: 2

    post logout_path(format: :json), as: :json
    assert_response :success
  end

  private

  def assert_security_headers(allow_dynamic_evaluation: false)
    policy = response.headers.fetch("Content-Security-Policy")

    assert_includes policy, "default-src 'self'"
    assert_includes policy, "base-uri 'self'"
    assert_includes policy, "connect-src 'self'"
    assert_includes policy, "form-action 'self'"
    assert_includes policy, "frame-ancestors 'none'"
    assert_includes policy, "object-src 'none'"
    assert_includes policy, "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com https://use.fontawesome.com https://cdn.datatables.net"
    if allow_dynamic_evaluation
      assert_includes policy, "script-src 'self' 'unsafe-eval' https://cdnjs.cloudflare.com https://cdn.datatables.net"
    else
      assert_includes policy, "script-src 'self' https://cdnjs.cloudflare.com https://cdn.datatables.net"
      assert_not_includes policy, "'unsafe-eval'"
    end

    assert_equal "DENY", response.headers["X-Frame-Options"]
    assert_equal "nosniff", response.headers["X-Content-Type-Options"]
    assert_equal "same-origin", response.headers["Referrer-Policy"]
    assert_equal "camera=(), display-capture=(), geolocation=(), microphone=(), payment=(), usb=()",
      response.headers["Permissions-Policy"]
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
