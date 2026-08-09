class RatingsController < ApplicationController

	before_action :authorize_api_request, only: [:index, :show, :update, :create]
	before_action :authorize_server_request, only: [:rate_web, :rate_paper, :load]

	before_action :set_owned_rating, only: [:show, :update]

	# GET /ratings.json
	def index
		@ratings = Rating.all
	end

	# GET /ratings/1.json
	def show
	end

	# GET /rate/:pubId/:reference
	def rate_paper
		publication = Publication.find_by(id: params[:pubId])
		reference_user = PaperRatingReference.resolve(params[:reference], publication: publication) if publication
		return render_invalid_paper_reference(params[:pubId]) unless reference_user
		return render_reference_owner_mismatch(publication.id) unless reference_user == current_user

		session[:paper_rating_reference] = params[:reference]
		@rating = Rating.new
		@pub_id = publication.id
		if Rating.exists?(user_id: current_user.id, publication_id: @pub_id)
			render "shared/halted", locals: {
				pubId: @pub_id,
				message: "",
				title: I18n.t("errors.messages.rating_already_given")
			}, status: :ok
		else
			render 'ratings/rating_paper'
		end
	end

	# GET /rate
	def rate_web
		render 'ratings/rating_web'
	end

	# POST /ratings.json
	def create
		@rating = Rating.new
		@rating.score = create_rating_params[:score]
		@rating.original_score = create_rating_params[:score]
		@rating.anonymous = create_rating_params[:anonymous]
		@rating.user = current_user
		publication = Publication.find_by_pdf_url(create_rating_params[:pdf_url])
		if create_rating_params[:pdf_url] == "https://arxiv.org/pdf/1812.05594.pdf"
			render json: {errors: [I18n.t("information.messages.test_url")]}, status: :ok
		else
			unless publication
				publication = Publication.new
				publication.pdf_url = create_rating_params[:pdf_url]
				publication.save
			end
			@rating.publication = publication
			if save_rating
				@rating.compute_scores
				RatingMailer.confirm(current_user, @rating.score, @rating.publication.pdf_url, unsubscribe_url(current_user.id)).deliver_now
				render :show, status: :created, location: @rating
			else
				render json: @rating.errors, status: :unprocessable_entity
			end
		end
	end

	# POST /load
	def load
		paper_reference = session.delete(:paper_rating_reference)
		publication = Publication.find_by(id: params[:pubId])
		requesting_user = PaperRatingReference.resolve(paper_reference, publication: publication) if publication
		return render_invalid_paper_reference(params[:pubId]) unless requesting_user

		if publication.pdf_url == "https://arxiv.org/pdf/1812.05594.pdf"
			render "shared/success", status: :ok, locals: {errors: [I18n.t("information.messages.test_url")]}, layout: false
		else
			if requesting_user == current_user
				if Rating.exists?(user_id: requesting_user.id, publication_id: publication.id)
					render "shared/halted", locals: {
						pubId: publication.id,
						message: "",
						title: I18n.t("errors.messages.rating_already_given")
					}, status: :ok
				else
					@rating = Rating.new paper_rating_params
					@rating.original_score = paper_rating_params[:score]
					@rating.publication = publication
					@rating.user = requesting_user
					if save_rating
						@rating.compute_scores
						RatingMailer.confirm(@rating.user, @rating.score, @rating.publication.pdf_url, unsubscribe_url(@rating.user.id)).deliver_now
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
				render_reference_owner_mismatch(publication.id)
			end
		end
	end

	# PATCH/PUT /rating/1.json
	def update
		@rating.score = update_rating_params[:score]
		@rating.edited = true
		if @rating.save
			render :show, status: :ok, location: @rating
		else
			render json: @rating.errors, status: :unprocessable_entity
		end
	end

	private

	def render_invalid_paper_reference(publication_id)
		render "shared/halted", locals: {
			pubId: publication_id,
			message: "",
			title: I18n.t("errors.messages.invalid_paper_reference")
		}, status: :ok
	end

	def render_reference_owner_mismatch(publication_id)
		render "shared/halted", locals: {
			pubId: publication_id,
			message: I18n.t("information.messages.not_the_same_user"),
			title: I18n.t("errors.messages.not_the_same_user")
		}, status: :ok
	end

	def set_owned_rating
		@rating = current_user.ratings.find_by(id: params[:id])
		head :not_found unless @rating
	end

	def save_rating
		@rating.save
	rescue ActiveRecord::RecordNotUnique
		@rating.errors.add(:publication_id, :taken)
		false
	end

	def create_rating_params
		params.require(:rating).permit(:score, :anonymous, :pdf_url)
	end

	def paper_rating_params
		params.require(:rating).permit(:score, :anonymous)
	end

	def update_rating_params
		params.require(:rating).permit(:score)
	end

end
