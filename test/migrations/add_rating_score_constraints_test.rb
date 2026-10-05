require "test_helper"
require_relative "../../db/migrate/20261005000000_add_rating_score_constraints"

class AddRatingScoreConstraintsTest < ActiveSupport::TestCase

  teardown do
    Rating.reset_column_information
  end

  test "installs reversible constraints without changing existing rating values" do
    before = Rating.order(:id).map(&:attributes)
    migration = AddRatingScoreConstraints.new

    capture_io do
      migration.migrate(:down)
      migration.migrate(:up)
    end

    assert_equal before, Rating.order(:id).map(&:attributes)
    [:score, :original_score].each do |attribute|
      column = Rating.connection.columns(:ratings).find { |item| item.name == attribute.to_s }
      assert_not column.null
      assert Rating.connection.check_constraint_exists?(:ratings, name: "ratings_#{attribute}_range")
    end
  end

  test "stops before changing the schema when existing ratings need review" do
    migration = AddRatingScoreConstraints.new
    capture_io { migration.migrate(:down) }
    Rating.where(id: ratings(:one).id).update_all(score: nil)
    Rating.where(id: ratings(:two).id).update_all(original_score: 101)
    before = Rating.order(:id).map(&:attributes)

    error = assert_raises(ActiveRecord::MigrationError) do
      capture_io { migration.migrate(:up) }
    end

    assert_includes error.message, "2 ratings have missing scores or values outside 0 to 100"
    assert_equal before, Rating.order(:id).map(&:attributes)
    [:score, :original_score].each do |attribute|
      column = Rating.connection.columns(:ratings).find { |item| item.name == attribute.to_s }
      assert column.null
      assert_not Rating.connection.check_constraint_exists?(:ratings, name: "ratings_#{attribute}_range")
    end
  end

end
