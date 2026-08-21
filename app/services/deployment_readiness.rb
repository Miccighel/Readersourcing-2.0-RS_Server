require "fileutils"
require "tempfile"

class DeploymentReadiness

	Result = Data.define(:failures) do
		def ready?
			failures.empty?
		end
	end

	def initialize(connection_pool: ActiveRecord::Base.connection_pool,
	               storage_path: Publication.storage_root.join("user"))
		@connection_pool = connection_pool
		@storage_path = Pathname.new(storage_path)
	end

	def check
		failures = []
		check_database(failures)
		check_storage(failures)
		Result.new(failures: failures.freeze)
	end

	private

	def check_database(failures)
		@connection_pool.with_connection do |connection|
			connection.select_value("SELECT 1")
		end
	rescue StandardError => error
		failures << "database: #{error.class}"
	end

	def check_storage(failures)
		FileUtils.mkdir_p(@storage_path)
		Tempfile.create([".readiness", ".tmp"], @storage_path) do |file|
			file.write("ready")
			file.flush
		end
	rescue StandardError => error
		failures << "publication storage: #{error.class}"
	end

end
