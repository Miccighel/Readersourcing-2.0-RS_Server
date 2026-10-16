# Host specific wrapper supplies only public paths and pinned identities.

layout_compose() {
  docker compose --project-name "$rs_expected_project" --project-directory "$rs_configuration_directory" \
    -f "$rs_configuration_directory/compose.json" "$@"
}

layout_inspect() {
  rs_inspection_name=$1
  rs_ids=$(docker ps --all --quiet --filter "label=com.docker.compose.project=$rs_expected_project")
  set -- $rs_ids
  test "$#" -eq 5
  docker inspect "$@" > "$rs_work_directory/$rs_inspection_name-containers.json"
}

layout_resolve() {
  rs_access_container=$(docker ps --all --quiet --filter "label=com.docker.compose.project=$rs_expected_project" --filter label=com.docker.compose.service=access)
  rs_web_container=$(docker ps --all --quiet --filter "label=com.docker.compose.project=$rs_expected_project" --filter label=com.docker.compose.service=rs_server_webapp)
  rs_mailpit_container=$(docker ps --all --quiet --filter "label=com.docker.compose.project=$rs_expected_project" --filter label=com.docker.compose.service=mailpit)
  rs_database_container=$(docker ps --all --quiet --filter "label=com.docker.compose.project=$rs_expected_project" --filter label=com.docker.compose.service=database)
  rs_setup_container=$(docker ps --all --quiet --filter "label=com.docker.compose.project=$rs_expected_project" --filter label=com.docker.compose.service=rs_server_setup)
  candidate_validate_container "$rs_access_container" access
  candidate_validate_container "$rs_web_container" rs_server_webapp
  candidate_validate_container "$rs_mailpit_container" mailpit
  candidate_validate_container "$rs_database_container" database
  candidate_validate_container "$rs_setup_container" rs_server_setup
}

layout_helper() {
  rs_helper_operation=$1
  rs_checks_mode=readonly
  test "$rs_helper_operation" != recovery-preflight || rs_checks_mode=
  set -- docker run --rm --pull never --runtime runc --network none --read-only --cap-drop ALL --cap-add DAC_OVERRIDE \
    --security-opt no-new-privileges --memory 256m --cpus 0.5 --pids-limit 64 --user 0:0 --entrypoint ruby \
    --mount "type=bind,source=$rs_package,target=/definition,readonly" \
    --mount "type=bind,source=$rs_prepared_plan,target=/plan,readonly" \
    --mount "type=bind,source=$rs_source_directory,target=/source,readonly" \
    --mount "type=bind,source=$rs_work_directory,target=/checks${rs_checks_mode:+,$rs_checks_mode}"
  case "$rs_helper_operation" in
    install|freeze)
      set -- "$@" --mount "type=bind,source=$rs_configuration_directory,target=/configuration" \
        --mount "type=bind,source=$rs_active_directory,target=/state" ;;
    configuration|recovery-preflight)
      set -- "$@" --mount "type=bind,source=$rs_configuration_directory,target=/configuration,readonly" \
        --mount "type=bind,source=$rs_active_directory,target=/state,readonly" ;;
  esac
  if [ "$rs_helper_operation" = recovery-preflight ]; then
    set -- "$@" --mount "type=bind,source=$rs_backup_directory,target=/backup,readonly"
  fi
  "$@" "$rs_candidate_image" -rbundler/setup /definition/deployment_layout_files.rb "$rs_helper_operation"
}

layout_preflight() {
  test "$(stat -c '%u:%a' "$rs_prepared_plan")" = 0:700
  test ! -L "$rs_prepared_plan"
  test ! -e "$rs_configuration_directory" && test ! -L "$rs_configuration_directory"
  test ! -e "$rs_installation_directory" && test ! -L "$rs_installation_directory"
  cmp -s "$rs_source_activation/candidate.json" "$rs_prepared_plan/source-candidate.json"
  layout_inspect source
  layout_helper preflight
  layout_helper recovery-code
  layout_resolve
  candidate_require_health "$rs_database_container"
  candidate_require_health "$rs_web_container"
  candidate_require_health "$rs_access_container"
  test "$(docker inspect --format '{{.State.Running}}' "$rs_mailpit_container")" = true
  # Test the read only probes before any service is interrupted.
  startup_database_fingerprint "$rs_work_directory/probe-database.jsonl"
  startup_publication_fingerprint "$rs_work_directory/probe-publications.json"
  docker exec "$rs_mailpit_container" sh -c 'command -v tar >/dev/null && test -r /tmp/mailpit.db'
  docker exec "$rs_web_container" ./bin/rails deployment:check
  docker inspect --format '{{.Id}} {{.Image}} {{.State.Running}} {{.State.StartedAt}} {{.RestartCount}}' \
    "$rs_database_container" "$rs_setup_container" > "$rs_work_directory/retained-before.txt"
}

