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

    responses = @requests.flat_map { |item| item.fetch("response") }
    assert_equal 7, responses.length
    responses.each do |response|
      refute response.fetch("header").any? { |header| header.fetch("key").casecmp?("Set-Cookie") }
    end
  end

  test "collection provides current and fictitious response examples" do
    examples = @requests.to_h do |item|
      [item.fetch("name"), item.fetch("response").to_h { |response| [response.fetch("name"), response] }]
    end

    assert_equal 200, examples.dig("Authentication (Authenticate)", "Successful authentication", "code")
    assert_equal "<authentication-token>", JSON.parse(
      examples.dig("Authentication (Authenticate)", "Successful authentication", "body")
    ).fetch("auth_token")
    assert_equal [I18n.t("errors.messages.invalid_credentials")], JSON.parse(
      examples.dig("Authentication (Authenticate)", "Invalid credentials", "body")
    ).fetch("errors")
    assert_equal [I18n.t("errors.messages.too_many_requests")], JSON.parse(
      examples.dig("Authentication (Authenticate)", "Authentication rate limit reached", "body")
    ).fetch("errors")

    publication = JSON.parse(examples.dig("Publications (Lookup)", "Publication found", "body"))
    assert_equal %w[id pdf_url url], %w[id pdf_url url] & publication.keys
    assert_equal [I18n.t("models.publications.errors.messages.lookup_error")], JSON.parse(
      examples.dig("Publications (Lookup)", "Publication not found", "body")
    ).fetch("errors")

    rating = JSON.parse(examples.dig("Ratings (Create)", "Rating created", "body"))
    assert_equal %w[id score original_score url], %w[id score original_score url] & rating.keys
    duplicate = Rating.new(user: users(:one), publication: publications(:one), score: 80, original_score: 80)
    assert_not duplicate.valid?
    assert_equal JSON.parse(JSON.generate(duplicate.errors.as_json)), JSON.parse(
      examples.dig("Ratings (Create)", "Duplicate rating", "body")
    )
  end

  test "collection checks variables and principal API responses" do
    assert_equal "https://schema.getpostman.com/json/collection/v2.1.0/collection.json",
      @collection.dig("info", "schema")

    prerequest_script = @collection.fetch("event").find do |event|
      event.fetch("listen") == "prerequest"
    end.dig("script", "exec").join("\n")
    assert_includes prerequest_script, "missingVariables"
    assert_includes prerequest_script, "Set the following collection variables"

    collection_test = @collection.fetch("event").find do |event|
      event.fetch("listen") == "test"
    end.dig("script", "exec").join("\n")
    assert_includes collection_test, "Response is not a server error"
    assert_includes collection_test, "Retry-After"

    ["Authentication (Authenticate)", "Publications (Lookup)", "Ratings (Create)"].each do |name|
      request = @requests.find { |item| item.fetch("name") == name }
      assert_not_empty request.fetch("event"), "#{name} has no response checks"
    end
  end

  test "collection includes the current recovery and software operations" do
    operations = @requests.to_h do |item|
      [[item.dig("request", "method"), item.dig("request", "url")], item.fetch("name")]
    end

    assert operations.key?(["GET", "{{host}}/software"])
    assert operations.key?(["GET", "{{host}}/password/reset?email={{email}}&reset_token={{resetToken}}"])
    assert operations.key?(["POST", "{{host}}/password/reset"])
    assert operations.key?(["POST", "{{host}}/publications/{{publicationId}}/refresh.json"])
    assert operations.key?(["POST", "{{host}}/publications/fetch_upload.json"])
    assert operations.key?(["GET", "{{host}}/unsubscribe/{{userId}}"])
    assert operations.key?(["POST", "{{host}}/unsubscribe/{{userId}}.json"])
    refute operations.key?(["GET", "{{host}}/publications/{{publicationId}}/refresh.json"])
    refute operations.key?(["GET", "{{host}}/unsubscribe/{{userId}}.json"])
    refute operations.key?(["GET", "{{host}}/logout"])
  end

  test "collection documents its origin and every request" do
    description = @collection.dig("info", "description")
    assert_includes description, "original release"
    assert_includes description, "IRCDL 2019"
    assert_includes description, "RS_Server implementation"
    refute_includes description, "<html>"

    @requests.each do |item|
      assert_not_empty item.dig("request", "description"), "#{item.fetch("name")} has no description"
    end
  end
end
