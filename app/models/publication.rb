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
		copy_for(user)&.available?("annotated") || false
	end

	def is_fetchable(deadline: PdfOperationDeadline.new)
		logger.info "Checking whether the publication URL returns a valid bounded PDF"
		download = pdf_fetcher.fetch(deadline: deadline)
		PdfInspector.new.call(download.io.path, deadline: deadline)
		true
	rescue PdfFetcher::Error, PdfInspector::Error, PdfOperationDeadline::Exceeded => error
		logger.info "The publication is not fetchable: #{error.message}"
		raise PublicationPreparationError.wrap(error)
	ensure
		download&.close
	end

	def fetch(request_data, source: nil, deadline: PdfOperationDeadline.new)

		data = Hash.new
		data[:host] = request_data.fetch(:host)
		data[:pub_id] = self.id
		data[:user] = request_data.fetch(:user)
		data[:paper_reference] = PaperRatingReference.issue(user: data[:user], publication: self)
		data[:rate_path] = "#{data[:host]}#{Rails.application.routes.url_helpers.rate_paper_path(data[:pub_id], data[:paper_reference])}"

		# FILE FETCHING STARTS HERE

		logger.info "Downloading a bounded PDF from the configured publication host"
		download = source || pdf_fetcher.fetch(deadline: deadline)
		deadline.check!
		filename = download.filename
		logger.info "File name: #{filename}"
		logger.info "Downloaded bytes: #{download.content_length}"

		# PDF VALIDATION AND EDITING START HERE

		logger.info "RS_PDF execution started"
		result = nil
		transaction(requires_new: true) do |transaction|
			store = PublicationCopyStore.new(PublicationCopy.root_for(self, data[:user]))
			copy = store.prepare(publication: self, user: data[:user], filename: filename, transaction: transaction) do |staged|
				result = pdf_preparer.call(
					download: download,
					storage_path: staged.directory,
					target_path: staged.path("annotated"),
					original_path: staged.path("original"),
					rate_path: data[:rate_path],
					deadline: deadline
				) { |metadata| update_pdf_metadata(metadata) }
			end
			deadline.check!
			@publication_copies ||= {}
			@publication_copies[data[:user].id] = copy
			transaction.after_rollback { @publication_copies.delete(data[:user].id) }
		end
		logger.info result.stdout unless result.stdout.blank?
		logger.info "RS_PDF execution completed"
	rescue PdfFetcher::Error, PdfUpload::Error, PdfInspector::Error,
	       RsPdfRunner::ExecutionError, AnnotatedPdfVerifier::VerificationError,
	       PdfOperationDeadline::Exceeded => error
		raise PublicationPreparationError.wrap(error)
	ensure
		download&.close
	end

	# Extracts the BaseUrl metadata from an uploaded PDF file.
	def self.extract_base_url(file, user, request_data)
		PdfRatingUrlExtractor.new.call(file, user: user, host: request_data.fetch(:host))
	end

	def remove_files(user)
		paths = [PublicationCopy.root_for(self, user), PublicationCopy.legacy(publication: self, user: user).directory].uniq
		paths.each do |path|
			FileUtils.remove_entry_secure(path) if path.directory?
		end
		@publication_copies&.delete(user.id)
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

	def pdf_download_url(host, user, copy: copy_for(user))
		pdf_url_for(host, user, variant: "original", copy: copy)
	end

	def pdf_download_url_link(host, user, copy: copy_for(user))
		pdf_url_for(host, user, variant: "annotated", copy: copy)
	end

	def copy_for(user)
		@publication_copies&.fetch(user.id, nil) || PublicationCopy.current(publication: self, user: user)
	end

	def pdf_file_path(user, variant:)
		copy = copy_for(user) || PublicationCopy.legacy(publication: self, user: user)
		copy.path(variant)
	end

	def pdf_filename(variant:, user: nil)
		return copy_for(user)&.name(variant) if user

		case variant.to_s
		when "original"
			"#{remove_extension_from_filename(pdf_name)}.pdf"
		when "annotated"
			"#{remove_extension_from_filename(pdf_name)}#{Settings.rs_pdf_link_suffix}.pdf"
		else
			raise ArgumentError, "Unsupported PDF variant"
		end
	end

	def self.storage_root
		configured_path = ENV["RS_PDF_STORAGE_ROOT"].presence
		configured_path ||= Rails.root.join("storage", "publications").to_s
		Pathname.new(configured_path).expand_path
	end

	def self.absolute_pdf_storage_temp_path(user)
		storage_root.join("user", user.id.to_s, "tmp")
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

	def pdf_url_for(host, user, variant:, copy:)
		return unless copy&.available?(variant)

		filename = copy.name(variant)
		reference = PublicationDownloadReference.issue(
			user: user,
			publication: self,
			variant: variant,
			filename: filename,
			generation: copy.generation
		)
		path = Rails.application.routes.url_helpers.publication_download_path(
			id: id,
			variant: variant,
			reference: reference,
			filename: filename
		)
		"#{host.to_s.delete_suffix("/")}#{path}"
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
		PublicationCopy.root_for(self, user)
	end

	def absolute_pdf_download_path(user)
		pdf_file_path(user, variant: "original")
	end

	def absolute_pdf_download_path_link(user)
		pdf_file_path(user, variant: "annotated")
	end

end


