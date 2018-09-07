class CreateRatings < ActiveRecord::Migration[5.2]
	def change
		create_table :ratings do |t|
			t.integer :score
			t.boolean :anonymous, default: false
			t.timestamps
		end
	end
end
