# Loaded by a verified host specific Bash wrapper with public paths and exact identities.

export_as_nas_user() { runuser -u "$rs_nas_user" -- "$@"; }

export_verify_nas() {
  [[ -d "$rs_nas_parent" && ! -L "$rs_nas_parent" ]] || return 1
  [[ $(findmnt --target "$rs_nas_parent" --types nfs4 --noheadings --output SOURCE) == "$rs_nas_source" ]] || return 1
  export_as_nas_user test -d "$rs_nas_root" || return 1
  export_as_nas_user test ! -L "$rs_nas_root" || return 1
  [[ $(export_as_nas_user stat -c %a "$rs_nas_root") == 700 ]] || return 1
  export_as_nas_user test -w "$rs_nas_root"
}

export_check_backup() {
  [[ -d "$rs_backup" && ! -L "$rs_backup" && $(stat -c '%u:%a' "$rs_backup") == 0:700 ]] || return 1
  python3 -B "$rs_package/deployment_backup_export.py" "$rs_backup" "$rs_active_directory" \
    "$rs_expected_project" "$rs_candidate_image" "$rs_source_revision" > /dev/null
}

export_finish() {
  rs_exit=$?
  trap - EXIT HUP INT TERM
  if [[ -n "$rs_work_directory" ]]; then
    case "$rs_work_directory" in "$rs_state_directory"/diagnostics/nas-copy.??????) ;; *) exit 1 ;; esac
    if [[ -d "$rs_work_directory" && ! -L "$rs_work_directory" && $(stat -c '%u:%a' "$rs_work_directory") == 0:700 ]]; then
      # Only the redundant plaintext archive made by this invocation is removed.
      rm -f -- "$rs_work_directory/backup.tar" || rs_exit=1
      gpgconf --homedir "$rs_work_directory/gnupg" --kill gpg-agent > /dev/null 2>&1 || true
    else
      rs_exit=1
    fi
  fi
  if [[ $rs_exit != 0 || $rs_success != yes ]]; then
    printf 'Encrypted layout copy not confirmed; stage: %s. Original backups were retained.\n' "$rs_stage" >&2
    [[ -z "$rs_destination" ]] || printf 'An incomplete encrypted copy may remain at %s\n' "$rs_destination" >&2
    exit 1
  fi
  cat "$rs_work_directory/report.json"
  printf '\nEncrypted layout backup verified at %s/backup.tar.gpg\n' "$rs_destination"
  printf '%s\n' 'Keep the passphrase separately. This exports the recorded migration backup, not a new live backup.'
}

