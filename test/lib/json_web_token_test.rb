require "test_helper"

class JsonWebTokenTest < ActiveSupport::TestCase
  test "round trips an HS256 token with its expiration" do
    token = JsonWebToken.encode({user_id: users(:one).id}, 10.minutes.from_now)

    decoded = JsonWebToken.decode(token)

    assert_equal users(:one).id, decoded[:user_id]
    assert decoded[:expiration_time].present?
    assert decoded[:exp].present?
  end

  test "rejects an unsigned token" do
    token = JWT.encode({user_id: users(:one).id}, nil, "none")

    assert_nil JsonWebToken.decode(token)
  end

  test "rejects an expired token" do
    token = JsonWebToken.encode({user_id: users(:one).id}, 1.minute.ago)

    assert_nil JsonWebToken.decode(token)
  end
end