layout_directory() {
  if [ -e "$1" ]; then
    test -d "$1" && test ! -L "$1"
    test "$(stat -c '%u:%a' "$1")" = "0:$2"
  else
    mkdir -m "$2" "$1"
  fi
}

layout_install() {
  layout_directory /opt/readersourcing 755
  layout_directory /etc/opt/readersourcing 700
  mkdir -m 755 "$rs_installation_directory"
  mkdir -m 700 "$rs_configuration_directory" "$rs_configuration_directory/runtime" "$rs_active_directory"
  for rs_name in candidate_restart.sh candidate_startup.sh startup_inventory.rb publication_fingerprint.rb database_fingerprint.sql \
    deployment_operations.sh deployment_layout_configuration.rb deployment_layout_inventory.rb deployment_layout_files.rb \
    recovery_rehearsal.sh recovery_configuration.rb recovery_probe.rb candidate_configuration.rb deployment_recovery.sh deployment_recovery_configuration.rb deployment_startup_inventory.rb OPERATIONS.md; do
    install -o root -g root -m 644 "$rs_package/$rs_name" "$rs_installation_directory/$rs_name"
  done
  install -o root -g root -m 755 "$rs_package/rs-server" "$rs_installation_directory/rs-server"
  (cd "$rs_installation_directory" && sha256sum candidate_restart.sh candidate_startup.sh startup_inventory.rb \
    publication_fingerprint.rb database_fingerprint.sql deployment_operations.sh deployment_layout_configuration.rb \
    deployment_layout_inventory.rb deployment_layout_files.rb recovery_rehearsal.sh recovery_configuration.rb recovery_probe.rb \
    candidate_configuration.rb deployment_recovery.sh deployment_recovery_configuration.rb OPERATIONS.md rs-server deployment_startup_inventory.rb > OPERATIONS-SHA256SUMS)
  chmod 644 "$rs_installation_directory/OPERATIONS-SHA256SUMS"
  for rs_name in smtp.crt smtp.key smtp.auth ui.auth proxy.conf; do
    test -f "$rs_source_directory/runtime/$rs_name" && test ! -L "$rs_source_directory/runtime/$rs_name"
    cp -p "$rs_source_directory/runtime/$rs_name" "$rs_configuration_directory/runtime/$rs_name"
  done
  test ! -e "$rs_state_directory/deployment.lock" && test ! -L "$rs_state_directory/deployment.lock"
  ln "$rs_old_lock" "$rs_state_directory/deployment.lock"
  test "$(stat -c '%d:%i' "$rs_old_lock")" = "$(stat -c '%d:%i' "$rs_state_directory/deployment.lock")"
  layout_helper install
  layout_compose config --format json > "$rs_work_directory/effective.json"
  layout_helper configuration
}

