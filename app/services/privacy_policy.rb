require "date"

class PrivacyPolicy

	EFFECTIVE_DATE = Date.new(2026, 8, 21)

	def initialize(environment = ENV)
		@environment = environment
	end

	def controller_name
		configured_value("PRIVACY_CONTROLLER_NAME", "Readersourcing project maintainer")
	end

	def contact_email
		configured_value("EMAIL_ADMIN", "privacy@readersourcing.invalid")
	end

	def hosting_provider
		configured_value("PRIVACY_HOSTING_PROVIDER", "the configured hosting provider")
	end

	def hosting_country
		configured_value("PRIVACY_HOSTING_COUNTRY", "the configured service region")
	end

	def email_provider
		configured_value("PRIVACY_EMAIL_PROVIDER", "the configured email provider")
	end

	def email_provider_country
		configured_value("PRIVACY_EMAIL_PROVIDER_COUNTRY", "the configured email service region")
	end

	def log_retention_days
		positive_integer("PRIVACY_LOG_RETENTION_DAYS", 30)
	end

	def backup_retention_days
		positive_integer("PRIVACY_BACKUP_RETENTION_DAYS", 30)
	end

	def service_url
		configured_value("PUBLIC_BASE_URL", "http://localhost:3000")
	end

	def effective_date
		EFFECTIVE_DATE
	end

	private

	def configured_value(name, fallback)
		@environment[name].to_s.strip.presence || fallback
	end

	def positive_integer(name, fallback)
		value = @environment[name].to_i
		value.positive? ? value : fallback
	end

end
