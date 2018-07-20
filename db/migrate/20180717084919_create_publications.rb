class CreatePublications < ActiveRecord::Migration[5.2]
	def change
		create_table :publications do |t|
			t.string :doi
			t.string :title
			t.string :subject
			t.string :pdf_url
			t.string :storage_url
			t.string :pdf_download_url
			t.timestamps
		end
	end
end
