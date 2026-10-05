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
    assert_equal 51, @rating.original_score
    assert @rating.edited
  end

  test "accepts the lower boundary and saves an unknown publication with its valid rating" do
    assert_difference(["Rating.count", "Publication.count"]) do
      capture_io do
        post ratings_url(format: :json),
          params: {rating: {score: 0, pdf_url: "https://example.test/new-publication.pdf"}},
          headers: @headers,
          as: :json
      end
    end

    assert_response :created
    assert_equal 0, response.parsed_body.fetch("score")
    assert_equal 0, response.parsed_body.fetch("original_score")
  end

  test "accepts the upper boundary through the JSON API" do
    assert_difference("Rating.count") do
      capture_io do
        post ratings_url(format: :json),
          params: {rating: {score: 100, pdf_url: publications(:two).pdf_url}},
          headers: @headers,
          as: :json
      end
    end

    assert_response :created
    assert_equal 100, response.parsed_body.fetch("score")
    assert_equal 100, response.parsed_body.fetch("original_score")
  end

  test "invalid API ratings neither create publications nor change domain scores or send mail" do
    before = domain_state
    invalid_scores.each do |score|
      assert_no_difference("ActionMailer::Base.deliveries.size") do
        post ratings_url(format: :json),
          params: {rating: {score: score, pdf_url: "https://example.test/invalid-score.pdf"}},
          headers: @headers,
          as: :json
      end

      assert_response :unprocessable_entity
      assert response.parsed_body.fetch("score").present?
      assert_equal before, domain_state
    end
  end

  test "a failed calculation rejects the API submission without partial domain changes or mail" do
    before = domain_state
    factory = RsmStrategy.method(:new)
    failing_strategy = ->(rating) { rating.user.email = nil; factory.call(rating) }

    assert_no_difference("ActionMailer::Base.deliveries.size") do
      RsmStrategy.stub(:new, failing_strategy) do
        capture_io do
          post ratings_url(format: :json),
            params: {rating: {score: 72, pdf_url: "https://example.test/calculation-failure.pdf"}},
            headers: @headers,
            as: :json
        end
      end
    end

    assert_response :unprocessable_entity
    assert_includes response.parsed_body.fetch("base"), I18n.t("errors.messages.rating_unsuccessful")
    assert_equal before, domain_state
  end

  test "a confirmation failure does not turn a saved API rating into a failed submission" do
    failing_confirmation = ->(*) { raise IOError, "Mail delivery failed" }

    assert_difference("Rating.count") do
      RatingMailer.stub(:confirm, failing_confirmation) do
        capture_io do
          post ratings_url(format: :json),
            params: {rating: {score: 72, pdf_url: publications(:two).pdf_url}},
            headers: @headers,
            as: :json
        end
      end
    end

    assert_response :created
    assert_equal 72, response.parsed_body.fetch("score")
    assert_equal BigDecimal("0.54"), publications(:two).reload.score_trm
  end

  test "a failed calculation reports an unsuccessful paper rating without partial changes or mail" do
    publication = publications(:two)
    reference = PaperRatingReference.issue(user: @user, publication: publication)
    authenticate_as(@user)
    get rate_paper_path(publication.id, reference), headers: {"REMOTE_ADDR" => "127.0.0.1"}
    before = domain_state
    factory = RsmStrategy.method(:new)
    failing_strategy = ->(rating) { rating.user.email = nil; factory.call(rating) }

    assert_no_difference("ActionMailer::Base.deliveries.size") do
      RsmStrategy.stub(:new, failing_strategy) do
        capture_io do
          post load_path,
            params: {pubId: publication.id, rating: {score: 72}},
            headers: {"REMOTE_ADDR" => "127.0.0.1"}
        end
      end
    end

    assert_response :success
    assert_includes response.body, I18n.t("errors.messages.rating_unsuccessful")
    assert_equal before, domain_state
  end

  test "the paper interface distinguishes a saved rating from an unavailable confirmation email" do
    publication = publications(:two)
    reference = PaperRatingReference.issue(user: @user, publication: publication)
    authenticate_as(@user)
    get rate_paper_path(publication.id, reference), headers: {"REMOTE_ADDR" => "127.0.0.1"}
    failing_confirmation = ->(*) { raise IOError, "Mail delivery failed" }

    assert_difference("Rating.count") do
      RatingMailer.stub(:confirm, failing_confirmation) do
        capture_io do
          post load_path,
            params: {pubId: publication.id, rating: {score: 72}},
            headers: {"REMOTE_ADDR" => "127.0.0.1"}
        end
      end
    end

    assert_response :success
    assert_includes response.body, I18n.t("confirmations.messages.operation_completed")
    assert_includes response.body, I18n.t("information.messages.rating_saved_without_confirmation")
    assert_equal BigDecimal("0.54"), publication.reload.score_trm
  end

  test "invalid edits retain the current and original rating and its edited flag" do
    before = domain_state
    invalid_scores.each do |score|
      assert_no_difference("ActionMailer::Base.deliveries.size") do
        patch rating_url(@rating, format: :json),
          params: {rating: {score: score}},
          headers: @headers,
          as: :json
      end

      assert_response :unprocessable_entity
      assert response.parsed_body.fetch("score").present?
      assert_equal before, domain_state
    end
  end

  test "rejects an invalid score from an annotated PDF without domain changes or confirmation mail" do
    publication = publications(:two)
    reference = PaperRatingReference.issue(user: @user, publication: publication)
    authenticate_as(@user)
    before = domain_state

    invalid_scores.each do |score|
      get rate_paper_path(publication.id, reference), headers: {"REMOTE_ADDR" => "127.0.0.1"}
      assert_response :success

      assert_no_difference("ActionMailer::Base.deliveries.size") do
        post load_path,
          params: {pubId: publication.id, rating: {score: score, anonymous: false}},
          headers: {"REMOTE_ADDR" => "127.0.0.1"}
      end

      assert_response :success
      assert_includes response.body, I18n.t("errors.messages.rating_unsuccessful")
      assert_equal before, domain_state
    end
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

  def invalid_scores
    [nil, "", -1, 101, 40.5, 40.0, "40suffix", "abc", true, false]
  end

  def domain_state
    [User, Publication, Rating].map { |model| model.order(:id).map(&:attributes) }
  end

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
