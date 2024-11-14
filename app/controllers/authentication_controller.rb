class AuthenticationController < ApplicationController

	include ActionController::MimeResponds

	before_action :set_error_manager

	# GET /login
	def login
	end

	# GET /logout or POST/logout.json
	def logout
		respond_to do |format|
			format.html do
				delete_token
				redirect_to root_path
			end
			format.json do
				delete_token
				render json: {message: I18n.t("confirmations.messages.logout")}, status: :ok
			end
		end
	end

	# POST /authenticate
	def authenticate
		# Create an instance of Authenticator with the proper arguments
		authenticator = Authenticator.new(params[:email], params[:password], request.remote_ip)

		# Call the instance method 'call'
		command = authenticator.call
		if command.success?
			# Unescaped auth token (a duplicate) is saved on server session (implemented through HTTP-ONLY COOKIES)
			store_token command.result
			render json: {auth_token: command.result}
		else
			render json: {errors: command.errors[:user_authentication]}, status: :unauthorized
		end
	end

	private

	def set_error_manager
		@error_manager = ErrorManager.new
	end

end