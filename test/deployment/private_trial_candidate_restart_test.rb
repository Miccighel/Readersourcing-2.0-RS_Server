require "minitest/autorun"
require "tmpdir"
require "open3"
require "json"
require "rbconfig"

class PrivateTrialCandidateRestartTest < Minitest::Test
  SCRIPT = File.expand_path("../../deploy/private/candidate_restart.sh", __dir__)
  SOURCE = File.read(SCRIPT)
  IMAGE = "sha256:e52ed41e7a62a5447923ec02f0bef0b61f285232afb58c7bdfc80020381b5ad5"
  REVISION = "d3f37eabfd0ddcb55ccd049af55be80eda8c5a8b"
  FAKE_DOCKER = <<~'RUBY'
    require "json"
    directory, mode = ENV.fetch("RS_RESTART_TEST_DIRECTORY"), ENV.fetch("RS_RESTART_TEST_MODE")
    path = File.join(directory, "state.json")
    state = File.exist?(path) ? JSON.parse(File.read(path)) : {
      "running" => {"web" => mode != "stopped_web", "access" => mode != "stopped_web", "database" => true, "mailpit" => true},
      "starts" => 0, "configuration_checks" => 0
    }
    File.open(File.join(directory, "commands.jsonl"), "a") { |file| file.puts(JSON.generate(ARGV)) }
    output, status = nil, 0
    case ARGV.first
    when "compose"
      if ARGV.include?("ps")
        service = ARGV.last
        output = service == "rs_server_webapp" ? "web" : service
        output = "another-web" if service == "rs_server_webapp" && mode == "container_replaced" && state["starts"] > 0
      elsif ARGV.include?("config")
        output = "{}"
      else
        raise "Unexpected Compose operation"
      end
    when "run"
      if ARGV.include?("/prepare.rb")
        output = "rs-private-8955233c3d65"
      elsif ARGV.include?("/restart_configuration.rb")
        state["configuration_checks"] += 1
        status = 7 if mode == "configuration_failure" || (mode == "configuration_changed" && state["configuration_checks"] > 1)
        output = JSON.generate("status" => "passed") if status == 0
      else
        raise "Unexpected helper container"
      end
    when "inspect"
      format, container = ARGV[2], ARGV.last
      output = if format.include?("com.docker.compose.project")
        mode == "wrong_project" ? "another-project" : "rs-private-8955233c3d65"
      elsif format.include?("com.docker.compose.service")
        container == "web" ? "rs_server_webapp" : container
      elsif format.include?("org.opencontainers.image.revision")
        "d3f37eabfd0ddcb55ccd049af55be80eda8c5a8b"
      elsif format == "{{.Image}}"
        mode == "wrong_image" ? "sha256:other" : "sha256:e52ed41e7a62a5447923ec02f0bef0b61f285232afb58c7bdfc80020381b5ad5"
      elsif format == "{{.State.Running}} {{.State.ExitCode}}"
        mode == "setup_running" ? "true 0" : "false 0"
      elsif format == "{{.State.Running}}"
        mode == "mailpit_stopped" && container == "mailpit" ? "false" : state["running"].fetch(container, false).to_s
      elsif format.include?(".State.Health")
        bad = (mode == "database_unhealthy" && container == "database") ||
          (mode == "web_unhealthy" && container == "web" && state["starts"] > 0) ||
          (mode == "access_unhealthy" && container == "access" && state["starts"] > 0)
        state["running"].fetch(container, false) ? (bad ? "true unhealthy" : "true healthy") : "false unhealthy"
      else
        raise "Unexpected inspection"
      end
    when "start", "stop"
      container = ARGV.last
      raise "Unexpected service lifecycle change" unless %w[web access].include?(container)
      if mode == "access_stop_failure" && ARGV.first == "stop" && container == "access"
        status = 8
      elsif mode == "web_start_failure" && ARGV.first == "start" && container == "web"
        status = 9
      else
        state["running"][container] = ARGV.first == "start"
        state["starts"] += 1 if ARGV.first == "start"
      end
    when "exec"
      raise "Unexpected command" unless ARGV == ["exec", "web", "./bin/rails", "deployment:check"]
      if mode == "deployment_failure"
        warn "Synthetic-private-diagnostic"
        status = 10
      end
    else
      raise "Unexpected Docker operation"
    end
    File.write(path, JSON.generate(state))
    puts output if output
    exit status
  RUBY

  def run_trial(mode, operation: "restart")
    Dir.mktmpdir("rs-restart-test.") do |directory|
      fake = File.join(directory, "fake.rb")
      File.write(fake, FAKE_DOCKER)
      source = <<~SH
        set -eu
        . '#{SCRIPT}'
        rs_operation='#{operation}'
        rs_work_directory='#{directory}'
        rs_trial_directory='#{directory}'
        rs_plan_directory='#{directory}'
        rs_operations_directory='#{directory}'
        rs_expected_project=rs-private-8955233c3d65
        rs_candidate_image='#{IMAGE}'
        rs_source_revision='#{REVISION}'
        rs_published_image=synthetic-reference
        rs_maintenance_started=no
        rs_completed=no
        docker() { '#{RbConfig.ruby}' '#{fake}' "$@"; }
        stat() { printf '1000:1000\\n'; }
        sleep() { :; }
        trap candidate_restart_finish EXIT
        candidate_restart_execute > "$rs_work_directory/output.log" 2> "$rs_work_directory/errors.log"
        rs_completed=yes
        printf 'SUCCESS\\n'
      SH
      output, errors, status = Open3.capture3({"RS_RESTART_TEST_DIRECTORY" => directory, "RS_RESTART_TEST_MODE" => mode}, "sh", "-c", source)
      state = JSON.parse(File.read(File.join(directory, "state.json")))
      commands = File.readlines(File.join(directory, "commands.jsonl")).map { |line| JSON.parse(line) }
      yield output, errors, status, state, commands
    end
  end

  def test_check_does_not_interrupt_services_or_execute_application_commands
    run_trial("success", operation: "check") do |output, errors, status, _state, commands|
      assert status.success?, errors
      assert_equal "SUCCESS\n", output
      refute commands.any? { |args| %w[start stop exec].include?(args.first) }
    end
  end

  def test_restart_reuses_only_web_and_access_and_checks_deployment_before_reopening
    run_trial("success") do |output, errors, status, state, commands|
      assert status.success?, errors
      assert_equal "SUCCESS\n", output
      assert state["running"].values.all?
      lifecycle = commands.select { |args| %w[start stop].include?(args.first) }.map { |args| [args.first, args.last] }
      assert_equal [["stop", "access"], ["stop", "web"], ["start", "web"], ["start", "access"]], lifecycle
      deployment = commands.index(["exec", "web", "./bin/rails", "deployment:check"])
      assert_operator deployment, :<, commands.index(["start", "access"])
    end
  end

  def test_wrong_image_project_or_configuration_and_unhealthy_database_fail_before_maintenance
    %w[wrong_image wrong_project configuration_failure database_unhealthy mailpit_stopped setup_running].each do |mode|
      run_trial(mode) do |_output, errors, status, _state, commands|
        refute status.success?
        assert_includes errors, "before maintenance"
        refute commands.any? { |args| %w[start stop].include?(args.first) }
      end
    end
  end

  def test_restart_can_resume_the_same_stopped_application_and_access_containers
    run_trial("stopped_web") do |_output, errors, status, state, _commands|
      assert status.success?, errors
      assert state["running"].fetch("web")
      assert state["running"].fetch("access")
    end
  end

  def test_check_does_not_start_stopped_application_containers
    run_trial("stopped_web", operation: "check") do |_output, _errors, status, state, commands|
      refute status.success?
      refute state["running"].fetch("access")
      refute commands.any? { |args| %w[start stop].include?(args.first) }
    end
  end

  def test_restart_failures_keep_access_stopped_and_do_not_disclose_private_diagnostics
    %w[web_start_failure web_unhealthy deployment_failure configuration_changed container_replaced access_unhealthy].each do |mode|
      run_trial(mode) do |output, errors, status, state, _commands|
        refute status.success?
        assert_includes errors, "Access was kept stopped"
        refute state["running"].fetch("access")
        refute_includes output + errors, "Synthetic-private-diagnostic"
      end
    end
  end

  def test_failure_to_stop_access_is_reported_without_claiming_it_is_stopped
    run_trial("access_stop_failure") do |_output, errors, status, state, commands|
      refute status.success?
      assert_includes errors, "access could not be stopped automatically"
      refute_includes errors, "Access was kept stopped"
      assert state["running"].fetch("access")
      refute commands.any? { |args| args.first == "stop" && args.last == "web" }
    end
  end

  def test_helpers_are_isolated_and_the_script_never_creates_or_selects_another_image
    assert_includes SOURCE, "--pull never --runtime runc --network none --read-only --cap-drop ALL"
    assert_includes SOURCE, "configuration_matches_activation"
    assert_includes SOURCE, "flock -n 9"
    refute_match(/\b(?:pg_restore|pg_dump|db:migrate|db:prepare|prune)\b/, SOURCE)
    refute_match(/docker (?:pull|build|load|tag|push|rm|restart)|candidate_compose (?:up|down|pull|run)/, SOURCE)
    assert SOURCE.lines.select { |line| line.include?("--mount") }.all? { |line| line.include?(",readonly") }
  end

  def test_main_rejects_unknown_operations_and_non_root_callers_before_docker
    [["0", "recreate", 64], ["1000", "restart", 1]].each do |uid, operation, code|
      source = "set -eu\n. '#{SCRIPT}'\nid() { printf '#{uid}\\n'; }\nuname() { printf 'Linux\\n'; }\ndocker() { echo UNEXPECTED; }\ncandidate_restart_main '#{operation}'"
      output, _errors, status = Open3.capture3("sh", "-c", source)
      assert_equal code, status.exitstatus
      assert_empty output
    end
  end
end
