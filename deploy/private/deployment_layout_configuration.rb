require "json"

class DeploymentLayoutConfiguration

  class Error < StandardError; end
  SERVICES = %w[access database mailpit rs_server_webapp].freeze
  SOURCE_SERVICES = (SERVICES + ["rs_server_setup"]).sort.freeze
  RUNTIME_BINDINGS = {
    "access" => {"proxy.conf" => "/trial/proxy.conf"}, "database" => {},
    "mailpit" => %w[smtp.crt smtp.key smtp.auth ui.auth].to_h { |name| [name, "/trial/#{name}"] },
    "rs_server_webapp" => {"smtp.crt" => "/trial/smtp.crt"}
  }.freeze
  RUNTIME_FILES = RUNTIME_BINDINGS.values.flat_map(&:keys).uniq.sort.freeze

  def initialize(source:, containers:, project:, application_image:, source_directory:, configuration_directory:)
    @source, @containers, @project, @application_image = source, containers, project, application_image
    @source_directory, @configuration_directory = source_directory, configuration_directory
  end

  def definition
    validate_source!
    images = runtime_images
    result = JSON.parse(JSON.generate(@source))
    # Service definitions are already resolved. Extension templates are not runtime inputs.
    result.delete_if { |key, _| key.start_with?("x-") }
    result.fetch("services").delete("rs_server_setup")
    result.fetch("services").each do |name, service|
      raise Error, "Unresolved service input" if %w[env_file extends build profiles].any? { |key| service.key?(key) }
      service["image"] = images.fetch(name)
      bindings, volumes = [], []
      service.fetch("volumes", []).each do |mount|
        case mount.fetch("type")
        when "bind"
          filename = File.basename(mount.fetch("source"))
          expected_target = RUNTIME_BINDINGS.fetch(name)[filename]
          raise Error, "Unexpected runtime bind mount" unless expected_target &&
            mount.fetch("source") == File.join(@source_directory, "runtime", filename) &&
            mount.fetch("target") == expected_target && mount.fetch("read_only") == true
          mount["source"] = File.join(@configuration_directory, "runtime", filename)
          bindings << filename
        when "volume"
          volumes << mount.fetch("source")
        else
          raise Error, "Unexpected storage type"
        end
      end
      expected_volumes = {"database" => ["database"], "rs_server_webapp" => ["publications"]}.fetch(name, [])
      raise Error, "Unexpected runtime file set" unless bindings.sort == RUNTIME_BINDINGS.fetch(name).keys.sort
      raise Error, "Unexpected persistent volume set" unless volumes.sort == expected_volumes
    end
    dependencies = result.fetch("services").fetch("rs_server_webapp").fetch("depends_on")
    setup = dependencies.fetch("rs_server_setup")
    raise Error, "Unexpected setup dependency" unless setup.fetch("condition") == "service_completed_successfully"
    dependencies.delete("rs_server_setup")
    result
  rescue KeyError, TypeError, NoMethodError
    raise Error, "Incomplete layout migration input"
  end

  def validate!(proposed)
    raise Error, "Layout changes more than the approved paths and orchestration metadata" unless proposed == definition
    {"status" => "layout_definition_verified", "project_identity_preserved" => true,
      "active_services" => SERVICES, "runtime_images_pinned_to_existing_contents" => true,
      "persistent_volume_definitions_preserved" => true, "ports_networks_environment_and_runtime_limits_preserved" => true,
      "setup_excluded_from_active_definition" => true, "unique_runtime_files" => RUNTIME_FILES.length,
      "trial_containers_created_or_restarted" => false, "migrations_run" => false}
  end

  private

  def validate_source!
    raise Error, "Invalid project identity" unless @project.match?(/\Ars-private-[0-9a-f]{12}\z/) && @source.fetch("name") == @project
    raise Error, "Unexpected source services" unless @source.fetch("services").keys.sort == SOURCE_SERVICES
    raise Error, "Invalid application image" unless @application_image.match?(/\Asha256:[0-9a-f]{64}\z/)
    [@source_directory, @configuration_directory].each do |path|
      raise Error, "Invalid configuration path" unless path.is_a?(String) && path.match?(/\A\/[A-Za-z0-9_.\/-]+\z/) && File.expand_path(path) == path && !%w[/ /var /tmp /var/tmp /etc /etc/opt].include?(path)
    end
    raise Error, "Source and destination paths overlap" if @source_directory == @configuration_directory ||
      @configuration_directory.start_with?("#{@source_directory}/") || @source_directory.start_with?("#{@configuration_directory}/")
  end

  def runtime_images
    raise Error, "Expected the five retained source containers" unless @containers.is_a?(Array) && @containers.length == SOURCE_SERVICES.length
    images = {}
    @containers.each do |container|
      labels, state = container.fetch("Config").fetch("Labels"), container.fetch("State")
      service = labels.fetch("com.docker.compose.service")
      raise Error, "Unexpected container identity" unless SOURCE_SERVICES.include?(service) && !images.key?(service) && labels.fetch("com.docker.compose.project") == @project
      raise Error, "Unstable source container" if %w[Paused Restarting Dead].any? { |key| state.fetch(key) }
      if service == "rs_server_setup"
        raise Error, "Setup must remain stopped and completed" unless !state.fetch("Running") && state.fetch("ExitCode") == 0
      else
        raise Error, "Source services must be running" unless state.fetch("Running")
      end
      image = container.fetch("Image")
      raise Error, "Invalid runtime image identity" unless image.match?(/\Asha256:[0-9a-f]{64}\z/)
      images[service] = image
    end
    raise Error, "Source application image differs" unless images.fetch("rs_server_webapp") == @application_image
    images.slice(*SERVICES)
  end

end
