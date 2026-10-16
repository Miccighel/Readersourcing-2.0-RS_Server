require_relative "startup_inventory"

# Only the final deployment opts into Docker's two representations of the default OOM setting.
class DeploymentStartupInventory < PrivateTrialStartupInventory

  DEFAULT_OOM_SERVICES = %w[access mailpit rs_server_webapp].freeze

  def initialize(definition:, **options)
    super(**options)
    raise Error, "Unexpected deployment definition" unless definition.fetch("name") == @project &&
      definition.fetch("services").keys.sort == %w[access database mailpit rs_server_webapp] &&
      definition.fetch("services").fetch("rs_server_webapp").fetch("image") == @image
    DEFAULT_OOM_SERVICES.each do |service|
      raise Error, "OOM killer must not be disabled" unless definition.fetch("services").fetch(service).fetch("oom_kill_disable", false).equal?(false)
    end
  end

  def snapshot
    default_oom_inventory(super)
  end

  def validate!(baseline)
    super(default_oom_inventory(baseline))
  end

  private

  def default_oom_inventory(value)
    raise Error, "Unexpected deployment inventory" unless value.is_a?(Hash) && value.keys.sort == SERVICES
    result = JSON.parse(JSON.generate(value))
    DEFAULT_OOM_SERVICES.each do |service|
      host = result.fetch(service).fetch("host")
      raise Error, "Missing or unsafe OOM setting" unless host.key?("OomKillDisable") &&
        (host.fetch("OomKillDisable").nil? || host.fetch("OomKillDisable").equal?(false))
      host["OomKillDisable"] = false
    end
    result
  end

end

if $PROGRAM_NAME == __FILE__
  begin
    raise PrivateTrialStartupInventory::Error, "Expected inspection, inventory, definition and identities" unless ARGV.length == 6
    inspection, inventory, definition, project, image, revision = ARGV
    checker = DeploymentStartupInventory.new(containers: JSON.parse(File.read(inspection)), definition: JSON.parse(File.read(definition)),
      project: project, image: image, revision: revision)
    puts JSON.generate(checker.validate!(JSON.parse(File.read(inventory))))
  rescue StandardError => error
    warn "Deployment startup inventory check failed (#{error.class}); private configuration was not printed"
    exit 1
  end
end
