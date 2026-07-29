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
		# Validate the supplied credentials and bind the token to this request's IP address.
		authenticator = Authenticator.new(params[:email], params[:password], request.remote_ip)

		command = authenticator.call
		if command.success?
			# Keep a copy of the authentication token in the server session,
			# which is backed by an HTTP-only cookie.
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
