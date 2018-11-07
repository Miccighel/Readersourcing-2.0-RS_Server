class AuthenticateUser

	prepend SimpleCommand

	def initialize(email, password, ip_address)
		@email = email
		@password = password
		@ip_address = ip_address
	end

	def call
		JsonWebToken.encode(user_id: user.id, ip_address: ip_address) if user
	end

	private

	attr_accessor :email, :password, :ip_address

	# Fetches the user if the inserted login data are valid
	def user
		user = User.find_by_email(email)
		if user && user.authenticate(password) && user.email_confirmed
			user
		else
			if user
				unless user && user.authenticate(password)
					errors.add :user_authentication, I18n.t("errors.messages.invalid_credentials")
				end
				unless user.email_confirmed
					errors.add :user_authentication, I18n.t("errors.messages.unconfirmed_mail")
				end
			else
				errors.add :user_authentication, I18n.t("errors.messages.invalid_credentials")
			end
			nil
		end
	end

end