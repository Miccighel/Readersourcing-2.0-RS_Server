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
		download_url = response.parsed_body.fetch("pdf_download_url_link")
		assert download_url.start_with?("http://www.example.com/publications/#{@publication.id}/download/annotated/")
		assert download_url.end_with?("/#{@publication.pdf_name_link}")
  end

	test "should use the configured public origin for publication links" do
		previous_origin = ENV["PUBLIC_BASE_URL"]
		ENV["PUBLIC_BASE_URL"] = "https://readersourcing.example"

		get publication_url(@publication, format: :json, host: "attacker.example"), headers: @headers

		assert_response :success
		assert response.parsed_body.fetch("pdf_download_url_link").start_with?(
			"https://readersourcing.example/publications/#{@publication.id}/download/annotated/"
		)
	ensure
		previous_origin.nil? ? ENV.delete("PUBLIC_BASE_URL") : ENV["PUBLIC_BASE_URL"] = previous_origin
	end

  test "should route publication refresh through post" do
    route = Rails.application.routes.recognize_path(
      refresh_publication_path(@publication, format: :json),
      method: :post
    )

    assert_equal "publications", route.fetch(:controller)
    assert_equal "refresh", route.fetch(:action)
    assert_equal @publication.id.to_s, route.fetch(:id)
  end

  test "should route publication upload preparation through post" do
    route = Rails.application.routes.recognize_path(
      fetch_upload_publications_path(format: :json),
      method: :post
    )

    assert_equal "publications", route.fetch(:controller)
    assert_equal "fetch_upload", route.fetch(:action)
  end

  test "should return a structured state for an invalid publication URL" do
    post is_fetchable_publications_url(format: :json),
      params: {publication: {pdf_url: "file:///tmp/Reader.pdf"}},
      headers: @headers,
      as: :json

    assert_response :unprocessable_entity
    assert_equal "invalid_url", response.parsed_body.fetch("status")
    assert_equal true, response.parsed_body.fetch("upload_supported")
  end

  test "should return a structured state when an upload is missing" do
    post fetch_upload_publications_url(format: :json),
      params: {publication: {pdf_url: "https://example.test/Reader.pdf"}},
      headers: @headers

    assert_response :unprocessable_entity
    assert_equal "upload_missing", response.parsed_body.fetch("status")
  end

  test "should not refresh publication through get" do
    assert_raises(ActionController::RoutingError) do
      get refresh_publication_url(@publication, format: :json), headers: @headers
    end
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
