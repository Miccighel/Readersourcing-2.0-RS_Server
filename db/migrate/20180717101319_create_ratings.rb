class CreateRatings < ActiveRecord::Migration[5.2]
	def change
		create_table :ratings do |t|
			t.integer :score
			t.integer :original_score
			t.boolean :anonymous, default: false
			t.boolean :edited, default: false
			t.decimal :goodness, default: 0.0
			t.decimal :informativeness, default: 0.0
			t.decimal :accuracy_loss, default: 0.0
			t.decimal :bonus, default: 0.0
			t.timestamps
		end
	end
end
