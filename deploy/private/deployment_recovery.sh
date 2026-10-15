# Loaded after recovery_rehearsal.sh and the neutral deployment functions.

recovery_check_source() {
  sh "$rs_operations_directory/rs-server" check
}

recovery_export_source_configuration() {
  candidate_compose config --format json > "$rs_work_directory/original.json"
}

recovery_runtime_owner() {
  stat -c '%u:%g' "$rs_trial_directory/runtime/smtp.key"
}

recovery_export_report() {
  test ! -L "$rs_plan_directory/recovery-latest.json"
  install -m 600 "$rs_work_directory/report.json" "$rs_plan_directory/recovery-latest.json"
  cat "$rs_plan_directory/recovery-latest.json"
}

deployment_recovery_main() {
  test "$#" -eq 1 && test "$1" = --confirm-isolated-restore
  candidate_prepare_context
  test -f "$rs_plan_directory/backup-directory" && test ! -L "$rs_plan_directory/backup-directory"
  test "$(stat -c '%u:%a' "$rs_plan_directory/backup-directory")" = 0:600
  IFS= read -r rs_backup_directory < "$rs_plan_directory/backup-directory"
  case "$rs_backup_directory" in "$rs_state_directory"/backups/layout.??????) ;; *) return 64 ;; esac
  test -d "$rs_backup_directory" && test ! -L "$rs_backup_directory"
  test "$(stat -c '%u:%a' "$rs_backup_directory")" = 0:700
  rs_backup_image=$rs_candidate_image
  # The common options include this legacy field; the layout adapter does not use a published image.
  rs_published_image=
  rs_recovery_configuration_script=deployment_recovery_configuration.rb
  rs_recovery_diagnostics_directory=$rs_state_directory/diagnostics
  flock -u 9
  recovery_main --confirm-isolated-restore
}
