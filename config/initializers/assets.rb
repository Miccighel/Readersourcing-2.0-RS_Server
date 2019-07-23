Rails.application.config.assets.paths << Rails.root.join('node_modules')

Rails.application.config.assets.paths  += %w( preloader.svg )
Rails.application.config.assets.paths  += %w( texture-bw.png )
Rails.application.config.assets.paths  += %w( logo.png )
Rails.application.config.assets.paths  += %w( logo-small.png )
Rails.application.config.assets.paths  += %w( chrome-webstore-badge.png )
Rails.application.config.assets.paths  += %w( orcid_id.gif )
Rails.application.config.assets.paths  += %w( rating-section.png )
Rails.application.config.assets.paths  += %w( publication-table.png )

Rails.application.config.assets.precompile += %w( application.css )
Rails.application.config.assets.precompile += %w( application.js )
Rails.application.config.assets.precompile += %w( main.js )

Rails.application.config.assets.precompile += %w( rating.css )
