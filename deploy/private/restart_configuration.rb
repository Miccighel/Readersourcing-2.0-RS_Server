require "json"
require_relative "candidate_configuration"

class PrivateTrialRestartConfiguration

  class Error < StandardError; end

  def initialize(original:, effective:, activated:, project:, published_image:, candidate_image:)
    @original, @effective, @activated = original, effective, activated
    @project, @published_image, @candidate_image = project, published_image, candidate_image
  end

  def validate!
    PrivateTrialCandidateConfiguration.new(
      baseline: @original, candidate: @effective, project: @project,
      published_image: @published_image, candidate_image: @candidate_image
    ).validate!
    raise Error, "Configuration differs from the activated candidate" unless @effective == @activated

    {"status" => "passed", "project" => @project, "candidate_image" => @candidate_image,
      "configuration_matches_activation" => true}
  rescue PrivateTrialCandidateConfiguration::Error => error
    raise Error, error.message
  end

end

if $PROGRAM_NAME == __FILE__
  begin
    raise PrivateTrialRestartConfiguration::Error, "Expected three configuration files, project and image identities" unless ARGV.length == 6
    original, effective, activated = ARGV.take(3).map { |path| JSON.parse(File.read(path)) }
    result = PrivateTrialRestartConfiguration.new(
      original: original, effective: effective, activated: activated,
      project: ARGV[3], published_image: ARGV[4], candidate_image: ARGV[5]
    ).validate!
    puts JSON.pretty_generate(result)
  rescue PrivateTrialRestartConfiguration::Error => error
    warn error.message
    exit 1
  rescue StandardError => error
    warn "Candidate restart configuration check failed (#{error.class}); private configuration was not printed"
    exit 1
  end
end
