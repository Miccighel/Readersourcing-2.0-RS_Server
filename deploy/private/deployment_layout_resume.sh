# Loaded by a verified host specific wrapper after the migration and startup functions.
# Resume only the recorded, never started replacements. This is not an installer or rollback.

layout_resume_package_check() {
  printf '%s  %s\n' "$rs_original_package_manifest" "$rs_original_package/ACTIVATION-SHA256SUMS" | sha256sum --check --status
  (cd "$rs_original_package" && sha256sum --check --status ACTIVATION-SHA256SUMS)
  test -f "$rs_installation_directory/OPERATIONS-SHA256SUMS"
  test ! -L "$rs_installation_directory/OPERATIONS-SHA256SUMS"
  test "$(stat -c '%u:%g:%a' "$rs_installation_directory/OPERATIONS-SHA256SUMS")" = 0:0:644
  rs_installed_files='candidate_restart.sh candidate_startup.sh startup_inventory.rb publication_fingerprint.rb database_fingerprint.sql deployment_operations.sh deployment_layout_configuration.rb deployment_layout_inventory.rb deployment_layout_files.rb recovery_rehearsal.sh recovery_configuration.rb recovery_probe.rb candidate_configuration.rb deployment_recovery.sh deployment_recovery_configuration.rb OPERATIONS.md rs-server'
  (cd "$rs_original_package" && sha256sum $rs_installed_files) > "$rs_work_directory/expected-operations.sha256"
  cmp -s "$rs_work_directory/expected-operations.sha256" "$rs_installation_directory/OPERATIONS-SHA256SUMS"
  for rs_name in $rs_installed_files; do
    test -f "$rs_installation_directory/$rs_name"
    test ! -L "$rs_installation_directory/$rs_name"
    rs_expected_mode=644
    test "$rs_name" != rs-server || rs_expected_mode=755
    test "$(stat -c '%u:%g:%a' "$rs_installation_directory/$rs_name")" = "0:0:$rs_expected_mode"
    cmp -s "$rs_original_package/$rs_name" "$rs_installation_directory/$rs_name"
    # Only the validator will be changed in the installed command set.
    if [ "$rs_name" != deployment_layout_inventory.rb ]; then
      cmp -s "$rs_original_package/$rs_name" "$rs_package/$rs_name"
    fi
  done
  (cd "$rs_installation_directory" && sha256sum --check --status OPERATIONS-SHA256SUMS)
}

layout_resume_helper() {
  docker run --rm --pull never --runtime runc --network none --read-only --cap-drop ALL --cap-add DAC_OVERRIDE \
    --security-opt no-new-privileges --memory 256m --cpus 0.5 --pids-limit 64 --user 0:0 --entrypoint ruby \
    --mount "type=bind,source=$rs_package,target=/definition,readonly" \
    --mount "type=bind,source=$rs_prepared_plan,target=/plan,readonly" \
    --mount "type=bind,source=$rs_source_directory,target=/source,readonly" \
    --mount "type=bind,source=$rs_work_directory,target=/checks,readonly" \
    --mount "type=bind,source=$rs_checkpoint_directory,target=/checkpoint,readonly" \
    --mount "type=bind,source=$rs_configuration_directory,target=/configuration,readonly" \
    --mount "type=bind,source=$rs_active_directory,target=/state,readonly" \
    "$rs_candidate_image" -rbundler/setup /definition/deployment_layout_resume.rb
}

layout_resume_preflight() {
  for rs_directory in "$rs_checkpoint_directory" "$rs_prepared_plan" "$rs_configuration_directory" \
    "$rs_configuration_directory/runtime" "$rs_active_directory"; do
    test -d "$rs_directory"
    test ! -L "$rs_directory"
    test "$(stat -c '%u:%a' "$rs_directory")" = 0:700
  done
  test "$(stat -c '%u:%a' "$rs_installation_directory")" = 0:755
  test ! -L "$rs_installation_directory"
  for rs_name in "$rs_old_lock" "$rs_state_directory/deployment.lock"; do
    test -f "$rs_name"
    test ! -L "$rs_name"
    test "$(stat -c '%u:%a' "$rs_name")" = 0:600
  done
  test "$(stat -c '%d:%i' "$rs_old_lock")" = "$(stat -c '%d:%i' "$rs_state_directory/deployment.lock")"
  test "$(docker image inspect --format '{{.Id}}' "$rs_candidate_image")" = "$rs_candidate_image"
  test "$(docker image inspect --format '{{index .Config.Labels "org.opencontainers.image.revision"}}' "$rs_candidate_image")" = "$rs_source_revision"
  layout_resume_package_check
  for rs_name in source-containers.json replacement-containers.json before-database.jsonl before-publications.json retained-before.txt; do
    test -f "$rs_checkpoint_directory/$rs_name"
    test ! -L "$rs_checkpoint_directory/$rs_name"
  done
  # Preserve the interrupted attempt as the source of truth; never overwrite it.
  for rs_name in source-containers.json before-database.jsonl before-publications.json retained-before.txt; do
    cp -p "$rs_checkpoint_directory/$rs_name" "$rs_work_directory/$rs_name"
  done
  layout_inspect replacement
  layout_compose config --format json > "$rs_work_directory/effective.json"
  cmp -s "$rs_source_activation/candidate.json" "$rs_prepared_plan/source-candidate.json"
  layout_resume_helper
  layout_resolve
  candidate_require_health "$rs_database_container"
  docker inspect --format '{{.Id}} {{.Image}} {{.State.Running}} {{.State.StartedAt}} {{.RestartCount}}' \
    "$rs_database_container" "$rs_setup_container" > "$rs_work_directory/retained-current.txt"
  cmp -s "$rs_work_directory/retained-before.txt" "$rs_work_directory/retained-current.txt"
  startup_database_fingerprint "$rs_work_directory/current-database.jsonl"
  startup_publication_fingerprint "$rs_work_directory/current-publications.json"
  cmp -s "$rs_work_directory/before-database.jsonl" "$rs_work_directory/current-database.jsonl"
  cmp -s "$rs_work_directory/before-publications.json" "$rs_work_directory/current-publications.json"
  test -f "$rs_active_directory/backup-directory"
  test ! -L "$rs_active_directory/backup-directory"
  test "$(stat -c '%u:%a' "$rs_active_directory/backup-directory")" = 0:600
  rs_backup_directory=$(cat "$rs_active_directory/backup-directory")
  printf '%s\n' "$rs_backup_directory" | LC_ALL=C grep -Eq "^$rs_state_directory/backups/layout\.[A-Za-z0-9]{6}$"
  test -d "$rs_backup_directory"
  test ! -L "$rs_backup_directory"
  test "$(stat -c '%u:%a' "$rs_backup_directory")" = 0:700
  cmp -s "$rs_work_directory/before-database.jsonl" "$rs_backup_directory/database-fingerprint.jsonl"
  cmp -s "$rs_work_directory/before-publications.json" "$rs_backup_directory/publication-fingerprint.json"
  # The recovery adapter verifies all eleven archive hashes and the actual configuration.
  layout_helper recovery-preflight
}

