# Loaded after the verified restart and startup functions. Configuration and locks use only the final paths.

startup_inventory() {
  test "$1" = check
  docker inspect "$rs_access_container" "$rs_database_container" "$rs_mailpit_container" \
    "$rs_setup_container" "$rs_web_container" > "$rs_work_directory/inspection.json"
  docker run --rm --pull never --runtime runc --network none --read-only --cap-drop ALL \
    --security-opt no-new-privileges --memory 256m --cpus 0.5 --pids-limit 64 --user 0:0 --entrypoint ruby \
    --mount "type=bind,source=$rs_work_directory,target=/checks,readonly" \
    --mount "type=bind,source=$rs_plan_directory,target=/plan,readonly" \
    --mount "type=bind,source=$rs_operations_directory,target=/definition,readonly" \
    "$rs_candidate_image" -rbundler/setup /definition/deployment_startup_inventory.rb /checks/inspection.json "$2" \
    /plan/definition.json "$rs_expected_project" "$rs_candidate_image" "$rs_source_revision"
}

candidate_compose() {
  docker compose --project-name "$rs_expected_project" --project-directory "$rs_trial_directory" \
    -f "$rs_trial_directory/compose.json" "$@"
}

candidate_prepare_context() {
  for rs_directory in "$rs_trial_directory" "$rs_plan_directory" "$rs_state_directory" "$rs_state_directory/diagnostics"; do
    test -d "$rs_directory" && test ! -L "$rs_directory"
    test "$(stat -c '%u:%a' "$rs_directory")" = 0:700
  done
  test -f "$rs_lock_file" && test ! -L "$rs_lock_file"
  test "$(stat -c '%u:%a' "$rs_lock_file")" = 0:600
  exec 9> "$rs_lock_file"
  flock -n 9
  test "$(docker image inspect --format '{{.Id}}' "$rs_candidate_image")" = "$rs_candidate_image"
  test "$(docker image inspect --format '{{index .Config.Labels "org.opencontainers.image.revision"}}' "$rs_candidate_image")" = "$rs_source_revision"
}

candidate_validate_configuration() {
  candidate_compose config --format json > "$rs_work_directory/effective.json"
  docker run --rm --pull never --runtime runc --network none --read-only --cap-drop ALL --cap-add DAC_OVERRIDE \
    --security-opt no-new-privileges --memory 256m --cpus 0.5 --pids-limit 64 --user 0:0 --entrypoint ruby \
    --mount "type=bind,source=$rs_operations_directory,target=/definition,readonly" \
    --mount "type=bind,source=$rs_trial_directory,target=/configuration,readonly" \
    --mount "type=bind,source=$rs_plan_directory,target=/state,readonly" \
    --mount "type=bind,source=$rs_work_directory,target=/checks,readonly" \
    "$rs_candidate_image" -rbundler/setup /definition/deployment_layout_files.rb configuration
}

candidate_resolve_containers() {
  rs_web_container=$(candidate_compose ps --all --quiet rs_server_webapp)
  rs_access_container=$(candidate_compose ps --all --quiet access)
  rs_database_container=$(candidate_compose ps --all --quiet database)
  rs_mailpit_container=$(candidate_compose ps --all --quiet mailpit)
  # The completed historical setup is retained for inspection, never as a startup dependency.
  rs_setup_container=$(docker ps --all --quiet --filter "label=com.docker.compose.project=$rs_expected_project" --filter label=com.docker.compose.service=rs_server_setup)
}

candidate_check_identities() {
  candidate_validate_container "$rs_web_container" rs_server_webapp
  candidate_validate_container "$rs_access_container" access
  candidate_validate_container "$rs_database_container" database
  candidate_validate_container "$rs_mailpit_container" mailpit
  candidate_validate_container "$rs_setup_container" rs_server_setup
  test "$(docker inspect --format '{{.Image}}' "$rs_web_container")" = "$rs_candidate_image"
  test "$(docker inspect --format '{{index .Config.Labels "org.opencontainers.image.revision"}}' "$rs_web_container")" = "$rs_source_revision"
  test "$(docker inspect --format '{{.State.Running}} {{.State.ExitCode}}' "$rs_setup_container")" = 'false 0'
  test "$(docker ps --all --quiet --filter "label=com.docker.compose.project=$rs_expected_project" | wc -l)" -eq 5
}

deployment_operations_main() {
  test "$(id -u)" = 0 && test "$(uname -s)" = Linux
  test "$#" -eq 1
  case "$1" in check|start|restart) rs_operation=$1 ;; *) return 64 ;; esac
  candidate_prepare_context
  rs_work_directory=$(mktemp -d "$rs_state_directory/diagnostics/operation.XXXXXX")
  rs_completed=no
  rs_maintenance_started=no
  trap startup_finish EXIT
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM
  deployment_execute > "$rs_work_directory/output.log" 2> "$rs_work_directory/errors.log"
  rs_completed=yes
  printf '{"status":"passed","operation":"%s","image_id":"%s","configuration_and_inventory_verified":true,"health_verified":true,"existing_service_containers_reused":true,"migrations_run":false,"images_pulled_or_built":false,"automatic_startup_configured":false,"host_rebooted":false}\n' "$rs_operation" "$rs_candidate_image"
  printf 'Protected diagnostics: %s; do not paste or upload their contents.\n' "$rs_work_directory"
}

deployment_execute() {
  candidate_validate_configuration
  candidate_resolve_containers
  candidate_check_identities
  startup_inventory check /plan/startup-inventory.json
  case "$rs_operation" in
    check) candidate_restart_execute ;;
    restart) candidate_restart_execute ;;
    start) startup_execute ;;
  esac
  startup_validate
  startup_require_ready
}
