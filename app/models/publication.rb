require 'open-uri'

class Publication < ApplicationRecord

	attr_accessor :absolute_pdf_storage_url, :absolute_pdf_download_url, :absolute_pdf_download_url_link
	has_many :ratings, dependent: :destroy

	validates :doi, uniqueness: true, allow_nil: true, format: {with: /\b(10[.][0-9]{4,}(?:[.][0-9]+)*\/(?:(?!["&\'<>])\S)+)\b/}
	validates :doi, uniqueness: true, allow_nil: true, format: {with: /\b(10[.][0-9]{4,}(?:[.][0-9]+)*\/(?:(?!["&\'<>])[[:graph:]])+)\b/}
	validates :pdf_url, presence: true, uniqueness: true, format: {with: URI.regexp}, if: Proc.new {|publication| publication.pdf_url.present?}

	def pretty_score_rsm
		"#{(self.score_rsm * 100).round(2).prettify}/100"
	end

	def pretty_score_trm
		"#{(self.score_trm * 100).round(2).prettify}/100"
	end

	def is_rated(user)
		logger.info "Starting to look for ratings given by user #{user.id}"
		self.ratings.each do |rating|
			if rating.user == user
				logger.info "Rating given by user #{user.id} found"
				return rating
			end
		end
		nil
	end

	def is_saved_for_later(user)
		begin
			File.file?(absolute_pdf_download_path_link(user))
		rescue TypeError
			false
		end
	end

	def is_fetchable
		logger.info "Fetching file at url: #{pdf_url}"
		begin
			publication = open(pdf_url)
		rescue SystemCallError => exception
			logger.info "Could not fetch file: #{exception.message}"
			raise
		rescue SocketError => exception
			logger.info "Could not fetch file: #{exception.message}"
			raise
		end
		content_type = publication.meta['content-type']
		logger.info "Content type found: #{content_type}"
		bytes_expected = publication.meta['content-length'].to_i
		logger.info "Bytes expected: #{bytes_expected}"
		bytes_expected > 0 and content_type == "application/pdf"
	end

	def fetch(request_data)

		data = Hash.new
		data[:authToken] = request_data.values[0]
		data[:host] = request_data.values[1]
		data[:pub_id] = self.id
		data[:user] = request_data.values[2]
		data[:rate_path] = "#{request_data.values[1]}#{Rails.application.routes.url_helpers.rate_paper_path(data[:pub_id], data[:authToken])}"

		# FILE FETCHING STARTS HERE

		logger.info "Fetching file at url: #{pdf_url}"
		publication = open(pdf_url)
		if publication.meta['content-disposition'] != nil
			logger.info "Content disposition meta tag detected. Reading file name from there"
			filename = publication.meta['content-disposition'].match(/filename=(\"?)(.+)\1/)[2]
		else
			logger.info "Content disposition meta tag not detected. Reading file name from url"
			filename = pdf_url.to_s.split('/')[-1]
		end
		if filename == nil
			raise "Filename is still null, something went wrong"
		end
		load_pdf_paths(filename, data[:host])
		logger.info "File name: #{filename}"

		logger.info "Checking if there is an old annotated version to remove."
		remove_annotated_file data[:user]

		logger.info "Creating folder at #{absolute_pdf_storage_path(data[:user])}."
		FileUtils::mkdir_p absolute_pdf_storage_path(data[:user])
		bytes_expected = publication.meta['content-length'].to_i
		logger.info "Copying file at #{absolute_pdf_download_path(data[:user])}"
		bytes_copied = IO.copy_stream(publication, absolute_pdf_download_path(data[:user]))
		if bytes_expected != bytes_copied
			raise "Expected #{bytes_expected} bytes but got #{bytes_copied}"
		end
		logger.info "Bytes copied: #{bytes_copied} expected: #{bytes_expected} difference: #{bytes_expected - bytes_copied}"

		# METADATA READING STARTS HERE

		logger.info "Reading metadata from: #{absolute_pdf_download_path(data[:user])}"
		reader = PDF::Reader.new(absolute_pdf_download_path(data[:user]))
		begin
			if !reader.info[:doi].blank?
				logger.info "DOI found"
				update_attribute(:doi, reader.info[:doi].chomp("doi:"))
			else
				update_attribute(:doi, nil)
			end
		rescue ArgumentError => e
			logger.info "Error reading doi metadata"
			logger.info e.message
		end
		begin
			if !reader.info[:Title].blank?
				logger.info "Title found"
				update_attribute(:title, reader.info[:Title])
			else
				update_attribute(:title, nil)
			end
		rescue ArgumentError => e
			logger.info "Error reading Title metadata"
			logger.info e.message
		end
		begin
			if !reader.info[:Subject].blank?
				logger.info "Subject found"
				update_attribute(:subject, reader.info[:Subject])
			else
				update_attribute(:subject, nil)
			end
		rescue ArgumentError => e
			logger.info "Error reading Subject metadata"
			logger.info e.message
		end
		begin
			if !reader.info[:Author].blank?
				logger.info "Author found"
				update_attribute(:author, reader.info[:Author])
			else
				update_attribute(:author, nil)
			end
		rescue ArgumentError => e
			logger.info "Error reading Author metadata"
			logger.info e.message
		end
		begin
			if !reader.info[:Creator].blank?
				logger.info "Creator found"
				update_attribute(:creator, reader.info[:Creator])
			else
				update_attribute(:creator, nil)
			end
		rescue ArgumentError => e
			logger.info "Error reading Creator metadata"
			logger.info e.message
		end
		begin
			if !reader.info[:Producer].blank?
				logger.info "Producer found"
				update_attribute(:producer, reader.info[:Producer])
			else
				update_attribute(:producer, nil)
			end
		rescue ArgumentError => e
			logger.info "Error reading Producer metadata"
			logger.info e.message
		end
		begin
			if !reader.info[:Producer].blank?
				logger.info "Producer found"
				update_attribute(:producer, reader.info[:Producer])
			else
				update_attribute(:producer, nil)
			end
		rescue ArgumentError => e
			logger.info "Error reading Producer metadata"
			logger.info e.message
		end

		# CHECK TO SEE IF CURRENT USER TRIES TO FETCH A PUBLICATION ALREADY PRESENT ON RS_SERVER

		begin
			if reader.info.key?(:BaseUrl)
				logger.info "This is a publication which is already present on RS_Server"
				raise I18n.t("errors.messages.publication_already_fetched")
			end
		rescue ArgumentError
			logger.info "Error reading Base Url metadata"
			logger.info "Probably this publication is not present on RS_Server"
		end

		# EDITING OF PDF FILE WITH RS_PDF STARTS HERE

		logger.info "Checking again existence of: #{absolute_pdf_download_path(data[:user])}"
		if File.exist?(absolute_pdf_download_path(data[:user]))
			logger.info "File exists"
			logger.info "RS_PDF execution started"
			logger.info "Path: #{absolute_rs_pdf_path}"
			logger.info "with options:"
			logger.info "-pIn: #{absolute_pdf_download_path(data[:user])}"
			logger.info "-pOut: #{absolute_pdf_storage_path(data[:user])}"
			logger.info "-u: #{data[:rate_path]}"
			logger.info "-c: Click here"
			logger.info "-pId: #{data[:pub_id]}"
			logger.info "-a: #{data[:authToken]}"
			logger.info "Complete command:"
			logger.info "java -jar #{absolute_rs_pdf_path} -pIn #{absolute_pdf_download_path(data[:user])} -pOut #{absolute_pdf_storage_path(data[:user])} -u #{data[:rate_path]} -c \"Express your rating\""
			output = %x( java -jar #{absolute_rs_pdf_path} -pIn #{absolute_pdf_download_path(data[:user])} -pOut #{absolute_pdf_storage_path(data[:user])} -u #{data[:rate_path]} -c "Express your rating")
			logger.info output
			logger.info "RS_PDF execution completed"
			File.delete(absolute_pdf_download_path(data[:user]))
			logger.info "Modified file"
			logger.info "Name: #{pdf_name_link}"
			logger.info "Download path: #{pdf_download_path_link}"
		else
			raise "File does not exists at #{absolute_pdf_download_path(data[:user])}"
		end
	end

	# The following method extract the BaseUrl metadata from an uploaded PDF file.
	def self.extract_base_url(file, user, request_data)
		current_host = request_data.values[1]
		logger.info "Copying temporary file with original name: #{file.original_filename}"
		FileUtils::mkdir_p absolute_pdf_storage_temp_path(user)
		temp_file_name_without_ext = remove_extension_from_filename(file.original_filename)
		temp_path = absolute_pdf_storage_temp_path(user).join("#{temp_file_name_without_ext}-Tmp.pdf")
		logger.info "Temporary path generated: #{temp_path}"
		temp_file_content_type = file.content_type
		logger.info "Temporary file content type: #{temp_file_content_type}"
		if temp_file_content_type == "application/pdf"
			FileUtils.cp(file.tempfile, temp_path)
			logger.info "Temporary file successfully copied"
			logger.info "Reading metadata from: #{temp_path}"
			reader = PDF::Reader.new(temp_path)
			base_url = reader.info[:BaseUrl]
			if !base_url.blank?
				logger.info "Base Url found: #{base_url}"
				logger.info "Comparing with Current Host: #{current_host}"
				if base_url.include?(current_host)
					return base_url
				else
					raise I18n.t("errors.messages.publication_fetched_somewhere_else")
				end
			else
				logger.info "Base Url not found"
				raise I18n.t("errors.messages.base_url_not_found")
			end
		else
			raise I18n.t("errors.messages.content_type_not_application_pdf")
		end
	end

	def remove_files(user)
		if File.exists? absolute_pdf_storage_path(user)
			logger.info "Deleting storage folder at: #{absolute_pdf_storage_path(user)}"
			FileUtils.rm_rf(absolute_pdf_storage_path(user))
		else
			logger.info "Storage folder not detected."
		end
	end

	def remove_annotated_file(user)
		if File.exists? absolute_pdf_download_path_link(user)
			logger.info "Deleting old annotated version at: #{absolute_pdf_download_path_link(user)}"
			File.delete(absolute_pdf_download_path_link(user))
		else
			logger.info "Old annotated version not detected."
		end
	end

	def other_users(current_user)
		other_users = Set.new
		self.ratings.each do |rating|
			other_user = rating.user
			if other_user != current_user
				other_users.add other_user
			end
		end
		other_users
	end

	def ratings_history
		Rating.where(publication_id: self.id).order(created_at: :asc).all
	end

	def pdf_download_url(host, user)
		pdf_name_without_ext = remove_extension_from_filename(pdf_name)
		pdf_name = "#{pdf_name_without_ext}.pdf"
		"#{host}/user/#{user.id}/#{pdf_storage_path}#{pdf_name}"
	end

	def pdf_download_url_link(host, user)
		pdf_name_without_ext = remove_extension_from_filename(pdf_name)
		"#{host}/user/#{user.id}/#{pdf_storage_path}#{pdf_name_without_ext}#{Settings.rs_pdf_link_suffix}.pdf"
	end

	private

	def remove_extension_from_filename(filename)
		filename.chomp(".pdf").gsub(/\s+/, '-')
	end

	def self.remove_extension_from_filename(filename)
		filename.chomp(".pdf").gsub(/\s+/, '-')
	end

	def load_pdf_paths(pdf_name, host)
		pdf_name_without_ext = remove_extension_from_filename(pdf_name)
		pdf_name = "#{pdf_name_without_ext}.pdf"
		update_attribute(:pdf_storage_path, "publication/pdf/#{id}/")
		update_attribute(:pdf_download_path, "#{pdf_storage_path}#{pdf_name}")
		update_attribute(:pdf_name, pdf_name)
		update_attribute(:pdf_download_path_link, "#{pdf_storage_path}#{pdf_name_without_ext}#{Settings.rs_pdf_link_suffix}.pdf")
		update_attribute(:pdf_name_link, "#{pdf_name_without_ext}#{Settings.rs_pdf_link_suffix}.pdf")
	end

	def absolute_rs_pdf_path
		Rails.root.join("lib").join(Settings.rs_pdf_name)
	end

	def absolute_pdf_storage_path(user)
		Rails.public_path.join("user").join(user.id.to_s).join(pdf_storage_path)
	end

	def absolute_pdf_download_path(user)
		Rails.public_path.join("user").join(user.id.to_s).join(pdf_download_path)
	end

	def absolute_pdf_download_path_link(user)
		Rails.public_path.join("user").join(user.id.to_s).join(pdf_download_path_link)
	end

	def self.absolute_pdf_storage_temp_path(user)
		Rails.public_path.join("user").join(user.id.to_s).join("tmp")
	end

end


