class AuthenticationController < ApplicationController

	include ActionController::MimeResponds

	before_action :set_error_manager

	rate_limit(
		**RequestRateLimit::AUTHENTICATION.rails_options,
		by: -> { RequestRateLimit.for_ip(request) },
		with: -> { render_rate_limited(RequestRateLimit::AUTHENTICATION) },
		only: :authenticate
	)

	# GET /login
	def login
	end

	# POST /logout or /logout.json
	def logout
		AuthenticationTokenRevoker.new(authorization_token).call if authorization_token.present?
		delete_token
		respond_to do |format|
			format.html do
				redirect_to root_path
			end
			format.json do
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
			reset_session
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
