ENV['RAILS_ENV'] ||= 'test'
require 'tmpdir'
require 'fileutils'
TEST_PUBLICATION_STORAGE_ROOT = File.join(Dir.tmpdir, "rs_server_test_publications_#{Process.pid}")
ENV['RS_PDF_STORAGE_ROOT'] = TEST_PUBLICATION_STORAGE_ROOT
require_relative '../config/environment'
require 'rails/test_help'
require 'minitest/mock'

Minitest.after_run do
  FileUtils.rm_rf(TEST_PUBLICATION_STORAGE_ROOT)
end

class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  def api_token_for(user, ip_address: "127.0.0.1")
    authentication_token = AuthenticationToken.issue_for(user)
    JsonWebToken.encode(
      {
        user_id: user.id,
        ip_address: ip_address,
        jti: authentication_token.jti
      },
      authentication_token.expires_at
    )
  end

  def api_headers_for(user)
    ip_address = "127.0.0.1"
    token = api_token_for(user, ip_address: ip_address)

    {
      "Authorization" => "Bearer #{token}",
      "REMOTE_ADDR" => ip_address
    }
  end
end

class ActionDispatch::IntegrationTest
  setup do
    RequestRateLimit.store.clear
  end
end
