# Loaded after candidate_restart.sh by a verified host specific wrapper.
# Startup is manual. The setup container is checked but never started.

startup_inventory() {
  docker inspect "$rs_access_container" "$rs_database_container" "$rs_mailpit_container" \
    "$rs_setup_container" "$rs_web_container" > "$rs_work_directory/inspection.json"
  docker run --rm --pull never --runtime runc --network none --read-only --cap-drop ALL \
    --security-opt no-new-privileges --memory 256m --cpus 0.5 --pids-limit 64 --user 0:0 --entrypoint ruby \
    --mount "type=bind,source=$rs_work_directory,target=/checks" \
    --mount "type=bind,source=$rs_plan_directory,target=/plan,readonly" \
    --mount "type=bind,source=$rs_operations_directory/startup_inventory.rb,target=/inventory.rb,readonly" \
    "$rs_candidate_image" -rbundler/setup /inventory.rb "$1" /checks/inspection.json "$2" \
    "$rs_expected_project" "$rs_candidate_image" "$rs_source_revision"
}

startup_validate() {
  candidate_validate_configuration
  candidate_check_identities
  startup_inventory check /plan/startup-inventory.json
}

startup_require_ready() {
  candidate_check_containers
  candidate_require_health "$rs_web_container"
  candidate_require_health "$rs_access_container"
}

startup_database_fingerprint() {
  docker exec -i "$rs_database_container" sh -c \
    'exec psql --no-psqlrc --quiet --no-align --tuples-only --set=ON_ERROR_STOP=on --username="$POSTGRES_USER" "$POSTGRES_DB"' \
    < "$rs_operations_directory/database_fingerprint.sql" > "$1"
  test -s "$1"
}

startup_publication_fingerprint() {
  test "$(docker volume inspect --format '{{index .Labels "com.docker.compose.project"}}' "${rs_expected_project}_publications")" = "$rs_expected_project"
  docker run --rm --pull never --runtime runc --network none --read-only --cap-drop ALL \
    --security-opt no-new-privileges --memory 256m --cpus 0.5 --pids-limit 64 --user 1000:1000 --entrypoint ruby \
    --mount "type=volume,source=${rs_expected_project}_publications,target=/publications,readonly" \
    --mount "type=bind,source=$rs_operations_directory/publication_fingerprint.rb,target=/fingerprint.rb,readonly" \
    "$rs_candidate_image" -rbundler/setup /fingerprint.rb /publications > "$1"
  test -s "$1"
}

startup_start_if_stopped() {
  if [ "$(docker inspect --format '{{.State.Running}}' "$1")" = false ]; then
    docker start "$1" > /dev/null
  fi
}

startup_open() {
  startup_start_if_stopped "$rs_database_container"
  candidate_wait_for_health "$rs_database_container"
  startup_start_if_stopped "$rs_mailpit_container"
  test "$(docker inspect --format '{{.State.Running}}' "$rs_mailpit_container")" = true

  if [ "$rs_operation" = rehearse ]; then
    startup_database_fingerprint "$rs_work_directory/database-after.jsonl"
    startup_publication_fingerprint "$rs_work_directory/publications-after.json"
    cmp -s "$rs_work_directory/database-before.jsonl" "$rs_work_directory/database-after.jsonl"
    cmp -s "$rs_work_directory/publications-before.json" "$rs_work_directory/publications-after.json"
  fi

  startup_validate
  docker start "$rs_web_container" > /dev/null
  candidate_wait_for_health "$rs_web_container"
  docker exec "$rs_web_container" ./bin/rails deployment:check
  startup_validate
  candidate_check_containers
  docker start "$rs_access_container" > /dev/null
  candidate_wait_for_health "$rs_access_container"
  startup_require_ready
}

startup_execute() {
  candidate_validate_configuration
  candidate_resolve_containers
  candidate_check_identities

  if [ "$rs_operation" = prepare ]; then
    startup_require_ready
    startup_inventory prepare /checks/inventory.json
    (set -C; cat "$rs_work_directory/inventory.json" > "$rs_plan_directory/startup-inventory.json")
    return
  fi

  startup_validate
  case "$rs_operation" in
    check) return ;;
    rehearse) startup_require_ready ;;
    start)
      # A healthy stack needs no interruption. A partial stack is closed before repair.
      if candidate_require_health "$rs_database_container" &&
        test "$(docker inspect --format '{{.State.Running}}' "$rs_mailpit_container")" = true &&
        candidate_require_health "$rs_web_container" && candidate_require_health "$rs_access_container"; then
        return
      fi ;;
  esac

  rs_maintenance_started=yes
  docker stop -t 30 "$rs_access_container" > /dev/null
  docker stop -t 30 "$rs_web_container" > /dev/null
  if [ "$rs_operation" = rehearse ]; then
    startup_database_fingerprint "$rs_work_directory/database-before.jsonl"
    startup_publication_fingerprint "$rs_work_directory/publications-before.json"
    docker stop -t 30 "$rs_mailpit_container" > /dev/null
    docker stop -t 60 "$rs_database_container" > /dev/null
  fi
  startup_open
}

startup_finish() {
  rs_status=$?
  trap - EXIT HUP INT TERM
  if [ "$rs_completed" != yes ]; then
    if [ "$rs_maintenance_started" = yes ]; then
      if docker stop -t 30 "$rs_access_container" >> "$rs_work_directory/recovery.log" 2>&1; then
        printf '%s\n' 'Startup failed. Access was kept stopped; inspect protected diagnostics before reopening it.' >&2
      else
        printf '%s\n' 'Startup failed and access could not be stopped; operator attention is required.' >&2
      fi
    else
      printf '%s\n' 'Startup checks failed before maintenance; no trial service was stopped or started.' >&2
    fi
    printf 'Private diagnostics: %s. Do not paste or upload their contents.\n' "$rs_work_directory" >&2
    exit 1
  fi
  exit "$rs_status"
}

candidate_startup_main() {
  test "$(id -u)" = 0
  test "$(uname -s)" = Linux
  test "$#" -eq 1
  case "$1" in prepare|check|start|rehearse) rs_operation=$1 ;; *) return 64 ;; esac
  umask 077
  candidate_prepare_context
  if [ "$rs_operation" = prepare ]; then
    test ! -e "$rs_plan_directory/startup-inventory.json"
    test ! -L "$rs_plan_directory/startup-inventory.json"
  else
    test -f "$rs_plan_directory/startup-inventory.json"
    test ! -L "$rs_plan_directory/startup-inventory.json"
    test "$(stat -c '%u:%a' "$rs_plan_directory/startup-inventory.json")" = 0:600
  fi
  rs_work_directory=$(mktemp -d /var/tmp/rs-server-candidate-startup.XXXXXX)
  rs_completed=no
  rs_maintenance_started=no
  trap startup_finish EXIT
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM
  startup_execute > "$rs_work_directory/output.log" 2> "$rs_work_directory/errors.log"
  rs_completed=yes
  rs_fingerprints=false
  test "$rs_operation" != rehearse || rs_fingerprints=true
  printf '{"status":"passed","operation":"%s","image_id":"%s","configuration_and_inventory_verified":true,"database_and_publication_fingerprints_checked":%s,"migrations_run":false,"containers_created":false,"automatic_startup_configured":false,"host_reboot_tested":false}\n' \
    "$rs_operation" "$rs_candidate_image" "$rs_fingerprints"
  printf 'Private diagnostics retained at %s; do not paste or upload their contents.\n' "$rs_work_directory"
}
