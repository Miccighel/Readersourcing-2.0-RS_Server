require 'open-uri'

class Publication < ApplicationRecord

	has_many :ratings, dependent: :destroy

	after_create do
		update_attribute("storage_path", Rails.root.join("storage", "publications", "#{id}").to_s)
		update_attribute("pdf_download_path", File.join(storage_path, self.pdf_url.to_s.split('/')[-1]))
	end

	def fetch
		FileUtils::mkdir_p self.storage_path
		publication = open(self.pdf_url)
		File.join(self.storage_path, self.pdf_download_path)
		IO.copy_stream(publication, self.pdf_download_path)
	end

end
