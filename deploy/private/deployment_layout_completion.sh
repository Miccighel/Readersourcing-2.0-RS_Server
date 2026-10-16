# Completes the recorded installed-command interruption. Configuration and frozen inventory stay untouched.

layout_completion_package_check() {
  printf '%s  %s\n' "$rs_baseline_manifest" "$rs_baseline_package/RESUME-SHA256SUMS" | sha256sum --check --status
  (cd "$rs_baseline_package" && sha256sum --check --status RESUME-SHA256SUMS)
  rs_installed_files='candidate_restart.sh candidate_startup.sh startup_inventory.rb publication_fingerprint.rb database_fingerprint.sql deployment_operations.sh deployment_layout_configuration.rb deployment_layout_inventory.rb deployment_layout_files.rb recovery_rehearsal.sh recovery_configuration.rb recovery_probe.rb candidate_configuration.rb deployment_recovery.sh deployment_recovery_configuration.rb OPERATIONS.md rs-server'
  (cd "$rs_baseline_package" && sha256sum $rs_installed_files) > "$rs_work_directory/expected-operations.sha256"
  cmp -s "$rs_work_directory/expected-operations.sha256" "$rs_checkpoint_directory/operations-after.sha256"
  cmp -s "$rs_work_directory/expected-operations.sha256" "$rs_installation_directory/OPERATIONS-SHA256SUMS"
  for rs_name in $rs_installed_files OPERATIONS-SHA256SUMS; do
    test -f "$rs_installation_directory/$rs_name"
    test ! -L "$rs_installation_directory/$rs_name"
    rs_expected_mode=644
    test "$rs_name" != rs-server || rs_expected_mode=755
    test "$(stat -c '%u:%g:%a' "$rs_installation_directory/$rs_name")" = "0:0:$rs_expected_mode"
    if [ "$rs_name" != OPERATIONS-SHA256SUMS ]; then
      cmp -s "$rs_baseline_package/$rs_name" "$rs_installation_directory/$rs_name"
      if [ "$rs_name" != deployment_operations.sh ]; then
        cmp -s "$rs_baseline_package/$rs_name" "$rs_package/$rs_name"
      fi
    fi
  done
  test ! -e "$rs_installation_directory/deployment_startup_inventory.rb"
  test ! -L "$rs_installation_directory/deployment_startup_inventory.rb"
  (cd "$rs_installation_directory" && sha256sum --check --status OPERATIONS-SHA256SUMS)
}

layout_completion_preflight() {
  for rs_directory in "$rs_checkpoint_directory" "$rs_prepared_plan" "$rs_configuration_directory" "$rs_active_directory"; do
    test -d "$rs_directory"
    test ! -L "$rs_directory"
    test "$(stat -c '%u:%a' "$rs_directory")" = 0:700
  done
  test -d "$rs_installation_directory"
  test ! -L "$rs_installation_directory"
  test "$(stat -c '%u:%a' "$rs_installation_directory")" = 0:755
  for rs_file in "$rs_old_lock" "$rs_state_directory/deployment.lock" "$rs_active_directory/startup-inventory.json" "$rs_active_directory/backup-directory"; do
    test -f "$rs_file"
    test ! -L "$rs_file"
    test "$(stat -c '%u:%a' "$rs_file")" = 0:600
  done
  test "$(stat -c '%d:%i' "$rs_old_lock")" = "$(stat -c '%d:%i' "$rs_state_directory/deployment.lock")"
  test "$(docker image inspect --format '{{.Id}}' "$rs_candidate_image")" = "$rs_candidate_image"
  test "$(docker image inspect --format '{{index .Config.Labels "org.opencontainers.image.revision"}}' "$rs_candidate_image")" = "$rs_source_revision"
  layout_completion_package_check
  for rs_name in before-database.jsonl after-database.jsonl before-publications.json after-publications.json retained-before.txt retained-after.txt replacement-containers.json; do
    test -f "$rs_checkpoint_directory/$rs_name"
    test ! -L "$rs_checkpoint_directory/$rs_name"
  done
  for rs_name in before-database.jsonl before-publications.json retained-before.txt; do
    cp -p "$rs_checkpoint_directory/$rs_name" "$rs_work_directory/$rs_name"
  done
  cmp -s "$rs_work_directory/before-database.jsonl" "$rs_checkpoint_directory/after-database.jsonl"
  cmp -s "$rs_work_directory/before-publications.json" "$rs_checkpoint_directory/after-publications.json"
  cmp -s "$rs_work_directory/retained-before.txt" "$rs_checkpoint_directory/retained-after.txt"
  cp -p "$rs_active_directory/startup-inventory.json" "$rs_work_directory/retained-inventory.json"
  layout_inspect replacement
  layout_compose config --format json > "$rs_work_directory/effective.json"
  layout_resume_helper deployment_layout_completion.rb
  layout_resolve
  candidate_require_health "$rs_database_container"
  docker inspect --format '{{.Id}} {{.Image}} {{.State.Running}} {{.State.StartedAt}} {{.RestartCount}}' \
    "$rs_database_container" "$rs_setup_container" > "$rs_work_directory/retained-current.txt"
  cmp -s "$rs_work_directory/retained-before.txt" "$rs_work_directory/retained-current.txt"
  docker inspect --format '{{.Id}} {{.Image}} {{.State.Running}} {{.State.StartedAt}} {{.RestartCount}}' \
    "$rs_database_container" "$rs_setup_container" "$rs_mailpit_container" > "$rs_work_directory/kept-before.txt"
  startup_database_fingerprint "$rs_work_directory/current-database.jsonl"
  startup_publication_fingerprint "$rs_work_directory/current-publications.json"
  cmp -s "$rs_work_directory/before-database.jsonl" "$rs_work_directory/current-database.jsonl"
  cmp -s "$rs_work_directory/before-publications.json" "$rs_work_directory/current-publications.json"
  IFS= read -r rs_backup_directory < "$rs_active_directory/backup-directory"
  printf '%s\n' "$rs_backup_directory" | LC_ALL=C grep -Eq "^$rs_state_directory/backups/layout\.[A-Za-z0-9]{6}$"
  test -d "$rs_backup_directory"
  test ! -L "$rs_backup_directory"
  test "$(stat -c '%u:%a' "$rs_backup_directory")" = 0:700
  cmp -s "$rs_work_directory/before-database.jsonl" "$rs_backup_directory/database-fingerprint.jsonl"
  cmp -s "$rs_work_directory/before-publications.json" "$rs_backup_directory/publication-fingerprint.json"
  layout_helper recovery-preflight
}

