require_relative "private_trial_candidate_startup_test"

class DeploymentOperationsTest < Minitest::Test
  SCRIPT = File.expand_path("../../deploy/private/deployment_operations.sh", __dir__)
  FAKE_DOCKER = PrivateTrialCandidateStartupTest::FAKE_DOCKER
    .sub('when "volume"', <<~'RUBY')
      when "ps"
        output = ARGV.include?("label=com.docker.compose.service=rs_server_setup") ? "rs_server_setup" : "web\naccess\ndatabase\nmailpit\nrs_server_setup"
      when "volume"
    RUBY
    .sub('if ARGV.include?("/inventory.rb")', <<~'RUBY')
      if ARGV.include?("/definition/deployment_layout_files.rb")
        output = "{}"
        status = 13 if mode == "configuration_failure"
      elsif ARGV.include?("/inventory.rb") || ARGV.include?("/definition/deployment_startup_inventory.rb")
    RUBY

  def run_operation(mode, operation)
    Dir.mktmpdir("rs-operations-test.") do |directory|
      File.write(File.join(directory, "fake.rb"), FAKE_DOCKER)
      shell = <<~SH
        set -eu
        . '#{PrivateTrialCandidateRestartTest::SCRIPT}'
        . '#{PrivateTrialCandidateStartupTest::SCRIPT}'
        . '#{SCRIPT}'
        rs_work_directory='#{directory}'
        rs_trial_directory='#{directory}'
        rs_plan_directory='#{directory}'
        rs_operations_directory='#{directory}'
        rs_expected_project=rs-private-8955233c3d65
        rs_candidate_image='#{PrivateTrialCandidateRestartTest::IMAGE}'
        rs_source_revision='#{PrivateTrialCandidateRestartTest::REVISION}'
        rs_operation='#{operation}'
        rs_maintenance_started=no
        rs_completed=no
        docker() { '#{RbConfig.ruby}' '#{directory}/fake.rb' "$@"; }
        sleep() { :; }
        trap startup_finish EXIT
        deployment_execute > "$rs_work_directory/output" 2> "$rs_work_directory/errors"
        rs_completed=yes
      SH
      output, errors, status = Open3.capture3({"RS_RESTART_TEST_DIRECTORY" => directory, "RS_RESTART_TEST_MODE" => mode}, "sh", "-c", shell)
      commands = File.readlines(File.join(directory, "commands.jsonl")).map { |line| JSON.parse(line) }
      yield output, errors, status, commands
    end
  end

  def test_check_uses_only_final_configuration_and_does_not_change_service_lifecycle
    run_operation("success", "check") do |_output, errors, status, commands|
      assert status.success?, errors
      refute commands.any? { |args| %w[start stop].include?(args.first) }
      assert commands.any? { |args| args.include?("/definition/deployment_layout_files.rb") }
      assert commands.any? { |args| args.include?("/definition/deployment_startup_inventory.rb") && args.include?("/plan/definition.json") }
      refute commands.any? { |args| args.include?("/inventory.rb") }
      refute commands.any? { |args| args.include?("/prepare.rb") || args.include?("candidate-images.yml") }
      refute commands.any? { |args| args.first == "compose" && args.last == "rs_server_setup" }
    end
  end

  def test_restart_reuses_existing_application_and_access_containers_only
    run_operation("success", "restart") do |_output, errors, status, commands|
      assert status.success?, errors
      lifecycle = commands.select { |args| %w[start stop].include?(args.first) }.map { |args| [args.first, args.last] }
      assert_equal [["stop", "access"], ["stop", "web"], ["start", "web"], ["start", "access"]], lifecycle
      refute commands.any? { |args| args.include?("up") || args.include?("db:migrate") }
    end
  end

  def test_start_can_resume_existing_stopped_services_in_order_without_running_setup
    run_operation("cold", "start") do |_output, errors, status, commands|
      assert status.success?, errors
      starts = commands.select { |args| args.first == "start" }.map(&:last)
      assert_equal %w[database mailpit web access], starts
      refute commands.any? { |args| args.include?("up") || args.include?("db:migrate") }
    end
  end

  def test_failed_configuration_or_inventory_check_stops_before_maintenance
    %w[configuration_failure inventory_failure].each do |mode|
      run_operation(mode, "restart") do |_output, errors, status, commands|
        refute status.success?
        assert_includes errors, "before maintenance"
        refute commands.any? { |args| %w[start stop].include?(args.first) }
      end
    end
  end
end
