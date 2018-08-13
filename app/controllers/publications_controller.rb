class PublicationsController < ApplicationController

	before_action :set_publication, only: [:show, :update, :destroy, :refresh, :is_rated]
	before_action :set_error_manager, only: [:lookup, :is_rated]

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
			render :show, status: :found, location: @publication
		else
			@error_manager.add_error(I18n.t("models.publications.errors.messages.lookup_error"))
			render partial: "shared/errors", status: :not_found, locals: {errors: @error_manager.get_errors}
		end
	end

	# GET /publications/random.json
	def random
		publication_id = Publication.pluck(:id).shuffle[0]
		@publication = Publication.find(publication_id)
		render :show, status: :ok, location: @publication
	end

	# GET /publications/1/is_rated.json
	def is_rated
		rating = @publication.is_rated(current_user)
		if rating != nil
			render rating, status: :ok
		else
			@error_manager.add_error(I18n.t("models.publications.errors.messages.is_rated_error"))
			render partial: "shared/errors", status: :not_found, locals: {errors: @error_manager.get_errors}
		end
	end

	# POST /publications.json
	def create
		@publication = Publication.new(publication_params)
		if @publication.save
			@publication.fetch
			render :show, status: :created, location: @publication
		else
			render json: @publication.errors, status: :unprocessable_entity
		end
	end

	# POST /publications/fetch.json
	def fetch
		if Publication.exists?(pdf_url: publication_params[:pdf_url])
			@publication = Publication.find_by_pdf_url(publication_params[:pdf_url])
			@publication.fetch
			render :show, status: :ok, location: @publication
		else
			@publication = Publication.new(pdf_url: publication_params[:pdf_url])
			if @publication.save
				@publication.fetch
				render :show, status: :created, location: @publication
			else
				render json: @publication.errors, status: :unprocessable_entity
			end
		end

	end

	# GET /publications/1/refresh.json
	def refresh
		@publication.fetch
		render :show, status: :ok, location: @publication
	end

	# PATCH/PUT /publications/1.json
	def update
		if @publication.update(publication_params)
			@publication.fetch
			render :show, status: :ok, location: @publication
		else
			render json: @publication.errors, status: :unprocessable_entity
		end
	end

	# DELETE /publications/1.json
	def destroy
		@publication.remove_files
		@publication.destroy
	end

	private

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
