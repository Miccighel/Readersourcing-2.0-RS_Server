require_relative "deployment_layout_configuration"
require_relative "startup_inventory"

class DeploymentLayoutInventory

  class Error < StandardError; end
  REPLACED = %w[access mailpit rs_server_webapp].freeze
  CONFIG_LABELS = %w[com.docker.compose.config-hash com.docker.compose.project.config_files
    com.docker.compose.project.working_dir com.docker.compose.replace].freeze

  def initialize(source:, current:, project:, image:, revision:, source_directory:, configuration_directory:)
    @source, @current, @project, @image, @revision = source, current, project, image, revision
    @source_directory, @configuration_directory = source_directory, configuration_directory
  end

  def validate!
    old = index(@source)
    current = index(@current)
    DeploymentLayoutConfiguration::SOURCE_SERVICES.each do |service|
      before, after = old.fetch(service), current.fetch(service)
      if REPLACED.include?(service)
        raise Error, "Replacement must be created without starting" unless !after.fetch("State").fetch("Running") && after.fetch("State").fetch("StartedAt").start_with?("0001-")
        raise Error, "Expected a new container identity" if before.fetch("Id") == after.fetch("Id")
        raise Error, "Container image differs" unless before.fetch("Image") == after.fetch("Image") && after.fetch("Config").fetch("Image") == after.fetch("Image")
        expected_binds = DeploymentLayoutConfiguration::RUNTIME_BINDINGS.fetch(service).keys.map { |name| File.join(@configuration_directory, "runtime", name) }.sort
        actual_binds = after.fetch("Mounts").select { |mount| mount.fetch("Type") == "bind" }.map { |mount| mount.fetch("Source") }.sort
        raise Error, "Replacement bind sources were not relocated" unless actual_binds == expected_binds
        validate_labels!(before, after, service)
        raise Error, "Container execution settings differ" unless config(before, service) == config(after, service)
        raise Error, "Container isolation settings differ" unless host(before, service, false) == host(after, service, true)
        raise Error, "Container mounts differ" unless mounts(before, service, false) == mounts(after, service, true)
      else
        raise Error, "Retained container identity differs" unless before.fetch("Id") == after.fetch("Id")
        raise Error, "Retained container lifecycle differs" unless %w[Running StartedAt].all? { |key| before.fetch("State").fetch(key) == after.fetch("State").fetch(key) } && before.fetch("RestartCount") == after.fetch("RestartCount")
        reference = inventory(@source).snapshot.fetch(service)
        raise Error, "Retained container settings differ" unless inventory(@current).snapshot.fetch(service) == reference
      end
      raise Error, "Container networks differ" unless before.fetch("NetworkSettings").fetch("Networks").keys.sort == after.fetch("NetworkSettings").fetch("Networks").keys.sort
      raise Error, "Container name differs" unless before.fetch("Name") == after.fetch("Name")
    end
    {"status" => "replacement_inventory_verified", "services_recreated" => REPLACED,
      "database_and_completed_setup_retained" => true, "images_and_execution_settings_preserved" => true,
      "runtime_bind_sources_relocated" => true, "replacements_started" => false}
  rescue KeyError, TypeError, NoMethodError
    raise Error, "Incomplete container inventory"
  end

  private

  def inventory(containers)
    PrivateTrialStartupInventory.new(containers: containers, project: @project, image: @image, revision: @revision)
  end

  def index(containers)
    inventory(containers).snapshot
    containers.to_h { |entry| [entry.fetch("Config").fetch("Labels").fetch("com.docker.compose.service"), entry] }
  end

  def validate_labels!(before, after, service)
    previous, current = before.fetch("Config").fetch("Labels"), after.fetch("Config").fetch("Labels")
    raise Error, "Unexpected configuration location label" unless current.fetch("com.docker.compose.project.config_files") == File.join(@configuration_directory, "compose.json") && current.fetch("com.docker.compose.project.working_dir") == @configuration_directory
    raise Error, "Invalid configuration hash" unless current.fetch("com.docker.compose.config-hash").match?(/\A[0-9a-f]{64}\z/)
    if current.key?("com.docker.compose.replace")
      raise Error, "Unexpected replacement label" unless current.fetch("com.docker.compose.replace") == before.fetch("Id")
    end
    return unless service == "rs_server_webapp"
    original = previous.fetch("com.docker.compose.depends_on").split(",")
    expected = original.reject { |part| part.split(":").first == "rs_server_setup" }.sort
    raise Error, "Unexpected dependency label" unless current.fetch("com.docker.compose.depends_on").split(",").sort == expected
  end

  def config(container, service)
    result = JSON.parse(JSON.generate(container.fetch("Config")))
    result.delete("Image")
    hostname = result.fetch("Hostname")
    result["Hostname"] = "<container-id>" if hostname == container.fetch("Id")[0, 12]
    labels = result.fetch("Labels")
    CONFIG_LABELS.each { |label| labels.delete(label) }
    labels.delete("com.docker.compose.depends_on") if service == "rs_server_webapp"
    environment = result.fetch("Env")
    raise Error, "Duplicate environment key" unless environment.map { |entry| entry.split("=", 2).first }.uniq.length == environment.length
    result["Env"] = environment.sort
    result
  end

  def relocated_source(source, service, replacement)
    return source unless replacement
    DeploymentLayoutConfiguration::RUNTIME_BINDINGS.fetch(service).keys.each do |name|
      return File.join(@source_directory, "runtime", name) if source == File.join(@configuration_directory, "runtime", name)
    end
    source
  end

  def host(container, service, replacement)
    result = JSON.parse(JSON.generate(container.fetch("HostConfig")))
    result.delete("ConsoleSize")
    if result["Mounts"]
      result["Mounts"].each do |mount|
        mount["Source"] = relocated_source(mount.fetch("Source"), service, replacement) if mount["Type"] == "bind"
      end
      result["Mounts"].sort_by! { |mount| mount.fetch("Target") }
    end
    if result["Binds"]
      result["Binds"] = result["Binds"].map do |bind|
        source, target, mode = bind.split(":", 3)
        [relocated_source(source, service, replacement), target, mode].compact.join(":")
      end.sort
    end
    result
  end

  def mounts(container, service, replacement)
    result = JSON.parse(JSON.generate(container.fetch("Mounts")))
    result.each do |mount|
      mount["Source"] = relocated_source(mount.fetch("Source"), service, replacement) if mount["Type"] == "bind"
    end
    result.sort_by { |mount| mount.fetch("Destination") }
  end

end
