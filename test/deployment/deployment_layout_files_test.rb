require "minitest/autorun"
require "tmpdir"
require "fileutils"
require_relative "../../deploy/private/deployment_layout_files"
require_relative "../../deploy/private/deployment_layout_resume"
require_relative "../../deploy/private/deployment_layout_completion"
require_relative "../support/deployment_layout_fixtures"

class DeploymentLayoutFilesTest < Minitest::Test
  include DeploymentLayoutFixtures

  def write_json(directory, name, contents)
    File.write(File.join(directory, name), JSON.generate(contents))
  end

  def with_files
    Dir.mktmpdir("rs-layout-files.") do |root|
      paths = %i[definition plan source checks configuration state].to_h { |name| [name, File.join(root, name.to_s)] }
      paths.each_value { |path| FileUtils.mkdir_p(path) }
      %i[source configuration].each { |name| FileUtils.mkdir_p(File.join(paths.fetch(name), "runtime")) }
      settings = {"project" => PROJECT, "application_image" => IMAGE, "source_revision" => REVISION,
        "source_directory" => SOURCE, "configuration_directory" => TARGET,
        "active_directory" => "/var/opt/readersourcing/rs-server/active", "state_directory" => "/var/opt/readersourcing/rs-server",
        "lock_file" => "/var/opt/readersourcing/rs-server/deployment.lock"}
      write_json(paths[:definition], "settings.json", settings)
      source = source_containers
      original = {"name" => PROJECT, "services" => {}, "volumes" => {"database" => {}, "publications" => {}}, "networks" => {"default" => {"internal" => true}}}
      source.each do |entry|
        name = entry["Config"]["Labels"]["com.docker.compose.service"]
        files = DeploymentLayoutConfiguration::RUNTIME_BINDINGS.fetch(name, {})
        mounts = files.map { |file, target| {"type" => "bind", "source" => "#{SOURCE}/runtime/#{file}", "target" => target, "read_only" => true} }
        volume = {"database" => "database", "rs_server_webapp" => "publications"}[name]
        mounts << {"type" => "volume", "source" => volume, "target" => "/data"} if volume
        original["services"][name] = {"image" => "original-tag", "volumes" => mounts, "environment" => {"PRIVATE" => "synthetic"}}
      end
      original["services"]["rs_server_webapp"]["depends_on"] = {"rs_server_setup" => {"condition" => "service_completed_successfully"}}
      planned = DeploymentLayoutConfiguration.new(source: original, containers: source, project: PROJECT,
        application_image: IMAGE, source_directory: SOURCE, configuration_directory: TARGET).definition
      write_json(paths[:plan], "source-candidate.json", original)
      write_json(paths[:plan], "source-containers.json", source)
      write_json(paths[:checks], "source-containers.json", source)
      write_json(paths[:plan], "compose.json", planned)
      write_json(paths[:plan], "resolved.json", planned)
      runtime = DeploymentLayoutConfiguration::RUNTIME_FILES.to_h do |name|
        file = File.join(paths[:source], "runtime", name)
        File.write(file, "synthetic #{name}")
        File.chmod(name == "smtp.crt" ? 0o644 : 0o600, file)
        FileUtils.cp(file, File.join(paths[:configuration], "runtime", name), preserve: true)
        stat = File.stat(file)
        [name, {"sha256" => Digest::SHA256.file(file).hexdigest, "uid" => stat.uid, "gid" => stat.gid, "mode" => stat.mode & 0o7777}]
      end
      write_json(paths[:plan], "runtime-files.json", runtime)
      yield DeploymentLayoutFiles.new(**paths), paths, source, planned
    end
  end

  def test_preparation_installation_configuration_and_inventory_preserve_the_inputs
    with_files do |files, paths, source, planned|
      original = File.binread(File.join(paths[:plan], "source-candidate.json"))
      assert_equal "layout_preflight_passed", files.perform("preflight")["status"]
      assert_equal "layout_files_installed", files.perform("install")["status"]
      write_json(paths[:checks], "effective.json", planned)
      assert_equal "layout_configuration_verified", files.perform("configuration")["status"]
      write_json(paths[:checks], "replacement-containers.json", replacements(source))
      assert_equal "replacement_inventory_verified", files.perform("replacement")["status"]
      assert_equal "layout_inventory_prepared", files.perform("freeze")["status"]
      baseline = JSON.parse(File.read(File.join(paths[:state], "startup-inventory.json")))
      assert_equal 5, baseline.length
      %w[compose.json context.sh settings.json].each do |name|
        assert_equal 0o600, File.stat(File.join(paths[:configuration], name)).mode & 0o777
      end
      assert_equal original, File.binread(File.join(paths[:plan], "source-candidate.json"))
      refute_includes File.read(File.join(paths[:configuration], "context.sh")), "PRIVATE"
      assert_raises(Errno::EEXIST) { files.perform("install") }
    end
  end

  def test_preflight_rejects_changed_inputs_without_creating_configuration
    [
      ->(paths) { File.write(File.join(paths[:source], "runtime", "smtp.key"), "changed") },
      ->(paths) { File.chmod(0o644, File.join(paths[:source], "runtime", "smtp.key")) },
      ->(paths) { config = JSON.parse(File.read(File.join(paths[:plan], "resolved.json"))); config["services"]["mailpit"]["image"] = "other"; write_json(paths[:plan], "resolved.json", config) }
    ].each do |change|
      with_files do |files, paths, _source, _planned|
        change.call(paths)
        assert_raises(DeploymentLayoutFiles::Error, DeploymentLayoutConfiguration::Error) { files.perform("preflight") }
        refute File.exist?(File.join(paths[:configuration], "compose.json"))
      end
    end
  end

  def test_post_install_checks_reject_context_configuration_copy_or_runtime_drift
    [
      ->(paths) { File.write(File.join(paths[:configuration], "context.sh"), "changed") },
      ->(paths) { write_json(paths[:configuration], "settings.json", {}) },
      ->(paths) { write_json(paths[:checks], "effective.json", {}) },
      ->(paths) { File.write(File.join(paths[:configuration], "runtime", "smtp.key"), "changed") },
      ->(paths) { File.chmod(0o644, File.join(paths[:configuration], "runtime", "smtp.key")) }
    ].each do |change|
      with_files do |files, paths, _source, planned|
        files.perform("install")
        write_json(paths[:checks], "effective.json", planned)
        change.call(paths)
        assert_raises(DeploymentLayoutFiles::Error) { files.perform("configuration") }
      end
    end
  end

  def test_runtime_symbolic_links_are_not_followed
    with_files do |files, paths, _source, _planned|
      file = File.join(paths[:source], "runtime", "smtp.key")
      File.rename(file, "#{file}.retained")
      File.symlink("#{file}.retained", file)
      assert_raises(DeploymentLayoutFiles::Error) { files.perform("preflight") }
    end
  end

  def with_resume
    with_files do |files, paths, source, planned|
      files.perform("install")
      checkpoint = File.join(paths[:checks], "checkpoint")
      Dir.mkdir(checkpoint)
      current = replacements(source)
      write_json(checkpoint, "source-containers.json", source)
      write_json(checkpoint, "replacement-containers.json", current)
      write_json(paths[:checks], "replacement-containers.json", current)
      write_json(paths[:checks], "effective.json", planned)
      yield DeploymentLayoutResume.new(checkpoint: checkpoint, **paths), paths, current, checkpoint
    end
  end

  def test_resume_validates_existing_checkpoint_without_writing_new_baselines
    with_resume do |resume, paths, _current, _checkpoint|
      before = Dir.glob("#{paths[:state]}/*").to_h { |path| [path, File.binread(path)] }
      assert_equal "stopped_layout_checkpoint_verified", resume.validate!["status"]
      assert_equal before, Dir.glob("#{paths[:state]}/*").to_h { |path| [path, File.binread(path)] }
      refute File.exist?(File.join(paths[:state], "startup-inventory.json"))
    end
  end

  def test_resume_rejects_started_recreated_changed_or_missing_checkpoint_containers
    [
      ->(current) { current.first["State"]["Running"] = true },
      ->(current) { current.first["State"]["Status"] = "exited" },
      ->(current) { current.first["State"]["StartedAt"] = "2026-10-15T16:00:00Z" },
      ->(current) { current.first["RestartCount"] += 1 },
      ->(current) { current.first["Id"] = "9" * 64 },
      ->(current) { current.first["HostConfig"]["OomKillDisable"] = true },
      ->(current) { current.first["HostConfig"]["Memory"] *= 2 },
      ->(current) { current.pop }
    ].each do |change|
      with_resume do |resume, paths, current, _checkpoint|
        change.call(current)
        write_json(paths[:checks], "replacement-containers.json", current)
        assert_raises(DeploymentLayoutFiles::Error, DeploymentLayoutInventory::Error, PrivateTrialStartupInventory::Error) { resume.validate! }
        refute File.exist?(File.join(paths[:state], "startup-inventory.json"))
      end
    end
  end

  def test_resume_requires_original_evidence_configuration_and_no_installed_inventory
    [
      ->(paths, checkpoint) { write_json(checkpoint, "source-containers.json", []) },
      ->(paths, _checkpoint) { write_json(paths[:checks], "effective.json", {}) },
      ->(paths, _checkpoint) { write_json(paths[:state], "startup-inventory.json", {}) },
      ->(paths, _checkpoint) { File.symlink("missing", File.join(paths[:state], "startup-inventory.json")) },
      ->(paths, _checkpoint) { File.write(File.join(paths[:configuration], "runtime", "smtp.key"), "changed") }
    ].each do |change|
      with_resume do |resume, paths, _current, checkpoint|
        change.call(paths, checkpoint)
        assert_raises(DeploymentLayoutFiles::Error) { resume.validate! }
      end
    end
  end

  def test_resume_allows_fresh_database_health_history_but_not_a_restart
    with_resume do |resume, paths, current, _checkpoint|
      database = current.find { |entry| entry["Config"]["Labels"]["com.docker.compose.service"] == "database" }
      database["State"]["Health"] = {"Status" => "healthy", "Log" => ["synthetic fresh probe"]}
      write_json(paths[:checks], "replacement-containers.json", current)
      assert_equal "stopped_layout_checkpoint_verified", resume.validate!["status"]
      database["State"]["StartedAt"] = "2026-10-15T16:00:00Z"
      write_json(paths[:checks], "replacement-containers.json", current)
      assert_raises(DeploymentLayoutFiles::Error) { resume.validate! }
    end
  end

  def with_completion
    with_resume do |_resume, paths, current, checkpoint|
      DeploymentLayoutFiles.new(**paths).perform("freeze")
      current.each do |entry|
        service = entry["Config"]["Labels"]["com.docker.compose.service"]
        next unless DeploymentLayoutInventory::REPLACED.include?(service)
        entry["HostConfig"]["OomKillDisable"] = nil
        entry["State"]["Running"] = service == "mailpit"
        entry["State"]["Status"] = service == "mailpit" ? "running" : "exited"
        entry["State"]["StartedAt"] = "2026-10-15T16:00:00Z"
      end
      write_json(paths[:checks], "replacement-containers.json", current)
      yield DeploymentLayoutCompletion.new(checkpoint: checkpoint, **paths), paths, current, checkpoint
    end
  end

  def test_completion_accepts_only_the_preserved_frozen_checkpoint_without_rewriting_it
    with_completion do |completion, paths, _current, _checkpoint|
      inventory = File.join(paths[:state], "startup-inventory.json")
      before = File.binread(inventory)
      assert_equal "layout_completion_checkpoint_verified", completion.validate!["status"]
      assert_equal before, File.binread(inventory)
    end
  end

  def test_completion_rejects_unsafe_drift_started_writers_and_retained_lifecycle_changes
    [
      ->(entries) { entries.first["HostConfig"]["OomKillDisable"] = true },
      ->(entries) { entries.first["HostConfig"]["Memory"] *= 2 },
      ->(entries) { entries.first["State"]["Running"] = true },
      ->(entries) { entries.first["State"]["OOMKilled"] = true },
      ->(entries) { entries.first["RestartCount"] += 1 },
      ->(entries) { entries.find { |entry| entry["Config"]["Labels"]["com.docker.compose.service"] == "database" }["State"]["StartedAt"] = "changed" },
      ->(entries) { entries.find { |entry| entry["Config"]["Labels"]["com.docker.compose.service"] == "mailpit" }["State"]["Running"] = false }
    ].each do |change|
      with_completion do |completion, paths, current, _checkpoint|
        change.call(current)
        write_json(paths[:checks], "replacement-containers.json", current)
        assert_raises(DeploymentLayoutFiles::Error, PrivateTrialStartupInventory::Error) { completion.validate! }
      end
    end
  end

  def test_completion_cannot_refresh_a_modified_frozen_inventory_or_recorded_replacement
    with_completion do |completion, paths, _current, checkpoint|
      value = JSON.parse(File.read(File.join(checkpoint, "replacement-containers.json")))
      value.first["Id"] = "changed"
      write_json(checkpoint, "replacement-containers.json", value)
      assert_raises(PrivateTrialStartupInventory::Error) { completion.validate! }
    end
    with_completion do |completion, paths, _current, _checkpoint|
      value = JSON.parse(File.read(File.join(paths[:state], "startup-inventory.json")))
      value["access"]["host"]["OomKillDisable"] = nil
      write_json(paths[:state], "startup-inventory.json", value)
      assert_raises(PrivateTrialStartupInventory::Error) { completion.validate! }
    end
  end
end
