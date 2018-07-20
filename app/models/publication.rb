require 'open-uri'

class Publication < ApplicationRecord

	attr_accessor :absolute_storage_url, :absolute_pdf_download_url

	has_many :ratings, dependent: :destroy

	after_create do
		update_attribute(:storage_url, "publication/#{id}/")
		update_attribute(:pdf_download_url, "#{storage_url}#{self.pdf_url.to_s.split('/')[-1]}")
	end

	def absolute_storage_url
		Rails.public_path.join(storage_url)
	end

	def absolute_pdf_download_url
		Rails.public_path.join(pdf_download_url)
	end

	def fetch
		FileUtils::mkdir_p absolute_storage_url
		publication = open(self.pdf_url)
		bytes_expected = publication.meta['content-length'].to_i
		bytes_copied = IO.copy_stream(publication, absolute_pdf_download_url)
		if bytes_expected != bytes_copied
			raise "Expected #{bytes_expected} bytes but got #{bytes_copied}"
		end
		reader = PDF::Reader.new(self.absolute_pdf_download_url)
		update_attribute(:title, reader.info[:Title]) if reader.info[:Title] != ""
		update_attribute(:subject, reader.info[:Subject]) if reader.info[:Subject] != ""
	end

end
