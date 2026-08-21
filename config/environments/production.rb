require "uri"

Rails.application.configure do

  #Rails.application.routes.default_url_options[:host] = request.host
  #config.action_mailer.default_url_options = request.host

  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  # Ensures that a master key has been made available in either ENV["RAILS_MASTER_KEY"]
  # or in config/master.key. This key is used to decrypt credentials (and other encrypted files).
  # config.require_master_key = true

  # Disable serving static files from the `/public` folder by default since
  # Apache or NGINX already handles this.
  config.public_file_server.enabled = true

  # Generate digests for assets URLs
  config.assets.digest = true

  # Compress JavaScripts and CSS
  config.assets.compress = true

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.action_controller.asset_host = 'http://assets.example.com'

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = 'X-Sendfile' # for Apache
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for NGINX

  # Store uploaded files on the local file system (see config/storage.yml for options)
  config.active_storage.service = :local

  # Mount Action Cable outside main process or domain
  # config.action_cable.mount_path = nil
  # config.action_cable.url = 'wss://example.com/cable'
  # config.action_cable.allowed_request_origins = [ 'http://example.com', /http:\/\/example.*/ ]

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # Keep local HTTP deployments available unless the operator explicitly enables this policy.
  config.force_ssl = ENV["FORCE_SSL"] == "true"
  config.assume_ssl = ENV["ASSUME_SSL"] == "true"

  configured_public_origin = ENV["PUBLIC_BASE_URL"].presence
  raise "PUBLIC_BASE_URL is not configured" unless configured_public_origin

  begin
    public_uri = URI.parse(configured_public_origin)
    valid_origin = public_uri.is_a?(URI::HTTP) &&
      public_uri.host.present? &&
      public_uri.userinfo.nil? &&
      public_uri.query.nil? &&
      public_uri.fragment.nil? &&
      (public_uri.path.blank? || public_uri.path == "/")
    raise URI::InvalidURIError unless valid_origin
  rescue URI::InvalidURIError
    raise "PUBLIC_BASE_URL must be an HTTP or HTTPS origin"
  end

  config.hosts << public_uri.host
  ENV.fetch("ADDITIONAL_ALLOWED_HOSTS", "").split(",").each do |host|
    normalized_host = host.strip
    config.hosts << normalized_host if normalized_host.present?
  end
  config.host_authorization = {
    exclude: ->(request) { %w[/up /ready].include?(request.path) }
  }

  # Use the lowest log level to ensure availability of diagnostic information
  # when problems arise.
  config.log_level = :info

  # Prepend all log lines with the following tags.
  config.log_tags = [:request_id]

  # Keep rate-limit counters available in the default single-process deployment.
  # Multi-process deployments should replace this with a shared Active Support cache store.
  config.cache_store = :memory_store

  # Use a real queuing backend for Active Job (and separate queues per environment)
  # config.active_job.queue_adapter     = :resque
  # config.active_job.queue_name_prefix = "RS_Server_#{Rails.env}"

  mailer_url_options = {host: public_uri.host, protocol: public_uri.scheme}
  mailer_url_options[:port] = public_uri.port unless [80, 443].include?(public_uri.port)
  config.action_mailer.default_url_options = mailer_url_options
  config.action_mailer.raise_delivery_errors = true
  ActionMailer::Base.smtp_settings = {
    :user_name => ENV['SMTP_USERNAME'],
    :password => ENV['SMTP_PASSWORD'],
    :domain => ENV['SMTP_DOMAIN_NAME'],
    :address => ENV['SMTP_DOMAIN_ADDRESS'],
    :port => ENV.fetch('SMTP_PORT', 587).to_i,
    :authentication => ENV.fetch('SMTP_AUTHENTICATION', 'plain').to_sym,
    :enable_starttls => :always,
    :open_timeout => ENV.fetch('SMTP_OPEN_TIMEOUT', 5).to_i,
    :read_timeout => ENV.fetch('SMTP_READ_TIMEOUT', 10).to_i
  }
  config.action_mailer.perform_deliveries = true
  config.action_mailer.perform_caching = true

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners.
  config.active_support.report_deprecations = false

  # Use default logging formatter so that PID and timestamp are not suppressed.
  config.log_formatter = ::Logger::Formatter.new

  # Use a different logger for distributed setups.
  # require 'syslog/logger'
  # config.logger = ActiveSupport::TaggedLogging.new(Syslog::Logger.new 'app-name')

  if ENV["RAILS_LOG_TO_STDOUT"].present?
    logger = ActiveSupport::Logger.new(STDOUT)
    logger.formatter = config.log_formatter
    config.logger = ActiveSupport::TaggedLogging.new(logger)
  end

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  config.secret_key_base = ENV["SECRET_PROD_KEY"] if ENV["SECRET_PROD_KEY"].present?

  config.lograge.enabled = true
  # add time to lograge
  config.lograge.custom_options = lambda do |event|
    { time: Time.now }
  end
end
