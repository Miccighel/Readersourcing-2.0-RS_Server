class RatingsController < ApplicationController

	before_action :set_rating, only: [:show, :update, :destroy]

	skip_before_action :authenticate_request, only: :rate

	# GET /ratings.json
	def index
		@ratings = Rating.all
	end

	# GET /ratings/1.json
	def show
	end

	# GET /rate/:pubId/:authToken
	def rate
		@publication = Publication.find(params[:pubId])
		@encrypted_auth_token = decrypt params[:authToken]
		@rating = Rating.new
		puts "Publication: #{@publication}"
		puts "Encrypted Auth Token: #{@encrypted_auth_token}"
		render :rate
		# User.find(decoded_auth_token[:user_id]) if decoded_auth_token
	end

	# POST /ratings.json
	def create
		@rating = Rating.new
		@rating.score = rating_params[:score]
		@rating.user = current_user
		publication = Publication.find_by_pdf_url(rating_params[:pdf_url])
		if publication
			@rating.publication = publication
		else
			publication = Publication.new
			publication.pdf_url = rating_params[:pdf_url]
			publication.save
			@rating.publication = publication
		end
		if @rating.save
			render :show, status: :created, location: @rating
		else
			render json: @rating.errors, status: :unprocessable_entity
		end
	end

	# PATCH/PUT /ratings/1.json
	def update
		if @rating.update(rating_params)
			render :show, status: :ok, location: @rating
		else
			render json: @rating.errors, status: :unprocessable_entity
		end
	end

	# DELETE /ratings/1.json
	def destroy
		@rating.destroy
	end

	private

	def set_rating
		@rating = Rating.find(params[:id])
	end

	def set_publication
		@rating = Publication.find(params[:publication_id])
	end

	def rating_params
		params.require(:rating).permit(:score, :user_id, :publication_id, :pdf_url)
	end
end
