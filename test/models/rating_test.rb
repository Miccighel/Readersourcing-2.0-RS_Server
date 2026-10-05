require "test_helper"

class RatingTest < ActiveSupport::TestCase

  test "accepts every integer in the original rating scale" do
    (0..100).each do |score|
      rating = build_rating(score: score, original_score: score)

      assert rating.valid?, "#{score} must remain a valid rating: #{rating.errors.full_messages}"
      assert_equal score / 100.0, rating.normalize_score
    end
  end

  test "accepts integer strings submitted by the browser slider" do
    %w[0 50 100].each do |score|
      rating = build_rating(score: score, original_score: score)

      assert rating.valid?
      assert_equal score.to_i, rating.score
      assert_equal score.to_i, rating.original_score
    end
  end

  test "requires both the current and original score" do
    [:score, :original_score].each do |attribute|
      [nil, "", " "].each do |value|
        rating = build_rating(attribute => value)

        assert_not rating.valid?
        assert rating.errors.of_kind?(attribute, :blank)
      end
    end
  end

  test "rejects scores outside the scale without clipping them" do
    [:score, :original_score].each do |attribute|
      [-1, 101, "-1", "101", 2**100].each do |value|
        rating = build_rating(attribute => value)

        assert_not rating.valid?, "#{attribute}=#{value.inspect} must be rejected"
        assert rating.errors[attribute].present?
      end
    end
  end

  test "rejects malformed values before integer conversion can disguise them" do
    [:score, :original_score].each do |attribute|
      [50.5, 50.0, "50.5", "50.0", "50suffix", "abc", "1e2", "0x10",
        true, false, [], {}, Float::NAN, Float::INFINITY].each do |value|
        rating = build_rating(attribute => value)

        assert_not rating.valid?, "#{attribute}=#{value.inspect} must be rejected"
        assert rating.errors[attribute].present?
      end
    end
  end

  test "database constraints reject missing and out of range scores even without model validation" do
    [:score, :original_score].each do |attribute|
      [nil, -1, 101].each do |value|
        error = assert_raises(ActiveRecord::StatementInvalid) do
          Rating.transaction(requires_new: true) do
            build_rating(attribute => value).save!(validate: false)
          end
        end

        assert_includes error.message, value.nil? ? "\"#{attribute}\"" : "ratings_#{attribute}_range"
      end
    end
  end

  test "allows one rating per reader and publication" do
    duplicate = Rating.new(
      user: users(:one),
      publication: publications(:one),
      score: 75,
      original_score: 75
    )

    assert_not duplicate.valid?
    assert duplicate.errors.added?(:publication_id, :taken, value: publications(:one).id)
  end

  private

  def build_rating(attributes = {})
    Rating.new({
      user: users(:one),
      publication: publications(:two),
      score: 50,
      original_score: 50
    }.merge(attributes))
  end

end
