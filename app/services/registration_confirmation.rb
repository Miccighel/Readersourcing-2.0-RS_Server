class RegistrationConfirmation

	def initialize(user, link:)
		@user = user
		@link = link
	end

	def call
		link = @link.respond_to?(:call) ? @link.call : @link
		UserMailer.registration_confirmation(@user, link).deliver_now
		true
	rescue StandardError => error
		Rails.logger.warn("Registration confirmation for reader #{@user.id} failed (#{error.class.name})")
		false
	end

end
