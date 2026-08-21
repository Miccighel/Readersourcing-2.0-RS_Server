namespace :deployment do
	desc "Check production configuration, migrations, storage, and SMTP access"
	task check: :environment do
		abort "deployment:check must run in production" unless Rails.env.production?

		require Rails.root.join("lib", "production_configuration")
		ProductionConfiguration.new.validate!
		ActiveRecord::Migration.check_all_pending!

		readiness = DeploymentReadiness.new.check
		abort "Deployment readiness failed: #{readiness.failures.join(", ")}" unless readiness.ready?

		SmtpReadiness.new.check!
		puts "Production configuration, migrations, storage, database, and SMTP are ready."
	end
end

namespace :security do
	desc "Delete expired authentication token records"
	task prune_expired_authentication_tokens: :environment do
		deleted_records = AuthenticationToken.where("expires_at <= ?", Time.current).delete_all
		puts "Deleted #{deleted_records} expired authentication token records."
	end
end
