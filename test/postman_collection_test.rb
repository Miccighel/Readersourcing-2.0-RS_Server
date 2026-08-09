require "test_helper"
require "json"

class PostmanCollectionTest < ActiveSupport::TestCase
  COLLECTION_PATH = Rails.root.join("postman", "Readersourcing_2.0.postman_collection.json")

  setup do
    @collection = JSON.parse(COLLECTION_PATH.read)
    @requests = @collection.fetch("item")
  end

  test "collection requests resolve to current application routes" do
    @requests.each do |item|
      request = item.fetch("request")
      path = request.fetch("url")
        .delete_prefix("{{host}}")
        .split("?", 2)
        .first
        .gsub(/\{\{[^}]+\}\}/, "1")

      recognized_route = Rails.application.routes.recognize_path(
        path,
        method: request.fetch("method").downcase
      )
      assert recognized_route, "#{item.fetch("name")} does not match a Rails route"
    rescue ActionController::RoutingError
      flunk "#{item.fetch("name")} does not match a Rails route"
    end
  end

  test "collection does not expose shared publication mutations" do
    publication_requests = @requests.select do |item|
      item.dig("request", "url").start_with?("{{host}}/publications/")
    end

    publication_requests.each do |item|
      refute_includes %w[PATCH PUT DELETE], item.dig("request", "method")
    end
    refute_includes @requests.map { |item| item.fetch("name") }, "Publications (Update)"
    refute_includes @requests.map { |item| item.fetch("name") }, "Publications (Delete)"
  end

  test "authenticated API requests use bearer authorization" do
    authorization_values = @requests.flat_map do |item|
      item.dig("request", "header").to_a.filter_map do |header|
        header.fetch("value") if header.fetch("key").casecmp?("Authorization")
      end
    end

    assert_not_empty authorization_values
    assert_equal ["Bearer {{authToken}}"], authorization_values.uniq
  end

  test "collection stores no session or authentication material" do
    variables = @collection.fetch("variable").to_h { |variable| [variable.fetch("key"), variable.fetch("value")] }
    %w[email password newPassword authToken confirmationToken resetToken paperReference].each do |name|
      assert_empty variables.fetch(name)
    end

    serialized_collection = JSON.generate(@collection)
    refute_match(/eyJ[a-zA-Z0-9_-]+[.%][a-zA-Z0-9_%=-]+/, serialized_collection)
    refute_includes serialized_collection, "_session_id="
    refute_includes serialized_collection, "authTokenPaper"
    assert @requests.all? { |item| item.fetch("response").empty? }
  end

  test "collection includes the current recovery and software operations" do
    operations = @requests.to_h do |item|
      [[item.dig("request", "method"), item.dig("request", "url")], item.fetch("name")]
    end

    assert operations.key?(["GET", "{{host}}/software"])
    assert operations.key?(["GET", "{{host}}/password/reset?email={{email}}&reset_token={{resetToken}}"])
    assert operations.key?(["POST", "{{host}}/password/reset"])
    refute operations.key?(["GET", "{{host}}/logout"])
  end
end
