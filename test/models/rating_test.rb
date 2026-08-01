require "test_helper"

class RatingTest < ActiveSupport::TestCase
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
end
