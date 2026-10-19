require "minitest/autorun"
require_relative "../../deploy/private/image_acceptance_configuration"

class ImageAcceptanceConfigurationTest < Minitest::Test
  PROJECT = "rs-private-123456abcdef"
  ACTIVE = "rs-private-8955233c3d65"
  BASE = "/var/tmp/rs-server-image-acceptance.example/base"
  IMAGE = "sha256:#{'1' * 64}"

  def setup
    @baseline = {"name" => PROJECT, "services" => {}, "networks" => {
      "default" => {"name" => "#{PROJECT}_default", "internal" => true, "driver" => "bridge",
        "driver_opts" => {"com.docker.network.bridge.gateway_mode_ipv4" => "isolated"}},
      "access" => {"name" => "#{PROJECT}_access"}}, "volumes" => {
        "database" => {"name" => "#{PROJECT}_database"}, "publications" => {"name" => "#{PROJECT}_publications"}}}
    images = {"database" => "postgres:17", "mailpit" => "axllent/mailpit:v1.31.5",
      "rs_server_setup" => PrivateTrial::APPLICATION_IMAGE, "rs_server_webapp" => PrivateTrial::APPLICATION_IMAGE}
    images.each do |name, image|
      service = {"image" => image, "runtime" => "runc", "restart" => "no", "networks" => {"default" => nil},
        "read_only" => true, "cap_drop" => ["ALL"], "security_opt" => ["no-new-privileges:true"], "volumes" => []}
      if name == "database" || name.start_with?("rs_server_")
        volume = name == "database" ? "database" : "publications"
        target = name == "database" ? "/var/lib/postgresql/data" : "/rs_server/storage/publications/user"
        service["volumes"] << {"type" => "volume", "source" => volume, "target" => target}
      end
      binds = name == "mailpit" ? %w[smtp.crt smtp.key smtp.auth ui.auth] : (name == "database" ? [] : ["smtp.crt"])
      binds.each { |file| service["volumes"] << {"type" => "bind", "source" => "#{BASE}/runtime/#{file}", "target" => "/trial/#{file}", "read_only" => true} }
      if name.start_with?("rs_server_")
        service["environment"] = {"PUBLIC_BASE_URL" => "http://127.0.0.1:33030", "RS_PDF_ALLOW_PRIVATE_NETWORKS" => "false", "SECRET_PROD_KEY" => "synthetic-secret"}
      end
      @baseline["services"][name] = service
    end
    @baseline["services"]["rs_server_setup"]["command"] = ["./bin/rails", "db:migrate"]
    @baseline["services"]["access"] = {"ports" => ["127.0.0.1:33030:8080"]}
  end

  def test_removes_access_and_pins_images_without_mutating_the_input
    result = checker.definition
    assert_equal ImageAcceptanceConfiguration::SERVICES.sort, result.fetch("services").keys.sort
    assert_equal ["default"], result.fetch("networks").keys
    result.fetch("services").each_value do |service|
      assert_equal IMAGE, service.fetch("image")
      assert_equal "never", service.fetch("pull_policy")
      refute service.key?("ports")
    end
    assert @baseline.fetch("services").key?("access")
    assert_equal PrivateTrial::APPLICATION_IMAGE, @baseline.dig("services", "rs_server_webapp", "image")
    assert_equal "/acceptance/Reader.pdf", result.dig("services", "rs_server_webapp", "volumes").last.fetch("target")
    refute_includes JSON.generate(checker.validate!(result)), "synthetic-secret"
  end

  def test_rejects_active_identity_and_mutable_images
    assert_raises(ImageAcceptanceConfiguration::Error) { checker(active_project: PROJECT).definition }
    assert_raises(ImageAcceptanceConfiguration::Error) { checker(application_image: "candidate:latest").definition }
  end

  def test_rejects_shared_storage_and_unexpected_bind_targets
    [
      -> { @baseline["volumes"]["database"]["name"] = "active_database" },
      -> { @baseline["volumes"]["publications"]["external"] = true },
      -> { @baseline["services"]["database"]["volumes"][0]["target"] = "/elsewhere" },
      -> { @baseline["services"]["mailpit"]["volumes"][0]["source"] = "/etc/opt/readersourcing/rs-server/smtp.crt" },
      -> { @baseline["services"]["mailpit"]["volumes"].pop },
      -> { @baseline["services"]["rs_server_webapp"]["volumes"][1]["read_only"] = false }
    ].each do |change|
      setup
      change.call
      assert_raises(ImageAcceptanceConfiguration::Error) { checker.definition }
    end
  end

  def test_rejects_network_runtime_and_security_changes
    [
      -> { @baseline["networks"]["default"]["internal"] = false },
      -> { @baseline["services"]["database"]["ports"] = ["5432:5432"] },
      -> { @baseline["services"]["rs_server_webapp"]["network_mode"] = "host" },
      -> { @baseline["services"]["rs_server_webapp"]["read_only"] = false },
      -> { @baseline["services"]["rs_server_webapp"]["privileged"] = true },
      -> { @baseline["services"]["rs_server_setup"]["command"] = ["./bin/rails", "db:drop"] },
      -> { @baseline["services"]["rs_server_webapp"]["environment"]["RS_PDF_ALLOW_PRIVATE_NETWORKS"] = "true" }
    ].each do |change|
      setup
      change.call
      assert_raises(ImageAcceptanceConfiguration::Error) { checker.definition }
    end
  end

  def test_requires_an_exact_compose_round_trip
    resolved = checker.definition
    resolved["services"]["rs_server_webapp"]["environment"]["SECRET_PROD_KEY"] = "changed"
    error = assert_raises(ImageAcceptanceConfiguration::Error) { checker.validate!(resolved) }
    refute_includes error.message, "synthetic-secret"
  end

  private

  def checker(**overrides)
    ImageAcceptanceConfiguration.new(**{baseline: @baseline, project: PROJECT, active_project: ACTIVE,
      base_directory: BASE, application_image: IMAGE, database_image: IMAGE, mailpit_image: IMAGE}.merge(overrides))
  end
end
