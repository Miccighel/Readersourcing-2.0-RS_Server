class ApplicationController < ActionController::API

	include ::ActionController::RequestForgeryProtection

	before_action :authenticate_request
	attr_reader :current_user

	protected

	def encrypt text
		text = text.to_s unless text.is_a? String
		len   = ActiveSupport::MessageEncryptor.key_len
		salt  = SecureRandom.hex len
		key   = ActiveSupport::KeyGenerator.new(Rails.application.secrets.secret_key_base).generate_key salt, len
		crypt = ActiveSupport::MessageEncryptor.new key
		encrypted_data = crypt.encrypt_and_sign text
		"#{salt}!!!!!!!!!!#{encrypted_data}"
	end

	def decrypt text
		salt, data = text.split "!!!!!!!!!!"
		len   = ActiveSupport::MessageEncryptor.key_len
		key   = ActiveSupport::KeyGenerator.new(Rails.application.secrets.secret_key_base).generate_key salt, len
		crypt.decrypt_and_verify data
	end

	private

	def authenticate_request
		@current_user = AuthorizeApiRequest.call(request.headers).result
		render json: {add_error: 'Not Authorized'}, status: 401 unless @current_user
	end

end
