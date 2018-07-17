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
    # Use callbacks to share common setup or constraints between actions.
    def set_rating
      @rating = Rating.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def rating_params
      params.require(:rating).permit(:value)
    end
end
