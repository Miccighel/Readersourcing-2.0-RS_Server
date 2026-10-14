require "json"

class PrivateTrialCandidateConfiguration

  class Error < StandardError; end

  APPLICATION_SERVICES = %w[rs_server_setup rs_server_webapp].freeze
  REQUIRED_SERVICES = (APPLICATION_SERVICES + %w[access database mailpit]).sort.freeze

  def initialize(baseline:, candidate:, project:, published_image:, candidate_image:)
    @baseline, @candidate = baseline, candidate
    @project, @published_image, @candidate_image = project, published_image, candidate_image
  end

  def validate!
    raise Error, "Invalid trial project" unless @project.match?(/\Ars-private-[0-9a-f]{12}\z/)
    raise Error, "The candidate requires an exact local image ID" unless @candidate_image.match?(/\Asha256:[0-9a-f]{64}\z/)
    raise Error, "The retained release requires an immutable reference" unless @published_image.match?(/\A[^\s]+@sha256:[0-9a-f]{64}\z/)
    raise Error, "Unexpected baseline project" unless @baseline.fetch("name") == @project
    raise Error, "Unexpected trial services" unless @baseline.fetch("services").keys.sort == REQUIRED_SERVICES

    expected = JSON.parse(JSON.generate(@baseline))
    APPLICATION_SERVICES.each do |name|
      raise Error, "Unexpected retained application image" unless expected.fetch("services").fetch(name).fetch("image") == @published_image
      expected.fetch("services").fetch(name)["image"] = @candidate_image
    end
    raise Error, "Candidate configuration changes more than the application images" unless @candidate == expected

    {
      "status" => "passed", "project" => @project,
      "published_image" => @published_image, "candidate_image" => @candidate_image,
      "changed_services" => APPLICATION_SERVICES,
      "only_application_images_changed" => true
    }
  rescue KeyError, NoMethodError, TypeError
    raise Error, "Incomplete trial configuration"
  end

end

if $PROGRAM_NAME == __FILE__
  begin
    raise PrivateTrialCandidateConfiguration::Error, "Expected two configuration files, project and image identities" unless ARGV.length == 5
    baseline, candidate = ARGV.take(2).map { |path| JSON.parse(File.read(path)) }
    result = PrivateTrialCandidateConfiguration.new(
      baseline: baseline, candidate: candidate, project: ARGV[2],
      published_image: ARGV[3], candidate_image: ARGV[4]
    ).validate!
    puts JSON.pretty_generate(result)
  rescue PrivateTrialCandidateConfiguration::Error => error
    warn error.message
    exit 1
  rescue StandardError => error
    warn "Trial configuration validation failed (#{error.class})"
    exit 1
  end
end
