class Authenticator

	include Rails.application.routes.url_helpers

	prepend SimpleCommand

	def initialize(email, password, ip_address)
		@email = email
		@password = password
		@ip_address = ip_address
	end

	def call
		# Keep credential handling private to the command.
		JsonWebToken.encode(user_id: user.id, ip_address: ip_address) if user
	end

	private

	attr_accessor :email, :password, :ip_address

	# Returns the user when the supplied credentials are valid.
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
					user.generate_confirm_token
					if user.save
						UserMailer.registration_confirmation(user, confirm_url(user.id, user.confirm_token)).deliver_now
					end
					errors.add :user_authentication, I18n.t("errors.messages.unconfirmed_mail")
				end
			else
				errors.add :user_authentication, I18n.t("errors.messages.invalid_credentials")
			end
			nil
		end
	end

end
