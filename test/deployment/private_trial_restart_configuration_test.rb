require "minitest/autorun"
require_relative "../../deploy/private/restart_configuration"

class PrivateTrialRestartConfigurationTest < Minitest::Test
  PUBLISHED = "example.test/rs_server@sha256:#{'1' * 64}"
  CANDIDATE = "sha256:#{'2' * 64}"

  def setup
    @original = {"name" => "rs-private-123456abcdef", "services" => {
      "rs_server_setup" => {"image" => PUBLISHED},
      "rs_server_webapp" => {"image" => PUBLISHED, "environment" => {"SECRET_PROD_KEY" => "test-only-secret"}, "read_only" => true},
      "database" => {"image" => "postgres:17"}, "mailpit" => {"image" => "mailpit:test"},
      "access" => {"ports" => [{"host_ip" => "127.0.0.1"}]}
    }, "networks" => {"default" => {"internal" => true}}}
    @effective = JSON.parse(JSON.generate(@original))
    %w[rs_server_setup rs_server_webapp].each { |name| @effective["services"][name]["image"] = CANDIDATE }
    @activated = JSON.parse(JSON.generate(@effective))
  end

  def validator
    PrivateTrialRestartConfiguration.new(original: @original, effective: @effective, activated: @activated,
      project: "rs-private-123456abcdef", published_image: PUBLISHED, candidate_image: CANDIDATE)
  end

  def test_accepts_only_the_activated_configuration_without_disclosing_environment
    result = validator.validate!
    assert result.fetch("configuration_matches_activation")
    assert_equal CANDIDATE, result.fetch("candidate_image")
    refute_includes JSON.generate(result), "test-only-secret"
  end

  def test_rejects_a_changed_key_even_when_original_and_effective_configurations_agree
    @original["services"]["rs_server_webapp"]["environment"]["SECRET_PROD_KEY"] = "another-test-secret"
    @effective["services"]["rs_server_webapp"]["environment"]["SECRET_PROD_KEY"] = "another-test-secret"
    error = assert_raises(PrivateTrialRestartConfiguration::Error) { validator.validate! }
    refute_includes error.message, "test-secret"
  end

  def test_rejects_a_changed_network_port_or_runtime_restriction
    [-> { @effective["networks"]["default"]["internal"] = false },
      -> { @effective["services"]["access"]["ports"][0]["host_ip"] = "0.0.0.0" },
      -> { @effective["services"]["rs_server_webapp"]["read_only"] = false }].each do |change|
      setup
      change.call
      assert_raises(PrivateTrialRestartConfiguration::Error) { validator.validate! }
    end
  end

  def test_rejects_different_application_images_or_project
    @effective["services"]["rs_server_setup"]["image"] = PUBLISHED
    assert_raises(PrivateTrialRestartConfiguration::Error) { validator.validate! }
    setup
    @effective["name"] = "rs-private-000000000000"
    assert_raises(PrivateTrialRestartConfiguration::Error) { validator.validate! }
  end

  def test_rejects_malformed_configuration_without_printing_values
    @effective = {"private" => "test-only-secret"}
    error = assert_raises(PrivateTrialRestartConfiguration::Error) { validator.validate! }
    refute_includes error.message, "test-only-secret"
  end
end
