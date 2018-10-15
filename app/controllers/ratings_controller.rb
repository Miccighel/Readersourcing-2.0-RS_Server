class RatingsController < ApplicationController

	include ::ActionView::Layouts

	layout "application", only: [:rate, :load]

	before_action :set_rating, only: [:show, :update]

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
		delete_old_rating = params[:delete]
		@publication = Publication.find(params[:pubId])
		@crypted_auth_token = params[:authToken]
		auth_token = decrypt(params[:authToken])
		payload = JsonWebToken.decode(auth_token)
		puts payload
		expiration_time = Time.at payload[:exp]
		@user = User.find(payload[:user_id])
		@rating = Rating.new
		logger.info "Publication: #{@publication}"
		logger.info "Crypted Auth Token: #{@crypted_auth_token}"
		logger.info "Auth Token: #{auth_token}"
		logger.info "Payload: #{payload}"
		logger.info "Expiration Time: #{expiration_time}"
		logger.info "Current Time: #{Time.now}"
		logger.info "User: #{@user}"
		if Time.now < expiration_time
			if delete_old_rating
				Rating.where(user_id: @user.id, publication_id: @publication.id).destroy_all
			else
				if Rating.exists?(user_id: @user.id, publication_id: @publication.id)
					render :already_given, locals: {pubId: @publication.id}
				else
					render :rate
				end
			end
		else
			@error_manager.add_error(I18n.t("errors.messages.password_does_not_match"))
			render "shared/errors", status: :unprocessable_entity, locals: {errors: @error_manager.get_errors}
		end
	end

	# POST /ratings.json
	def create
		@rating = Rating.new
		@rating.score = rating_params[:score]
		@rating.anonymous = rating_params[:anonymous]
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
			@rating.compute_scores
			RatingMailer.confirm(current_user, @rating.score, publication.pdf_url).deliver
			render :show, status: :created, location: @rating
		else
			render json: @rating.errors, status: :unprocessable_entity
		end
	end

	# POST /load
	def load
		@crypted_auth_token = params[:cryptedAuthToken]
		inserted_email = params[:email]
		inserted_password = params[:password]
		publication = Publication.find params[:pubId]
		requesting_user = User.find params[:userId]
		if User.exists?(email: inserted_email)
			logged_user = User.find_by_email inserted_email
			if requesting_user.id == logged_user.id and requesting_user.email == logged_user.email and BCrypt::Password.new(logged_user.password_digest) == inserted_password
				if Rating.exists?(user_id: requesting_user.id, publication_id: publication.id)
					render :already_given, locals: {pubId: publication.id}
				else
					@rating = Rating.new rating_params
					@rating.publication = publication
					@rating.user = requesting_user
					if @rating.save
						@rating.compute_scores
						RatingMailer.confirm(requesting_user, @rating.score, publication.pdf_url).deliver
						render :successful, locals: {pubId: publication.id}
					else
						render :unsuccessful, locals: {pubId: publication.id}
					end
				end
			else
				render :not_the_same_user, locals: {pubId: publication.id}
			end
		else
			render :not_the_same_user, locals: {pubId: publication.id}
		end
	end

	private

	def set_rating
		@rating = Rating.find(params[:id])
	end

	def set_publication
		@rating = Publication.find(params[:publication_id])
	end

	def rating_params
		params.require(:rating).permit(:score, :anonymous, :user_id, :publication_id, :pdf_url)
	end
end
