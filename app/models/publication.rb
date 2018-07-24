require 'open-uri'

class Publication < ApplicationRecord

	attr_accessor :absolute_pdf_storage_url, :absolute_pdf_download_url, :absolute_pdf_download_url_link
	has_many :ratings, dependent: :destroy

	def fetch

		load_paths

		logger.info "Fetching publication from: #{pdf_url}"
		FileUtils::mkdir_p absolute_pdf_storage_url
		publication = open(pdf_url)
		bytes_expected = publication.meta['content-length'].to_i
		bytes_copied = IO.copy_stream(publication, absolute_pdf_download_url)
		if bytes_expected != bytes_copied
			raise "Expected #{bytes_expected} bytes but got #{bytes_copied}"
		end
		logger.info "Bytes copied: #{bytes_copied} expected: #{bytes_expected} difference: #{bytes_expected - bytes_copied}"

		# METADATA READING STARTS HERE

		logger.info "Reading metadata from: #{absolute_pdf_download_url}"
		reader = PDF::Reader.new(absolute_pdf_download_url)
		if !reader.info[:Title].blank? and title.blank?
			logger.info "Title found"
			update_attribute(:title, reader.info[:Title])
		end
		if !reader.info[:Subject].blank? and subject.blank?
			logger.info "Subject found"
			update_attribute(:subject, reader.info[:Subject])
		end

		# EDITING OF PDF FILE WITH PDFxREADERSOURCING STARTS HERE

		logger.info "Checking again existence of: #{absolute_pdf_download_url}"
		if File.exist?(absolute_pdf_download_url)
			logger.info "File exists"
			logger.info "PDFxReadersourcing execution started"
			logger.info "Path: #{APP_CONFIG['pdf_x_readersourcing_path']}"
			logger.info "with options:"
			logger.info "-pIn: #{absolute_pdf_download_url}"
			logger.info "-pOut: #{absolute_pdf_storage_url}"
			logger.info "Complete command:"
			logger.info "java -jar #{APP_CONFIG['pdf_x_readersourcing_path']} -pIn #{absolute_pdf_download_url} -pOut #{absolute_pdf_storage_url} "
			output = %x( java -jar #{APP_CONFIG['pdf_x_readersourcing_path']} -pIn #{absolute_pdf_download_url} -pOut #{absolute_pdf_storage_url} )
			logger.info output
			logger.info "PDFxReadersourcing execution completed"
			File.delete(absolute_pdf_download_url)
			logger.info "Modified file"
			logger.info "Name: #{pdf_name_link}"
			logger.info "Download url: #{pdf_download_url_link}"
		else
			raise "File does not exists at #{absolute_pdf_download_url}"
		end
	end

	private

	def load_paths
		update_attribute(:pdf_storage_url, "publication/#{id}/")
		update_attribute(:pdf_download_url, "#{pdf_storage_url}#{self.pdf_url.to_s.split('/')[-1]}")
		update_attribute(:pdf_name, "#{self.pdf_url.to_s.split('/')[-1]}")
		pdf_name_without_ext = (self.pdf_url.to_s.split('/')[-1]).chomp(".pdf")
		update_attribute(:pdf_download_url_link, "#{pdf_storage_url}#{pdf_name_without_ext}#{APP_CONFIG['pdf_x_readersourcing_link_suffix']}.pdf")
		update_attribute(:pdf_name_link, "#{pdf_name_without_ext}#{APP_CONFIG['pdf_x_readersourcing_link_suffix']}.pdf")
	end

	def absolute_pdf_storage_url
		Rails.public_path.join(pdf_storage_url)
	end

	def absolute_pdf_download_url
		Rails.public_path.join(pdf_download_url)
	end

	def absolute_pdf_download_url_link
		Rails.public_path.join(pdf_download_url_link)
	end

end
