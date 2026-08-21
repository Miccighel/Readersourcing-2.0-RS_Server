namespace :publications do

	desc "Move prepared PDFs from the legacy public directory to private storage"
	task migrate_private_storage: :environment do
		legacy_path = Rails.public_path.join("user")
		private_path = Publication.storage_root.join("user")

		unless legacy_path.exist?
			puts "No legacy publication directory was found."
			next
		end

		raise "Private publication storage already exists at #{private_path}" if private_path.exist?

		FileUtils.mkdir_p(private_path.dirname)
		FileUtils.mv(legacy_path, private_path)
		puts "Prepared PDFs were moved to #{private_path}."
	end

end
