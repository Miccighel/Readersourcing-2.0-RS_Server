class UsersController < ApplicationController

	skip_before_action :authorize_api_request, only: [:list, :sign_up, :create, :confirm_email, :unsubscribe, :edit]

	before_action :set_user, only: [:show, :update, :unsubscribe, :destroy]
	before_action :set_error_manager, only: [:confirm_email]

	require "http"

	# GET /users.json
	def index
		@users = User.all
	end

	# GET /readers/list/:authToken
	def list
		request.headers['Authorization'] = unescape_jwt(params[:authToken])
		command = AuthorizeApiRequest.call(request.headers, request.remote_ip)
		if command.success?
			@users = User.all
			render 'list'
		else
			render "shared/errors", status: :unprocessable_entity, locals: {errors: command.errors[:token]}, layout: false
		end
	end

	# GET /users/1.json
	def show
	end

	# POST /users/info.json
	def info
		render current_user
	end

	# GET /sign_up
	def sign_up
	end

	# POST /users.json
	def create
		@user = User.new(user_params)
		@user.generate_confirm_token
		if @user.save
			UserMailer.registration_confirmation(@user, confirm_url(@user.id, @user.confirm_token)).deliver_now
			render json: {message: I18n.t("confirmations.messages.please_confirm")}, status: :created
		else
			render json: @user.errors, status: :unprocessable_entity
		end
	end

	# GET /confirm/:id/:confirmToken
	def confirm_email
		@user = User.find_by_confirm_token(params[:confirmToken])
		if @user
			@user.activate_email
			render "shared/success", locals: {message: I18n.t("confirmations.messages.registration_successful")}, status: :created, layout: false
		else
			@error_manager.add_error(I18n.t("errors.messages.user_not_exists"))
			render "shared/errors", status: :unprocessable_entity, locals: {errors: @error_manager.get_errors}, layout: false
		end
	end

	# GET /profile/edit/:authToken
	def edit
		request.headers['Authorization'] = unescape_jwt(params[:authToken])
		command = AuthorizeApiRequest.call(request.headers, request.remote_ip)
		if command.success?
			render :update
		else
			render "shared/errors", status: :unauthorized, locals: {errors: command.errors[:token]}, layout: false
		end
	end

	# PATCH/PUT /users/1.json
	def update
		if @user.update(user_params)
			render json: {message: I18n.t("confirmations.messages.update_successful")}, status: :ok
		else
			render json: @user.errors, status: :unprocessable_entity
		end
	end

	# POST /unsubscribe/:id
	def unsubscribe
		if @user.update(subscribe: false)
			render "shared/success", locals: {message: I18n.t("mails.user.unsubscribe_successful")}, status: :ok
		else
			render json: @user.errors, status: :unprocessable_entity
		end
	end

	# DELETE /users/1.json
	def destroy
		@user.destroy
	end

	private

	def set_error_manager
		@error_manager = ErrorManager.new
	end

	def set_user
		@user = User.find(params[:id])
	end

	def user_params
		params.require(:user).permit(:first_name, :last_name, :email, :orcid, :subscribe, :password, :password_confirmation)
	end
end
