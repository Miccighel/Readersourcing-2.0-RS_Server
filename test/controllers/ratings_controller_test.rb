require "test_helper"

class RatingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @rating = ratings(:one)
    @user = users(:one)
    @headers = api_headers_for(@user)
  end

  test "should get index" do
    get ratings_url(format: :json), headers: @headers

    assert_response :success
    assert_equal 2, response.parsed_body.length
  end

  test "should create rating" do
    assert_difference("Rating.count") do
      capture_io do
        post ratings_url(format: :json),
          params: {
            rating: {
              score: 72,
              anonymous: false,
              pdf_url: publications(:two).pdf_url
            }
          },
          headers: @headers,
          as: :json
      end
    end

    assert_response :created
    assert_equal 72, response.parsed_body.fetch("score")
  end

  test "should show rating" do
    get rating_url(@rating, format: :json), headers: @headers

    assert_response :success
    assert_equal @rating.score, response.parsed_body.fetch("score")
  end

  test "should not show another user's rating" do
    get rating_url(ratings(:two), format: :json), headers: @headers

    assert_response :not_found
  end

  test "should update rating" do
    patch rating_url(@rating, format: :json),
      params: { rating: { score: 77 } },
      headers: @headers,
      as: :json

    assert_response :ok
    assert_equal 77, @rating.reload.score
    assert @rating.edited
  end

  test "should not update another user's rating" do
    other_rating = ratings(:two)

    patch rating_url(other_rating, format: :json),
      params: { rating: { score: 77 } },
      headers: @headers,
      as: :json

    assert_response :not_found
    assert_equal 36, other_rating.reload.score
    assert_not other_rating.edited
  end

  test "should not create a second rating for the same publication" do
    assert_no_difference("Rating.count") do
      capture_io do
        post ratings_url(format: :json),
          params: {
            rating: {
              score: 72,
              anonymous: false,
              pdf_url: publications(:one).pdf_url
            }
          },
          headers: @headers,
          as: :json
      end
    end

    assert_response :unprocessable_entity
  end
end
