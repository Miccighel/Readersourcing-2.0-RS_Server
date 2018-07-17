class PublicationsController < ApplicationController

  before_action :set_publication, only: [:show, :update, :destroy]

  # GET /publications.json
  def index
    @publications = Publication.all
  end

  # GET /publications/1.json
  def show
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
    # Use callbacks to share common setup or constraints between actions.
    def set_publication
      @publication = Publication.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def publication_params
      params.require(:publication).permit(:doi, :title)
    end
end
