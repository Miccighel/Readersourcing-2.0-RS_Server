require "test_helper"

class RatingSubmissionTest < ActiveSupport::TestCase

  setup do
    @user = users(:one)
    @publication = publications(:two)
    @rating = Rating.new(user: @user, publication: @publication, score: 72, original_score: 72)
  end

  test "saves a rating and computes RSM followed by TRM before confirmation" do
    order = []
    rsm_factory = RsmStrategy.method(:new)
    trm_factory = TrmStrategy.method(:new)
    rsm = ->(rating) { order << :rsm; rsm_factory.call(rating) }
    trm = ->(rating) { order << :trm; trm_factory.call(rating) }

    RsmStrategy.stub(:new, rsm) do
      TrmStrategy.stub(:new, trm) do
        capture_io do
          assert RatingSubmission.new(@rating).call { order << :confirmation }
        end
      end
    end

    assert_equal [:rsm, :trm, :confirmation], order
    assert @rating.persisted?
    assert_equal 72, @rating.original_score
    assert_equal BigDecimal("0.72"), @publication.reload.score_rsm
    assert_equal BigDecimal("0.54"), @publication.score_trm
    assert_equal BigDecimal("1"), @rating.reload.goodness
  end

  test "invalid ratings neither write records nor trigger confirmation" do
    @rating.score = false
    before = domain_state
    confirmation = []

    assert_not RatingSubmission.new(@rating).call { confirmation << :sent }

    assert_equal before, domain_state
    assert_empty confirmation
  end

  test "duplicate ratings leave the complete domain state unchanged" do
    @rating.publication = publications(:one)
    before = domain_state
    confirmation = []

    assert_not RatingSubmission.new(@rating).call { confirmation << :sent }

    assert @rating.errors.of_kind?(:publication_id, :taken)
    assert_equal before, domain_state
    assert_empty confirmation
  end

  test "a rejected RSM write rolls back a new publication rating and computed scores" do
    @rating.publication = Publication.new(pdf_url: "https://example.test/rollback-publication.pdf")
    before = domain_state
    confirmation = []
    factory = RsmStrategy.method(:new)
    failing_strategy = ->(rating) { rating.user.email = nil; factory.call(rating) }

    RsmStrategy.stub(:new, failing_strategy) do
      capture_io do
        assert_not RatingSubmission.new(@rating).call { confirmation << :sent }
      end
    end

    assert @rating.errors[:base].present?
    assert_not @rating.persisted?
    assert_equal before, domain_state
    assert_empty confirmation
  end

  test "a rejected previous reader write rolls back all earlier RSM writes" do
    @rating.user = users(:two)
    @rating.publication = publications(:one)
    before = domain_state
    factory = RsmStrategy.method(:new)
    failing_strategy = lambda do |rating|
      previous_readers = rating.publication.method(:other_users)
      rating.publication.define_singleton_method(:other_users) do |reader|
        previous_readers.call(reader).each { |previous| previous.email = nil }
      end
      factory.call(rating)
    end

    RsmStrategy.stub(:new, failing_strategy) do
      capture_io { assert_not RatingSubmission.new(@rating).call }
    end

    assert_equal before, domain_state
  end

  test "an unexpected TRM failure rolls back the completed RSM phase" do
    before = domain_state
    confirmation = []
    strategy = Object.new
    strategy.define_singleton_method(:compute_scores) { raise "TRM could not complete" }

    TrmStrategy.stub(:new, strategy) do
      capture_io do
        error = assert_raises(RuntimeError) do
          RatingSubmission.new(@rating).call { confirmation << :sent }
        end
        assert_equal "TRM could not complete", error.message
      end
    end

    assert_equal before, domain_state
    assert_empty confirmation
  end

  test "a rejected TRM write rolls back RSM and prior TRM writes" do
    before = domain_state
    factory = TrmStrategy.method(:new)
    failing_strategy = lambda do |rating|
      strategy = factory.call(rating)
      strategy.instance_variable_get(:@ratings).each { |item| item.user.email = nil }
      strategy
    end

    TrmStrategy.stub(:new, failing_strategy) do
      capture_io { assert_not RatingSubmission.new(@rating).call }
    end

    assert_equal before, domain_state
  end

  test "reloads the reader and publication before computing from their current state" do
    User.where(id: @user.id).update_all(score: BigDecimal("1"))
    @publication.ratings.load

    capture_io { assert RatingSubmission.new(@rating).call }

    assert_equal BigDecimal("1"), @publication.reload.steadiness
  end

  test "uses an existing publication even when the submitted candidate was built earlier" do
    @rating.publication = Publication.new(pdf_url: @publication.pdf_url)

    assert_no_difference("Publication.count") do
      capture_io { assert RatingSubmission.new(@rating).call }
    end

    assert_equal @publication.id, @rating.publication_id
  end

  test "edits retain the original score and do not recompute the Readersourcing models" do
    rating = ratings(:one)
    scores = domain_metrics
    fail_if_computed = ->(_rating) { raise "Editing does not recompute scores" }

    RsmStrategy.stub(:new, fail_if_computed) do
      TrmStrategy.stub(:new, fail_if_computed) do
        assert RatingSubmission.new(rating).call(attributes: {score: 77, edited: true})
      end
    end

    assert_equal 77, rating.reload.score
    assert_equal 51, rating.original_score
    assert rating.edited
    assert_equal scores, domain_metrics
  end

  test "an explicit edit is applied after reloading a stale rating" do
    rating = ratings(:one)
    Rating.where(id: rating.id).update_all(score: 65)

    assert RatingSubmission.new(rating).call(attributes: {score: 51, edited: true})

    assert_equal 51, rating.reload.score
  end

  test "invalid edits are checked before type casting can turn them into valid scores" do
    rating = ratings(:one)
    before = domain_state

    assert_not RatingSubmission.new(rating).call(attributes: {score: false, edited: true})

    assert_equal before, domain_state
  end

  test "a confirmation failure leaves the saved rating and computed scores successful" do
    submission = RatingSubmission.new(@rating)

    capture_io { assert submission.call { raise "Mail delivery failed" } }

    assert submission.confirmation_failed
    assert @rating.persisted?
    assert_equal BigDecimal("0.54"), @publication.reload.score_trm
  end

  private

  def domain_state
    [User, Publication, Rating].map { |model| model.order(:id).map(&:attributes) }
  end

  def domain_metrics
    [
      User.order(:id).pluck(:score, :steadiness, :bonus),
      Publication.order(:id).pluck(:score_rsm, :score_trm, :steadiness),
      Rating.order(:id).pluck(:goodness, :informativeness, :accuracy_loss, :bonus)
    ]
  end

end
