require "test_helper"

class PublicBaseUrlTest < ActiveSupport::TestCase
  Request = Struct.new(:base_url)

  test "uses the configured public origin instead of the request host" do
    with_public_base_url("https://readersourcing.example") do
      public_url = PublicBaseUrl.for(Request.new("https://attacker.example"))

      assert_equal(
        "https://readersourcing.example/password/reset",
        public_url.join("/password/reset")
      )
    end
  end

  test "retains the request origin outside production when no origin is configured" do
    with_public_base_url(nil) do
      public_url = PublicBaseUrl.for(Request.new("http://localhost:3000"))

      assert_equal "http://localhost:3000/password/reset", public_url.join("password/reset")
    end
  end

  test "requires a configured origin in production" do
    with_public_base_url(nil) do
      environment = ActiveSupport::EnvironmentInquirer.new("production")

      assert_raises(PublicBaseUrl::ConfigurationError) do
        PublicBaseUrl.for(
          Request.new("https://attacker.example"),
          environment: environment
        )
      end
    end
  end

  test "rejects values that are not origins" do
    invalid_urls = [
      "javascript:alert(1)",
      "https://user:password@example.test",
      "https://example.test/readersourcing",
      "https://example.test?source=mail",
      "https://example.test#reset"
    ]

    invalid_urls.each do |url|
      assert_raises(PublicBaseUrl::ConfigurationError) { PublicBaseUrl.new(url) }
    end
  end

  private

  def with_public_base_url(value)
    previous_value = ENV["PUBLIC_BASE_URL"]
    value.nil? ? ENV.delete("PUBLIC_BASE_URL") : ENV["PUBLIC_BASE_URL"] = value
    yield
  ensure
    previous_value.nil? ? ENV.delete("PUBLIC_BASE_URL") : ENV["PUBLIC_BASE_URL"] = previous_value
  end
end
