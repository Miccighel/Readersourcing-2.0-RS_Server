class AddUniqueReaderPublicationIndexToRatings < ActiveRecord::Migration[8.1]
  INDEX_NAME = "index_ratings_on_user_id_and_publication_id"

  def change
    add_index :ratings, [:user_id, :publication_id], unique: true, name: INDEX_NAME
  end
end
