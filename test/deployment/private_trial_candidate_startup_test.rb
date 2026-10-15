require_relative "private_trial_candidate_restart_test"

class PrivateTrialCandidateStartupTest < Minitest::Test
  SCRIPT = File.expand_path("../../deploy/private/candidate_startup.sh", __dir__)
  FAKE_DOCKER = PrivateTrialCandidateRestartTest::FAKE_DOCKER
    .sub('"web" => mode != "stopped_web", "access" => mode != "stopped_web", "database" => true, "mailpit" => true',
      '"web" => !%w[cold partial].include?(mode), "access" => mode != "cold", "database" => mode != "cold", "mailpit" => mode != "cold"')
    .sub('when "compose"', <<~'RUBY')
      when "volume"
        output = "rs-private-8955233c3d65"
      when "compose"
    RUBY
    .sub('if ARGV.include?("/prepare.rb")', <<~'RUBY')
      if ARGV.include?("/inventory.rb")
        state["inventory_checks"] = state.fetch("inventory_checks", 0) + 1
        status = 12 if mode == "inventory_failure" || (mode == "inventory_changed" && state["inventory_checks"] > 1)
        File.write(File.join(directory, "inventory.json"), "{}") if ARGV.include?("prepare")
        output = "{}"
      elsif ARGV.include?("/fingerprint.rb")
        state["publication_checks"] = state.fetch("publication_checks", 0) + 1
        output = mode == "publication_changed" && state["publication_checks"] > 1 ? "changed" : "publications"
      elsif ARGV.include?("/prepare.rb")
    RUBY
    .sub('format, container = ARGV[2], ARGV.last', <<~'RUBY')
      if !ARGV.include?("--format")
        File.write(path, JSON.generate(state))
        puts "[]"
        exit
      end
      format, container = ARGV[2], ARGV.last
    RUBY
    .sub('%w[web access].include?(container)', '%w[web access database mailpit].include?(container)')
    .sub('if mode == "access_stop_failure"', 'if mode == "mailpit_start_failure" && ARGV.first == "start" && container == "mailpit"; status = 11; elsif mode == "access_stop_failure"')
    .sub('raise "Unexpected command" unless ARGV ==', <<~'RUBY')
      if ARGV.include?("-i")
        STDIN.read
        state["database_checks"] = state.fetch("database_checks", 0) + 1
        puts(mode == "database_changed" && state["database_checks"] > 1 ? "changed" : "database")
        File.write(path, JSON.generate(state))
        exit
      end
      raise "Unexpected command" unless ARGV ==
    RUBY

  def run_trial(mode, operation: "rehearse")
    Dir.mktmpdir("rs-startup-test.") do |directory|
      File.write(File.join(directory, "fake.rb"), FAKE_DOCKER)
      File.write(File.join(directory, "database_fingerprint.sql"), "synthetic")
      source = <<~SH
        set -eu
        umask 077
        . '#{PrivateTrialCandidateRestartTest::SCRIPT}'
        . '#{SCRIPT}'
        rs_operation='#{operation}'
        rs_work_directory='#{directory}'
        rs_trial_directory='#{directory}'
        rs_plan_directory='#{directory}'
        rs_operations_directory='#{directory}'
        rs_expected_project=rs-private-8955233c3d65
        rs_candidate_image='#{PrivateTrialCandidateRestartTest::IMAGE}'
        rs_source_revision='#{PrivateTrialCandidateRestartTest::REVISION}'
        rs_published_image=synthetic-reference
        rs_maintenance_started=no
        rs_completed=no
        docker() { '#{RbConfig.ruby}' '#{directory}/fake.rb' "$@"; }
        stat() { printf '1000:1000\\n'; }
        sleep() { :; }
        trap startup_finish EXIT
        startup_execute > "$rs_work_directory/output.log" 2> "$rs_work_directory/errors.log"
        rs_completed=yes
        printf 'SUCCESS\\n'
      SH
      output, errors, status = Open3.capture3({"RS_RESTART_TEST_DIRECTORY" => directory, "RS_RESTART_TEST_MODE" => mode}, "sh", "-c", source)
      commands = File.readlines(File.join(directory, "commands.jsonl")).map { |line| JSON.parse(line) }
      state = JSON.parse(File.read(File.join(directory, "state.json")))
      yield output, errors, status, state, commands
    end
  end

  def lifecycle(commands)
    commands.select { |args| %w[start stop].include?(args.first) }.map { |args| [args.first, args.last] }
  end

  def test_rehearsal_stops_and_starts_only_trial_services_in_dependency_order
    run_trial("success") do |output, errors, status, state, commands|
      assert status.success?, errors
      assert_equal "SUCCESS\n", output
      assert_equal [["stop", "access"], ["stop", "web"], ["stop", "mailpit"], ["stop", "database"],
        ["start", "database"], ["start", "mailpit"], ["start", "web"], ["start", "access"]], lifecycle(commands)
      assert_equal 2, state.fetch("database_checks")
      assert_equal 2, state.fetch("publication_checks")
      assert_operator commands.index(["exec", "web", "./bin/rails", "deployment:check"]), :<, commands.index(["start", "access"])
    end
  end

  def test_start_resumes_existing_cold_containers_but_does_not_rehearse_or_run_setup
    run_trial("cold", operation: "start") do |_output, errors, status, state, commands|
      assert status.success?, errors
      assert state.fetch("running").values.all?
      assert_equal %w[database mailpit web access], lifecycle(commands).select { |verb, _| verb == "start" }.map(&:last)
      refute state.key?("database_checks")
    end
  end

  def test_start_closes_access_before_resuming_a_partial_stack
    run_trial("partial", operation: "start") do |_output, errors, status, _state, commands|
      assert status.success?, errors
      assert_equal [["stop", "access"], ["stop", "web"], ["start", "web"], ["start", "access"]], lifecycle(commands)
    end
  end

  def test_check_and_prepare_do_not_change_service_lifecycle
    %w[check prepare].each do |operation|
      run_trial(operation == "check" ? "cold" : "success", operation: operation) do |_output, errors, status, _state, commands|
        assert status.success?, errors
        assert_empty lifecycle(commands)
        refute commands.any? { |args| args.first == "exec" }
      end
    end
  end

  def test_start_is_idempotent_when_every_service_is_ready
    run_trial("success", operation: "start") do |_output, errors, status, _state, commands|
      assert status.success?, errors
      assert_empty lifecycle(commands)
    end
  end

  def test_configuration_identity_and_inventory_errors_prevent_maintenance
    %w[configuration_failure wrong_project wrong_image setup_running inventory_failure].each do |mode|
      run_trial(mode) do |_output, errors, status, _state, commands|
        refute status.success?
        assert_includes errors, "before maintenance"
        assert_empty lifecycle(commands)
      end
    end
  end

  def test_startup_and_fingerprint_errors_keep_access_closed_without_exposing_logs
    %w[mailpit_start_failure web_start_failure web_unhealthy access_unhealthy deployment_failure inventory_changed database_changed publication_changed].each do |mode|
      run_trial(mode) do |output, errors, status, state, _commands|
        refute status.success?, mode
        assert_includes errors, "Access was kept stopped"
        refute state.fetch("running").fetch("access")
        refute_includes output + errors, "Synthetic-private-diagnostic"
      end
    end
  end

  def test_unknown_operations_and_non_root_callers_fail_before_docker
    [["0", "restart", 64], ["1000", "start", 1]].each do |uid, operation, expected|
      source = "set -eu\n. '#{SCRIPT}'\nid() { printf '#{uid}\\n'; }\nuname() { printf 'Linux\\n'; }\ncandidate_startup_main '#{operation}'"
      output, _errors, status = Open3.capture3("sh", "-c", source)
      assert_equal expected, status.exitstatus
      assert_empty output
    end
  end
end
