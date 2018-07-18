class AddPublicationToRatings < ActiveRecord::Migration[5.2]
	def change
		add_reference :ratings, :publication, foreign_key: true
	end
end
