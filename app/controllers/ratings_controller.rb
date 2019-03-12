class RatingsController < ApplicationController

	before_action :set_rating, only: [:show, :update]

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
			@auth_token_paper = params[:authToken]
			@user = command.result
			@publication = Publication.find(params[:pubId])
			@rating = Rating.new
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

	# PATCH/PUT /rating/1.json
	def update
		@rating.score = rating_params[:score]
		@rating.edited = true
		if @rating.save
			render :show, status: :ok, location: @rating
		else
			render json: @rating.errors, status: :unprocessable_entity
		end
	end

	# POST /ratings.json
	def create
		@rating = Rating.new
		@rating.score = rating_params[:score]
		@rating.original_score = rating_params[:score]
		@rating.anonymous = rating_params[:anonymous]
		@rating.user = current_user
		publication = Publication.find_by_pdf_url(rating_params[:pdf_url])
		if rating_params[:pdf_url] == "https://arxiv.org/pdf/1812.05594.pdf"
			render json: {errors: [I18n.t("information.messages.test_url")]}, status: :ok
		else
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
	end

	# POST /load
	def load
		@auth_token_user = unescape_jwt(params[:authTokenUser])
		@auth_token_paper = unescape_jwt(params[:authTokenPaper])
		decoded_auth_token_user = JsonWebToken.decode(@auth_token_user)
		decoded_auth_token_paper = JsonWebToken.decode(@auth_token_paper)
		requesting_user = User.find(decoded_auth_token_paper[:user_id])
		logged_user = User.find(decoded_auth_token_user[:user_id])
		publication = Publication.find params[:pubId]
		if publication.pdf_url == "https://arxiv.org/pdf/1812.05594.pdf"
			render "shared/success", status: :ok, locals: {errors: [I18n.t("information.messages.test_url")]}, layout: false
		else
			if requesting_user.id == logged_user.id
				if Rating.exists?(user_id: requesting_user.id, publication_id: publication.id)
					render "shared/halted", locals: {
						pubId: publication.id,
						message: "",
						title: I18n.t("errors.messages.rating_already_given")
					}, status: :ok
				else
					@rating = Rating.new rating_params
					@rating.original_score = rating_params[:score]
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
		params.require(:rating).permit(:score, :original_score, :anonymous, :user_id, :publication_id, :pdf_url)
	end

end
