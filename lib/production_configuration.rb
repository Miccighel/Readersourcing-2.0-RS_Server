require "date"
require "ipaddr"
require "uri"

class ProductionConfiguration

	class ConfigurationError < StandardError; end

	MINIMUM_SECRET_LENGTH = 64
	MINIMUM_DATABASE_PASSWORD_LENGTH = 16
	EMAIL_PATTERN = /\A[^\s@]+@[^\s@]+\.[^\s@]+\z/
	PLACEHOLDER_PATTERNS = [
		/replace[_ ]with/i,
		/your[_ -]/i,
		/<[^>]+>/,
		/\.example(?::\d+)?\z/i
	].freeze

	REQUIRED_MAIL_SETTINGS = %w[
		SMTP_USERNAME
		SMTP_PASSWORD
		SMTP_DOMAIN_NAME
		SMTP_DOMAIN_ADDRESS
		EMAIL_ADMIN
		EMAIL_BUG_REPORT
	].freeze

	REQUIRED_PRIVACY_SETTINGS = %w[
		PRIVACY_CONTROLLER_NAME
		PRIVACY_HOSTING_PROVIDER
		PRIVACY_HOSTING_COUNTRY
		PRIVACY_EMAIL_PROVIDER
		PRIVACY_EMAIL_PROVIDER_COUNTRY
	].freeze

	POSITIVE_INTEGER_SETTINGS = %w[
		RAILS_MAX_THREADS
		SMTP_PORT
		SMTP_OPEN_TIMEOUT
		SMTP_READ_TIMEOUT
		PRIVACY_LOG_RETENTION_DAYS
		PRIVACY_BACKUP_RETENTION_DAYS
		RS_PDF_MAX_DOWNLOAD_BYTES
		RS_PDF_OPEN_TIMEOUT
		RS_PDF_READ_TIMEOUT
		RS_PDF_PROCESS_TIMEOUT
		RS_PDF_DOWNLOAD_URL_TTL
		RS_AUTHENTICATION_RATE_LIMIT
		RS_PASSWORD_RECOVERY_IP_RATE_LIMIT
		RS_PASSWORD_RECOVERY_ACCOUNT_RATE_LIMIT
		RS_CONTACT_RATE_LIMIT
		RS_PDF_PROCESSING_RATE_LIMIT
	].freeze

	DEFAULTS = {
		"RAILS_MAX_THREADS" => "5",
		"SMTP_PORT" => "587",
		"SMTP_OPEN_TIMEOUT" => "5",
		"SMTP_READ_TIMEOUT" => "10",
		"RS_PDF_MAX_DOWNLOAD_BYTES" => "52428800",
		"RS_PDF_OPEN_TIMEOUT" => "5",
		"RS_PDF_READ_TIMEOUT" => "20",
		"RS_PDF_PROCESS_TIMEOUT" => "60",
		"RS_PDF_DOWNLOAD_URL_TTL" => "300",
		"RS_AUTHENTICATION_RATE_LIMIT" => "10",
		"RS_PASSWORD_RECOVERY_IP_RATE_LIMIT" => "5",
		"RS_PASSWORD_RECOVERY_ACCOUNT_RATE_LIMIT" => "3",
		"RS_CONTACT_RATE_LIMIT" => "5",
		"RS_PDF_PROCESSING_RATE_LIMIT" => "30"
	}.freeze

	attr_reader :environment

	def initialize(environment = ENV)
		@environment = environment
	end

	def validate!
		configuration_errors = errors
		return true if configuration_errors.empty?

		raise ConfigurationError,
			"Production configuration is invalid:\n- #{configuration_errors.join("\n- ")}"
	end

	def errors
		configuration_errors = []
		validate_secret(configuration_errors)
		validate_public_origin(configuration_errors)
		validate_boolean_settings(configuration_errors)
		validate_database(configuration_errors)
		validate_required_settings(REQUIRED_MAIL_SETTINGS, configuration_errors)
		validate_email("EMAIL_ADMIN", configuration_errors)
		validate_email("EMAIL_BUG_REPORT", configuration_errors)
		validate_smtp_authentication(configuration_errors)
		validate_required_settings(REQUIRED_PRIVACY_SETTINGS, configuration_errors)
		validate_positive_integers(configuration_errors)
		configuration_errors
	end

	private

	def validate_secret(configuration_errors)
		secret = value("SECRET_PROD_KEY")
		if missing_or_placeholder?(secret)
			configuration_errors << "SECRET_PROD_KEY must contain a real generated secret"
		elsif secret.length < MINIMUM_SECRET_LENGTH
			configuration_errors << "SECRET_PROD_KEY must contain at least #{MINIMUM_SECRET_LENGTH} characters"
		end
	end

	def validate_public_origin(configuration_errors)
		origin = value("PUBLIC_BASE_URL")
		if missing_or_placeholder?(origin)
			configuration_errors << "PUBLIC_BASE_URL must contain the real application origin"
			return
		end

		uri = URI.parse(origin)
		valid_origin = uri.is_a?(URI::HTTP) &&
			uri.host && uri.userinfo.nil? && uri.query.nil? && uri.fragment.nil? &&
			(uri.path.nil? || uri.path.empty? || uri.path == "/")
		unless valid_origin
			configuration_errors << "PUBLIC_BASE_URL must be an HTTP or HTTPS origin without a path"
			return
		end

		unless local_host?(uri.host)
			configuration_errors << "PUBLIC_BASE_URL must use HTTPS for a public deployment" unless uri.scheme == "https"
			configuration_errors << "FORCE_SSL must be true for a public deployment" unless value("FORCE_SSL") == "true"
		end

		cors_origins = value("CORS_ALLOWED_ORIGINS").to_s.split(",").map(&:strip)
		if !local_host?(uri.host) && cors_origins.include?("*")
			configuration_errors << "CORS_ALLOWED_ORIGINS must not contain * for a public deployment"
		end
		validate_cors_origins(cors_origins, configuration_errors)
	rescue URI::InvalidURIError
		configuration_errors << "PUBLIC_BASE_URL must be an HTTP or HTTPS origin without a path"
	end

	def validate_boolean_settings(configuration_errors)
		%w[FORCE_SSL ASSUME_SSL RS_PDF_ALLOW_PRIVATE_NETWORKS].each do |name|
			configured_value = value(name)
			next if configured_value.nil? || %w[true false].include?(configured_value)

			configuration_errors << "#{name} must be true or false"
		end

		if value("ASSUME_SSL") == "true" && value("FORCE_SSL") != "true"
			configuration_errors << "ASSUME_SSL requires FORCE_SSL=true"
		end
	end

	def validate_cors_origins(origins, configuration_errors)
		origins.reject { |origin| origin.empty? || origin == "*" }.each do |origin|
			uri = URI.parse(origin)
			valid_origin = uri.is_a?(URI::HTTP) && uri.host && uri.userinfo.nil? &&
				uri.query.nil? && uri.fragment.nil? && (uri.path.nil? || uri.path.empty? || uri.path == "/")
			configuration_errors << "CORS_ALLOWED_ORIGINS contains an invalid origin" unless valid_origin
		rescue URI::InvalidURIError
			configuration_errors << "CORS_ALLOWED_ORIGINS contains an invalid origin"
		end
	end

	def validate_database(configuration_errors)
		database_url = value("DATABASE_URL")
		if database_url && !database_url.empty?
			if placeholder?(database_url)
				configuration_errors << "DATABASE_URL must contain a real PostgreSQL connection string"
				return
			end

			begin
				uri = URI.parse(database_url)
				unless %w[postgres postgresql].include?(uri.scheme) && uri.host && uri.user && uri.password
					configuration_errors << "DATABASE_URL must contain a PostgreSQL host, user, and password"
				end
			rescue URI::InvalidURIError
				configuration_errors << "DATABASE_URL must contain a valid PostgreSQL connection string"
			end
		else
			validate_required_settings(%w[POSTGRES_USER POSTGRES_PASSWORD POSTGRES_DB POSTGRES_HOST], configuration_errors)
			password = value("POSTGRES_PASSWORD")
			if password && !placeholder?(password) && password.length < MINIMUM_DATABASE_PASSWORD_LENGTH
				configuration_errors << "POSTGRES_PASSWORD must contain at least #{MINIMUM_DATABASE_PASSWORD_LENGTH} characters"
			end
		end
	end

	def validate_required_settings(names, configuration_errors)
		names.each do |name|
			configuration_errors << "#{name} must be configured" if missing_or_placeholder?(value(name))
		end
	end

	def validate_email(name, configuration_errors)
		email = value(name)
		return if email.nil? || placeholder?(email)
		configuration_errors << "#{name} must contain a valid email address" unless email.match?(EMAIL_PATTERN)
	end

	def validate_smtp_authentication(configuration_errors)
		authentication = value("SMTP_AUTHENTICATION") || "plain"
		unless %w[plain login cram_md5].include?(authentication)
			configuration_errors << "SMTP_AUTHENTICATION must be plain, login, or cram_md5"
		end
	end

	def validate_positive_integers(configuration_errors)
		POSITIVE_INTEGER_SETTINGS.each do |name|
			configured_value = value(name) || DEFAULTS[name]
			if configured_value.nil? || !configured_value.match?(/\A\d+\z/) || configured_value.to_i <= 0
				configuration_errors << "#{name} must contain a positive integer"
			end
		end
	end

	def value(name)
		configured_value = environment[name].to_s.strip
		configured_value.empty? ? nil : configured_value
	end

	def missing_or_placeholder?(configured_value)
		configured_value.nil? || placeholder?(configured_value)
	end

	def placeholder?(configured_value)
		PLACEHOLDER_PATTERNS.any? { |pattern| configured_value.match?(pattern) }
	end

	def local_host?(host)
		return true if host.casecmp?("localhost")
		return true if host.end_with?(".localhost")

		IPAddr.new(host).loopback?
	rescue IPAddr::InvalidAddressError
		false
	end

end
