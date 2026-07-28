require "bigdecimal"
require "minitest/autorun"
require "set"

require_relative "../../lib/readersourcing_strategy"
require_relative "../../lib/readersourcing"
require_relative "../../lib/rsm_strategy"
require_relative "../../lib/trm_strategy"

class CharacterizationUser
  attr_accessor :score, :steadiness, :bonus
  attr_reader :ratings

  def initialize
    @score = BigDecimal("0.000001")
    @steadiness = BigDecimal("0")
    @bonus = BigDecimal("0")
    @ratings = []
  end

  def given_rating(publication)
    ratings.find { |rating| rating.publication == publication }
  end

  def given_ratings
    ratings
  end

  def save
    true
  end
end

class CharacterizationPublication
  attr_accessor :steadiness, :score_rsm, :score_trm
  attr_reader :ratings

  def initialize
    @steadiness = BigDecimal("0")
    @score_rsm = BigDecimal("0")
    @score_trm = BigDecimal("0")
    @ratings = []
  end

  def other_users(current_user)
    ratings
      .map(&:user)
      .reject { |user| user == current_user }
      .to_set
  end

  def ratings_history
    ratings.sort_by(&:created_at)
  end

  def save
    true
  end
end

class CharacterizationRating
  attr_accessor :score, :goodness, :informativeness, :accuracy_loss, :bonus
  attr_reader :user, :publication, :created_at

  def initialize(score:, user:, publication:, created_at:)
    @score = score
    @user = user
    @publication = publication
    @created_at = created_at
    @goodness = BigDecimal("0")
    @informativeness = BigDecimal("0")
    @accuracy_loss = BigDecimal("0")
    @bonus = BigDecimal("0")

    user.ratings << self
    publication.ratings << self
  end

  def normalize_score
    score / 100.0
  end

  def save
    true
  end
end

class ReadersourcingCharacterizationTest < Minitest::Test
  # Ruby 2.6 loses a few decimal digits when the Active Record-style
  # BigDecimal values are combined with the Float returned by normalize_score.
  # Ruby 3.4 agrees with the current Readersourcing_OO reference implementation.
  # This tolerance accepts both runtimes while still detecting domain changes.
  LEGACY_RUNTIME_DELTA = 2e-9

  GROUND_TRUTH_2 = [
    [51, 0, 0],
    [36, 0, 1],
    [51, 1, 0],
    [93, 1, 1],
    [59, 2, 0],
    [3, 2, 1]
  ].freeze

  def test_context_delegates_score_computation_to_the_selected_strategy
    strategy = Minitest::Mock.new
    strategy.expect(:compute_scores, :computed)

    result = Readersourcing.new(strategy).compute_scores

    assert_equal :computed, result
    strategy.verify
  end

  def test_first_rsm_rating_bootstraps_publication_and_reader
    user = CharacterizationUser.new
    publication = CharacterizationPublication.new
    rating = CharacterizationRating.new(
      score: 51,
      user: user,
      publication: publication,
      created_at: Time.at(1)
    )

    compute_quietly(RsmStrategy.new(rating))

    assert_decimal "0.000001", publication.steadiness
    assert_decimal "0.51", publication.score_rsm
    assert_decimal "1.0", rating.goodness
    assert_decimal "0.000001", user.steadiness
    assert_decimal "1.0", user.score
  end

  def test_second_rsm_rating_recomputes_the_previous_readers_reputation
    first_user = CharacterizationUser.new
    second_user = CharacterizationUser.new
    publication = CharacterizationPublication.new

    first_rating = CharacterizationRating.new(
      score: 51,
      user: first_user,
      publication: publication,
      created_at: Time.at(1)
    )
    compute_quietly(RsmStrategy.new(first_rating))

    second_rating = CharacterizationRating.new(
      score: 36,
      user: second_user,
      publication: publication,
      created_at: Time.at(2)
    )
    compute_quietly(RsmStrategy.new(second_rating))

    expected_goodness = "0.7261387212474169"

    assert_decimal "0.000002", publication.steadiness
    assert_decimal "0.435", publication.score_rsm
    assert_decimal expected_goodness, first_rating.goodness
    assert_decimal expected_goodness, second_rating.goodness
    assert_decimal "0.000002", first_user.steadiness
    assert_decimal expected_goodness, first_user.score
    assert_decimal "0.000002", second_user.steadiness
    assert_decimal expected_goodness, second_user.score
  end

  def test_ground_truth_2_sequence_is_stable_across_both_strategies
    users = Array.new(3) { CharacterizationUser.new }
    publications = Array.new(2) { CharacterizationPublication.new }
    ratings = []

    GROUND_TRUTH_2.each_with_index do |(score, user_index, publication_index), index|
      rating = CharacterizationRating.new(
        score: score,
        user: users.fetch(user_index),
        publication: publications.fetch(publication_index),
        created_at: Time.at(index + 1)
      )
      ratings << rating

      compute_quietly(RsmStrategy.new(rating))
      compute_quietly(TrmStrategy.new(rating))
    end

    snapshot = {
      users: users.map { |user| [user.score.to_f, user.steadiness.to_f, user.bonus.to_f] },
      publications: publications.map do |publication|
        [
          publication.score_rsm.to_f,
          publication.score_trm.to_f,
          publication.steadiness.to_f
        ]
      end,
      ratings: ratings.map do |rating|
        [
          rating.goodness.to_f,
          rating.informativeness.to_f,
          rating.accuracy_loss.to_f,
          rating.bonus.to_f
        ]
      end
    }

    assert_snapshot_in_delta expected_ground_truth_2_snapshot, snapshot
  end

  private

  def assert_decimal(expected, actual, delta = 1e-15)
    assert_in_delta expected.to_f, actual.to_f, delta
  end

  def assert_snapshot_in_delta(expected, actual)
    expected.each do |entity, expected_rows|
      actual_rows = actual.fetch(entity)
      assert_equal expected_rows.length, actual_rows.length

      expected_rows.zip(actual_rows).each do |expected_values, actual_values|
        assert_equal expected_values.length, actual_values.length

        expected_values.zip(actual_values).each do |expected_value, actual_value|
          assert_in_delta expected_value, actual_value, LEGACY_RUNTIME_DELTA
        end
      end
    end
  end

  def compute_quietly(strategy)
    capture_io { Readersourcing.new(strategy).compute_scores }
  end

  def expected_ground_truth_2_snapshot
    {
      users: [
        [0.6620740494702405, 2.7690628923241496, 0.0],
        [0.3248665499756201, 2.7690628923241496, 0.10282843684148664],
        [0.33352160805166764, 2.7690628923241496, 0.0]
      ],
      publications: [
        [0.5366666666666666, 0.5366666666666666, 0.000003],
        [0.4741940759062552, 0.44, 2.7690598923241496]
      ],
      ratings: [
        [0.8367006838144548, 0.0, 0.0, 0.0],
        [0.6620738602797127, 0.0, 0.0, 0.0],
        [0.8367006838144548, 0.0064, 0.0064, 0.016884500150148137],
        [0.32486599545442474, 0.1089, 0.81, 0.1887723735328251],
        [0.7690598923241496, 0.0, 0.0, 0.0],
        [0.3335211361894098, 0.0, 0.0, 0.0]
      ]
    }
  end
end
