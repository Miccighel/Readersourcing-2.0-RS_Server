require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "requires passwords to contain at least six characters" do
    user = User.new(
      first_name: "Grace",
      last_name: "Hopper",
      email: "grace@example.test",
      password: "short",
      password_confirmation: "short"
    )

    assert_not user.valid?
    assert user.errors.added?(:password, :too_short, count: 6)
  end

  test "stores a digest of a password reset token" do
    user = users(:one)

    token = user.generate_password_token!

    assert_not_equal token, user.reset_password_token
    assert_equal User.password_token_digest(token), user.reset_password_token
    assert_equal user, User.find_by_password_reset_token(token)
    assert user.password_token_valid?
  end
end
