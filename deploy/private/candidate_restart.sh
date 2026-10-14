# Loaded by a host specific wrapper after its pinned inputs have been verified.
# The wrapper supplies the rs_* identities and directories; no image is selected from a tag.

candidate_compose() {
  docker compose --project-name "$rs_expected_project" --project-directory "$rs_trial_directory" \
    -f "$rs_trial_directory/compose.yml" -f "$rs_plan_directory/candidate-images.yml" "$@"
}

candidate_validate_container() {
  test -n "$1" || return 1
  test "$(docker inspect --format '{{index .Config.Labels "com.docker.compose.project"}}' "$1")" = "$rs_expected_project" || return 1
  test "$(docker inspect --format '{{index .Config.Labels "com.docker.compose.service"}}' "$1")" = "$2" || return 1
}

candidate_require_health() {
  test "$(docker inspect --format '{{.State.Running}} {{if .State.Health}}{{.State.Health.Status}}{{end}}' "$1")" = 'true healthy'
}

candidate_wait_for_health() {
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

candidate_validate_configuration() {
  rs_project=$(docker run --rm --pull never --runtime runc --network none --read-only --cap-drop ALL \
    --security-opt no-new-privileges --memory 128m --cpus 0.25 --pids-limit 64 \
    --user "$(stat -c '%u:%g' "$rs_trial_directory")" --entrypoint ruby \
    --mount "type=bind,source=$rs_trial_directory,target=/trial,readonly" \
    --mount "type=bind,source=$rs_operations_directory/validate_trial.rb,target=/prepare.rb,readonly" \
    "$rs_candidate_image" /prepare.rb validate /trial)
  test "$rs_project" = "$rs_expected_project"

  docker compose --project-name "$rs_expected_project" --project-directory "$rs_trial_directory" \
    -f "$rs_trial_directory/compose.yml" config --format json > "$rs_work_directory/original.json"
  candidate_compose config --format json > "$rs_work_directory/effective.json"
  docker run --rm --pull never --runtime runc --network none --read-only --cap-drop ALL \
    --security-opt no-new-privileges --memory 256m --cpus 0.5 --pids-limit 64 --user 0:0 --entrypoint ruby \
    --mount "type=bind,source=$rs_work_directory,target=/checks,readonly" \
    --mount "type=bind,source=$rs_plan_directory/candidate.json,target=/activated.json,readonly" \
    --mount "type=bind,source=$rs_operations_directory/restart_configuration.rb,target=/restart_configuration.rb,readonly" \
    --mount "type=bind,source=$rs_operations_directory/candidate_configuration.rb,target=/candidate_configuration.rb,readonly" \
    "$rs_candidate_image" /restart_configuration.rb /checks/original.json /checks/effective.json /activated.json \
    "$rs_expected_project" "$rs_published_image" "$rs_candidate_image" > "$rs_work_directory/configuration-check.json"
  test -s "$rs_work_directory/configuration-check.json"
}

candidate_check_containers() {
  candidate_validate_container "$rs_web_container" rs_server_webapp
  candidate_validate_container "$rs_access_container" access
  candidate_validate_container "$rs_database_container" database
  candidate_validate_container "$rs_mailpit_container" mailpit
  candidate_validate_container "$rs_setup_container" rs_server_setup
  test "$(docker inspect --format '{{.Image}}' "$rs_web_container")" = "$rs_candidate_image"
  test "$(docker inspect --format '{{index .Config.Labels "org.opencontainers.image.revision"}}' "$rs_web_container")" = "$rs_source_revision"
  test "$(candidate_compose ps --all --quiet rs_server_webapp)" = "$rs_web_container"
  test "$(candidate_compose ps --all --quiet access)" = "$rs_access_container"
  test "$(candidate_compose ps --all --quiet database)" = "$rs_database_container"
  test "$(candidate_compose ps --all --quiet mailpit)" = "$rs_mailpit_container"
  test "$(candidate_compose ps --all --quiet rs_server_setup)" = "$rs_setup_container"
  candidate_require_health "$rs_database_container"
  test "$(docker inspect --format '{{.State.Running}}' "$rs_mailpit_container")" = true
  test "$(docker inspect --format '{{.State.Running}} {{.State.ExitCode}}' "$rs_setup_container")" = 'false 0'
}

candidate_restart_finish() {
  rs_status=$?
  trap - EXIT HUP INT TERM
  if [ "$rs_completed" != yes ]; then
    if [ "$rs_maintenance_started" = yes ]; then
      if docker stop -t 30 "$rs_access_container" >> "$rs_work_directory/recovery.log" 2>&1; then
        printf '%s\n' 'Candidate restart failed. Access was kept stopped; inspect the private diagnostics before reopening it.' >&2
      else
        printf '%s\n' 'Candidate restart failed and access could not be stopped automatically; operator attention is required.' >&2
      fi
    else
      printf '%s\n' 'Candidate checks failed before maintenance; no trial service was stopped or started.' >&2
    fi
    printf 'Private diagnostics: %s. Do not paste or upload their contents.\n' "$rs_work_directory" >&2
  fi
  exit "$rs_status"
}

candidate_restart_execute() {
  candidate_validate_configuration
  rs_web_container=$(candidate_compose ps --all --quiet rs_server_webapp)
  rs_access_container=$(candidate_compose ps --all --quiet access)
  rs_database_container=$(candidate_compose ps --all --quiet database)
  rs_mailpit_container=$(candidate_compose ps --all --quiet mailpit)
  rs_setup_container=$(candidate_compose ps --all --quiet rs_server_setup)
  candidate_check_containers

  if [ "$rs_operation" = restart ]; then
    rs_maintenance_started=yes
    docker stop -t 30 "$rs_access_container" > /dev/null
    docker stop -t 30 "$rs_web_container" > /dev/null
    docker start "$rs_web_container" > /dev/null
    candidate_wait_for_health "$rs_web_container"
    docker exec "$rs_web_container" ./bin/rails deployment:check
    candidate_validate_configuration
    candidate_check_containers
    docker start "$rs_access_container" > /dev/null
    candidate_wait_for_health "$rs_access_container"
  fi

  candidate_check_containers
  candidate_require_health "$rs_web_container"
  candidate_require_health "$rs_access_container"
}

candidate_restart_main() {
  test "$(id -u)" = 0
  test "$(uname -s)" = Linux
  test "$#" -eq 1
  case "$1" in check|restart) rs_operation=$1 ;; *) return 64 ;; esac
  printf '%s\n' "$rs_expected_project" | LC_ALL=C grep -Eq '^rs-private-[0-9a-f]{12}$'
  printf '%s\n' "$rs_candidate_image" | LC_ALL=C grep -Eq '^sha256:[0-9a-f]{64}$'
  printf '%s\n' "$rs_source_revision" | LC_ALL=C grep -Eq '^[0-9a-f]{40}$'
  for rs_directory in "$rs_trial_directory" "$rs_plan_directory" "$rs_operations_directory"; do
    test -d "$rs_directory"
    test ! -L "$rs_directory"
  done
  test "$(stat -c '%u:%a' "$rs_plan_directory")" = 0:700
  for rs_name in candidate-images.yml candidate.json; do
    test -f "$rs_plan_directory/$rs_name"
    test ! -L "$rs_plan_directory/$rs_name"
  done
  printf '%s  %s\n' "$rs_override_sha256" "$rs_plan_directory/candidate-images.yml" | sha256sum --check --status
  if [ -e "$rs_lock_file" ]; then
    test -f "$rs_lock_file"
    test ! -L "$rs_lock_file"
  fi
  exec 9> "$rs_lock_file"
  flock -n 9
  test "$(docker image inspect --format '{{.Id}}' "$rs_candidate_image")" = "$rs_candidate_image"
  test "$(docker image inspect --format '{{index .Config.Labels "org.opencontainers.image.revision"}}' "$rs_candidate_image")" = "$rs_source_revision"

  rs_work_directory=$(mktemp -d /var/tmp/rs-server-candidate-restart.XXXXXX)
  rs_maintenance_started=no
  rs_completed=no
  trap candidate_restart_finish EXIT
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM

  candidate_restart_execute > "$rs_work_directory/output.log" 2> "$rs_work_directory/errors.log"
  rs_completed=yes
  printf '{"status":"passed","operation":"%s","image_id":"%s","configuration_matches_activation":true,"health_verified":true,"existing_containers_reused":true,"migrations_run":false,"images_pulled_or_built":false,"database_or_mailpit_restarted":false,"database_content_fingerprints_checked":false}\n' \
    "$rs_operation" "$rs_candidate_image"
  printf 'Private diagnostics retained at %s; do not paste or upload their contents.\n' "$rs_work_directory"
}
