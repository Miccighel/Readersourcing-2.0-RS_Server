require "digest"
require "shellwords"
require_relative "deployment_layout_inventory"

class DeploymentLayoutFiles

  class Error < StandardError; end

  def initialize(definition:, plan:, source:, checks:, configuration:, state:, backup: "/backup")
    @definition, @plan, @source, @checks, @configuration, @state = definition, plan, source, checks, configuration, state
    @backup = backup
  end

  def perform(operation)
    case operation
    when "recovery-code"
      require_relative "deployment_recovery_configuration"
      {"status" => "layout_recovery_code_loaded"}
    when "recovery-preflight"
      require_relative "deployment_recovery_configuration"
      require "securerandom"
      settings = read(@definition, "settings.json")
      original = read(@state, "definition.json")
      raise Error, "Recovery input differs" unless original == read(@checks, "effective.json")
      destination = File.join(@checks, "recovery-preflight")
      Dir.mkdir(destination, 0o700)
      DeploymentRecoveryConfiguration.new(backup: @backup, original: File.join(@checks, "effective.json"), destination: destination,
        project: "rs-recovery-#{SecureRandom.hex(6)}", source_project: settings.fetch("project"), published_image: "",
        backup_image: settings.fetch("application_image"), application_image: settings.fetch("application_image"),
        database_image: original.fetch("services").fetch("database").fetch("image"),
        mailpit_image: original.fetch("services").fetch("mailpit").fetch("image")).prepare!
      {"status" => "layout_backup_recovery_definition_verified", "recovery_containers_created" => false}
    when "preflight"
      settings = read(@definition, "settings.json")
      original, current = read(@plan, "source-containers.json"), read(@checks, "source-containers.json")
      inventory(current, settings).validate!(inventory(original, settings).snapshot)
      layout = DeploymentLayoutConfiguration.new(source: read(@plan, "source-candidate.json"), containers: current,
        project: settings.fetch("project"), application_image: settings.fetch("application_image"),
        source_directory: settings.fetch("source_directory"), configuration_directory: settings.fetch("configuration_directory"))
      layout.validate!(read(@plan, "compose.json"))
      layout.validate!(read(@plan, "resolved.json"))
      raise Error, "Prepared runtime inputs changed" unless runtime_inventory(@source) == read(@plan, "runtime-files.json")
      {"status" => "layout_preflight_passed"}
    when "install"
      perform("preflight")
      settings = read(@definition, "settings.json")
      raise Error, "Runtime copy differs" unless runtime_inventory(@configuration) == read(@plan, "runtime-files.json")
      definition = read(@plan, "compose.json")
      write(@configuration, "compose.json", definition)
      write(@configuration, "settings.json", settings)
      context = {"rs_expected_project" => "project", "rs_candidate_image" => "application_image",
        "rs_source_revision" => "source_revision", "rs_trial_directory" => "configuration_directory",
        "rs_plan_directory" => "active_directory", "rs_state_directory" => "state_directory",
        "rs_lock_file" => "lock_file"}.map { |variable, key| "#{variable}=#{Shellwords.escape(settings.fetch(key))}\n" }.join
      write_bytes(@configuration, "context.sh", context)
      write(@state, "definition.json", definition)
      write(@state, "runtime-files.json", read(@plan, "runtime-files.json"))
      write(@state, "settings.json", settings)
      write(@state, "context-sha256.json", {"sha256" => Digest::SHA256.hexdigest(context)})
      {"status" => "layout_files_installed", "services_changed" => false}
    when "configuration"
      settings = read(@state, "settings.json")
      raise Error, "Installed context differs" unless settings == read(@configuration, "settings.json") &&
        Digest::SHA256.file(File.join(@configuration, "context.sh")).hexdigest == read(@state, "context-sha256.json").fetch("sha256")
      frozen = read(@state, "definition.json")
      raise Error, "Installed configuration differs" unless frozen == read(@configuration, "compose.json") && frozen == read(@checks, "effective.json")
      raise Error, "Runtime files differ" unless runtime_inventory(@configuration) == read(@state, "runtime-files.json")
      {"status" => "layout_configuration_verified"}
    when "replacement"
      settings = read(@definition, "settings.json")
      DeploymentLayoutInventory.new(source: read(@checks, "source-containers.json"), current: read(@checks, "replacement-containers.json"), definition: read(@plan, "compose.json"),
        project: settings.fetch("project"), image: settings.fetch("application_image"), revision: settings.fetch("source_revision"),
        source_directory: settings.fetch("source_directory"), configuration_directory: settings.fetch("configuration_directory")).validate!
    when "freeze"
      perform("replacement")
      settings = read(@definition, "settings.json")
      write(@state, "startup-inventory.json", inventory(read(@checks, "replacement-containers.json"), settings).snapshot)
      {"status" => "layout_inventory_prepared"}
    else
      raise Error, "Unknown layout operation"
    end
  end

  private

  def inventory(containers, settings)
    PrivateTrialStartupInventory.new(containers: containers, project: settings.fetch("project"),
      image: settings.fetch("application_image"), revision: settings.fetch("source_revision"))
  end

  def regular_file(directory, name)
    path = File.join(directory, name)
    raise Error, "Expected an ordinary file" unless File.lstat(path).file?
    path
  end

  def read(directory, name)
    JSON.parse(File.read(regular_file(directory, name)))
  end

  def write(directory, name, contents)
    write_bytes(directory, name, JSON.pretty_generate(contents) + "\n")
  end

  def write_bytes(directory, name, contents)
    File.open(File.join(directory, name), "wx", 0o600) { |file| file.write(contents) }
  end

  def runtime_inventory(directory)
    runtime = File.join(directory, "runtime")
    raise Error, "Expected an ordinary runtime directory" unless File.lstat(runtime).directory?
    DeploymentLayoutConfiguration::RUNTIME_FILES.to_h do |name|
      path = regular_file(runtime, name)
      stat = File.lstat(path)
      [name, {"sha256" => Digest::SHA256.file(path).hexdigest, "uid" => stat.uid, "gid" => stat.gid, "mode" => stat.mode & 0o7777}]
    end
  end

end

if $PROGRAM_NAME == __FILE__
  begin
    raise DeploymentLayoutFiles::Error, "Expected one layout operation" unless ARGV.length == 1
    checker = DeploymentLayoutFiles.new(definition: "/definition", plan: "/plan", source: "/source", checks: "/checks",
      configuration: "/configuration", state: "/state")
    puts JSON.generate(checker.perform(ARGV.first))
  rescue StandardError => error
    warn "Layout check failed (#{error.class}); private values were not printed"
    exit 1
  end
end
