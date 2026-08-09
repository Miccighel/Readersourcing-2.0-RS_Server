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

  test "opens a durable paper reference for its reader" do
    publication = publications(:two)
    reference = PaperRatingReference.issue(user: @user, publication: publication)
    authenticate_as(@user)

    get rate_paper_path(publication.id, reference), headers: {"REMOTE_ADDR" => "127.0.0.1"}

    assert_response :success
    assert_includes response.body, "Rate this publication"
  end

  test "logout does not invalidate a paper reference" do
    publication = publications(:two)
    reference = PaperRatingReference.issue(user: @user, publication: publication)
    auth_token = authenticate_as(@user)
    jti = JsonWebToken.decode(auth_token)[:jti]
    post logout_path(format: :json),
      headers: {"REMOTE_ADDR" => "127.0.0.1"},
      as: :json
    assert_not AuthenticationToken.exists?(jti: jti)

    authenticate_as(@user)
    get rate_paper_path(publication.id, reference), headers: {"REMOTE_ADDR" => "127.0.0.1"}

    assert_response :success
    assert_includes response.body, "Rate this publication"
  end

  test "rejects a paper reference opened by another reader" do
    publication = publications(:two)
    reference = PaperRatingReference.issue(user: @user, publication: publication)
    authenticate_as(users(:two))

    get rate_paper_path(publication.id, reference), headers: {"REMOTE_ADDR" => "127.0.0.1"}

    assert_response :success
    assert_includes response.body, I18n.t("errors.messages.not_the_same_user")
  end

  test "rejects an invalid paper reference without exposing an error" do
    authenticate_as(@user)

    get rate_paper_path(publications(:two).id, "invalid-reference"),
      headers: {"REMOTE_ADDR" => "127.0.0.1"}

    assert_response :success
    assert_includes response.body, I18n.t("errors.messages.invalid_paper_reference")
  end

  test "creates a rating from a durable paper reference" do
    publication = publications(:two)
    reference = PaperRatingReference.issue(user: @user, publication: publication)
    authenticate_as(@user)
    get rate_paper_path(publication.id, reference), headers: {"REMOTE_ADDR" => "127.0.0.1"}

    assert_difference("Rating.count") do
      capture_io do
        post load_path,
          params: {
            pubId: publication.id,
            rating: {
              score: 64,
              anonymous: false
            }
          },
          headers: {"REMOTE_ADDR" => "127.0.0.1"}
      end
    end

    assert_response :success
    rating = Rating.find_by!(user: @user, publication: publication)
    assert_equal 64, rating.score
  end

  private

  def authenticate_as(user)
    post authenticate_path(format: :json),
      params: {
        email: user.email,
        password: "password"
      },
      headers: {"REMOTE_ADDR" => "127.0.0.1"},
      as: :json

    assert_response :success

    response.parsed_body.fetch("auth_token")
  end

end