layout_completion_patch() {
  layout_completion_package_check
  for rs_name in .operations-completion .inventory-completion .manifest-completion; do
    test ! -e "$rs_installation_directory/$rs_name"
    test ! -L "$rs_installation_directory/$rs_name"
  done
  cp -p "$rs_installation_directory/deployment_operations.sh" "$rs_work_directory/operations-before.sh"
  cp -p "$rs_installation_directory/OPERATIONS-SHA256SUMS" "$rs_work_directory/operations-before.sha256"
  install -o root -g root -m 644 "$rs_package/deployment_startup_inventory.rb" "$rs_installation_directory/.inventory-completion"
  install -o root -g root -m 644 "$rs_package/deployment_operations.sh" "$rs_installation_directory/.operations-completion"
  mv "$rs_installation_directory/.inventory-completion" "$rs_installation_directory/deployment_startup_inventory.rb"
  mv "$rs_installation_directory/.operations-completion" "$rs_installation_directory/deployment_operations.sh"
  (cd "$rs_installation_directory" && sha256sum $rs_installed_files deployment_startup_inventory.rb) > "$rs_work_directory/operations-after.sha256"
  install -o root -g root -m 644 "$rs_work_directory/operations-after.sha256" "$rs_installation_directory/.manifest-completion"
  mv "$rs_installation_directory/.manifest-completion" "$rs_installation_directory/OPERATIONS-SHA256SUMS"
  (cd "$rs_installation_directory" && sha256sum --check --status OPERATIONS-SHA256SUMS)
}

layout_completion_execute() {
  rs_stage=completion_checkpoint_preflight
  layout_completion_preflight
  rs_stage=install_default_oom_checker
  layout_completion_patch
  rs_preserve_mailpit_lifecycle=yes
  rs_maintenance_started=yes
  layout_complete_activation
  rs_stage=completion_preservation_checks
  docker inspect --format '{{.Id}} {{.Image}} {{.State.Running}} {{.State.StartedAt}} {{.RestartCount}}' \
    "$rs_database_container" "$rs_setup_container" "$rs_mailpit_container" > "$rs_work_directory/kept-after.txt"
  cmp -s "$rs_work_directory/kept-before.txt" "$rs_work_directory/kept-after.txt"
  cmp -s "$rs_work_directory/retained-inventory.json" "$rs_active_directory/startup-inventory.json"
}

deployment_layout_completion_main() {
  test "$(id -u)" = 0
  test "$(uname -s)" = Linux
  test "$#" -eq 1
  test "$1" = --confirm-guarded-completion
  umask 077
  test -d "$rs_state_directory/diagnostics"
  test ! -L "$rs_state_directory/diagnostics"
  test "$(stat -c '%u:%a' "$rs_state_directory/diagnostics")" = 0:700
  test -f "$rs_old_lock"
  test ! -L "$rs_old_lock"
  test "$(stat -c '%u:%a' "$rs_old_lock")" = 0:600
  exec 9<> "$rs_old_lock"
  flock -n 9
  rs_work_directory=$(mktemp -d "$rs_state_directory/diagnostics/layout-completion.XXXXXX")
  rs_stage=checkpoint_checks
  rs_completed=no
  rs_maintenance_started=no
  rs_mailbox_paused=no
  trap layout_finish EXIT
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM
  layout_completion_execute > "$rs_work_directory/output.log" 2> "$rs_work_directory/errors.log"
  rs_completed=yes
  printf '{"status":"deployment_layout_completed","image_id":"%s","frozen_inventory_unchanged":true,"configuration_not_reinstalled":true,"existing_service_containers_reused":true,"database_setup_and_mailpit_lifecycle_preserved":true,"database_and_publication_fingerprints_match":true,"installed_command_check_passed":true,"isolated_restore_from_new_backup_passed":true,"oom_killer_disabling_allowed":false,"migrations_run":false,"images_pulled_or_built":false,"host_packages_changed":false,"host_rebooted":false,"automatic_startup_configured":false,"recurring_backups_configured":false,"public_deployment":false}\n' "$rs_candidate_image"
  printf 'Protected diagnostics: %s; do not paste or upload their contents.\n' "$rs_work_directory"
}
