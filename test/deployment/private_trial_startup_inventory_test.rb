require "minitest/autorun"
require_relative "../../deploy/private/startup_inventory"

class PrivateTrialStartupInventoryTest < Minitest::Test
  def containers
    PrivateTrialStartupInventory::SERVICES.map do |service|
      {"Id" => "id-#{service}", "Name" => "/trial-#{service}", "Image" => service == "rs_server_webapp" ? "candidate" : "retained",
        "Config" => {"Env" => ["PRIVATE=synthetic"], "Labels" => {"com.docker.compose.project" => "trial",
          "com.docker.compose.service" => service, "org.opencontainers.image.revision" => "revision"}},
        "HostConfig" => {"ConsoleSize" => [0, 0], "RestartPolicy" => {"Name" => "no"}, "ReadonlyRootfs" => true},
        "Mounts" => [{"Name" => "trial-data", "Destination" => "/data", "RW" => false}],
        "State" => {"Running" => service != "rs_server_setup", "ExitCode" => 0, "Paused" => false, "Restarting" => false, "Dead" => false},
        "NetworkSettings" => {"Networks" => {"trial_default" => {"IPAddress" => "172.18.0.2"}}}}
    end
  end

  def inventory(entries)
    PrivateTrialStartupInventory.new(containers: entries, project: "trial", image: "candidate", revision: "revision")
  end

  def test_same_containers_can_be_stopped_without_changing_the_inventory
    entries = containers
    baseline = inventory(entries).snapshot
    entries.each do |entry|
      entry["State"]["Running"] = false
      entry["HostConfig"]["ConsoleSize"] = [24, 80]
      entry["NetworkSettings"]["Networks"]["trial_default"]["IPAddress"] = ""
    end
    assert_equal "passed", inventory(entries).validate!(baseline).fetch("status")
    assert_equal "retained", baseline.fetch("rs_server_setup").fetch("image")
  end

  def test_identity_image_configuration_mount_and_network_changes_are_rejected
    [
      ->(entry) { entry["Id"] = "replacement" },
      ->(entry) { entry["Image"] = "replacement" },
      ->(entry) { entry["Config"]["Env"] = ["PRIVATE=changed"] },
      ->(entry) { entry["HostConfig"]["ReadonlyRootfs"] = false },
      ->(entry) { entry["Mounts"][0]["RW"] = true },
      ->(entry) { entry["NetworkSettings"]["Networks"] = {"another" => {}} }
    ].each do |change|
      entries = containers
      baseline = inventory(entries).snapshot
      change.call(entries.first)
      assert_raises(PrivateTrialStartupInventory::Error) { inventory(entries).validate!(baseline) }
    end
  end

  def test_duplicate_missing_or_foreign_containers_and_automatic_restart_are_rejected
    [
      ->(entries) { entries.pop },
      ->(entries) { entries[0] = entries[1] },
      ->(entries) { entries.first["Config"]["Labels"]["com.docker.compose.project"] = "foreign" },
      ->(entries) { entries.first["HostConfig"]["RestartPolicy"]["Name"] = "always" },
      ->(entries) { entries.first["State"]["Paused"] = true },
      ->(entries) { entries.find { |entry| entry["Name"].end_with?("setup") }["State"]["ExitCode"] = 1 }
    ].each do |change|
      entries = containers
      change.call(entries)
      assert_raises(PrivateTrialStartupInventory::Error) { inventory(entries).snapshot }
    end
  end

  def test_candidate_image_and_revision_are_checked_independently_of_the_baseline
    %w[Image revision].each do |field|
      entries = containers
      web = entries.last
      field == "Image" ? web[field] = "old" : web["Config"]["Labels"]["org.opencontainers.image.revision"] = "old"
      assert_raises(PrivateTrialStartupInventory::Error) { inventory(entries).snapshot }
    end
  end

  def test_mount_order_is_ignored_in_existing_and_new_inventories_without_rewriting_the_baseline
    entries = containers
    entries.each { |entry| entry["Mounts"] << {"Name" => "trial-config", "Destination" => "/config", "RW" => false} }
    baseline = inventory(entries).snapshot
    baseline.each_value { |entry| entry.fetch("mounts").reverse! }
    retained_baseline = JSON.generate(baseline)
    expected = inventory(entries).snapshot
    entries.each { |entry| entry["Mounts"].reverse! }

    assert_equal expected, inventory(entries).snapshot
    assert_equal "passed", inventory(entries).validate!(baseline).fetch("status")
    assert_equal retained_baseline, JSON.generate(baseline)
  end

  def test_mount_content_changes_are_still_rejected_after_reordering
    [
      ->(mounts) { mounts.first["Destination"] = "/other" },
      ->(mounts) { mounts.first["Name"] = "another-volume" },
      ->(mounts) { mounts.first["RW"] = true },
      ->(mounts) { mounts.first["Source"] = "/another-source" },
      ->(mounts) { mounts.first["Mode"] = "changed" },
      ->(mounts) { mounts.first["Propagation"] = "shared" },
      ->(mounts) { mounts.pop }
    ].each do |change|
      entries = containers
      entries.first["Mounts"] << {"Destination" => "/config", "RW" => false}
      baseline = inventory(entries).snapshot
      entries.first["Mounts"].reverse!
      change.call(entries.first["Mounts"])
      assert_raises(PrivateTrialStartupInventory::Error) { inventory(entries).validate!(baseline) }
    end
  end

  def test_missing_and_duplicate_mount_destinations_are_rejected
    [
      ->(mounts) { mounts.first.delete("Destination") },
      ->(mounts) { mounts.first["Destination"] = "" },
      ->(mounts) { mounts << mounts.first.dup }
    ].each do |change|
      entries = containers
      change.call(entries.first["Mounts"])
      assert_raises(PrivateTrialStartupInventory::Error) { inventory(entries).snapshot }
    end
  end
end
