Rails.application.config.assets.paths << Rails.root.join('node_modules')

Rails.application.config.assets.precompile += %w( home.js )

Rails.application.config.assets.precompile += %w( login.js )

Rails.application.config.assets.precompile += %w( profile_update.css )
Rails.application.config.assets.precompile += %w( profile_update.js )

Rails.application.config.assets.precompile += %w( sign_up.css )
Rails.application.config.assets.precompile += %w( sign_up.js )

Rails.application.config.assets.precompile += %w( password_forgot.js )
Rails.application.config.assets.precompile += %w( password_update.js )

Rails.application.config.assets.precompile += %w( rating.js )
Rails.application.config.assets.precompile += %w( rating.css )