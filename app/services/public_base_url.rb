require "uri"

class PublicBaseUrl

	class ConfigurationError < StandardError; end

	def self.for(request, environment: Rails.env)
		configured_url = ENV["PUBLIC_BASE_URL"].presence
		configured_url ||= request.base_url unless environment.production?
		new(configured_url)
	end

	def initialize(url)
		raise ConfigurationError, "PUBLIC_BASE_URL is not configured" if url.blank?

		@uri = URI.parse(url)
		validate!
		@uri.path = ""
	rescue URI::InvalidURIError
		raise ConfigurationError, "PUBLIC_BASE_URL must be an HTTP or HTTPS origin"
	end

	def join(path)
		path = "/#{path}" unless path.start_with?("/")
		"#{@uri}#{path}"
	end

	def to_s
		@uri.to_s
	end

	private

	def validate!
		valid_scheme = @uri.is_a?(URI::HTTP) && %w[http https].include?(@uri.scheme)
		valid_origin = @uri.host.present? &&
			@uri.userinfo.nil? &&
			@uri.query.nil? &&
			@uri.fragment.nil?
		valid_path = @uri.path.blank? || @uri.path == "/"

		return if valid_scheme && valid_origin && valid_path

		raise ConfigurationError, "PUBLIC_BASE_URL must be an HTTP or HTTPS origin"
	end

end
