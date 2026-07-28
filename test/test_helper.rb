ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'

class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  def api_headers_for(user)
    ip_address = "127.0.0.1"
    token = JsonWebToken.encode(user_id: user.id, ip_address: ip_address)

    {
      "Authorization" => "Bearer #{token}",
      "REMOTE_ADDR" => ip_address
    }
  end
end
