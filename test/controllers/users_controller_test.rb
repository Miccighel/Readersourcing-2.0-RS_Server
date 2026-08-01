require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @headers = api_headers_for(@user)
  end

  test "should get index" do
    get users_url(format: :json), headers: @headers

    assert_response :success
    assert_equal 2, response.parsed_body.length
    response.parsed_body.each do |reader|
      assert reader.key?("score")
      assert_not reader.key?("email")
      assert_not reader.key?("subscribe")
    end
  end

  test "should create user" do
    assert_difference("User.count") do
      post users_url(format: :json), params: {
        user: {
          email: "grace@example.test",
          first_name: "Grace",
          last_name: "Hopper",
          password: "a-secure-password",
          password_confirmation: "a-secure-password"
        }
      }, as: :json
    end

    assert_response :created
  end

  test "should show user" do
    get user_url(@user, format: :json), headers: @headers

    assert_response :success
    assert_equal @user.first_name, response.parsed_body.fetch("first_name")
    assert_not response.parsed_body.key?("email")
    assert_not response.parsed_body.key?("subscribe")
  end

  test "info should expose only the current user's private profile" do
    post info_users_url(format: :json), headers: @headers

    assert_response :success
    assert_equal @user.id, response.parsed_body.fetch("id")
    assert_equal @user.email, response.parsed_body.fetch("email")
    assert_equal @user.subscribe, response.parsed_body.fetch("subscribe")
    assert_not response.parsed_body.key?("password_digest")
    assert_not response.parsed_body.key?("confirm_token")
    assert_not response.parsed_body.key?("reset_password_token")
  end

  test "should update user" do
    patch user_url(@user, format: :json),
      params: { user: { last_name: "Byron" } },
      headers: @headers,
      as: :json

    assert_response :ok
    assert_equal "Byron", @user.reload.last_name
  end

  test "should not update another user" do
    other_user = users(:two)

    patch user_url(other_user, format: :json),
      params: { user: { last_name: "Byron" } },
      headers: @headers,
      as: :json

    assert_response :not_found
    assert_equal "Turing", other_user.reload.last_name
  end

  test "profile update should not accept credentials" do
    original_email = @user.email
    original_password_digest = @user.password_digest

    patch user_url(@user, format: :json),
      params: {
        user: {
          email: "changed@example.test",
          password: "changed-password",
          password_confirmation: "changed-password"
        }
      },
      headers: @headers,
      as: :json

    assert_response :ok
    assert_equal original_email, @user.reload.email
    assert_equal original_password_digest, @user.password_digest
  end

  test "should destroy user" do
    assert_difference("User.count", -1) do
      assert_difference("AuthenticationToken.count", -1) do
        delete user_url(@user, format: :json), headers: @headers
      end
    end

    assert_response :no_content
  end

  test "should not destroy another user" do
    other_user = users(:two)

    assert_no_difference("User.count") do
      delete user_url(other_user, format: :json), headers: @headers
    end

    assert_response :not_found
    assert User.exists?(other_user.id)
  end
end
