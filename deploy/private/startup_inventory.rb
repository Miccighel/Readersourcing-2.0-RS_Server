require "json"

class PrivateTrialStartupInventory

  class Error < StandardError; end
  SERVICES = %w[access database mailpit rs_server_setup rs_server_webapp].freeze

  def initialize(containers:, project:, image:, revision:)
    @containers, @project, @image, @revision = containers, project, image, revision
  end

  def snapshot
    raise Error, "Expected exactly five trial containers" unless @containers.is_a?(Array) && @containers.length == SERVICES.length
    result = @containers.to_h do |container|
      config, host, state = container.fetch("Config"), container.fetch("HostConfig"), container.fetch("State")
      labels = config.fetch("Labels")
      service = labels.fetch("com.docker.compose.service")
      raise Error, "Unexpected trial identity" unless labels.fetch("com.docker.compose.project") == @project && SERVICES.include?(service)
      raise Error, "Unstable container state" if %w[Paused Restarting Dead].any? { |key| state.fetch(key) }
      if service == "rs_server_setup"
        raise Error, "Setup must remain completed" unless !state.fetch("Running") && state.fetch("ExitCode") == 0
      elsif service == "rs_server_webapp"
        raise Error, "Unexpected application image" unless container.fetch("Image") == @image && labels.fetch("org.opencontainers.image.revision") == @revision
      end
      raise Error, "Automatic restarts are not part of the trial" unless host.fetch("RestartPolicy").fetch("Name") == "no"
      # Environment values stay in the protected inventory, never in a public report.
      # Endpoint addresses and console size change when the same container restarts.
      [service, {"id" => container.fetch("Id"), "name" => container.fetch("Name"),
        "image" => container.fetch("Image"), "config" => config,
        "host" => host.reject { |key, _| key == "ConsoleSize" }, "mounts" => container.fetch("Mounts"),
        "networks" => container.fetch("NetworkSettings").fetch("Networks").keys.sort}]
    end
    raise Error, "Trial service identities are not unique" unless result.keys.sort == SERVICES && result.values.map { |entry| entry.fetch("id") }.uniq.length == SERVICES.length
    JSON.parse(JSON.generate(result.sort.to_h))
  end

  def validate!(baseline)
    raise Error, "Existing container inventory differs from preparation" unless snapshot == baseline
    {"status" => "passed", "containers_checked" => SERVICES.length}
  end

end

if $PROGRAM_NAME == __FILE__
  begin
    raise PrivateTrialStartupInventory::Error, "Expected operation, inspection, inventory and candidate identities" unless ARGV.length == 6
    operation, inspection, inventory, project, image, revision = ARGV
    checker = PrivateTrialStartupInventory.new(containers: JSON.parse(File.read(inspection)), project: project, image: image, revision: revision)
    case operation
    when "prepare"
      File.write(inventory, JSON.pretty_generate(checker.snapshot) + "\n", mode: "wx", perm: 0600)
      puts JSON.generate(status: "prepared", containers_checked: 5)
    when "check"
      puts JSON.generate(checker.validate!(JSON.parse(File.read(inventory))))
    else
      raise PrivateTrialStartupInventory::Error, "Unknown inventory operation"
    end
  rescue StandardError => error
    warn "Startup inventory check failed (#{error.class}); private configuration was not printed"
    exit 1
  end
end
