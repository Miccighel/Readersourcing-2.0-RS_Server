class CreatePublications < ActiveRecord::Migration[5.2]
	def change
		create_table :publications do |t|
			t.string :doi
			t.string :title
			t.string :storage_path
			t.string :pdf_url
			t.string :pdf_download_path
			t.timestamps
		end
	end
end
