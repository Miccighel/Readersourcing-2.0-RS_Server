class UsersController < ApplicationController

	include ::ActionView::Layouts

	layout "application", only: [:confirm_email, :unsubscribe]

	skip_before_action :authorize_api_request, only: [:create, :confirm_email, :unsubscribe]

	before_action :set_user, only: [:show, :update, :unsubscribe, :destroy]
	before_action :set_error_manager, only: [:confirm_email]

	require "http"

	# GET /users.json
	def index
		@users = User.all
	end

	# GET /users/1.json
	def show
	end

	# POST /users/info.json
	def info
		render current_user
	end

	# POST /users.json
	def create
		@user = User.new(user_params)
		@user.generate_confirm_token
		if @user.save
			UserMailer.registration_confirmation(@user, confirm_url(@user.id, @user.confirm_token)).deliver_now
			render "shared/success", status: :created, locals: {message: I18n.t("confirmations.messages.please_confirm")}
		else
			render json: @user.errors, status: :unprocessable_entity
		end
	end

	# GET /confirm/:id/:confirmToken
	def confirm_email
		@user = User.find_by_confirm_token(params[:confirmToken])
		if @user
			@user.activate_email
			render "shared/success", status: :created, locals: {message: I18n.t("confirmations.messages.registration_successful")}
		else
			@error_manager.add_error(I18n.t("errors.messages.user_not_exists"))
			render "shared/errors", status: :unprocessable_entity, locals: {errors: @error_manager.get_errors}
		end
	end

	# PATCH/PUT /users/1.json
	def update
		if @user.update(user_params)
			render "shared/success", status: :created, locals: {message: I18n.t("confirmations.messages.update_successful")}
		else
			render json: @user.errors, status: :unprocessable_entity
		end
	end

	# POST /unsubscribe/:id
	def unsubscribe
		if @user.update(subscribe: false)
			render "shared/success", status: :created, locals: {message: I18n.t("mails.user.unsubscribe_successful")}
		else
			render json: @user.errors, status: :unprocessable_entity
		end
	end

	# DELETE /users/1.json
	def destroy
		@user.destroy
	end

	private

	# METHOD TO VERIFY GOOGLE reCAPTCHA v2
	def verify_recaptcha(recaptcha_response)
		response = HTTP.post("https://www.google.com/recaptcha/api/siteverify?secret=#{ENV["RECAPTCHA_SECRET_KEY"]}&response=#{recaptcha_response}")
		json = JSON.parse response.body
		if json["success"]
			logger.info "Current user verified with reCAPTCHA"
			true
		else
			logger.info "Current user unverified with reCAPTCHA"
			json["error-codes"]
		end
	end

	def set_error_manager
		@error_manager = ErrorManager.new
	end

	def set_user
		@user = User.find(params[:id])
	end

	def user_params
		params.require(:user).permit(:first_name, :last_name, :email, :orcid, :subscribe, :password, :password_confirmation, :recaptcha_response)
	end
end