layout_backup() {
  layout_directory "$rs_state_directory/backups" 700
  rs_backup_directory=$(mktemp -d "$rs_state_directory/backups/layout.XXXXXX")
  printf '%s\n' 'Backup not complete' > "$rs_backup_directory/INCOMPLETE"
  startup_database_fingerprint "$rs_work_directory/before-database.jsonl"
  startup_publication_fingerprint "$rs_work_directory/before-publications.json"
  cp "$rs_work_directory/before-database.jsonl" "$rs_backup_directory/database-fingerprint.jsonl"
  cp "$rs_work_directory/before-publications.json" "$rs_backup_directory/publication-fingerprint.json"
  cp "$rs_prepared_plan/source-candidate.json" "$rs_backup_directory/source-definition.json"
  cp "$rs_work_directory/source-containers.json" "$rs_backup_directory/source-containers.json"
  cp "$rs_active_directory/runtime-files.json" "$rs_backup_directory/runtime-files.json"
  docker exec -i "$rs_database_container" sh -c \
    'exec pg_dump --format=custom --no-owner --no-privileges --username="$POSTGRES_USER" "$POSTGRES_DB"' > "$rs_backup_directory/database.dump"
  test -s "$rs_backup_directory/database.dump"
  docker exec -i "$rs_database_container" pg_restore --list < "$rs_backup_directory/database.dump" > /dev/null
  docker run --rm --pull never --runtime runc --network none --read-only --cap-drop ALL \
    --security-opt no-new-privileges --memory 128m --cpus 0.5 --pids-limit 64 --entrypoint tar \
    --mount "type=volume,source=${rs_expected_project}_publications,target=/publications,readonly" \
    "$rs_candidate_image" -C /publications -czf - . > "$rs_backup_directory/publications.tar.gz"
  tar -C "$rs_source_directory" -czf "$rs_backup_directory/source-configuration.tar.gz" \
    compose.yml project-name trial.json runtime fixtures -C "$rs_source_activation" candidate-images.yml candidate.json
  tar -C "$rs_configuration_directory" -czf "$rs_backup_directory/new-configuration.tar.gz" .
  # Capture the bounded temporary mailbox before recreating Mailpit. No message body is printed.
  rs_mailbox_paused=yes
  docker pause "$rs_mailpit_container" > /dev/null
  mkdir -m 700 "$rs_backup_directory/mailpit-tmp"
  docker cp -a "$rs_mailpit_container:/tmp/." "$rs_backup_directory/mailpit-tmp"
  docker unpause "$rs_mailpit_container" > /dev/null
  rs_mailbox_paused=no
  tar -C "$rs_backup_directory/mailpit-tmp" -czf "$rs_backup_directory/mailpit-tmp.tar.gz" .
  printf '{"project":"%s","application_image":"%s","source_revision":"%s","created_at":"%s","off_host_copy":false,"archive_integrity_at_creation":true,"restore_rehearsed_at_creation":false}\n' \
    "$rs_expected_project" "$rs_candidate_image" "$rs_source_revision" "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" > "$rs_backup_directory/manifest.json"
  gzip -t "$rs_backup_directory/publications.tar.gz" "$rs_backup_directory/source-configuration.tar.gz" \
    "$rs_backup_directory/new-configuration.tar.gz" "$rs_backup_directory/mailpit-tmp.tar.gz"
  (cd "$rs_backup_directory" && sha256sum database.dump publications.tar.gz source-configuration.tar.gz \
    new-configuration.tar.gz mailpit-tmp.tar.gz source-definition.json source-containers.json manifest.json runtime-files.json \
    database-fingerprint.jsonl publication-fingerprint.json > SHA256SUMS && \
    sha256sum --check --status SHA256SUMS)
  startup_database_fingerprint "$rs_work_directory/backup-database.jsonl"
  startup_publication_fingerprint "$rs_work_directory/backup-publications.json"
  cmp -s "$rs_work_directory/before-database.jsonl" "$rs_work_directory/backup-database.jsonl"
  cmp -s "$rs_work_directory/before-publications.json" "$rs_work_directory/backup-publications.json"
  printf '%s\n' 'Archive integrity verified at creation. Subsequent recovery outcomes are recorded separately in protected operational state.' > "$rs_backup_directory/INCOMPLETE"
  mv "$rs_backup_directory/INCOMPLETE" "$rs_backup_directory/COMPLETE"
  (set -C; printf '%s\n' "$rs_backup_directory" > "$rs_active_directory/backup-directory")
}

layout_activate() {
  rs_stage=install_configuration_and_commands
  layout_install
  rs_stage=backup
  rs_maintenance_started=yes
  docker stop -t 30 "$rs_access_container" > /dev/null
  docker stop -t 30 "$rs_web_container" > /dev/null
  layout_backup
  rs_stage=backup_recovery_preparation
  layout_helper recovery-preflight
  rs_stage=create_stopped_replacements
  docker stop -t 30 "$rs_mailpit_container" > /dev/null
  layout_compose up --no-start --no-deps --no-build --pull never --force-recreate mailpit rs_server_webapp access
  layout_inspect replacement
  layout_helper replacement
  layout_helper freeze
  layout_resolve
  layout_complete_activation
}

layout_complete_activation() {
  rs_stage=verify_application_and_data
  if [ "${rs_preserve_mailpit_lifecycle:-no}" = yes ]; then
    test "$(docker inspect --format '{{.State.Running}}' "$rs_mailpit_container")" = true
  else
    docker start "$rs_mailpit_container" > /dev/null
  fi
  docker start "$rs_web_container" > /dev/null
  candidate_wait_for_health "$rs_web_container"
  docker exec "$rs_web_container" ./bin/rails deployment:check
  docker stop -t 30 "$rs_web_container" > /dev/null
  startup_database_fingerprint "$rs_work_directory/after-database.jsonl"
  startup_publication_fingerprint "$rs_work_directory/after-publications.json"
  cmp -s "$rs_work_directory/before-database.jsonl" "$rs_work_directory/after-database.jsonl"
  cmp -s "$rs_work_directory/before-publications.json" "$rs_work_directory/after-publications.json"
  docker inspect --format '{{.Id}} {{.Image}} {{.State.Running}} {{.State.StartedAt}} {{.RestartCount}}' \
    "$rs_database_container" "$rs_setup_container" > "$rs_work_directory/retained-after.txt"
  cmp -s "$rs_work_directory/retained-before.txt" "$rs_work_directory/retained-after.txt"
  cmp -s "$rs_source_activation/candidate.json" "$rs_prepared_plan/source-candidate.json"
  layout_compose config --format json > "$rs_work_directory/effective.json"
  layout_helper configuration
  rs_stage=reopen_access
  docker start "$rs_web_container" > /dev/null
  candidate_wait_for_health "$rs_web_container"
  docker start "$rs_access_container" > /dev/null
  candidate_wait_for_health "$rs_access_container"
  rs_stage=installed_command_check
  flock -u 9
  sh "$rs_installation_directory/rs-server" check
  rs_stage=isolated_recovery_rehearsal
  sh "$rs_installation_directory/rs-server" restore-rehearsal --confirm-isolated-restore
  flock -n 9
}

