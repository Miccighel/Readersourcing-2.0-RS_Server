require "minitest/autorun"
require "tmpdir"
require "json"
require "open3"
require "rbconfig"

class PrivateTrialRecoveryRehearsalTest < Minitest::Test
  SCRIPT = File.expand_path("../../deploy/private/recovery_rehearsal.sh", __dir__)
  SOURCE = File.read(SCRIPT)
  FAKE = <<~'RUBY'
    require "json"
    root, mode = ENV.values_at("RS_RECOVERY_TEST_ROOT", "RS_RECOVERY_TEST_MODE")
    File.open("#{root}/commands.jsonl", "a") { |file| file.puts(JSON.generate(ARGV)) }
    project = "rs-recovery-0123456789ab"
    case ARGV.first
    when "ps"
      if ARGV.any? { |arg| arg.end_with?("service=database") }
        puts "source-database"
      elsif ARGV.any? { |arg| arg.end_with?("service=mailpit") }
        puts "source-mailpit"
      elsif ARGV.any? { |arg| arg.include?(project) }
        puts "collision" if mode == "existing_project"
      else
        puts %w[source-access source-database source-mailpit source-setup source-web]
      end
    when "inspect"
      format, id = ARGV[2], ARGV.last
      if format.include?("com.docker.compose.project")
        puts(mode == "wrong_target_project" ? "rs-private-8955233c3d65" : project)
      elsif format.include?("com.docker.compose.service")
        puts id.delete_prefix("target-")
      elsif format.include?(".Mounts")
        service = id.delete_prefix("target-")
        puts({"database" => "#{project}_database ", "rs_server_webapp" => "#{project}_publications ", "mailpit" => ""}.fetch(service))
      elsif format.include?("PortBindings")
        puts(mode == "published_target_port" ? '{"3000/tcp":[]}' : '{}')
      elsif format.include?(".State.Health")
        puts(mode == "web_unhealthy" ? 'true unhealthy' : 'true healthy')
      elsif format == "{{.Image}}"
        puts "sha256:#{'3' * 64}"
      else
        puts "#{id} stable-image true stable-start 0"
      end
    when "network"
      # No matching network.
    when "volume"
      if ARGV[1] == "inspect" && ARGV.include?("--format")
        puts project
      else
        exit(mode == "existing_volume" ? 0 : 1)
      end
    when "compose"
      # Installed Compose start has no --wait or --wait-timeout options.
      exit 16 if ARGV.include?("start") && (ARGV.include?("--wait") || ARGV.include?("--wait-timeout"))
      if ARGV.include?("create")
        # Compose 2.39 create accepts --no-build and --pull, but not --no-deps.
        exit 16 if ARGV.include?("--no-deps")
      elsif ARGV.include?("ps")
        puts "target-#{ARGV.last}"
      elsif ARGV.include?("up")
        raise "Unexpected source project" unless ARGV.include?(project)
      end
    when "run"
      if ARGV.include?("/definition/recovery_configuration.rb")
        Dir.mkdir("#{root}/recovery/runtime")
        %w[smtp.crt smtp.key smtp.auth ui.auth].each { |name| File.write("#{root}/recovery/runtime/#{name}", "synthetic") }
      elsif ARGV.include?("/fingerprint.rb")
        puts "publication-fingerprint"
      elsif ARGV.any? { |arg| arg.include?('result = {status: "recovery_rehearsal_passed"') }
        File.write("#{root}/report.json", '{"status":"recovery_rehearsal_passed"}')
      end
    when "exec"
      command = ARGV.last
      if command.include?("pg_restore")
        raise "Refusing source writes" unless ARGV.include?("target-database")
        exit 7 if mode == "restore_failure"
      elsif command.include?("psql")
        puts(mode == "fingerprint_mismatch" ? "wrong-database" : "database-fingerprint")
      elsif ARGV.include?("runner") && command == "-"
        raise "Probe stdin is missing" unless STDIN.read == "synthetic-probe"
        if mode == "probe_failure"
          warn "Synthetic-private-probe-diagnostic"
          exit 18
        end
      elsif ARGV.include?("cat") && command == "/tmp/recovery-probe.json"
        puts '{"status":"passed"}'
      end
    when "cp"
      warn "Error response from daemon: container rootfs is marked read-only"
      exit 19
    when "start"
      raise "Unexpected container start" unless ARGV == ["start", "target-rs_server_webapp"]
      exit 17 if mode == "web_start_failure"
    else
      raise "Unexpected Docker command"
    end
  RUBY

  def run_recovery(mode)
    Dir.mktmpdir("rs-recovery-shell-test.") do |root|
      File.write("#{root}/fake.rb", FAKE)
      Dir.mkdir("#{root}/backup")
      Dir.mkdir("#{root}/operations")
      %w[database.dump publications.tar.gz].each { |name| File.write("#{root}/backup/#{name}", "synthetic") }
      File.write("#{root}/backup/database-fingerprint.jsonl", "database-fingerprint\n")
      File.write("#{root}/backup/publication-fingerprint.json", "publication-fingerprint\n")
      File.write("#{root}/operations/database_fingerprint.sql", "synthetic-query")
      File.write("#{root}/operations/recovery_probe.rb", "synthetic-probe")
      script = <<~SH
        set -eu
        . '#{SCRIPT}'
        rs_work_directory='#{root}'
        rs_backup_directory='#{root}/backup'
        rs_operations_directory='#{root}/operations'
        rs_trial_directory='#{root}/source'
        rs_expected_project=rs-private-8955233c3d65
        rs_published_image=synthetic-published
        rs_backup_image=synthetic-backup
        rs_candidate_image='sha256:#{'3' * 64}'
        rs_started_seconds=$(date +%s)
        rs_target_created=no
        rs_completed=no
        docker() { '#{RbConfig.ruby}' '#{root}/fake.rb' "$@"; }
        openssl() { printf '0123456789ab\\n'; }
        stat() { printf '1000:1000\\n'; }
        chown() { :; }
        recovery_source_ids > "$rs_work_directory/source-ids.txt"
        recovery_source_state > "$rs_work_directory/source-before.txt"
        trap recovery_finish EXIT
        recovery_execute > "$rs_work_directory/output.log" 2> "$rs_work_directory/errors.log"
      SH
      output, errors, status = Open3.capture3({"RS_RECOVERY_TEST_ROOT" => root, "RS_RECOVERY_TEST_MODE" => mode}, "sh", "-c", script)
      commands = File.readlines("#{root}/commands.jsonl").map { |line| JSON.parse(line) }
      yield output, errors, status, commands
    end
  end

  def test_success_restores_only_fresh_target_and_stops_it_after_checks
    run_recovery("success") do |output, errors, status, commands|
      assert status.success?, errors
      assert_includes output, "recovery_rehearsal_passed"
      restore = commands.find { |args| args.first == "exec" && args.last.include?("pg_restore") }
      assert_includes restore, "target-database"
      creation = commands.find { |args| args.first == "compose" && args.include?("create") }
      refute_nil creation
      refute_includes creation, "--no-deps"
      assert_includes creation, "--no-build"
      assert_equal "never", creation[creation.index("--pull") + 1]
      stops = commands.select { |args| args.first == "compose" && args.include?("stop") }
      assert_equal 1, stops.length
      assert_includes stops.first, "rs-recovery-0123456789ab"
      refute commands.any? { |args| %w[stop restart rm].include?(args.first) }
      assert_equal [["start", "target-rs_server_webapp"]], commands.select { |args| args.first == "start" }
      refute commands.any? { |args| args.first == "cp" }
      probe = commands.find { |args| args.first == "exec" && args.include?("runner") }
      assert_includes probe, "-i"
      assert_equal "-", probe.last
    end
  end

  def test_existing_resources_abort_before_target_creation_or_restore
    %w[existing_project existing_volume].each do |mode|
      run_recovery(mode) do |_output, errors, status, commands|
        refute status.success?
        assert_includes errors, "Recovery not confirmed"
        refute commands.any? { |args| args.include?("up") || args.include?("pg_restore") || args.include?("stop") }
      end
    end
  end

  def test_restore_or_fingerprint_failures_stop_only_the_recovery_project
    %w[restore_failure fingerprint_mismatch wrong_target_project published_target_port web_unhealthy web_start_failure probe_failure].each do |mode|
      run_recovery(mode) do |output, errors, status, commands|
        refute status.success?
        assert_includes errors, "Recovery not confirmed"
        assert_includes errors, "Recovery stopped during stage:"
        stops = commands.select { |args| args.first == "compose" && args.include?("stop") }
        assert_equal 1, stops.length
        assert_includes stops.first, "rs-recovery-0123456789ab"
        refute commands.any? { |args| args.first == "exec" && args[1].start_with?("source-") }
        refute_includes output + errors, "Synthetic-private-probe-diagnostic"
      end
    end
  end

  def test_no_global_cleanup_migration_build_or_image_download_is_performed
    refute_match(/\b(?:prune|db:migrate|db:prepare)\b/, SOURCE)
    refute_match(/docker (?:pull|build|push|rm|restart)|recovery_compose (?:down|pull|build)/, SOURCE)
    assert_includes SOURCE, "--network none"
    assert_includes SOURCE, 'source=$rs_backup_directory,target=/backup,readonly'
    assert_includes SOURCE, "flock -n 9"
  end
end
