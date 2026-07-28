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

  test "should show publication" do
    get publication_url(@publication, format: :json), headers: @headers

    assert_response :success
    assert_equal @publication.pdf_url, response.parsed_body.fetch("pdf_url")
  end

  test "should destroy publication" do
    assert_difference("Publication.count", -1) do
      delete publication_url(@publication, format: :json), headers: @headers
    end

    assert_response :no_content
  end
end
