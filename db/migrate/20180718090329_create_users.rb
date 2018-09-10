class CreateUsers < ActiveRecord::Migration[5.2]
	def change
		create_table :users do |t|
			t.string :first_name
			t.string :last_name
			t.string :email
			t.string :orcid
			t.string :password_digest
			t.string :reset_password_token
			t.datetime :reset_password_sent_at
			t.decimal :steadiness, default: 0.0
			t.decimal :score, default: 0.000001
			t.timestamps
		end
	end
end
