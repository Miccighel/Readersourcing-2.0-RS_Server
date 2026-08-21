require "json"

class PostmanCollectionPublisher

	IDENTIFIER_KEYS = %w[id uid postman_id _postman_id].freeze
	SEMANTIC_KEYS = %w[name key listen].freeze

	def initialize(api_client:, collection_uid:, collection_path:)
		@api_client = api_client
		@collection_uid = collection_uid
		@collection_path = collection_path
	end

	def call
		local_collection = JSON.parse(File.read(@collection_path))
		remote_collection = @api_client.collection(@collection_uid)
		preserve_identifiers(local_collection, remote_collection)
		@api_client.replace_collection(@collection_uid, local_collection)
	end

	private

	def preserve_identifiers(local_value, remote_value)
		case local_value
		when Hash
			unless remote_value.is_a?(Hash)
				remove_identifiers(local_value)
				return
			end

			IDENTIFIER_KEYS.each do |key|
				if remote_value.key?(key)
					local_value[key] = remote_value[key]
				else
					local_value.delete(key)
				end
			end
			local_value.each do |key, value|
				preserve_identifiers(value, remote_value[key]) unless IDENTIFIER_KEYS.include?(key)
			end
		when Array
			unless remote_value.is_a?(Array)
				remove_identifiers(local_value)
				return
			end

			local_value.each_with_index do |value, index|
				remote_entry = matching_entry(value, remote_value)
				remote_entry ||= remote_value[index] unless value.is_a?(Hash)
				preserve_identifiers(value, remote_entry)
			end
		end
	end

	def remove_identifiers(value)
		case value
		when Hash
			IDENTIFIER_KEYS.each { |key| value.delete(key) }
			value.each_value { |entry| remove_identifiers(entry) }
		when Array
			value.each { |entry| remove_identifiers(entry) }
		end
	end

	def matching_entry(local_entry, remote_entries)
		return unless local_entry.is_a?(Hash)

		identifier = IDENTIFIER_KEYS.find { |key| local_entry.key?(key) }
		if identifier
			match = remote_entries.find do |entry|
				entry.is_a?(Hash) && entry[identifier] == local_entry[identifier]
			end
			return match if match
		end

		semantic_key = SEMANTIC_KEYS.find { |key| local_entry.key?(key) }
		return unless semantic_key

		remote_entries.find do |entry|
			entry.is_a?(Hash) && entry[semantic_key] == local_entry[semantic_key]
		end
	end

end
