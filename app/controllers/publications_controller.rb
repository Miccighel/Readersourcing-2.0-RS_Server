class PublicationsController < ApplicationController

	before_action :set_user, :set_request_data
	before_action :set_publication, only: [:show, :update, :destroy, :refresh, :is_rated, :is_saved_for_later]
	before_action :set_error_manager, only: [:lookup, :is_rated, :is_saved_for_later, :fetch, :is_fetchable, :extract, :refresh, :create, :update]

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
			@error_manager.add_error(I18n.t("errors.messages.publication_not_saved_for_later"))
			render json: {errors: @error_manager.get_errors}, status: :not_found
		end
	end

	# POST /publications.json
	def create
		@publication = Publication.new(publication_params)
		begin
			@publication.transaction do
				if @publication.save
					begin
						@publication.fetch @request_data
						render :show, status: :created, location: @publication
					rescue RuntimeError => error
						raise ActiveRecord::Rollback error.message
					end
				else
					render json: @publication.errors, status: :unprocessable_entity
				end
			rescue ActiveRecord::Rollback => error
				@error_manager.add_error(error.message)
				render json: {errors: @error_manager.get_errors}, status: :unprocessable_entity
			end
		end
	end

	# POST /publications/is_fetchable.json
	def is_fetchable
		if Publication.exists?(pdf_url: publication_params[:pdf_url])
			@publication = Publication.find_by_pdf_url(publication_params[:pdf_url])
			render "publications/show_without_paths", status: :ok, location: @publication
		else
			@publication = Publication.new(pdf_url: publication_params[:pdf_url])
			begin
				if @publication.is_fetchable
					render json: {message: I18n.t("confirmations.messages.fetchable_publication")}, status: :ok
				else
					@error_manager.add_error(I18n.t("errors.messages.unfetchable_publication"))
					render json: {errors: @error_manager.get_errors}, status: :unprocessable_entity
				end
			rescue SocketError
				@error_manager.add_error(message: I18n.t("errors.messages.unfetchable_publication_host"))
				render json: {errors: @error_manager.get_errors}, status: :unprocessable_entity
			rescue SystemCallError => error
				@error_manager.add_error(error.message)
				render json: {errors: @error_manager.get_errors}, status: :internal_server_error
			end
		end
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
		if Publication.exists?(pdf_url: publication_params[:pdf_url])
			@publication = Publication.find_by_pdf_url(publication_params[:pdf_url])
			begin
				@publication.transaction do
					begin
						@publication.fetch @request_data
						render :show, status: :ok, location: @publication
					rescue RuntimeError => error
						raise ActiveRecord::Rollback error.message
					end
				rescue ActiveRecord::Rollback => error
					@error_manager.add_error(error.message)
					render json: {errors: @error_manager.get_errors}, status: :unprocessable_entity
				end
			end
		else
			@publication = Publication.new(pdf_url: publication_params[:pdf_url])
			begin
				@publication.transaction do
					if @publication.save
						begin
							@publication.fetch @request_data
							render :show, status: :created, location: @publication
						rescue RuntimeError => error
							raise ActiveRecord::Rollback error.message
						end
					else
						render json: @publication.errors, status: :unprocessable_entity
					end
				rescue ActiveRecord::Rollback => error
					@error_manager.add_error(error.message)
					render json: {errors: @error_manager.get_errors}, status: :unprocessable_entity
				end
			end
		end
	end

	# GET /publications/1/refresh.json
	def refresh
		begin
			@publication.transaction do
				@publication.fetch @request_data
				render :show, status: :ok, location: @publication
			rescue RuntimeError => error
				raise ActiveRecord::Rollback error.message
			end
		rescue ActiveRecord::Rollback => error
			@error_manager.add_error(error.message)
			render json: {errors: @error_manager.get_errors}, status: :unprocessable_entity
		end
	end

	# PATCH/PUT /publications/1.json
	def update
		begin
			@publication.transaction do
				if @publication.update(publication_params)
					@publication.remove_files(current_user)
					begin
						@publication.fetch @request_data
						render :show, status: :ok, location: @publication
					rescue RuntimeError => error
						raise ActiveRecord::Rollback error.message
					end
				else
					render json: @publication.errors, status: :unprocessable_entity
				end
			rescue ActiveRecord::Rollback => error
				@error_manager.add_error(error.message)
				render json: {errors: @error_manager.get_errors}, status: :unprocessable_entity
			end
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

end
