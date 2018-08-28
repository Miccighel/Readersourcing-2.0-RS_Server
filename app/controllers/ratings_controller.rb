class RatingsController < ApplicationController

    before_action :set_rating, only: [:show, :update, :destroy]

    skip_before_action :authenticate_request, only: [:rate, :load]

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
        auth_token = decrypt(params[:authToken])
        @payload = JsonWebToken.decode(auth_token)
        @user = User.find(@payload[:user_id])
        @rating = Rating.new
        logger.info "Publication: #{@publication}"
        logger.info "Auth Token: #{auth_token}"
        logger.info "Payload: #{@payload}"
        logger.info "User: #{@user}"
        render :rate
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

    # POST /load
    def load
        requesting_user = User.find params[:userId]
        publication = Publication.find params[:pubId]
        if User.exists?(email: params[:email])
            logged_user = User.find_by_email params[:email]
            if requesting_user.id == logged_user.id and requesting_user.email == logged_user.email and BCrypt::Password.new(logged_user.password_digest) == params[:password]
                if Rating.exists?(user_id: requesting_user.id, publication_id: publication.id)
                    render :already_given
                else
                    @rating = Rating.new rating_params
                    @rating.publication = publication
                    @rating.user = requesting_user
                    if @rating.save
                        render :successful
                    else
                        render :unsuccessful
                    end
                end
            else
                render :not_the_same_user
            end
        else
            render :not_the_same_user
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
