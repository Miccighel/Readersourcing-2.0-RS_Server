require "test_helper"

class ProductionConfigurationTest < ActiveSupport::TestCase

	setup do
		@environment = {
			"SECRET_PROD_KEY" => "s" * 64,
			"PUBLIC_BASE_URL" => "https://readersourcing.test",
			"FORCE_SSL" => "true",
			"CORS_ALLOWED_ORIGINS" => "https://readersourcing.test",
			"POSTGRES_USER" => "rs_server",
			"POSTGRES_PASSWORD" => "a-long-database-password",
			"POSTGRES_DB" => "rs_server",
			"POSTGRES_HOST" => "database",
			"SMTP_USERNAME" => "smtp-user",
			"SMTP_PASSWORD" => "smtp-password",
			"SMTP_DOMAIN_NAME" => "readersourcing.test",
			"SMTP_DOMAIN_ADDRESS" => "smtp.readersourcing.test",
			"EMAIL_ADMIN" => "admin@readersourcing.test",
			"EMAIL_BUG_REPORT" => "bugs@readersourcing.test",
			"PRIVACY_CONTROLLER_NAME" => "Readersourcing Controller",
			"PRIVACY_HOSTING_PROVIDER" => "Example Host",
			"PRIVACY_HOSTING_COUNTRY" => "Italy",
			"PRIVACY_EMAIL_PROVIDER" => "Example Mail",
			"PRIVACY_EMAIL_PROVIDER_COUNTRY" => "Italy",
			"PRIVACY_LOG_RETENTION_DAYS" => "30",
			"PRIVACY_BACKUP_RETENTION_DAYS" => "30"
		}
	end

	test "accepts a complete production configuration" do
		assert ProductionConfiguration.new(@environment).validate!
	end

	test "accepts local HTTP without forced SSL" do
		@environment["PUBLIC_BASE_URL"] = "http://127.0.0.1:3000"
		@environment["FORCE_SSL"] = "false"

		assert ProductionConfiguration.new(@environment).validate!
	end

	test "rejects placeholders, weak secrets, and incomplete public HTTPS" do
		@environment["SECRET_PROD_KEY"] = "replace_with_a_secret"
		@environment["PUBLIC_BASE_URL"] = "http://readersourcing.test"
		@environment["FORCE_SSL"] = "false"
		@environment["CORS_ALLOWED_ORIGINS"] = "*"

		error = assert_raises(ProductionConfiguration::ConfigurationError) do
			ProductionConfiguration.new(@environment).validate!
		end

		assert_includes error.message, "SECRET_PROD_KEY"
		assert_includes error.message, "PUBLIC_BASE_URL must use HTTPS"
		assert_includes error.message, "FORCE_SSL"
		assert_includes error.message, "CORS_ALLOWED_ORIGINS"
	end

	test "rejects missing mail and privacy settings" do
		@environment.delete("SMTP_PASSWORD")
		@environment.delete("PRIVACY_CONTROLLER_NAME")

		errors = ProductionConfiguration.new(@environment).errors

		assert_includes errors, "SMTP_PASSWORD must be configured"
		assert_includes errors, "PRIVACY_CONTROLLER_NAME must be configured"
	end

	test "accepts a complete database URL instead of individual settings" do
		%w[POSTGRES_USER POSTGRES_PASSWORD POSTGRES_DB POSTGRES_HOST].each { |name| @environment.delete(name) }
		@environment["DATABASE_URL"] = "postgresql://reader:database-password@database/rs_server"

		assert ProductionConfiguration.new(@environment).validate!
	end

	test "rejects invalid retention and timeout values" do
		@environment["PRIVACY_LOG_RETENTION_DAYS"] = "0"
		@environment["RS_PDF_PROCESS_TIMEOUT"] = "many"

		errors = ProductionConfiguration.new(@environment).errors

		assert_includes errors, "PRIVACY_LOG_RETENTION_DAYS must contain a positive integer"
		assert_includes errors, "RS_PDF_PROCESS_TIMEOUT must contain a positive integer"
	end

	test "rejects invalid Boolean, CORS, and SMTP settings" do
		@environment["ASSUME_SSL"] = "true"
		@environment["FORCE_SSL"] = "false"
		@environment["CORS_ALLOWED_ORIGINS"] = "https://trusted.test/path"
		@environment["SMTP_AUTHENTICATION"] = "unknown"

		errors = ProductionConfiguration.new(@environment).errors

		assert_includes errors, "ASSUME_SSL requires FORCE_SSL=true"
		assert_includes errors, "CORS_ALLOWED_ORIGINS contains an invalid origin"
		assert_includes errors, "SMTP_AUTHENTICATION must be plain, login, or cram_md5"
	end

end