layout_finish() {
  rs_exit=$?
  trap - EXIT HUP INT TERM
  if [ "$rs_completed" != yes ]; then
    if [ "$rs_mailbox_paused" = yes ]; then
      docker unpause "$rs_mailpit_container" >> "$rs_work_directory/failure.log" 2>&1 || true
    fi
    if [ "$rs_maintenance_started" = yes ]; then
      # Stop only this project's access and writer; never restore a database automatically.
      layout_resolve >> "$rs_work_directory/failure.log" 2>&1 && \
        docker stop -t 30 "$rs_access_container" "$rs_web_container" >> "$rs_work_directory/failure.log" 2>&1 || \
        printf '%s\n' 'Access closure needs operator attention.' >&2
      printf '%s\n' 'Migration not confirmed; access and application were kept stopped where possible. Inspect before reopening.' >&2
    else
      printf '%s\n' 'Checks stopped before maintenance; no application service was stopped or started.' >&2
    fi
    printf 'Stage: %s. Protected diagnostics: %s; do not paste or upload their contents.\n' "$rs_stage" "$rs_work_directory" >&2
    printf '%s\n' 'Existing volumes, old configuration and backups were not deleted. No automatic database restore was attempted.' >&2
    exit 1
  fi
  exit "$rs_exit"
}

deployment_layout_migration_main() {
  test "$(id -u)" = 0 && test "$(uname -s)" = Linux
  test "$#" -eq 1
  case "$1" in --check|--activate) rs_operation=$1 ;; *) return 64 ;; esac
  umask 077
  layout_directory "$rs_state_directory/diagnostics" 700
  rs_work_directory=$(mktemp -d "$rs_state_directory/diagnostics/layout.XXXXXX")
  rs_stage=preflight
  rs_completed=no
  rs_maintenance_started=no
  rs_mailbox_paused=no
  trap layout_finish EXIT
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM
  sh "$rs_source_operations/startup_candidate.sh" check > "$rs_work_directory/original-check.log" 2>&1
  exec 9> "$rs_old_lock"
  flock -n 9
  layout_preflight > "$rs_work_directory/preflight-output.log" 2> "$rs_work_directory/preflight-errors.log"
  if [ "$rs_operation" = --activate ]; then
    layout_activate > "$rs_work_directory/activation-output.log" 2> "$rs_work_directory/activation-errors.log"
  fi
  rs_completed=yes
  if [ "$rs_operation" = --check ]; then
    printf '{"status":"layout_activation_preflight_passed","services_interrupted":false,"configuration_installed":false,"read_only_data_probes_passed":true,"host_packages_changed":false,"host_rebooted":false}\n'
  else
    printf '{"status":"deployment_layout_activated","image_id":"%s","operations":"%s","configuration":"%s","state":"%s","database_and_completed_setup_retained":true,"database_and_publication_fingerprints_match":true,"runtime_file_contents_and_permissions_preserved":true,"new_command_check_passed":true,"isolated_recovery_from_new_backup_passed":true,"mailpit_messages_archived_before_recreation":true,"mailpit_active_inbox_recreated":true,"database_migrations_run":false,"images_pulled_or_built":false,"old_installation_retained":true,"host_packages_changed":false,"host_rebooted":false,"automatic_startup_configured":false,"recurring_backups_configured":false,"public_deployment":false}\n' \
      "$rs_candidate_image" "$rs_installation_directory" "$rs_configuration_directory" "$rs_state_directory"
    printf 'Protected point in time backup: %s; database and publication restore rehearsed in isolation, not a new NAS copy or mailbox restore.\n' "$rs_backup_directory"
  fi
  printf 'Protected diagnostics: %s; do not paste or upload their contents.\n' "$rs_work_directory"
}