export_archive_and_copy() {
  rs_work_directory=$(mktemp -d "$rs_state_directory/diagnostics/nas-copy.XXXXXX") || return 1
  mkdir -m 700 "$rs_work_directory/gnupg" || return 1
  rs_stage=protected_archive
  rs_backup_files=(database.dump publications.tar.gz source-configuration.tar.gz new-configuration.tar.gz
    mailpit-tmp.tar.gz source-definition.json source-containers.json manifest.json runtime-files.json
    database-fingerprint.jsonl publication-fingerprint.json)
  tar -C "$rs_backup" -cf "$rs_work_directory/backup.tar" -- COMPLETE SHA256SUMS "${rs_backup_files[@]}" || return 1
  rs_plain_sha=$(sha256sum "$rs_work_directory/backup.tar" | cut -d ' ' -f 1) || return 1
  export_check_backup || return 1
  rs_stage=encryption
  printf '%s\n' 'Keep the passphrase in your password manager, never in this directory or in chat.'
  printf '%s\n' 'GnuPG asks for encryption and then independent decryption verification. Input is hidden.'
  gpg --no-options --homedir "$rs_work_directory/gnupg" --no-symkey-cache --pinentry-mode loopback \
    --cipher-algo AES256 --compress-algo none --symmetric \
    --output "$rs_work_directory/backup.tar.gpg" "$rs_work_directory/backup.tar" || return 1
  rs_stage=decryption_verification
  rs_verified_sha=$(gpg --no-options --homedir "$rs_work_directory/gnupg" --no-symkey-cache --pinentry-mode loopback \
    --decrypt "$rs_work_directory/backup.tar.gpg" | sha256sum | cut -d ' ' -f 1) || return 1
  [[ "$rs_plain_sha" == "$rs_verified_sha" ]] || return 1
  rm -- "$rs_work_directory/backup.tar" || return 1
  rs_cipher_sha=$(sha256sum "$rs_work_directory/backup.tar.gpg" | cut -d ' ' -f 1) || return 1
  rs_cipher_bytes=$(stat -c %s "$rs_work_directory/backup.tar.gpg") || return 1
  rs_stage=nas_copy
  export_verify_nas || return 1
  rs_destination=$(export_as_nas_user mktemp -d "$rs_nas_root/rs-server-layout-2.0.4-$(date -u '+%Y%m%dT%H%M%SZ').XXXXXX") || return 1
  [[ "$rs_destination" == "$rs_nas_root"/rs-server-layout-2.0.4-* ]] || return 1
  [[ $(export_as_nas_user stat -c %a "$rs_destination") == 700 ]] || return 1
  export_as_nas_user sh -c 'umask 077; set -C; cat > "$1/backup.tar.gpg.partial"' sh "$rs_destination" \
    < "$rs_work_directory/backup.tar.gpg" || return 1
  [[ $(export_as_nas_user sha256sum "$rs_destination/backup.tar.gpg.partial" | cut -d ' ' -f 1) == "$rs_cipher_sha" ]] || return 1
  [[ $(export_as_nas_user stat -c %a "$rs_destination/backup.tar.gpg.partial") == 600 ]] || return 1
  export_as_nas_user mv -n -- "$rs_destination/backup.tar.gpg.partial" "$rs_destination/backup.tar.gpg" || return 1
  printf '%s  backup.tar.gpg\n' "$rs_cipher_sha" | export_as_nas_user sh -c 'umask 077; set -C; cat > "$1/SHA256SUMS"' sh "$rs_destination" || return 1
  export_as_nas_user sync "$rs_destination/backup.tar.gpg" "$rs_destination/SHA256SUMS" || return 1
  rs_stage=final_verification
  export_verify_nas || return 1
  export_check_backup || return 1
  [[ $(export_as_nas_user sha256sum "$rs_destination/backup.tar.gpg" | cut -d ' ' -f 1) == "$rs_cipher_sha" ]] || return 1
  printf '{"status":"encrypted_layout_nas_copy_verified","recorded_at":"%s","cipher":"OpenPGP AES256 symmetric encryption with GnuPG","ciphertext_sha256":"%s","ciphertext_bytes":%s,"recorded_isolated_restore_matches_backup":true,"decryption_round_trip_verified_before_transfer":true,"nas_ciphertext_checksum_verified_after_transfer":true,"separate_nfs_server_verified":true,"off_host_copy":true,"plaintext_or_passphrase_written_to_nas":false,"passphrase_saved_by_script":false,"temporary_plaintext_archive_removed":true,"original_backups_retained":true,"application_services_stopped_or_replaced_by_export":false,"new_live_backup_created":false,"recurring_backups_configured":false,"full_application_restore_from_nas_copy_rehearsed":false}\n' \
    "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$rs_cipher_sha" "$rs_cipher_bytes" > "$rs_work_directory/report.json" || return 1
  rs_success=yes
}

deployment_backup_export_main() {
  [[ $(id -u) == 0 && $(uname -s) == Linux && $# == 1 && $1 == --confirm-encrypted-copy ]] || return 64
  [[ -t 0 && -t 2 ]] || { printf '%s\n' 'An interactive terminal is required for the passphrase.' >&2; return 64; }
  umask 077
  rs_work_directory=
  rs_destination=
  rs_success=no
  rs_stage=preflight
  trap export_finish EXIT
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM
  for rs_directory in "$rs_state_directory" "$rs_state_directory/diagnostics" "$rs_state_directory/backups" "$rs_active_directory"; do
    [[ -d "$rs_directory" && ! -L "$rs_directory" && $(stat -c '%u:%a' "$rs_directory") == 0:700 ]] || return 1
  done
  [[ -f "$rs_active_directory/backup-directory" && ! -L "$rs_active_directory/backup-directory" ]] || return 1
  [[ $(stat -c '%u:%a' "$rs_active_directory/backup-directory") == 0:600 ]] || return 1
  IFS= read -r rs_backup < "$rs_active_directory/backup-directory" || return 1
  [[ "$rs_backup" =~ ^/var/opt/readersourcing/rs-server/backups/layout\.[A-Za-z0-9]{6}$ ]] || return 1
  [[ -f "$rs_state_directory/deployment.lock" && ! -L "$rs_state_directory/deployment.lock" ]] || return 1
  [[ $(stat -c '%u:%a' "$rs_state_directory/deployment.lock") == 0:600 ]] || return 1
  exec 9<> "$rs_state_directory/deployment.lock" || return 1
  flock -n 9 || return 1
  export_check_backup || return 1
  export_verify_nas || return 1
  export_archive_and_copy
}
