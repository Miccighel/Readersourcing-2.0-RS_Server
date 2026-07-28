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
    assert_equal @user.email, response.parsed_body.fetch("email")
  end

  test "should update user" do
    patch user_url(@user, format: :json),
      params: { user: { last_name: "Byron" } },
      headers: @headers,
      as: :json

    assert_response :ok
    assert_equal "Byron", @user.reload.last_name
  end

  test "should destroy user" do
    assert_difference("User.count", -1) do
      delete user_url(@user, format: :json), headers: @headers
    end

    assert_response :no_content
  end
end
