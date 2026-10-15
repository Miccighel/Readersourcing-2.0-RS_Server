require_relative "deployment_layout_files"

# Validates a recorded interruption without replacing its evidence or accepting a new baseline.
class DeploymentLayoutResume < DeploymentLayoutFiles

  def initialize(checkpoint:, **paths)
    super(**paths)
    @checkpoint = checkpoint
  end

  def validate!
    perform("preflight")
    perform("configuration")
    settings = read(@definition, "settings.json")
    raise Error, "Prepared settings differ" unless settings == read(@state, "settings.json")
    raise Error, "Prepared definition differs" unless read(@plan, "compose.json") == read(@state, "definition.json")
    inventory_path = File.join(@state, "startup-inventory.json")
    raise Error, "Startup inventory already exists" if File.exist?(inventory_path) || File.symlink?(inventory_path)
    raise Error, "Source checkpoint differs" unless read(@checks, "source-containers.json") == read(@checkpoint, "source-containers.json")
    recorded, current = read(@checkpoint, "replacement-containers.json"), read(@checks, "replacement-containers.json")
    inventory(current, settings).validate!(inventory(recorded, settings).snapshot)
    by_service = ->(entries) { entries.to_h { |entry| [entry.fetch("Config").fetch("Labels").fetch("com.docker.compose.service"), entry] } }
    old = by_service.call(recorded)
    by_service.call(current).each do |service, entry|
      previous = old.fetch(service)
      raise Error, "Checkpoint restart count differs" unless entry.fetch("RestartCount") == previous.fetch("RestartCount")
      if DeploymentLayoutInventory::REPLACED.include?(service)
        raise Error, "Replacement checkpoint state differs" unless entry.fetch("State") == previous.fetch("State")
        raise Error, "Replacement is not waiting at the checkpoint" unless entry.fetch("State").fetch("Status") == "created"
      else
        # A running database updates its health history. Compare lifecycle, not probe timestamps.
        lifecycle = %w[Status Running StartedAt FinishedAt ExitCode Paused Restarting Dead OOMKilled Pid Error]
        raise Error, "Retained checkpoint lifecycle differs" unless lifecycle.all? do |key|
          entry.fetch("State").key?(key) == previous.fetch("State").key?(key) && entry.fetch("State")[key] == previous.fetch("State")[key]
        end
      end
    end
    perform("replacement")
    {"status" => "stopped_layout_checkpoint_verified", "existing_replacements_reused" => true,
      "configuration_or_inventory_written" => false, "services_started" => false}
  end

end

if $PROGRAM_NAME == __FILE__
  begin
    raise DeploymentLayoutFiles::Error, "Unexpected resume arguments" unless ARGV.empty?
    checker = DeploymentLayoutResume.new(definition: "/definition", plan: "/plan", source: "/source", checks: "/checks",
      configuration: "/configuration", state: "/state", checkpoint: "/checkpoint")
    puts JSON.generate(checker.validate!)
  rescue StandardError => error
    warn "Stopped layout checkpoint rejected (#{error.class}); private values were not printed"
    exit 1
  end
end
