require "json"
require "net/http"
require "uri"

class PostmanApiClient

	class Error < StandardError; end

	API_URL = "https://api.postman.com"

	def initialize(api_key:, api_url: API_URL)
		@api_key = api_key.to_s
		@api_url = URI(api_url)
		raise ArgumentError, "Postman API key is required" if @api_key.empty?
	end

	def collection(collection_uid)
		request_json(Net::HTTP::Get, collection_path(collection_uid)).fetch("collection")
	end

	def replace_collection(collection_uid, collection)
		request_json(
			Net::HTTP::Put,
			collection_path(collection_uid),
			body: {collection: collection}
		)
	end

	private

	def collection_path(collection_uid)
		uid = collection_uid.to_s
		raise ArgumentError, "Postman collection UID is required" if uid.empty?

		"/collections/#{URI.encode_www_form_component(uid)}"
	end

	def request_json(request_class, path, body: nil)
		request = request_class.new(path)
		request["Accept"] = "application/json"
		request["Content-Type"] = "application/json" if body
		request["x-api-key"] = @api_key
		request.body = JSON.generate(body) if body

		response = Net::HTTP.start(
			@api_url.host,
			@api_url.port,
			use_ssl: @api_url.scheme == "https",
			open_timeout: 10,
			read_timeout: 60
		) { |http| http.request(request) }

		unless response.is_a?(Net::HTTPSuccess)
			raise Error, "Postman API returned HTTP #{response.code}"
		end

		JSON.parse(response.body)
	rescue JSON::ParserError
		raise Error, "Postman API returned an invalid JSON response"
	rescue SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout
		raise Error, "Postman API could not be reached"
	end

end
