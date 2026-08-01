# Be sure to restart your server when you modify this file.

# Allow extension and web clients from explicitly configured origins in production.
# Development and test retain the open policy used by the local workflow.

configured_origins = ENV.fetch("CORS_ALLOWED_ORIGINS", "")
	.split(",")
	.map(&:strip)
	.reject(&:blank?)
allowed_origins = configured_origins
allowed_origins = ["*"] if allowed_origins.empty? && !Rails.env.production?

Rails.application.config.middleware.insert_before 0, Rack::Cors do
	unless allowed_origins.empty?
		allow do
			origins(*allowed_origins)
			resource "*",
							 headers: :any,
							 methods: [:get, :post, :put, :patch, :delete, :options, :head]
		end
	end
end
