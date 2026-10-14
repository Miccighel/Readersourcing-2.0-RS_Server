require "minitest/autorun"
require_relative "../../deploy/private/candidate_configuration"

class PrivateTrialCandidateConfigurationTest < Minitest::Test

  PUBLISHED = "miccighel/rs_server@sha256:#{"1" * 64}"
  CANDIDATE = "sha256:#{"2" * 64}"

  def setup
    @baseline = {
      "name" => "rs-private-123456abcdef",
      "services" => {
        "rs_server_setup" => {"image" => PUBLISHED},
        "rs_server_webapp" => {"image" => PUBLISHED, "environment" => {"SECRET_PROD_KEY" => "unit-test-only", "PUBLIC_BASE_URL" => "http://127.0.0.1:33030"}, "read_only" => true},
        "database" => {"image" => "postgres:17", "volumes" => [{"source" => "database", "target" => "/var/lib/postgresql/data"}]},
        "mailpit" => {"image" => "axllent/mailpit:v1.31.5"},
        "access" => {"ports" => [{"host_ip" => "127.0.0.1", "published" => "33030", "target" => 8080}]}
      },
      "networks" => {"default" => {"internal" => true}}
    }
    @candidate = JSON.parse(JSON.generate(@baseline))
    PrivateTrialCandidateConfiguration::APPLICATION_SERVICES.each { |name| @candidate["services"][name]["image"] = CANDIDATE }
  end

  def test_accepts_only_the_two_explicit_application_image_changes
    result = validator.validate!
    assert_equal true, result.fetch("only_application_images_changed")
    refute_includes JSON.generate(result), "unit-test-only"
    assert_equal PUBLISHED, @baseline.dig("services", "rs_server_webapp", "image")
  end

  def test_rejects_a_changed_signing_key_or_public_origin
    %w[SECRET_PROD_KEY PUBLIC_BASE_URL].each do |name|
      setup
      @candidate["services"]["rs_server_webapp"]["environment"][name] = "changed"
      error = assert_raises(PrivateTrialCandidateConfiguration::Error) { validator.validate! }
      refute_includes error.message, "unit-test-only"
    end
  end

  def test_rejects_security_network_and_storage_changes
    [
      -> { @candidate["services"]["rs_server_webapp"]["read_only"] = false },
      -> { @candidate["networks"]["default"]["internal"] = false },
      -> { @candidate["services"]["access"]["ports"][0]["host_ip"] = "0.0.0.0" },
      -> { @candidate["services"]["database"]["volumes"][0]["source"] = "another_database" },
      -> { @candidate["services"]["mailpit"]["image"] = "another-image" }
    ].each do |change|
      setup
      change.call
      assert_raises(PrivateTrialCandidateConfiguration::Error) { validator.validate! }
    end
  end

  def test_rejects_an_unpinned_candidate_image
    @candidate["services"]["rs_server_webapp"]["image"] = "rs-server-candidate:latest"
    assert_raises(PrivateTrialCandidateConfiguration::Error) { validator(candidate_image: "rs-server-candidate:latest").validate! }
  end

  def test_rejects_a_partial_image_override
    @candidate["services"]["rs_server_setup"]["image"] = PUBLISHED
    assert_raises(PrivateTrialCandidateConfiguration::Error) { validator.validate! }
  end

  def test_rejects_another_project_and_extra_services
    @candidate["name"] = "rs-private-000000000000"
    assert_raises(PrivateTrialCandidateConfiguration::Error) { validator.validate! }
    setup
    @candidate["services"]["unrelated"] = {"image" => "other"}
    assert_raises(PrivateTrialCandidateConfiguration::Error) { validator.validate! }
  end

  private

  def validator(candidate_image: CANDIDATE)
    PrivateTrialCandidateConfiguration.new(
      baseline: @baseline, candidate: @candidate, project: "rs-private-123456abcdef",
      published_image: PUBLISHED, candidate_image: candidate_image
    )
  end

end
