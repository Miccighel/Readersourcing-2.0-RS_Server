class AuthenticationController < ApplicationController

	skip_before_action :authorize_api_request

	before_action :set_error_manager

	# POST /authenticate
	def authenticate
		command = AuthenticateUser.call(params[:email], params[:password], request.remote_ip)
		if command.success?
			respond_to do |format|
				format.html do
					session[:auth_token] = command.result
					render "ratings/rate_web"
				end
				format.json {render json: {auth_token: command.result}}
			end
		else
			render json: { errors: command.errors[:user_authentication]}, status: :unauthorized
		end
	end

	private

	def set_error_manager
		@error_manager = ErrorManager.new
	end

end