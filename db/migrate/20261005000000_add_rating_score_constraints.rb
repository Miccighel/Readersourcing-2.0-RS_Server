class AddRatingScoreConstraints < ActiveRecord::Migration[8.1]

  def up
    invalid_count = select_value(<<~SQL).to_i
      SELECT COUNT(*) FROM ratings
      WHERE score IS NULL OR score < 0 OR score > 100
         OR original_score IS NULL OR original_score < 0 OR original_score > 100
    SQL
    if invalid_count.positive?
      raise ActiveRecord::MigrationError,
        "#{invalid_count} ratings have missing scores or values outside 0 to 100. " \
        "Review these records before running the migration."
    end

    change_column_null :ratings, :score, false
    change_column_null :ratings, :original_score, false
    add_check_constraint :ratings, "score BETWEEN 0 AND 100", name: "ratings_score_range"
    add_check_constraint :ratings, "original_score BETWEEN 0 AND 100", name: "ratings_original_score_range"
  end

  def down
    remove_check_constraint :ratings, name: "ratings_original_score_range"
    remove_check_constraint :ratings, name: "ratings_score_range"
    change_column_null :ratings, :original_score, true
    change_column_null :ratings, :score, true
  end

end
