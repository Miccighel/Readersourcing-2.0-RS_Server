class Authorizer

	prepend SimpleCommand

	def initialize(auth_token, ip_address)
		@auth_token = auth_token
		@ip_address = ip_address
	end

	def call
		authorize_user
	end

	private

	attr_reader :headers, :ip_address

	def authorize_user
		decoded_auth_token = nil
		if @auth_token.present?
			decoded_auth_token = JsonWebToken.decode @auth_token
		else
			errors.add(:token, I18n.t("errors.messages.missing_token"))
		end
		if decoded_auth_token
			# If the user represented by the token exists and his IP address is equal to the one of the current request
			if @user.nil?
				same_ip_address = false
				unexpired_token = false
				if decoded_auth_token[:ip_address] == ip_address
					same_ip_address = true
				else
					errors.add(:token, I18n.t("errors.messages.ip_address_changed"))
				end
				if Time.now <= decoded_auth_token[:expiration_time]
					unexpired_token = true
				else
					errors.add(:token, I18n.t("errors.messages.expired_login_token"))
				end
				if same_ip_address and unexpired_token
					@user = User.find(decoded_auth_token[:user_id])
					unless @user
						errors.add(:token, I18n.t("errors.messages.invalid_token"))
					end
				end
			end
		end
		@user || nil
	end

end