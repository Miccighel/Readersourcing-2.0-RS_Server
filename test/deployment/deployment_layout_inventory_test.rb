require "minitest/autorun"
require "digest"
require_relative "../../deploy/private/deployment_layout_inventory"
require_relative "../support/deployment_layout_fixtures"

class DeploymentLayoutInventoryTest < Minitest::Test
  include DeploymentLayoutFixtures

  def setup
    @source = source_containers
    @current = replacements(@source)
    @definition = {"services" => DeploymentLayoutConfiguration::SERVICES.to_h { |name| [name, {}] }}
    @definition["services"]["rs_server_webapp"]["depends_on"] = {"database" => {"condition" => "service_healthy"}}
  end

  def checker
    DeploymentLayoutInventory.new(source: @source, current: @current, definition: @definition, project: PROJECT, image: IMAGE, revision: REVISION,
      source_directory: SOURCE, configuration_directory: TARGET)
  end

  def test_only_stopped_replacements_with_the_same_runtime_settings_are_accepted
    retained = JSON.generate(@source)
    report = checker.validate!
    assert_equal "replacement_inventory_verified", report.fetch("status")
    assert report.fetch("database_and_completed_setup_retained")
    refute report.fetch("replacements_started")
    refute_includes JSON.generate(report), "PRIVATE"
    assert_equal retained, JSON.generate(@source)
    @current.each do |entry|
      entry["Mounts"].reverse!
      next unless DeploymentLayoutInventory::REPLACED.include?(entry["Config"]["Labels"]["com.docker.compose.service"])
      entry["Config"]["Env"].reverse!
      entry["HostConfig"]["Mounts"].reverse!
    end
    checker.validate!
  end

  def test_execution_is_rejected_if_a_replacement_started_or_the_image_command_secret_or_user_changed
    [
      ->(entry) { entry["State"]["Running"] = true },
      ->(entry) { entry["State"]["StartedAt"] = "2026-10-15T12:00:00Z" },
      ->(entry) { entry["Image"] = "sha256:#{'9' * 64}" },
      ->(entry) { entry["Config"]["Image"] = "mutable-tag" },
      ->(entry) { entry["Config"]["Env"][0] = "PRIVATE=changed" },
      ->(entry) { entry["Config"]["Env"] << "PRIVATE=duplicate" },
      ->(entry) { entry["Config"]["Cmd"] = ["another-command"] },
      ->(entry) { entry["Config"]["User"] = "0" },
      ->(entry) { entry["HostConfig"]["ReadonlyRootfs"] = false },
      ->(entry) { entry["HostConfig"]["CapDrop"] = [] },
      ->(entry) { entry["HostConfig"]["Memory"] *= 2 }
    ].each do |change|
      setup
      change.call(@current.first)
      assert_raises(DeploymentLayoutInventory::Error) { checker.validate! }
    end
  end

  def test_compose_replacement_names_and_selected_dependency_labels_match_the_approved_definition
    @source.last["Config"]["Labels"]["com.docker.compose.depends_on"] = ""
    @definition["services"]["rs_server_webapp"]["depends_on"]["mailpit"] = {"condition" => "service_started"}
    @definition["services"]["access"]["depends_on"] = {"rs_server_webapp" => {"condition" => "service_healthy"}, "mailpit" => {"condition" => "service_started"}}
    web = @current.last["Config"]["Labels"]
    access = @current.first["Config"]["Labels"]
    web["com.docker.compose.depends_on"] = "mailpit:service_started:false"
    access["com.docker.compose.depends_on"] = "rs_server_webapp:service_healthy:false,mailpit:service_started:false"
    assert_equal "replacement_inventory_verified", checker.validate!["status"]
    web["com.docker.compose.depends_on"] += ",database:service_healthy:false"
    assert_raises(DeploymentLayoutInventory::Error) { checker.validate! }
    web["com.docker.compose.depends_on"] = "mailpit:service_started:false"
    access["com.docker.compose.depends_on"] = "mailpit:service_started:true"
    assert_raises(DeploymentLayoutInventory::Error) { checker.validate! }
    access["com.docker.compose.depends_on"] = "rs_server_webapp:service_healthy:false,mailpit:service_started:false"
    web["com.docker.compose.replace"] = @source.last["Id"]
    assert_raises(DeploymentLayoutInventory::Error) { checker.validate! }
  end

  def test_labels_cannot_change_identity_dependencies_or_configuration_location
    [
      ["com.docker.compose.project.config_files", "/other/compose.json"],
      ["com.docker.compose.project.working_dir", "/other"],
      ["com.docker.compose.config-hash", "invalid"],
      ["com.docker.compose.replace", "another-id"],
      ["com.docker.compose.depends_on", "unexpected:service_started:false"]
    ].each do |key, value|
      setup
      @current.last["Config"]["Labels"][key] = value
      assert_raises(DeploymentLayoutInventory::Error) { checker.validate! }
    end
    setup
    @current.first["Config"]["Labels"]["unrelated-label"] = "new"
    assert_raises(DeploymentLayoutInventory::Error) { checker.validate! }
  end

  def test_mounts_must_move_to_the_exact_new_sources_without_other_changes
    [
      ->(entry) { entry["Mounts"].first["Source"] = "#{SOURCE}/runtime/proxy.conf" },
      ->(entry) { entry["Mounts"].first["Source"] = "/other/proxy.conf" },
      ->(entry) { entry["Mounts"].first["RW"] = true },
      ->(entry) { entry["Mounts"].first["Destination"] = "/other" },
      ->(entry) { entry["HostConfig"]["Mounts"].first["ReadOnly"] = false },
      ->(entry) { entry["HostConfig"]["Mounts"].first["Source"] = "/other" },
      ->(entry) { entry["NetworkSettings"]["Networks"] = {"another" => {}} }
    ].each do |change|
      setup
      change.call(@current.first)
      assert_raises(DeploymentLayoutInventory::Error) { checker.validate! }
    end
  end

  def test_the_database_and_completed_setup_cannot_be_replaced_or_restarted
    %w[database rs_server_setup].each do |service|
      [
        ->(entry) { entry["Id"] = "replacement" },
        ->(entry) { entry["RestartCount"] += 1 },
        ->(entry) { entry["State"]["StartedAt"] = "changed" },
        ->(entry) { entry["Config"]["Env"][0] = "PRIVATE=changed" }
      ].each do |change|
        setup
        change.call(@current.find { |entry| entry["Config"]["Labels"]["com.docker.compose.service"] == service })
        assert_raises(DeploymentLayoutInventory::Error) { checker.validate! }
      end
    end
  end
end
