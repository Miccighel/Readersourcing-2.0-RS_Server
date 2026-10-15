require "minitest/autorun"
require "tmpdir"
require "open3"

class DeploymentLayoutMigrationTest < Minitest::Test
  SCRIPT = File.expand_path("../../deploy/private/deployment_layout_migration.sh", __dir__)

  def run_migration(mode)
    Dir.mktmpdir("rs-layout-migration-test.") do |directory|
      File.write(File.join(directory, "candidate.json"), "synthetic")
      File.write(File.join(directory, "source-candidate.json"), "synthetic")
      File.write(File.join(directory, "rs-server"), "exit #{mode == 'command_failure' ? 22 : 0}\n")
      script = <<~SH
        set -eu
        . '#{SCRIPT}'
        rs_work_directory='#{directory}'
        rs_source_activation='#{directory}'
        rs_prepared_plan='#{directory}'
        rs_installation_directory='#{directory}'
        rs_stage=preflight
        rs_completed=no
        rs_maintenance_started=no
        rs_mailbox_paused=no
        mode='#{mode}'
        event() { printf '%s\\n' "$*" >> '#{directory}/events'; }
        layout_install() { event install; test "$mode" != install_failure; }
        layout_backup() {
          event backup
          test "$mode" != backup_failure
          printf database > "$rs_work_directory/before-database.jsonl"
          printf publications > "$rs_work_directory/before-publications.json"
        }
        layout_compose() { event compose "$@"; case "$1" in config) printf '{}' ;; esac; }
        layout_inspect() { event inspect "$1"; }
        layout_helper() { event helper "$1"; test "$mode:$1" != inventory_failure:replacement; }
        layout_resolve() { rs_access_container=access; rs_web_container=web; rs_mailpit_container=mailpit; rs_database_container=database; rs_setup_container=setup; }
        docker() { event docker "$@"; case "$1" in inspect) printf 'retained\\n' ;; esac; }
        candidate_wait_for_health() { event health "$1"; test "$mode:$1" != health_failure:web; }
        startup_database_fingerprint() { event database-fingerprint; test "$mode" != data_change && printf database > "$1" || printf changed > "$1"; }
        startup_publication_fingerprint() { event publication-fingerprint; printf publications > "$1"; }
        flock() { event flock "$@"; }
        layout_resolve
        printf 'retained\\n' > "$rs_work_directory/retained-before.txt"
        trap layout_finish EXIT
        layout_activate > "$rs_work_directory/output" 2> "$rs_work_directory/errors"
        rs_completed=yes
        printf 'SUCCESS\\n'
      SH
      output, errors, status = Open3.capture3("sh", "-c", script)
      events = File.readlines(File.join(directory, "events"), chomp: true)
      yield output, errors, status, events
    end
  end

  def test_activation_backs_up_then_checks_stopped_replacements_before_starting_them
    run_migration("success") do |output, errors, status, events|
      assert status.success?, errors
      assert_equal "SUCCESS\n", output
      creation = "compose up --no-start --no-deps --no-build --pull never --force-recreate mailpit rs_server_webapp access"
      assert_includes events, creation
      assert_operator events.index("backup"), :<, events.index(creation)
      assert_operator events.index("helper replacement"), :<, events.index("docker start mailpit")
      assert_operator events.index("helper freeze"), :<, events.index("docker start web")
      assert_operator events.index("database-fingerprint"), :<, events.index("docker start access")
      assert_operator events.index("publication-fingerprint"), :<, events.index("docker start access")
      refute events.any? { |event| event.match?(/docker (start|stop).* (database|setup)\z/) }
      refute events.any? { |event| event.include?("db:migrate") || event.include?("--pull always") || event.include?("compose down") }
    end
  end

  def test_installation_failure_does_not_interrupt_any_service
    run_migration("install_failure") do |_output, errors, status, events|
      refute status.success?
      assert_includes errors, "before maintenance"
      refute events.any? { |event| event.start_with?("docker stop", "docker start", "compose up") }
    end
  end

  def test_backup_or_inventory_failure_keeps_access_and_writer_stopped_without_starting_replacements
    %w[backup_failure inventory_failure].each do |mode|
      run_migration(mode) do |_output, errors, status, events|
        refute status.success?
        assert_includes errors, "kept stopped"
        assert_includes events, "docker stop -t 30 access web"
        refute events.any? { |event| event.start_with?("docker start") }
        refute events.any? { |event| event.match?(/docker stop.* (database|setup)\z/) }
      end
    end
  end

  def test_application_or_data_check_failure_does_not_reopen_access
    %w[health_failure data_change].each do |mode|
      run_migration(mode) do |_output, _errors, status, events|
        refute status.success?
        refute_includes events, "docker start access"
        assert_includes events, "docker stop -t 30 access web"
        refute events.any? { |event| event.include?("pg_restore") }
      end
    end
  end

  def test_installed_command_failure_closes_access_again_without_restoring_or_removing_data
    run_migration("command_failure") do |_output, _errors, status, events|
      refute status.success?
      assert_includes events, "docker start access"
      assert_equal "docker stop -t 30 access web", events.last
      refute events.any? { |event| event.match?(/docker (rm|volume|system)/) }
    end
  end
end
