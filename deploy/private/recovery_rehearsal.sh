# Loaded by a host specific wrapper with fixed image, backup and source identities.

recovery_compose() {
  docker compose --project-name "$rs_recovery_project" --project-directory "$rs_work_directory/recovery" \
    -f "$rs_work_directory/recovery/compose.json" "$@"
}

recovery_source_ids() {
  docker ps --all --quiet --filter "label=com.docker.compose.project=$rs_expected_project" | LC_ALL=C sort
}

recovery_source_state() {
  while IFS= read -r rs_id; do
    docker inspect --format '{{.Id}} {{.Image}} {{.State.Running}} {{.State.StartedAt}} {{.RestartCount}}' "$rs_id"
  done < "$rs_work_directory/source-ids.txt"
}

recovery_validate_target() {
  rs_target_id=$(recovery_compose ps --all --quiet "$1")
  test -n "$rs_target_id"
  test "$(docker inspect --format '{{index .Config.Labels "com.docker.compose.project"}}' "$rs_target_id")" = "$rs_recovery_project"
  test "$(docker inspect --format '{{index .Config.Labels "com.docker.compose.service"}}' "$rs_target_id")" = "$1"
  rs_mounts=$(docker inspect --format '{{range .Mounts}}{{if eq .Type "volume"}}{{.Name}} {{end}}{{end}}' "$rs_target_id")
  case "$1:$rs_mounts" in
    "database:${rs_recovery_project}_database "|"rs_server_webapp:${rs_recovery_project}_publications "|"mailpit:") ;;
    *) return 1 ;;
  esac
  test "$(docker inspect --format '{{json .HostConfig.PortBindings}}' "$rs_target_id")" = '{}'
}

recovery_database_fingerprint() {
  recovery_validate_target database
  docker exec -i "$rs_target_id" sh -c \
    'exec psql --no-psqlrc --quiet --no-align --tuples-only --set=ON_ERROR_STOP=on --username="$POSTGRES_USER" "$POSTGRES_DB"' \
    < "$rs_operations_directory/database_fingerprint.sql" > "$1"
}

recovery_wait_for_health() {
  rs_checks_left=90
  while [ "$rs_checks_left" -gt 0 ]; do
    rs_health=$(docker inspect --format '{{.State.Running}} {{if .State.Health}}{{.State.Health.Status}}{{end}}' "$1") || return 1
    case "$rs_health" in
      'true healthy') return 0 ;;
      'true starting') ;;
      *) return 1 ;;
    esac
    rs_checks_left=$((rs_checks_left - 1))
    sleep 2
  done
  return 1
}

recovery_check_source_unchanged() {
  recovery_source_ids > "$rs_work_directory/source-ids-after.txt"
  cmp -s "$rs_work_directory/source-ids.txt" "$rs_work_directory/source-ids-after.txt"
  recovery_source_state > "$rs_work_directory/source-after.txt"
  cmp -s "$rs_work_directory/source-before.txt" "$rs_work_directory/source-after.txt"
}

recovery_finish() {
  rs_exit=$?
  trap - EXIT HUP INT TERM
  if [ "$rs_target_created" = yes ]; then
    if ! recovery_compose stop > "$rs_work_directory/stop.log" 2>&1; then
      printf '%s\n' 'Recovery containers could not all be stopped; inspect the protected diagnostics.' >&2
      rs_exit=1
    fi
  fi
  if ! recovery_check_source_unchanged >> "$rs_work_directory/source-check.log" 2>&1; then
    printf '%s\n' 'Source container identity or lifecycle changed during the rehearsal; operator review is required.' >&2
    rs_exit=1
  fi
  if [ "$rs_exit" -ne 0 ] || [ "$rs_completed" != yes ]; then
    printf 'Recovery stopped during stage: %s\n' "$rs_stage" >&2
    printf 'Recovery not confirmed. Protected diagnostics: %s. Do not paste or upload their contents.\n' "$rs_work_directory" >&2
    exit 1
  fi
  install -m 644 "$rs_work_directory/report.json" "$rs_operations_directory/recovery-report.json"
  cat "$rs_operations_directory/recovery-report.json"
  printf '\nRecovery containers are stopped; their isolated volumes and protected configuration remain at %s\n' "$rs_work_directory"
  printf '%s\n' 'No off host backup was made. The active trial was not stopped or replaced.'
}

