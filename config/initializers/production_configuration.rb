if Rails.env.production? && ENV["SECRET_KEY_BASE_DUMMY"].blank?
	require Rails.root.join("lib", "production_configuration")
	ProductionConfiguration.new.validate!
end
