require "net/smtp"

class SmtpReadiness

	def initialize(settings: ActionMailer::Base.smtp_settings, smtp_class: Net::SMTP)
		@settings = settings
		@smtp_class = smtp_class
	end

	def check!
		raise ArgumentError, "SMTP readiness requires STARTTLS" unless @settings.fetch(:enable_starttls) == :always

		smtp = @smtp_class.new(@settings.fetch(:address), @settings.fetch(:port))
		smtp.open_timeout = @settings.fetch(:open_timeout)
		smtp.read_timeout = @settings.fetch(:read_timeout)
		smtp.enable_starttls
		smtp.start(
			@settings.fetch(:domain),
			@settings.fetch(:user_name),
			@settings.fetch(:password),
			@settings.fetch(:authentication)
		) { true }
		true
	end

end
