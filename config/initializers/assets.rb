Rails.application.config.assets.paths << Rails.root.join('node_modules')

Rails.application.config.assets.paths  += %w( preloader.svg )
Rails.application.config.assets.paths  += %w( texture-bw.png )
Rails.application.config.assets.paths  += %w( logo.png )
Rails.application.config.assets.paths  += %w( logo-small.png )
Rails.application.config.assets.paths  += %w( chrome-webstore-badge.png )
Rails.application.config.assets.paths  += %w( orcid_id.gif )

Rails.application.config.assets.precompile += %w( errors.js )
Rails.application.config.assets.precompile += %w( success.js )
Rails.application.config.assets.precompile += %w( halted.js )

Rails.application.config.assets.precompile += %w( application.css )
Rails.application.config.assets.precompile += %w( application.js )
Rails.application.config.assets.precompile += %w( resources.js )
Rails.application.config.assets.precompile += %w( bug.js )
Rails.application.config.assets.precompile += %w( home.js )
Rails.application.config.assets.precompile += %w( login.js )

Rails.application.config.assets.precompile += %w( profile_update.css )
Rails.application.config.assets.precompile += %w( profile_update.js )

Rails.application.config.assets.precompile += %w( sign_up.css )
Rails.application.config.assets.precompile += %w( sign_up.js )

Rails.application.config.assets.precompile += %w( password_forgot.js )
Rails.application.config.assets.precompile += %w( password_update.js )

Rails.application.config.assets.precompile += %w( rating_web.js )
Rails.application.config.assets.precompile += %w( rating_web.css )
Rails.application.config.assets.precompile += %w( rating_paper.js )
Rails.application.config.assets.precompile += %w( rating_paper.css )