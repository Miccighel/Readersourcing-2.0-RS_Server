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
		result = verify_recaptcha params[:recaptcha_response]
		if result
			@user = User.new(user_params)
			if @user.save
				UserMailer.confirm(@user).deliver_now
				render :show, status: :created, location: @user
			else
				render json: @user.errors, status: :unprocessable_entity
			end
		else
			result.each do |error|
				@error_manager.add_error(I18n.t("errors.codes.#{error}"))
			end
			render "shared/errors", status: :not_found, locals: {errors: @error_manager.get_errors}
		end
	end

	# PATCH/PUT /users/1.json
	def update
		if @user.update(user_params)
			render :show, status: :ok, location: @user
		else
			render json: @user.errors, status: :unprocessable_entity
		end
	end

	# DELETE /users/1.json
	def destroy
		@user.destroy
	end

	private

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
		params.require(:user).permit(:first_name, :last_name, :email, :orcid, :password, :password_confirmation, :recaptcha_response)
	end
end