recovery_execute() {
  rs_stage=source_configuration
  docker compose --project-name "$rs_expected_project" --project-directory "$rs_trial_directory" \
    -f "$rs_trial_directory/compose.yml" config --format json > "$rs_work_directory/original.json"
  rs_source_database=$(docker ps --quiet --filter "label=com.docker.compose.project=$rs_expected_project" --filter label=com.docker.compose.service=database)
  rs_source_mailpit=$(docker ps --quiet --filter "label=com.docker.compose.project=$rs_expected_project" --filter label=com.docker.compose.service=mailpit)
  test -n "$rs_source_database" && test -n "$rs_source_mailpit"
  rs_database_image=$(docker inspect --format '{{.Image}}' "$rs_source_database")
  rs_mailpit_image=$(docker inspect --format '{{.Image}}' "$rs_source_mailpit")
  rs_stage=target_isolation
  rs_recovery_project="rs-recovery-$(openssl rand -hex 6)"
  test -z "$(docker ps --all --quiet --filter "label=com.docker.compose.project=$rs_recovery_project")"
  test -z "$(docker network ls --quiet --filter "name=^${rs_recovery_project}_default$")"
  for rs_volume in database publications; do
    if docker volume inspect "${rs_recovery_project}_$rs_volume" > /dev/null 2>&1; then return 1; fi
  done
  mkdir -m 700 "$rs_work_directory/recovery"
  rs_stage=backup_validation
  docker run --rm --pull never --runtime runc --network none --read-only --cap-drop ALL \
    --security-opt no-new-privileges --memory 256m --cpus 0.5 --pids-limit 64 --user 0:0 --entrypoint ruby \
    --mount "type=bind,source=$rs_work_directory,target=$rs_work_directory" \
    --mount "type=bind,source=$rs_backup_directory,target=/backup,readonly" \
    --mount "type=bind,source=$rs_operations_directory,target=/definition,readonly" \
    "$rs_candidate_image" -rbundler/setup -rjson -e '
      keys = %w[backup original destination project source_project published_image backup_image application_image database_image mailpit_image]
      File.write(ARGV[0], JSON.generate(keys.zip(ARGV.drop(1)).to_h), mode: "wx", perm: 0600)
    ' "$rs_work_directory/options.json" /backup "$rs_work_directory/original.json" "$rs_work_directory/recovery" \
    "$rs_recovery_project" "$rs_expected_project" "$rs_published_image" "$rs_backup_image" "$rs_candidate_image" "$rs_database_image" "$rs_mailpit_image"
  docker run --rm --pull never --runtime runc --network none --read-only --cap-drop ALL \
    --security-opt no-new-privileges --memory 256m --cpus 0.5 --pids-limit 64 --user 0:0 --entrypoint ruby \
    --mount "type=bind,source=$rs_work_directory,target=$rs_work_directory" \
    --mount "type=bind,source=$rs_backup_directory,target=/backup,readonly" \
    --mount "type=bind,source=$rs_operations_directory,target=/definition,readonly" \
    "$rs_candidate_image" -rbundler/setup /definition/recovery_configuration.rb "$rs_work_directory/options.json"
  for rs_name in smtp.crt smtp.key smtp.auth ui.auth; do
    chown "$(stat -c '%u:%g' "$rs_trial_directory")" "$rs_work_directory/recovery/runtime/$rs_name"
  done
  chmod 644 "$rs_work_directory/recovery/runtime/smtp.crt"
  recovery_compose config --quiet
  rs_stage=target_start
  rs_target_created=yes
  recovery_compose up --detach --no-deps --no-build --pull never --wait --wait-timeout 180 database mailpit
  rs_stage=database_restore
  recovery_validate_target database
  docker exec -i "$rs_target_id" sh -c \
    'exec pg_restore --exit-on-error --no-owner --no-privileges --username="$POSTGRES_USER" --dbname="$POSTGRES_DB"' \
    < "$rs_backup_directory/database.dump"
  rs_stage=database_verification
  recovery_database_fingerprint "$rs_work_directory/database-restored.jsonl"
  cmp -s "$rs_backup_directory/database-fingerprint.jsonl" "$rs_work_directory/database-restored.jsonl"
  rs_stage=application_container_creation
  # Recovery services have no dependencies; create does not accept --no-deps.
  recovery_compose create --no-build --pull never rs_server_webapp
  recovery_validate_target rs_server_webapp
  rs_web_container=$rs_target_id
  test "$(docker inspect --format '{{.Image}}' "$rs_web_container")" = "$rs_candidate_image"
  test "$(docker volume inspect --format '{{index .Labels "com.docker.compose.project"}}' "${rs_recovery_project}_publications")" = "$rs_recovery_project"
  rs_stage=publication_restore
  docker run --rm --pull never --runtime runc --network none --read-only --cap-drop ALL --cap-add CHOWN --cap-add FOWNER --cap-add DAC_OVERRIDE \
    --security-opt no-new-privileges --memory 256m --cpus 0.5 --pids-limit 64 --user 0:0 --entrypoint sh \
    --mount "type=volume,source=${rs_recovery_project}_publications,target=/publications" \
    --mount "type=bind,source=$rs_backup_directory/publications.tar.gz,target=/publications.tar.gz,readonly" \
    "$rs_candidate_image" -c 'test -z "$(find /publications -mindepth 1 -maxdepth 1 -print -quit)" && tar --numeric-owner -xzf /publications.tar.gz -C /publications'
  rs_stage=publication_verification
  docker run --rm --pull never --runtime runc --network none --read-only --cap-drop ALL \
    --security-opt no-new-privileges --memory 256m --cpus 0.5 --pids-limit 64 --user 1000:1000 --entrypoint ruby \
    --mount "type=volume,source=${rs_recovery_project}_publications,target=/publications,readonly" \
    --mount "type=bind,source=$rs_operations_directory/publication_fingerprint.rb,target=/fingerprint.rb,readonly" \
    "$rs_candidate_image" -rbundler/setup /fingerprint.rb /publications > "$rs_work_directory/publications-restored.json"
  cmp -s "$rs_backup_directory/publication-fingerprint.json" "$rs_work_directory/publications-restored.json"
  rs_stage=application_start
  docker start "$rs_web_container" > /dev/null
  recovery_wait_for_health "$rs_web_container"
  docker exec "$rs_web_container" ./bin/rails deployment:check
  rs_stage=application_probe_execution
  docker exec -i -e "RS_RECOVERY_PROJECT=$rs_recovery_project" "$rs_web_container" ./bin/rails runner - \
    < "$rs_operations_directory/recovery_probe.rb"
  rs_stage=application_probe_report
  docker exec "$rs_web_container" cat /tmp/recovery-probe.json > "$rs_work_directory/probe.json"
  rs_stage=post_probe_verification
  recovery_database_fingerprint "$rs_work_directory/database-after-probe.jsonl"
  cmp -s "$rs_work_directory/database-restored.jsonl" "$rs_work_directory/database-after-probe.jsonl"
  recovery_validate_target mailpit
  recovery_validate_target rs_server_webapp
  recovery_check_source_unchanged
  rs_stage=report
  rs_finished_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  rs_elapsed=$(($(date +%s) - rs_started_seconds))
  docker run --rm --pull never --runtime runc --network none --read-only --cap-drop ALL \
    --security-opt no-new-privileges --memory 128m --cpus 0.25 --pids-limit 64 --user 0:0 --entrypoint ruby \
    --mount "type=bind,source=$rs_work_directory,target=/checks" \
    "$rs_candidate_image" -rbundler/setup -rjson -rdigest -e '
      probe = JSON.parse(File.read("/checks/probe.json"))
      raise "Probe did not pass" unless probe.fetch("status") == "passed"
      database_entries = File.readlines("/checks/database-restored.jsonl").map { |line| JSON.parse(line) }
      result = {status: "recovery_rehearsal_passed", recorded_at: ARGV[0], elapsed_seconds: ARGV[1].to_i,
        project: ARGV[2], source_project: ARGV[3], backup_image: ARGV[4], restored_application_image: ARGV[5],
        database_and_sequences_match_backup: true, publication_inventory_matches_backup_before_probes: true,
        database_fingerprint_sha256: Digest::SHA256.file("/checks/database-restored.jsonl").hexdigest,
        database_tables_checked: database_entries.count { |entry| entry.fetch("kind") == "table" },
        database_sequences_checked: database_entries.count { |entry| entry.fetch("kind") == "sequence" },
        publication_inventory: JSON.parse(File.read("/checks/publications-restored.json")),
        database_unchanged_after_probes: true, source_container_identities_and_lifecycle_unchanged: true,
        migrations_run: false, ports_published: false, images_pulled_or_built: false,
        recovery_services_stopped_after_checks: true,
        off_host_backup: false, security_approval: false, probe: probe}
      File.write("/checks/report.json", JSON.pretty_generate(result) + "\n", mode: "wx", perm: 0600)
    ' "$rs_finished_at" "$rs_elapsed" "$rs_recovery_project" "$rs_expected_project" "$rs_backup_image" "$rs_candidate_image"
  rs_completed=yes
}

recovery_main() {
  test "$(id -u)" = 0 && test "$(uname -s)" = Linux
  test "$#" -eq 1 && test "$1" = --confirm-isolated-restore
  for rs_directory in "$rs_trial_directory" "$rs_backup_directory" "$rs_operations_directory"; do
    test -d "$rs_directory" && test ! -L "$rs_directory"
  done
  test "$(stat -c '%u:%a' "$rs_backup_directory")" = 0:700
  sh "$rs_source_operations/restart_candidate.sh" check
  exec 9> "$rs_lock_file"
  flock -n 9
  rs_started_seconds=$(date +%s)
  rs_work_directory=$(mktemp -d /var/tmp/rs-server-recovery.XXXXXX)
  rs_target_created=no
  rs_completed=no
  recovery_source_ids > "$rs_work_directory/source-ids.txt"
  test "$(wc -l < "$rs_work_directory/source-ids.txt")" -eq 5
  recovery_source_state > "$rs_work_directory/source-before.txt"
  trap recovery_finish EXIT
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM
  recovery_execute > "$rs_work_directory/output.log" 2> "$rs_work_directory/errors.log"
}
