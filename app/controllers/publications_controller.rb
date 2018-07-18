class PublicationsController < ApplicationController

	before_action :set_publication, only: [:show, :update, :destroy, :fetch]

	# GET /publications.json
	def index
		@publications = Publication.all
	end

	# GET /publications/1.json
	def show
	end

	# POST /publications/1/fetch.json
	def fetch
		@publication.fetch
		render :fetch, status: :ok, location: @publication
	end

	# POST /publications.json
	def create
		@publication = Publication.new(publication_params)
		if @publication.save
			render :show, status: :created, location: @publication
		else
			render json: @publication.errors, status: :unprocessable_entity
		end
	end

	# PATCH/PUT /publications/1.json
	def update
		if @publication.update(publication_params)
			render :show, status: :ok, location: @publication
		else
			render json: @publication.errors, status: :unprocessable_entity
		end
	end

	# DELETE /publications/1.json
	def destroy
		@publication.destroy
	end

	private

	def set_publication
		@publication = Publication.find(params[:id])
	end

	def publication_params
		params.require(:publication).permit(:doi, :title, :pdf_url)
	end
end
