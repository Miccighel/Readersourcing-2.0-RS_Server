require "test_helper"

class PublicationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @publication = publications(:one)
    @user = users(:one)
    @headers = api_headers_for(@user)
  end

  test "should get index" do
    get publications_url(format: :json), headers: @headers

    assert_response :success
    assert_equal 2, response.parsed_body.length
  end

  test "should reject an unauthenticated request" do
    get publications_url(format: :json), headers: { "Authorization" => "Bearer invalid" }

    assert_response :unauthorized
  end

  test "should reject a request without an authorization header" do
    get publications_url(format: :json)

    assert_response :unauthorized
  end

  test "should reject an unsupported authorization scheme" do
    get publications_url(format: :json), headers: { "Authorization" => "Basic invalid" }

    assert_response :unauthorized
  end

  test "should preserve the extension raw token contract" do
    raw_token = @headers.fetch("Authorization").delete_prefix("Bearer ")
    get publications_url(format: :json), headers: @headers.merge("Authorization" => raw_token)

    assert_response :success
  end

  test "should reject a valid token when its user no longer exists" do
    missing_user_token = JsonWebToken.encode(user_id: User.maximum(:id) + 1, ip_address: "127.0.0.1")
    get publications_url(format: :json), headers: {
      "Authorization" => "Bearer #{missing_user_token}",
      "REMOTE_ADDR" => "127.0.0.1"
    }

    assert_response :unauthorized
  end

  test "should retain the open CORS policy in the test environment" do
    get publications_url(format: :json), headers: {"Origin" => "https://client.example"}

    assert_response :unauthorized
    assert_equal "*", response.headers["Access-Control-Allow-Origin"]
  end

  test "should show publication" do
    get publication_url(@publication, format: :json), headers: @headers

    assert_response :success
    assert_equal @publication.pdf_url, response.parsed_body.fetch("pdf_url")
  end

  test "should not expose publication mutation routes" do
    publication_count = Publication.count
    rating_count = Rating.count
    original_attributes = @publication.attributes

    assert_raises(ActionController::RoutingError) do
      patch publication_url(@publication, format: :json),
        params: {publication: {title: "Changed"}},
        headers: @headers,
        as: :json
    end

    assert_raises(ActionController::RoutingError) do
      put publication_url(@publication, format: :json),
        params: {publication: {title: "Changed"}},
        headers: @headers,
        as: :json
    end

    assert_raises(ActionController::RoutingError) do
      delete publication_url(@publication, format: :json), headers: @headers
    end

    assert_equal publication_count, Publication.count
    assert_equal rating_count, Rating.count
    assert_equal original_attributes, @publication.reload.attributes
  end
end
