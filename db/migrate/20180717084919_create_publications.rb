class CreatePublications < ActiveRecord::Migration[5.2]
	def change
		create_table :publications do |t|
			t.string :doi
			t.string :title
			t.string :subject
			t.string :author
			t.string :creator
			t.string :producer
			t.string :pdf_url
			t.string :pdf_storage_url
			t.string :pdf_name
			t.string :pdf_download_url
			t.string :pdf_name_link
			t.string :pdf_download_url_link
			t.decimal :steadiness, default: 0.0
			t.decimal :score_sm, default: 0.0
			t.decimal :score_tr, default: 0.0
			t.timestamps
		end
	end
end
