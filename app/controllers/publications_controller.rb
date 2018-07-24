class PublicationsController < ApplicationController

	before_action :set_publication, only: [:show, :update, :destroy, :refresh]

	# GET /publications.json
	def index
		@publications = Publication.all
	end

	# GET /publications/1.json
	def show
	end

	# GET /publications/random.json
	def random
		publication_id = Publication.pluck(:id).shuffle[0]
		@publication = Publication.find(publication_id)
		render :show, status: :ok, location: @publication
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

	# POST /publications/fetch.json
	def fetch
		if Publication.exists?(pdf_url: publication_params[:pdf_url])
			@publication = Publication.find_by_pdf_url(publication_params[:pdf_url])
			@publication.fetch
			render :fetch, status: :ok, location: @publication
		else
			@publication = Publication.create(pdf_url: publication_params[:pdf_url])
			@publication.fetch
			render :fetch, status: :created, location: @publication
		end

	end

	# GET /publications/1/refresh.json
	def refresh
		@publication.fetch
		render :fetch, status: :ok, location: @publication
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
		params.require(:publication).permit(:doi, :title, :subject, :pdf_url)
	end
end
