class RatingsController < ApplicationController

	before_action :set_rating, only: [:show, :update, :destroy]

	# GET /ratings.json
	def index
		@ratings = Rating.all
	end

	# GET /ratings/1.json
	def show
	end

	# POST /ratings.json
	def create
		@rating = Rating.new(rating_params)

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

	def set_user
		@user = User.find(params[:user_id])
	end

	def set_publication
		@rating = Publication.find(params[:publication_id])
	end

	def rating_params
		params.require(:rating).permit(:score, :user_id, :publication_id)
	end
end
