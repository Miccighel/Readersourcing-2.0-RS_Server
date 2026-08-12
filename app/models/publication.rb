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
		logger.info "Checking whether the publication URL returns a valid bounded PDF"
		download = pdf_fetcher.fetch
		PdfInspector.new.call(download.io.path)
		true
	rescue PdfFetcher::Error, PdfInspector::Error => error
		logger.info "The publication is not fetchable: #{error.message}"
		raise PublicationPreparationError.wrap(error)
	ensure
		download&.close
	end

	def fetch(request_data, source: nil)

		data = Hash.new
		data[:host] = request_data.fetch(:host)
		data[:pub_id] = self.id
		data[:user] = request_data.fetch(:user)
		data[:paper_reference] = PaperRatingReference.issue(user: data[:user], publication: self)
		data[:rate_path] = "#{data[:host]}#{Rails.application.routes.url_helpers.rate_paper_path(data[:pub_id], data[:paper_reference])}"

		# FILE FETCHING STARTS HERE

		logger.info "Downloading a bounded PDF from the configured publication host"
		download = source || pdf_fetcher.fetch
		filename = download.filename
		load_pdf_paths(filename, data[:host])
		logger.info "File name: #{filename}"

		logger.info "Creating folder at #{absolute_pdf_storage_path(data[:user])}."
		FileUtils::mkdir_p absolute_pdf_storage_path(data[:user])
		logger.info "Downloaded bytes: #{download.content_length}"

		# PDF VALIDATION AND EDITING START HERE

		logger.info "RS_PDF execution started"
		storage_path = absolute_pdf_storage_path(data[:user])
		result = pdf_preparer.call(
			download: download,
			storage_path: storage_path,
			target_path: absolute_pdf_download_path_link(data[:user]),
			rate_path: data[:rate_path]
		) { |metadata| update_pdf_metadata(metadata) }
		logger.info result.stdout unless result.stdout.blank?
		logger.info "RS_PDF execution completed"
		logger.info "Modified file"
		logger.info "Name: #{pdf_name_link}"
		logger.info "Download path: #{pdf_download_path_link}"
	rescue PdfFetcher::Error, PdfUpload::Error, PdfInspector::Error,
	       RsPdfRunner::ExecutionError, AnnotatedPdfVerifier::VerificationError => error
		raise PublicationPreparationError.wrap(error)
	ensure
		download&.close
	end

	# Extracts the BaseUrl metadata from an uploaded PDF file.
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
				logger.info "BaseUrl found: #{base_url}"
				logger.info "Comparing with current host: #{current_host}"
				if base_url.include?(current_host)
					return base_url
				else
					raise I18n.t("errors.messages.publication_fetched_somewhere_else")
				end
			else
				logger.info "BaseUrl not found"
				raise I18n.t("errors.messages.base_url_not_found")
			end
		else
			raise I18n.t("errors.messages.content_type_not_application_pdf")
		end
	end

	def remove_files(user)
		if File.exist? absolute_pdf_storage_path(user)
			logger.info "Deleting storage folder at: #{absolute_pdf_storage_path(user)}"
			FileUtils.rm_rf(absolute_pdf_storage_path(user))
		else
			logger.info "Storage folder not detected."
		end
	end

	def remove_annotated_file(user)
		if File.exist? absolute_pdf_download_path_link(user)
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
		safe_pdf_stem(filename)
	end

	def self.remove_extension_from_filename(filename)
		safe_pdf_stem(filename)
	end

	def self.safe_pdf_stem(filename)
		base_name = File.basename(filename.to_s.tr("\\", "/"))
		stem = base_name.sub(/\.pdf\z/i, "")
		stem = stem.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
		stem = stem.delete("\0").gsub(/[[:cntrl:]]/, "")
		stem = stem.gsub(/[^\p{Alnum}_.()\-]+/u, "-").sub(/\A[.\-]+/, "")
		stem.blank? ? "publication" : stem
	end

	def safe_pdf_stem(filename)
		self.class.safe_pdf_stem(filename)
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

	def pdf_fetcher
		PdfFetcher.new(pdf_url)
	end

	def rs_pdf_runner
		RsPdfRunner.new(jar_path: absolute_rs_pdf_path)
	end

	def pdf_preparer
		PdfPreparation.new(runner: rs_pdf_runner)
	end

	def update_pdf_metadata(metadata)
		{
			doi: :doi,
			title: :Title,
			subject: :Subject,
			author: :Author,
			creator: :Creator,
			producer: :Producer
		}.each do |attribute, metadata_key|
			value = metadata[metadata_key]
			value = value.sub(/\Adoi:/i, "") if attribute == :doi && value.respond_to?(:sub)
			logger.info "#{metadata_key} found" unless value.blank?
			update_attribute(attribute, value.presence)
		rescue ArgumentError => error
			logger.info "Error reading #{metadata_key} metadata"
			logger.info error.message
		end
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


