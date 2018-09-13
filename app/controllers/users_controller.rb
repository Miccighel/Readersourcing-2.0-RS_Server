class UsersController < ApplicationController

	skip_before_action :authenticate_request, only: :create

	before_action :set_user, only: [:show, :update, :destroy]

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
			UserMailer.confirm(@user).deliver
			render :show, status: :created, location: @user
		else
			render json: @user.errors, status: :unprocessable_entity
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
