require "test_helper"

class AuthenticationTokenTest < ActiveSupport::TestCase
  test "issues a unique active identifier for a reader" do
    authentication_token = AuthenticationToken.issue_for(users(:one))

    assert authentication_token.jti.present?
    assert authentication_token.active?
    assert_equal users(:one), authentication_token.user
    assert_in_delta 168.hours.from_now.to_i, authentication_token.expires_at.to_i, 2
  end

  test "issuing a token removes expired records for the same reader" do
    expired_token = users(:one).authentication_tokens.create!(
      expires_at: 1.minute.ago
    )

    AuthenticationToken.issue_for(users(:one))

    assert_not AuthenticationToken.exists?(expired_token.id)
  end
end
