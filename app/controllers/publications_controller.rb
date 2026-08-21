class PublicationsController < ApplicationController

	before_action :authorize_api_request, only: [:index, :show, :lookup, :random, :is_rated, :is_saved_for_later, :create, :is_fetchable, :extract, :fetch, :fetch_upload, :refresh]
	before_action :authorize_server_request, only: [:list]

	before_action :set_user, :set_request_data
	before_action :set_publication, only: [:show, :refresh, :is_rated, :is_saved_for_later]
	before_action :set_error_manager, only: [:lookup, :is_rated, :is_saved_for_later, :fetch, :fetch_upload, :is_fetchable, :extract, :refresh, :create]

	rate_limit(
		**RequestRateLimit::PDF_PROCESSING.rails_options,
		by: -> { RequestRateLimit.for_user(current_user) },
		with: -> { render_rate_limited(RequestRateLimit::PDF_PROCESSING) },
		scope: :publication_processing,
		only: [:create, :is_fetchable, :extract, :fetch, :fetch_upload, :refresh]
	)

	# GET /publications.json
	def index
		@publications = Publication.all
	end

	# GET /publications/list/
	def list
		@publications = Publication.all
		render 'list'
	end

	# GET /publications/1.json
	def show
	end

	# POST /publications/lookup.json
	def lookup
		@publication = Publication.find_by_pdf_url(publication_params[:pdf_url])
		if @publication
			render :show_without_paths, status: :ok, location: @publication
		else
			@error_manager.add_error(I18n.t("models.publications.errors.messages.lookup_error"))
			render json: {errors: @error_manager.get_errors}, status: :not_found
		end
	end

	# GET /publications/random.json
	def random
		publication_id = Publication.pluck(:id).shuffle[0]
		@publication = Publication.find(publication_id)
		render :show_without_paths, status: :ok, location: @publication
	end

	# GET /publications/1/is_rated.json
	def is_rated
		if @publication.pdf_url == "https://arxiv.org/pdf/1812.05594.pdf"
			render json: {errors: [I18n.t("information.messages.test_url")]}, status: :not_found
		else
			rating = @publication.is_rated(current_user)
			if rating != nil
				render rating, status: :ok
			else
				@error_manager.add_error(I18n.t("models.publications.errors.messages.is_rated_error"))
				render json: {errors: @error_manager.get_errors}, status: :not_found
			end
		end
	end

	# GET /publications/1/is_saved_for_later.json
	def is_saved_for_later
		if @publication.pdf_url == "https://arxiv.org/pdf/1812.05594.pdf"
			render json: {errors: [I18n.t("information.messages.test_url")]}, status: :not_found
		else
			if @publication.is_saved_for_later(current_user)
				render :show, status: :ok, location: @publication
			else
				@error_manager.add_error(I18n.t("errors.messages.publication_not_saved_for_later"))
				render json: {errors: @error_manager.get_errors}, status: :not_found
			end
		end
	end

	# POST /publications.json
	def create
		@publication = Publication.new(publication_params)
		prepare_and_render
	end

	# POST /publications/is_fetchable.json
	def is_fetchable
		@publication = Publication.find_by_pdf_url(publication_params[:pdf_url])
		@publication ||= Publication.new(pdf_url: publication_params[:pdf_url])
		@publication.is_fetchable

		render json: {
			status: "available",
			message: I18n.t("confirmations.messages.fetchable_publication"),
			publication_id: @publication.id
		}.compact, status: :ok
	rescue PublicationPreparationError => error
		render_preparation_error(error)
	end

	# POST /publications/extract.json
	def extract
		if params.has_key?(:file)
			begin
				base_url = Publication.extract_base_url(params[:file], current_user, @request_data)
				render json: {message: I18n.t("confirmations.messages.base_url_found"), baseUrl: base_url}, status: :ok
			rescue RuntimeError => error
				@error_manager.add_error(error.message)
				render json: {errors: @error_manager.get_errors}, status: :unprocessable_entity
			rescue ArgumentError
				@error_manager.add_error(I18n.t("errors.messages.error_reading_base_url"))
				render json: {errors: @error_manager.get_errors}, status: :unprocessable_entity
			end
		else
			@error_manager.add_error(I18n.t("errors.messages.pdf_not_uploaded"))
			render json: {errors: @error_manager.get_errors}, status: :not_found
		end
	end

	# POST /publications/fetch.json
	def fetch
		@publication = Publication.find_or_initialize_by(pdf_url: publication_params[:pdf_url])
		prepare_and_render
	end

	# POST /publications/fetch_upload.json
	def fetch_upload
		source = PdfUpload.new(params[:file]).fetch
		@publication = Publication.find_or_initialize_by(pdf_url: publication_params[:pdf_url])
		prepare_and_render(source: source)
	rescue PdfUpload::Error => error
		render_preparation_error(PublicationPreparationError.wrap(error))
	ensure
		source&.close
	end

	# POST /publications/1/refresh.json
	def refresh
		@publication.transaction { @publication.fetch @request_data }
		render :show, status: :ok, location: @publication
	rescue PublicationPreparationError => error
		render_preparation_error(error)
	end

	private

	def set_request_data
		@request_data = {}
		@request_data[:host] = PublicBaseUrl.for(request).to_s
		@request_data[:user] = current_user
	end

	def set_user
		@user = current_user
	end

	def set_publication
		@publication = Publication.find(params[:id])
	end

	def set_error_manager
		@error_manager = ErrorManager.new
	end

	def publication_params
		params.require(:publication).permit(:doi, :title, :subject, :creator, :author, :pdf_url)
	end

	def prepare_and_render(source: nil)
		created = @publication.new_record?
		saved = true

		@publication.transaction do
			saved = @publication.save if created
			raise ActiveRecord::Rollback unless saved

			@publication.fetch @request_data, source: source
		end

		if saved
			render :show, status: created ? :created : :ok, location: @publication
		else
			render json: @publication.errors, status: :unprocessable_entity
		end
	rescue PublicationPreparationError => error
		render_preparation_error(error)
	ensure
		source&.close
	end

	def render_preparation_error(error)
		render json: {
			status: error.code,
			message: error.message,
			errors: [error.message],
			upload_supported: true
		}, status: error.http_status
	end

end
