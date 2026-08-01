class AuthenticationTokenRevoker

	prepend SimpleCommand

	def initialize(auth_token)
		@auth_token = auth_token
	end

	def call
		decoded_auth_token = JsonWebToken.decode(@auth_token)
		return unless decoded_auth_token

		AuthenticationToken.find_by(
			jti: decoded_auth_token[:jti],
			user_id: decoded_auth_token[:user_id]
		)&.destroy!
	end

end
