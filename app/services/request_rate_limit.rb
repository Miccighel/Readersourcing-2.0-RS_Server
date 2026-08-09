require "digest"

class RequestRateLimit

	attr_reader :name, :requests, :period

	class << self

		def store
			Rails.cache
		end

		def for_ip(request)
			digest("ip", request.remote_ip)
		end

		def for_account(account)
			digest("account", account.to_s.strip.downcase)
		end

		def for_user(user)
			digest("user", user&.id || "anonymous")
		end

		private

		def configured_requests(environment_name, default)
			requests = Integer(ENV.fetch(environment_name, default))
			raise ArgumentError, "#{environment_name} must be greater than zero" unless requests.positive?

			requests
		end

		def digest(kind, value)
			Digest::SHA256.hexdigest([kind, value].join("\0"))
		end

	end

	def initialize(name:, requests:, period:)
		@name = name
		@requests = requests
		@period = period
	end

	def rails_options
		{
			to: requests,
			within: period,
			store: self.class.store,
			name: name
		}
	end

	def cache_key(scope:, identity:)
		["rate-limit", scope, name, identity].join(":")
	end

	AUTHENTICATION = new(
		name: "authentication",
		requests: configured_requests("RS_AUTHENTICATION_RATE_LIMIT", 10),
		period: 3.minutes
	)

	PASSWORD_RECOVERY_IP = new(
		name: "password-recovery-ip",
		requests: configured_requests("RS_PASSWORD_RECOVERY_IP_RATE_LIMIT", 5),
		period: 15.minutes
	)

	PASSWORD_RECOVERY_ACCOUNT = new(
		name: "password-recovery-account",
		requests: configured_requests("RS_PASSWORD_RECOVERY_ACCOUNT_RATE_LIMIT", 3),
		period: 30.minutes
	)

	CONTACT = new(
		name: "contact",
		requests: configured_requests("RS_CONTACT_RATE_LIMIT", 5),
		period: 10.minutes
	)

	PDF_PROCESSING = new(
		name: "pdf-processing",
		requests: configured_requests("RS_PDF_PROCESSING_RATE_LIMIT", 30),
		period: 1.hour
	)

end
