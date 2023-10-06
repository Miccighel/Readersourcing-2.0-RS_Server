# config/middleware/set_default_host_middleware.rb

class DefaultHostMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    host = env['HTTP_HOST'] || 'localhost:3000'  # Default to localhost:3000 if the host is not present in the request
    Rails.application.routes.default_url_options[:host] = host
    @app.call(env)
  end
end
