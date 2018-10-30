class AuthenticationController < ApplicationController

	skip_before_action :authenticate_request

	before_action :set_error_manager

	# POST /authenticate
	def authenticate
		command = AuthenticateUser.call(params[:email], params[:password])
		if command.success?
			render json: { auth_token: command.result }
		else
			command.errors[:user_authentication].each do |error|
				@error_manager.add_error(error)
			end
			render json: { errors: @error_manager.get_errors}, status: :unauthorized
		end
	end

	private

	def set_error_manager
		@error_manager = ErrorManager.new
	end

end