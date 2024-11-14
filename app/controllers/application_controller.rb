class ApplicationController < ActionController::API

	include ActionController::Cookies
	include ::ActionController::RequestForgeryProtection

	attr_reader :current_user

	# GET /
	def home
	end

	# GET /resources
	def resources
	end

	# GET /software
	def software
	end

	# GET /privacy
	def privacy
	end

	# GET /contact
	def contact
	end

	# POST /message.json
	def message
		if params[:bug_report]
			ApplicationMailer.report(params[:email], params[:message]).deliver_now
			render json: {message: I18n.t("confirmations.messages.bug_report_sent")}, status: :ok
		else
			ApplicationMailer.send_message(params[:email], params[:message]).deliver_now
			render json: {message: I18n.t("confirmations.messages.message_sent")}, status: :ok
		end
	end

	# GET /unauthorized
	def unauthorized
		@error_manager = ErrorManager.new
		@error_manager.add_error(I18n.t("errors.messages.not_authorized"))
		render "shared/errors", status: 401, locals: {errors: @error_manager.get_errors}, layout: false
	end

	protected

	def encrypt(text)
		text = text.to_s unless text.is_a? String
		len = ActiveSupport::MessageEncryptor.key_len
		salt = SecureRandom.hex len
		key = ActiveSupport::KeyGenerator.new(Rails.application.secrets.secret_key_base).generate_key salt, len
		crypt = ActiveSupport::MessageEncryptor.new key
		encrypted_data = crypt.encrypt_and_sign text
		"#{salt}!!!!!#{encrypted_data}"
	end

	def decrypt(text)
		salt, data = text.split "!!!!!"
		len = ActiveSupport::MessageEncryptor.key_len
		key = ActiveSupport::KeyGenerator.new(Rails.application.secrets.secret_key_base).generate_key salt, len
		crypt = ActiveSupport::MessageEncryptor.new key
		crypt.decrypt_and_verify data
	end

	def store_token(auth_token)
		session[:auth_token] = auth_token
	end

	def fetch_token
		session[:auth_token]
	end

	def delete_token
		cookies.delete :authToken
		session.delete(:auth_token)
	end

	private

	def authorize_server_request
		# Instantiate Authorizer and call the instance method 'call'
		authorizer = Authorizer.new(fetch_token, request.remote_ip)
		@current_user = authorizer.call.result
		render "login", status: :ok, locals: {message: I18n.t("information.messages.login")} unless @current_user
	end

	def authorize_api_request
		auth_token = request.headers['Authorization'].split(' ').last

		# Instantiate Authorizer and call the instance method 'call'
		authorizer = Authorizer.new(auth_token, request.remote_ip)
		@current_user = authorizer.call.result

		@error_manager = ErrorManager.new
		@error_manager.add_error(I18n.t("errors.messages.not_authorized"))
		render "shared/errors", status: 401, locals: {errors: @error_manager.get_errors}, layout: false unless @current_user
	end

end
