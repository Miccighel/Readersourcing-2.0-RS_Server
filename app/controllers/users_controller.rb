class UsersController < ApplicationController

	skip_before_action :authenticate_request, only: :create

	before_action :set_user, only: [:show, :update, :destroy]

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
		if @user.save
			UserMailer.successful(@user).deliver_now
			render "shared/success", status: :created, locals: {message: I18n.t("mails.user.registration_successful")}
		else
			render json: @user.errors, status: :unprocessable_entity
		end
	end

	# PATCH/PUT /users/1.json
	def update
		if @user.update(user_params)
			render "shared/success", status: :created, locals: {message: I18n.t("mails.user.update_successful")}
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
