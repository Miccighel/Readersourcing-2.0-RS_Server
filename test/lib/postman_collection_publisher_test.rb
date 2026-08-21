require "test_helper"
require "postman_collection_publisher"
require "tempfile"

class PostmanCollectionPublisherTest < ActiveSupport::TestCase

	class ApiClient

		attr_reader :replacement

		def initialize(collection)
			@collection = collection
		end

		def collection(_collection_uid)
			@collection
		end

		def replace_collection(collection_uid, collection)
			@replacement = collection
			{"collection" => {"uid" => collection_uid}}
		end

	end

	test "preserves remote identifiers while publishing local content" do
		local_collection = {
			"info" => {"_postman_id" => "local-collection", "name" => "Readersourcing 2.0"},
			"item" => [
				{
					"name" => "Authentication (Authenticate)",
					"request" => {"method" => "POST"},
					"response" => [{"name" => "Successful authentication", "body" => "current"}]
				}
			]
		}
		remote_collection = {
			"info" => {"_postman_id" => "remote-collection", "name" => "Readersourcing 2.0"},
			"item" => [
				{
					"id" => "remote-request",
					"name" => "Authentication (Authenticate)",
					"request" => {"method" => "POST"},
					"response" => [
						{"id" => "remote-response", "name" => "Successful authentication", "body" => "old"}
					]
				}
			]
		}

		Tempfile.create(["postman-collection", ".json"]) do |file|
			file.write(JSON.generate(local_collection))
			file.flush
			client = ApiClient.new(remote_collection)

			result = PostmanCollectionPublisher.new(
				api_client: client,
				collection_uid: "4632696-remote-collection",
				collection_path: file.path
			).call

			assert_equal "4632696-remote-collection", result.dig("collection", "uid")
			assert_equal "remote-collection", client.replacement.dig("info", "_postman_id")
			assert_equal "remote-request", client.replacement.dig("item", 0, "id")
			assert_equal "remote-response", client.replacement.dig("item", 0, "response", 0, "id")
			assert_equal "current", client.replacement.dig("item", 0, "response", 0, "body")
		end
	end

	test "leaves new collection entries without invented identifiers" do
		local_collection = {
			"info" => {"name" => "Readersourcing 2.0"},
			"item" => [
				{
					"id" => "local-request",
					"_postman_id" => "local-request",
					"name" => "New request",
					"event" => [
						{
							"listen" => "test",
							"script" => {"id" => "local-script", "exec" => ["return;"]}
						}
					],
					"request" => {"method" => "GET"}
				}
			]
		}
		remote_collection = {
			"info" => {"_postman_id" => "remote-collection", "name" => "Readersourcing 2.0"},
			"item" => [{"id" => "existing-request", "name" => "Existing request"}]
		}

		Tempfile.create(["postman-collection", ".json"]) do |file|
			file.write(JSON.generate(local_collection))
			file.flush
			client = ApiClient.new(remote_collection)

			PostmanCollectionPublisher.new(
				api_client: client,
				collection_uid: "4632696-remote-collection",
				collection_path: file.path
			).call

			assert_equal "remote-collection", client.replacement.dig("info", "_postman_id")
			assert_not client.replacement.dig("item", 0).key?("id")
			assert_not client.replacement.dig("item", 0).key?("_postman_id")
			assert_not client.replacement.dig("item", 0, "event", 0, "script").key?("id")
		end
	end

end
