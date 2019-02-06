class ApplicationController < ActionController::API

	include ::ActionController::RequestForgeryProtection

	before_action :authorize_api_request, except: [:home, :request_authorization, :unauthorized]
	attr_reader :current_user

	# GET /
	def home
	end

	# POST /request_authorization.json
	def request_authorization
		@current_user = AuthorizeApiRequest.call(request.headers, request.remote_ip).result
		if @current_user
			render json: {message: I18n.t("confirmations.messages.authorization_completed")}, status: :ok
		else
			@error_manager = ErrorManager.new
			@error_manager.add_error(I18n.t("errors.messages.not_authorized"))
			render json: {errors: @error_manager.get_errors}, status: 401
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
		"#{salt}!!!!!!!!!!#{encrypted_data}"
	end

	def decrypt(text)
		salt, data = text.split "!!!!!!!!!!"
		len = ActiveSupport::MessageEncryptor.key_len
		key = ActiveSupport::KeyGenerator.new(Rails.application.secrets.secret_key_base).generate_key salt, len
		crypt = ActiveSupport::MessageEncryptor.new key
		crypt.decrypt_and_verify data
	end

	private

	def authorize_api_request
		@current_user = AuthorizeApiRequest.call(request.headers, request.remote_ip).result
		@error_manager = ErrorManager.new
		@error_manager.add_error(I18n.t("errors.messages.not_authorized"))
		render "shared/errors", status: 401, locals: {errors: @error_manager.get_errors}, layout: false unless @current_user
	end

end
