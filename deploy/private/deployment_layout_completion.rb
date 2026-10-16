require_relative "deployment_layout_files"
require_relative "deployment_startup_inventory"

class DeploymentLayoutCompletion < DeploymentLayoutFiles

  def initialize(checkpoint:, **paths)
    super(**paths)
    @checkpoint = checkpoint
  end

  def validate!
    perform("configuration")
    settings = read(@definition, "settings.json")
    raise Error, "Completion context differs" unless settings == read(@state, "settings.json") &&
      read(@plan, "compose.json") == read(@state, "definition.json")
    baseline = read(@state, "startup-inventory.json")
    recorded = read(@checkpoint, "replacement-containers.json")
    # The frozen inventory must still be the one prepared before the first replacement start.
    inventory(recorded, settings).validate!(baseline)
    current = read(@checks, "replacement-containers.json")
    DeploymentStartupInventory.new(containers: current, definition: read(@state, "definition.json"),
      project: settings.fetch("project"), image: settings.fetch("application_image"), revision: settings.fetch("source_revision")).validate!(baseline)
    index = ->(entries) { entries.to_h { |entry| [entry.fetch("Config").fetch("Labels").fetch("com.docker.compose.service"), entry] } }
    old = index.call(recorded)
    index.call(current).each do |service, entry|
      before, state = old.fetch(service), entry.fetch("State")
      raise Error, "Unexpected restart count" unless entry.fetch("RestartCount") == before.fetch("RestartCount")
      case service
      when "access", "rs_server_webapp"
        raise Error, "Access and writer must remain stopped" unless state.fetch("Running").equal?(false) && state.fetch("Status") == "exited" && !state.fetch("StartedAt").start_with?("0001-")
        raise Error, "Unexpected OOM termination" unless state.fetch("OOMKilled").equal?(false)
      when "database", "rs_server_setup"
        raise Error, "Retained lifecycle differs" unless %w[Running StartedAt ExitCode].all? { |key| before.fetch("State").fetch(key) == state.fetch(key) }
      when "mailpit"
        raise Error, "Mail service must remain running" unless state.fetch("Running").equal?(true) && state.fetch("Status") == "running"
      end
    end
    {"status" => "layout_completion_checkpoint_verified", "frozen_inventory_preserved" => true,
      "existing_container_identities_verified" => true, "services_changed" => false}
  end

end

if $PROGRAM_NAME == __FILE__
  begin
    raise DeploymentLayoutFiles::Error, "Unexpected completion arguments" unless ARGV.empty?
    puts JSON.generate(DeploymentLayoutCompletion.new(definition: "/definition", plan: "/plan", source: "/source", checks: "/checks",
      configuration: "/configuration", state: "/state", checkpoint: "/checkpoint").validate!)
  rescue StandardError => error
    warn "Layout completion checkpoint rejected (#{error.class}); private values were not printed"
    exit 1
  end
end
