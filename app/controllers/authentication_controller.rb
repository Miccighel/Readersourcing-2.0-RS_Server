class AuthenticationController < ApplicationController

	include ActionController::MimeResponds

	before_action :set_error_manager

	# GET /login
	def login
		@message = ""
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
		command = AuthenticateUser.call(params[:email], params[:password], request.remote_ip)
		if command.success?
			# Unescaped auth token (a duplicate) is saved on server session (implemented through HTTP-ONLY COOKIES)
			store_token command.result.dup
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