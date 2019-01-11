class PublicationsController < ApplicationController

	before_action :set_user, :set_request_data
	before_action :set_publication, only: [:show, :update, :destroy, :refresh, :is_rated, :is_saved_for_later]
	before_action :set_error_manager, only: [:lookup, :is_rated, :is_saved_for_later, :is_fetchable]

	# GET /publications.json
	def index
		@publications = Publication.all
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
		rating = @publication.is_rated(current_user)
		if rating != nil
			render rating, status: :ok
		else
			@error_manager.add_error(I18n.t("models.publications.errors.messages.is_rated_error"))
			render json: {errors: @error_manager.get_errors}, status: :not_found
		end
	end

	# GET /publications/1/is_saved_for_later.json
	def is_saved_for_later
		if @publication.is_saved_for_later(current_user)
			render :show, status: :ok, location: @publication
		else
			@error_manager.add_error("not saved for later")
			render json: {errors: @error_manager.get_errors}, status: :not_found
		end
	end

	# POST /publications.json
	def create
		@publication = Publication.new(publication_params)
		if @publication.save
			@publication.fetch @request_data
			render :show, status: :created, location: @publication
		else
			render json: @publication.errors, status: :unprocessable_entity
		end
	end

	# POST /publications/is_fetchable.json
	def is_fetchable
		if Publication.exists?(pdf_url: publication_params[:pdf_url])
			@publication = Publication.find_by_pdf_url(publication_params[:pdf_url])
			render "publications/show_without_paths", status: :ok, location: @publication
		else
			@publication = Publication.new(pdf_url: publication_params[:pdf_url])
			if @publication.is_fetchable
				render json: {message: I18n.t("confirmations.messages.fetchable_publication")}, status: :ok
			else
				@error_manager.add_error(I18n.t("errors.messages.unfetchable_publication"))
				render json: {errors: @error_manager.get_errors}, status: :not_found
			end
		end
	end

	# POST /publications/extract.json
	def extract
		file = params[:file]
		logger.info "Reading metadata from: #{file.original_filename}"
		logger.info absolute_pdf_storage_temp_path
		# TODO: Salva il file nella posizione temporanea e leggine i metadati.
		render json: {message: "Test"}, status: :ok
	end

	# POST /publications/fetch.json
	def fetch
		if Publication.exists?(pdf_url: publication_params[:pdf_url])
			@publication = Publication.find_by_pdf_url(publication_params[:pdf_url])
			@publication.fetch @request_data
			render :show, status: :ok, location: @publication
		else
			@publication = Publication.new(pdf_url: publication_params[:pdf_url])
			if @publication.save
				@publication.fetch @request_data
				render :show, status: :created, location: @publication
			else
				render json: @publication.errors, status: :unprocessable_entity
			end
		end

	end

	# GET /publications/1/refresh.json
	def refresh
		@publication.fetch @request_data
		render :show, status: :ok, location: @publication
	end

	# PATCH/PUT /publications/1.json
	def update
		if @publication.update(publication_params)
			@publication.fetch @request_data
			render :show, status: :ok, location: @publication
		else
			render json: @publication.errors, status: :unprocessable_entity
		end
	end

	# DELETE /publications/1.json
	def destroy
		@publication.remove_files(current_user)
		@publication.destroy
	end

	private

	def set_request_data
		@request_data = Hash.new
		@request_data[:authToken] = encrypt request.headers["Authorization"]
		@request_data[:host] = "#{request.protocol}#{request.host_with_port}"
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

	def absolute_pdf_storage_temp_path
		Rails.public_path.join("user").join(current_user.id.to_s).join("temp")
	end

end
