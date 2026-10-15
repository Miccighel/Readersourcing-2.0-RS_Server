require "minitest/autorun"
require_relative "../../deploy/private/deployment_layout_configuration"

class DeploymentLayoutConfigurationTest < Minitest::Test
  OLD = "/var/tmp/rs-source.synthetic"
  NEW = "/etc/opt/readersourcing/rs-server"
  APPLICATION = "sha256:#{'a' * 64}"

  def setup
    @source = {"name" => "rs-private-0123456789ab", "services" => {},
      "networks" => {"default" => {"internal" => true}},
      "volumes" => {"database" => {"name" => "retained_database"}, "publications" => {"name" => "retained_publications"}},
      "x-app" => {"image" => "old-template"}}
    DeploymentLayoutConfiguration::SOURCE_SERVICES.each do |name|
      @source["services"][name] = {"image" => "original-tag", "environment" => {"PRIVATE" => "synthetic-secret"},
        "read_only" => name != "database", "restart" => "no", "runtime" => "runc", "volumes" => []}
    end
    DeploymentLayoutConfiguration::RUNTIME_BINDINGS.each do |service, files|
      files.each do |name, target|
        @source["services"][service]["volumes"] << {"type" => "bind", "source" => "#{OLD}/runtime/#{name}", "target" => target, "read_only" => true, "bind" => {"create_host_path" => true}}
      end
    end
    @source["services"]["database"]["volumes"] << {"type" => "volume", "source" => "database", "target" => "/var/lib/postgresql/data"}
    @source["services"]["rs_server_webapp"]["volumes"] << {"type" => "volume", "source" => "publications", "target" => "/rs_server/storage/publications/user"}
    @source["services"]["rs_server_webapp"]["depends_on"] = {"database" => {"condition" => "service_healthy"}, "rs_server_setup" => {"condition" => "service_completed_successfully", "required" => true}}
    @source["services"]["access"]["ports"] = [{"host_ip" => "127.0.0.1", "published" => "33030", "target" => 8080}]
    @containers = DeploymentLayoutConfiguration::SOURCE_SERVICES.each_with_index.map do |name, index|
      {"Image" => name == "rs_server_webapp" ? APPLICATION : "sha256:#{index.to_s * 64}",
        "Config" => {"Labels" => {"com.docker.compose.project" => @source["name"], "com.docker.compose.service" => name}},
        "State" => {"Running" => name != "rs_server_setup", "ExitCode" => 0, "Paused" => false, "Restarting" => false, "Dead" => false}}
    end
  end

  def layout(**options)
    DeploymentLayoutConfiguration.new(source: @source, containers: @containers, project: @source["name"],
      application_image: APPLICATION, source_directory: OLD, configuration_directory: NEW, **options)
  end

  def test_relocates_only_runtime_files_and_pins_the_existing_images_without_mutating_the_source
    retained = JSON.generate(@source)
    planned = layout.definition
    assert_equal DeploymentLayoutConfiguration::SERVICES, planned.fetch("services").keys.sort
    assert_equal @source.fetch("volumes"), planned.fetch("volumes")
    assert_equal @source.fetch("networks"), planned.fetch("networks")
    refute planned.key?("x-app")
    refute planned["services"]["rs_server_webapp"]["depends_on"].key?("rs_server_setup")
    assert_equal APPLICATION, planned["services"]["rs_server_webapp"]["image"]
    planned.fetch("services").each_value do |service|
      service.fetch("volumes").select { |mount| mount["type"] == "bind" }.each do |mount|
        assert mount.fetch("source").start_with?("#{NEW}/runtime/")
        assert mount.fetch("read_only")
      end
    end
    assert_equal retained, JSON.generate(@source)
    report = layout.validate!(planned)
    refute_includes JSON.generate(report), "synthetic-secret"
    assert report.fetch("project_identity_preserved")
  end

  def test_definition_changes_to_secrets_volumes_networks_ports_and_runtime_restrictions_are_rejected
    [
      ->(config) { config["services"]["rs_server_webapp"]["environment"]["PRIVATE"] = "changed" },
      ->(config) { config["services"]["database"]["volumes"][0]["source"] = "other" },
      ->(config) { config["networks"]["default"]["internal"] = false },
      ->(config) { config["services"]["access"]["ports"][0]["host_ip"] = "0.0.0.0" },
      ->(config) { config["services"]["mailpit"]["read_only"] = false },
      ->(config) { config["services"]["mailpit"]["image"] = "another" }
    ].each do |change|
      planned = layout.definition
      change.call(planned)
      assert_raises(DeploymentLayoutConfiguration::Error) { layout.validate!(planned) }
    end
  end

  def test_unexpected_mount_sources_targets_and_permissions_are_rejected
    [
      ->(mount) { mount["source"] = "/other/smtp.crt" },
      ->(mount) { mount["target"] = "/other/smtp.crt" },
      ->(mount) { mount["read_only"] = false }
    ].each do |change|
      setup
      change.call(@source["services"]["rs_server_webapp"]["volumes"][0])
      assert_raises(DeploymentLayoutConfiguration::Error) { layout.definition }
    end
  end

  def test_foreign_duplicate_missing_stopped_and_changed_image_containers_are_rejected
    [
      -> { @containers.pop },
      -> { @containers[0] = @containers[1] },
      -> { @containers.first["Config"]["Labels"]["com.docker.compose.project"] = "foreign" },
      -> { @containers.first["State"]["Running"] = false },
      -> { @containers.find { |entry| entry["Config"]["Labels"]["com.docker.compose.service"] == "rs_server_setup" }["State"]["Running"] = true },
      -> { @containers.last["Image"] = "sha256:#{'f' * 64}" }
    ].each do |change|
      setup
      change.call
      assert_raises(DeploymentLayoutConfiguration::Error) { layout.definition }
    end
  end

  def test_unresolved_inputs_and_extra_runtime_files_are_rejected
    @source["services"]["database"]["env_file"] = ["old.env"]
    assert_raises(DeploymentLayoutConfiguration::Error) { layout.definition }
    setup
    @source["services"]["mailpit"]["volumes"].pop
    assert_raises(DeploymentLayoutConfiguration::Error) { layout.definition }
    setup
    @source["services"]["rs_server_webapp"]["depends_on"]["rs_server_setup"]["condition"] = "service_started"
    assert_raises(DeploymentLayoutConfiguration::Error) { layout.definition }
  end
end
