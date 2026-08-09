require "test_helper"

class RequestRateLimitTest < ActiveSupport::TestCase

  test "uses opaque and normalized request identities" do
    first = RequestRateLimit.for_account(" Reader@Example.Test ")
    second = RequestRateLimit.for_account("reader@example.test")

    assert_equal first, second
    assert_not_includes first, "reader@example.test"
    assert_not_equal first, RequestRateLimit.for_user(users(:one))
  end

  test "provides bounded positive policies to Rails" do
    policies = [
      RequestRateLimit::AUTHENTICATION,
      RequestRateLimit::PASSWORD_RECOVERY_IP,
      RequestRateLimit::PASSWORD_RECOVERY_ACCOUNT,
      RequestRateLimit::CONTACT,
      RequestRateLimit::PDF_PROCESSING
    ]

    policies.each do |policy|
      assert_predicate policy.requests, :positive?
      assert_predicate policy.period, :positive?
      assert_same RequestRateLimit.store, policy.rails_options.fetch(:store)
    end
  end

end
