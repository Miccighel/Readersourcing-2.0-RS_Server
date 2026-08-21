require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Readersourcing2
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Keep the domain strategies and support objects in lib.
    config.autoload_lib(ignore: %w[assets tasks])

    config.i18n.default_locale = :en
    config.active_storage.variant_processor = :disabled

    # Rails supplies the remaining default security headers. These explicit
    # values tighten framing and prevent paper reference paths from being sent
    # as referrers when a reader follows an external link.
    config.action_dispatch.default_headers["X-Frame-Options"] = "DENY"
    config.action_dispatch.default_headers["Referrer-Policy"] = "same-origin"
    config.action_dispatch.default_headers["Permissions-Policy"] =
      "camera=(), display-capture=(), geolocation=(), microphone=(), payment=(), usb=()"
  end
end
