class UsersController < ApplicationController

	skip_before_action :authenticate_request, only: :create

	before_action :set_error_manager, only: [:password]
	before_action :set_user, only: [:show, :update, :destroy]

	# GET /users.json
	def index
		@users = User.all
	end

	# GET /users/1.json
	def show
	end

	# POST /users.json
	def create
		@user = User.new(user_params)
		if @user.save
			render :show, status: :created, location: @user
		else
			render json: @user.errors, status: :unprocessable_entity
		end
	end

	# POST /users/password.json
	def password
		inserted_password = user_params[:password]
		inserted_password_confirmation = user_params[:password_confirmation]
		if inserted_password == inserted_password_confirmation
			current_user.password = inserted_password
			if current_user.save
				render partial: "shared/success", status: :ok, locals: {message: I18n.t("confirmations.messages.password_update_successful")}
			else
				render json: @user.errors, status: :unprocessable_entity
			end
		else
			@error_manager.add_error(I18n.t("errors.messages.password_does_not_match"))
			render partial: "shared/errors", status: :unprocessable_entity, locals: {errors: @error_manager.get_errors}
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

	def set_error_manager
		@error_manager = ErrorManager.new
	end

	def set_user
		@user = User.find(params[:id])
	end

	def user_params
		params.require(:user).permit(:first_name, :last_name, :email, :orcid, :password, :password_confirmation)
	end
end
