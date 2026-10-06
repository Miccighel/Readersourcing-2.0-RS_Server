class Authenticator

	include Rails.application.routes.url_helpers

	prepend SimpleCommand

	attr_reader :confirmation_failed

	def initialize(email, password, ip_address, confirmation_url: nil)
		@email = email
		@password = password
		@ip_address = ip_address
		@confirmation_failed = false
		@confirmation_url = confirmation_url || ->(user) {
			PublicBaseUrl.new(ENV["PUBLIC_BASE_URL"]).join(confirm_path(user.id, user.confirm_token))
		}
	end

	def call
		# Keep credential handling private to the command.
		authenticated_user = user
		return unless authenticated_user

		authentication_token = AuthenticationToken.issue_for(authenticated_user)
		JsonWebToken.encode(
			{
				user_id: authenticated_user.id,
				ip_address: ip_address,
				jti: authentication_token.jti
			},
			authentication_token.expires_at
		)
	end

	private

	attr_accessor :email, :password, :ip_address

	# Returns the user when the supplied credentials are valid.
	def user
		user = User.find_by_email(email)
		unless user && password.present? && user.authenticate(password)
			errors.add :user_authentication, I18n.t("errors.messages.invalid_credentials")
			return
		end
		return user if user.email_confirmed

		user.generate_confirm_token
		confirmation = RegistrationConfirmation.new(user, link: -> { @confirmation_url.call(user) })
		@confirmation_failed = !user.save || !confirmation.call
		message_key = confirmation_failed ? "confirmation_delivery_unavailable" : "unconfirmed_mail"
		errors.add :user_authentication, I18n.t("errors.messages.#{message_key}")
		nil
	end

end
