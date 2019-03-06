class AuthenticationController < ApplicationController

	skip_before_action :authorize_api_request

	before_action :set_error_manager

	# GET /login

	def login
	end

	# POST /authenticate
	def authenticate
		command = AuthenticateUser.call(params[:email], params[:password], request.remote_ip)
		if command.success?
			render json: {auth_token: escape_jwt(command.result)}
		else
			render json: {errors: command.errors[:user_authentication]}, status: :unauthorized
		end
	end

	private

	def set_error_manager
		@error_manager = ErrorManager.new
	end

end