class ApplicationController < ActionController::API

	include ::ActionController::RequestForgeryProtection
	include ::ActionView::Layouts

	before_action :authorize_api_request, except: [:home]
	attr_reader :current_user

	# GET /
	def home
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
		render "shared/errors", status: 401, locals: {errors: @error_manager.get_errors} unless @current_user
	end

end
