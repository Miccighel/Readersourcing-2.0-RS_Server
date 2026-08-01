class  Authorizer

	prepend SimpleCommand

	def initialize(auth_token, ip_address)
		@auth_token = auth_token
		@ip_address = ip_address
	end

	def call
		# Keep token validation private to the command.
		authorize_user
	end

	private

	attr_reader :ip_address

	def authorize_user
		unless @auth_token.present?
			errors.add(:token, I18n.t("errors.messages.missing_token"))
			return
		end

		decoded_auth_token = JsonWebToken.decode(@auth_token)
		unless decoded_auth_token
			errors.add(:token, I18n.t("errors.messages.invalid_token"))
			return
		end

		unless decoded_auth_token[:ip_address] == ip_address
			errors.add(:token, I18n.t("errors.messages.ip_address_changed"))
			return
		end

		expiration_time = Integer(decoded_auth_token[:expiration_time], exception: false)
		unless expiration_time && Time.current.to_i <= expiration_time
			errors.add(:token, I18n.t("errors.messages.expired_login_token"))
			return
		end

		authentication_token = AuthenticationToken.find_by(
			jti: decoded_auth_token[:jti],
			user_id: decoded_auth_token[:user_id]
		)
		unless authentication_token&.active?
			errors.add(:token, I18n.t("errors.messages.invalid_token"))
			return
		end

		authentication_token.user
	end

end
