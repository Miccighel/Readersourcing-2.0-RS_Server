require "test_helper"

class DeploymentReadinessTest < ActiveSupport::TestCase

	test "reports a reachable database and writable publication storage" do
		Dir.mktmpdir do |storage_path|
			result = DeploymentReadiness.new(
				connection_pool: connection_pool_returning(1),
				storage_path: storage_path
			).check

			assert result.ready?
			assert_empty result.failures
		end
	end

	test "reports database and publication storage failures without raising" do
		Dir.mktmpdir do |directory|
			storage_path = Pathname.new(directory).join("not-a-directory")
			storage_path.write("occupied")
			result = DeploymentReadiness.new(
				connection_pool: connection_pool_raising(PG::ConnectionBad.new("unavailable")),
				storage_path: storage_path
			).check

			assert_not result.ready?
			assert_includes result.failures, "database: PG::ConnectionBad"
			assert result.failures.any? { |failure| failure.start_with?("publication storage:") }
		end
	end

	private

	def connection_pool_returning(value)
		connection = Object.new
		connection.define_singleton_method(:select_value) { |_query| value }
		connection_pool_yielding(connection)
	end

	def connection_pool_raising(error)
		connection_pool = Object.new
		connection_pool.define_singleton_method(:with_connection) { |_block = nil| raise error }
		connection_pool
	end

	def connection_pool_yielding(connection)
		connection_pool = Object.new
		connection_pool.define_singleton_method(:with_connection) { |&block| block.call(connection) }
		connection_pool
	end

end
