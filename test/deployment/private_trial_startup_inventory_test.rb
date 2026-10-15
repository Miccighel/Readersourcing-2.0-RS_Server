require "minitest/autorun"
require_relative "../../deploy/private/startup_inventory"

class PrivateTrialStartupInventoryTest < Minitest::Test
  def containers
    PrivateTrialStartupInventory::SERVICES.map do |service|
      {"Id" => "id-#{service}", "Name" => "/trial-#{service}", "Image" => service == "rs_server_webapp" ? "candidate" : "retained",
        "Config" => {"Env" => ["PRIVATE=synthetic"], "Labels" => {"com.docker.compose.project" => "trial",
          "com.docker.compose.service" => service, "org.opencontainers.image.revision" => "revision"}},
        "HostConfig" => {"ConsoleSize" => [0, 0], "RestartPolicy" => {"Name" => "no"}, "ReadonlyRootfs" => true},
        "Mounts" => [{"Name" => "trial-data", "RW" => false}],
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
end
