class RatingsController < ApplicationController

	before_action :set_rating, only: [:show]

	skip_before_action :authorize_api_request, only: [:rate_web, :rate_paper, :load]

	# GET /ratings.json
	def index
		@ratings = Rating.all
	end

	# GET /ratings/1.json
	def show
	end

	# GET /rate/:pubId/:authToken
	def rate_paper
		request.headers['Authorization'] = unescape_jwt(params[:authToken])
		command = AuthorizeApiRequest.call(request.headers, request.remote_ip)
		if command.success?
			@user = command.result
			@publication = Publication.find(params[:pubId])
			if Rating.exists?(user_id: @user.id, publication_id: @publication.id)
				render "shared/halted", locals: {
					pubId: @publication.id,
					message: "",
					title: I18n.t("errors.messages.rating_already_given")
				}, status: :ok
			else
				render 'ratings/rating_paper'
			end
		else
			render "shared/errors", status: :unprocessable_entity, locals: {errors: command.errors[:token]}, layout: false
		end
	end

	# GET /rate/:authToken
	def rate_web
		request.headers['Authorization'] = unescape_jwt(params[:authToken])
		command = AuthorizeApiRequest.call(request.headers, request.remote_ip)
		if command.success?
			render 'ratings/rating_web'
		else
			render "shared/errors", status: :unprocessable_entity, locals: {errors: command.errors[:token]}, layout: false
		end
	end

	# POST /ratings.json
	def create
		@rating = Rating.new
		@rating.score = rating_params[:score]
		@rating.anonymous = rating_params[:anonymous]
		@rating.user = current_user
		publication = Publication.find_by_pdf_url(rating_params[:pdf_url])
		unless publication
			publication = Publication.new
			publication.pdf_url = rating_params[:pdf_url]
			publication.save
		end
		@rating.publication = publication
		if @rating.save
			@rating.compute_scores
			RatingMailer.confirm(current_user, @rating.score, @rating.publication.pdf_url, unsubscribe_url(current_user.id)).deliver
			render :show, status: :created, location: @rating
		else
			render json: @rating.errors, status: :unprocessable_entity
		end
	end

	# POST /load
	def load
		@auth_token = params[:authToken]
		inserted_email = params[:email]
		inserted_password = params[:password]
		publication = Publication.find params[:pubId]
		requesting_user = User.find params[:userId]
		if User.exists?(email: inserted_email)
			logged_user = User.find_by_email inserted_email
			if requesting_user.id == logged_user.id and requesting_user.email == logged_user.email and BCrypt::Password.new(logged_user.password_digest) == inserted_password
				if Rating.exists?(user_id: requesting_user.id, publication_id: publication.id)
					render "shared/halted", locals: {
						pubId: publication.id,
						message: "",
						title: I18n.t("errors.messages.rating_already_given")
					}, status: :ok
				else
					@rating = Rating.new rating_params
					@rating.publication = publication
					@rating.user = requesting_user
					if @rating.save
						@rating.compute_scores
						RatingMailer.confirm(@rating.user, @rating.score, @rating.publication.pdf_url, unsubscribe_url(@rating.user.id)).deliver
						render "shared/success", locals: {
							pubId: @rating.publication.id,
							message: I18n.t("information.messages.mail_confirmation"),
							title: I18n.t("confirmations.messages.rating_successful")
						}, status: :ok
					else
						render "shared/halted", locals: {
							pubId: @rating.publication.id,
							message: I18n.t("information.messages.try_again"),
							title: I18n.t("errors.messages.rating_unsuccessful")
						}, status: :ok
					end
				end
			else
				render "shared/halted", locals: {
					pubId: publication.id,
					message: I18n.t("information.messages.not_the_same_user"),
					title: I18n.t("errors.messages.not_the_same_user")
				}, status: :ok
			end
		else
			render "shared/halted", locals: {
				pubId: publication.id,
				message: I18n.t("information.messages.not_the_same_user"),
				title: I18n.t("errors.messages.not_the_same_user")
			}, status: :ok
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