layout_resume_patch_validator() {
  layout_resume_package_check
  test ! -e "$rs_installation_directory/.validator-resume"
  test ! -L "$rs_installation_directory/.validator-resume"
  test ! -e "$rs_installation_directory/.manifest-resume"
  test ! -L "$rs_installation_directory/.manifest-resume"
  cp -p "$rs_installation_directory/deployment_layout_inventory.rb" "$rs_work_directory/validator-before.rb"
  cp -p "$rs_installation_directory/OPERATIONS-SHA256SUMS" "$rs_work_directory/operations-before.sha256"
  install -o root -g root -m 644 "$rs_package/deployment_layout_inventory.rb" "$rs_installation_directory/.validator-resume"
  mv "$rs_installation_directory/.validator-resume" "$rs_installation_directory/deployment_layout_inventory.rb"
  (cd "$rs_installation_directory" && sha256sum $rs_installed_files) > "$rs_work_directory/operations-after.sha256"
  install -o root -g root -m 644 "$rs_work_directory/operations-after.sha256" "$rs_installation_directory/.manifest-resume"
  mv "$rs_installation_directory/.manifest-resume" "$rs_installation_directory/OPERATIONS-SHA256SUMS"
  (cd "$rs_installation_directory" && sha256sum --check --status OPERATIONS-SHA256SUMS)
}

layout_resume_execute() {
  rs_stage=stopped_checkpoint_preflight
  layout_resume_preflight
  rs_stage=install_reviewed_validator
  layout_resume_patch_validator
  rs_stage=freeze_verified_replacements
  layout_helper freeze
  layout_resolve
  rs_maintenance_started=yes
  layout_complete_activation
}

deployment_layout_resume_main() {
  test "$(id -u)" = 0
  test "$(uname -s)" = Linux
  test "$#" -eq 1
  test "$1" = --confirm-guarded-resume
  umask 077
  test -d "$rs_state_directory/diagnostics"
  test ! -L "$rs_state_directory/diagnostics"
  test "$(stat -c '%u:%a' "$rs_state_directory/diagnostics")" = 0:700
  # Do not create a replacement lock if the expected one disappeared.
  test -f "$rs_old_lock"
  test ! -L "$rs_old_lock"
  test "$(stat -c '%u:%a' "$rs_old_lock")" = 0:600
  exec 9<> "$rs_old_lock"
  flock -n 9
  rs_work_directory=$(mktemp -d "$rs_state_directory/diagnostics/layout-resume.XXXXXX")
  rs_stage=checkpoint_checks
  rs_completed=no
  rs_maintenance_started=no
  rs_mailbox_paused=no
  trap layout_finish EXIT
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM
  layout_resume_execute > "$rs_work_directory/output.log" 2> "$rs_work_directory/errors.log"
  rs_completed=yes
  printf '{"status":"deployment_layout_resumed","image_id":"%s","existing_stopped_replacements_reused":true,"database_and_completed_setup_lifecycle_preserved":true,"configuration_not_reinstalled":true,"only_installed_validator_updated":true,"database_and_publication_fingerprints_match":true,"installed_command_check_passed":true,"isolated_restore_from_new_backup_passed":true,"service_containers_created":false,"migrations_run":false,"host_packages_changed":false,"host_rebooted":false,"automatic_startup_configured":false,"recurring_backups_configured":false,"public_deployment":false}\n' "$rs_candidate_image"
  printf 'Protected diagnostics: %s; do not paste or upload their contents.\n' "$rs_work_directory"
}
