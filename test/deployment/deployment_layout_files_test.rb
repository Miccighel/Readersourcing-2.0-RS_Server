require "minitest/autorun"
require "tmpdir"
require "fileutils"
require_relative "../../deploy/private/deployment_layout_files"
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
end
