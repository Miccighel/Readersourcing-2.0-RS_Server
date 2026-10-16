require "minitest/autorun"
require_relative "../../deploy/private/deployment_startup_inventory"
require_relative "../../deploy/private/deployment_layout_inventory"
require_relative "../support/deployment_layout_fixtures"

class DeploymentStartupInventoryTest < Minitest::Test
  include DeploymentLayoutFixtures

  def setup
    @entries = source_containers
    @definition = {"name" => PROJECT, "services" => %w[access database mailpit rs_server_webapp].to_h { |service| [service, {"image" => service == "rs_server_webapp" ? IMAGE : "retained"}] }}
    @baseline = PrivateTrialStartupInventory.new(containers: @entries, project: PROJECT, image: IMAGE, revision: REVISION).snapshot
    DeploymentStartupInventory::DEFAULT_OOM_SERVICES.each { |service| @baseline[service]["host"]["OomKillDisable"] = false }
  end

  def checker
    DeploymentStartupInventory.new(containers: @entries, definition: @definition, project: PROJECT, image: IMAGE, revision: REVISION)
  end

  def test_default_representation_can_change_without_rewriting_the_baseline_or_raw_inspection
    before = JSON.generate([@entries, @baseline])
    assert_equal "passed", checker.validate!(@baseline)["status"]
    assert_equal before, JSON.generate([@entries, @baseline])
    DeploymentStartupInventory::DEFAULT_OOM_SERVICES.each do |service|
      @entries.find { |entry| entry["Config"]["Labels"]["com.docker.compose.service"] == service }["HostConfig"]["OomKillDisable"] = false
      @baseline[service]["host"]["OomKillDisable"] = nil
    end
    assert_equal "passed", checker.validate!(@baseline)["status"]
  end

  def test_true_missing_and_non_boolean_settings_are_rejected_in_current_and_frozen_inventories
    [true, 0, "false", []].each do |value|
      setup
      @entries.first["HostConfig"]["OomKillDisable"] = value
      assert_raises(PrivateTrialStartupInventory::Error) { checker.validate!(@baseline) }
      setup
      @baseline["access"]["host"]["OomKillDisable"] = value
      assert_raises(PrivateTrialStartupInventory::Error) { checker.validate!(@baseline) }
    end
    setup
    @entries.first["HostConfig"].delete("OomKillDisable")
    assert_raises(PrivateTrialStartupInventory::Error) { checker.validate!(@baseline) }
    setup
    @baseline["access"]["host"].delete("OomKillDisable")
    assert_raises(PrivateTrialStartupInventory::Error) { checker.validate!(@baseline) }
  end

  def test_definition_must_explicitly_leave_oom_killing_enabled
    [true, nil, 0, "false"].each do |value|
      setup
      @definition["services"]["access"]["oom_kill_disable"] = value
      assert_raises(PrivateTrialStartupInventory::Error) { checker.validate!(@baseline) }
    end
    setup
    @definition["services"]["access"]["oom_kill_disable"] = false
    assert_equal "passed", checker.validate!(@baseline)["status"]
    @definition["name"] = "other"
    assert_raises(PrivateTrialStartupInventory::Error) { checker.validate!(@baseline) }
  end

  def test_other_runtime_changes_and_retained_oom_settings_remain_exact
    [
      -> { @entries.first["HostConfig"]["Memory"] *= 2 },
      -> { @entries.first["HostConfig"]["ReadonlyRootfs"] = false },
      -> { @entries.first["HostConfig"]["CapDrop"] = [] },
      -> { @entries.first["Config"]["Env"] = ["PRIVATE=changed"] },
      -> { @entries.first["Mounts"].first["RW"] = true },
      -> { @entries.first["Id"] = "replacement" }
    ].each do |change|
      setup
      change.call
      assert_raises(PrivateTrialStartupInventory::Error) { checker.validate!(@baseline) }
    end
    %w[database rs_server_setup].each do |service|
      setup
      @entries.find { |entry| entry["Config"]["Labels"]["com.docker.compose.service"] == service }["HostConfig"]["OomKillDisable"] = false
      assert_raises(PrivateTrialStartupInventory::Error) { checker.validate!(@baseline) }
    end
  end

  def test_original_inventory_checker_does_not_gain_implicit_normalization
    assert_raises(PrivateTrialStartupInventory::Error) do
      PrivateTrialStartupInventory.new(containers: @entries, project: PROJECT, image: IMAGE, revision: REVISION).validate!(@baseline)
    end
  end
end
