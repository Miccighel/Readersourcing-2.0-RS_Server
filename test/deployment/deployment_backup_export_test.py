import contextlib
import copy
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[2] / "deploy/private/deployment_backup_export.py"
SPEC = importlib.util.spec_from_file_location("backup_export", SCRIPT)
EXPORT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(EXPORT)


class DeploymentBackupExportTest(unittest.TestCase):
    PROJECT = "rs-private-0123456789ab"
    IMAGE = "sha256:" + "a" * 64
    REVISION = "b" * 40

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="rs-export-test.")
        self.root = Path(self.directory.name)
        self.backup, self.active = self.root / "backup", self.root / "active"
        self.backup.mkdir()
        self.active.mkdir()
        for name in EXPORT.BACKUP_FILES:
            (self.backup / name).write_text("synthetic-private-value")
        self.identity = {"project": self.PROJECT, "application_image": self.IMAGE, "source_revision": self.REVISION}
        self.write_json(self.backup / "manifest.json", self.identity)
        self.write_json(self.active / "settings.json", self.identity)
        self.inventory = {"sha256": "c" * 64, "files": 24, "directories": 24, "bytes": 100}
        self.write_json(self.backup / "publication-fingerprint.json", self.inventory)
        (self.backup / "COMPLETE").write_text("complete")
        (self.active / "backup-directory").write_text(str(self.backup) + "\n")
        self.report = {"status": "recovery_rehearsal_passed", "source_project": self.PROJECT,
                       "backup_image": self.IMAGE, "restored_application_image": self.IMAGE,
                       "database_fingerprint_sha256": EXPORT.digest(self.backup / "database-fingerprint.jsonl"),
                       "publication_inventory": self.inventory, "probe": {"status": "passed"}}
        for key in ("database_and_sequences_match_backup", "publication_inventory_matches_backup_before_probes",
                    "database_unchanged_after_probes", "source_container_identities_and_lifecycle_unchanged",
                    "recovery_services_stopped_after_checks"):
            self.report[key] = True
        for key in ("migrations_run", "ports_published", "images_pulled_or_built"):
            self.report[key] = False
        self.write_json(self.active / "recovery-latest.json", self.report)
        self.checksums()

    def tearDown(self):
        self.directory.cleanup()

    def write_json(self, path, value):
        path.write_text(json.dumps(value))

    def checksums(self):
        (self.backup / "SHA256SUMS").write_text("".join(
            EXPORT.digest(self.backup / name) + "  " + name + "\n" for name in EXPORT.BACKUP_FILES))

    def verify(self):
        return EXPORT.verify(self.backup, self.active, self.PROJECT, self.IMAGE, self.REVISION)

    def test_matching_backup_and_completed_restore_pass_without_disclosing_values_or_writing_inputs(self):
        before = {str(path): hashlib.sha256(path.read_bytes()).hexdigest()
                  for path in self.root.rglob("*") if path.is_file()}
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            result = self.verify()
        self.assertEqual("layout_backup_export_inputs_verified", result["status"])
        self.assertEqual(11, result["backup_files_checked"])
        self.assertFalse(result["new_live_backup_created"])
        self.assertEqual("", output.getvalue())
        self.assertNotIn("synthetic-private-value", json.dumps(result))
        self.assertEqual(before, {str(path): hashlib.sha256(path.read_bytes()).hexdigest()
                                 for path in self.root.rglob("*") if path.is_file()})

    def test_changed_payload_is_rejected(self):
        (self.backup / "database.dump").write_text("changed")
        with self.assertRaises(ValueError):
            self.verify()

    def test_missing_duplicate_or_unsafe_checksum_entries_are_rejected(self):
        manifest = self.backup / "SHA256SUMS"
        original = manifest.read_text()
        for text in (original + original.splitlines()[0] + "\n", "\n".join(original.splitlines()[1:]),
                     original.replace("database.dump", "../database.dump")):
            manifest.write_text(text)
            with self.assertRaises(ValueError):
                self.verify()

    def test_symbolic_payload_and_marker_are_rejected(self):
        for name in ("database.dump", "COMPLETE", "SHA256SUMS"):
            with self.subTest(name=name):
                path = self.backup / name
                saved = path.read_bytes()
                path.unlink()
                path.symlink_to(self.active / "settings.json")
                with self.assertRaises(ValueError):
                    self.verify()
                path.unlink()
                path.write_bytes(saved)

    def test_incomplete_marker_including_dangling_link_is_rejected(self):
        marker = self.backup / "INCOMPLETE"
        marker.symlink_to(self.root / "missing")
        with self.assertRaises(ValueError):
            self.verify()

    def test_pointer_must_select_exact_backup(self):
        (self.active / "backup-directory").write_text(str(self.backup) + "\nextra\n")
        with self.assertRaises(ValueError):
            self.verify()

    def test_project_image_and_revision_must_match_active_and_backup_records(self):
        for path in (self.active / "settings.json", self.backup / "manifest.json"):
            for key in self.identity:
                changed = dict(self.identity, **{key: "foreign"})
                self.write_json(path, changed)
                self.checksums()
                with self.assertRaises(ValueError):
                    self.verify()
                self.write_json(path, self.identity)
                self.checksums()

    def test_recovery_identity_and_fingerprints_must_match_exported_backup(self):
        for key in ("status", "source_project", "backup_image", "restored_application_image",
                    "database_fingerprint_sha256", "publication_inventory", "probe"):
            changed = copy.deepcopy(self.report)
            changed[key] = {} if key in ("probe", "publication_inventory") else "foreign"
            self.write_json(self.active / "recovery-latest.json", changed)
            with self.assertRaises(ValueError):
                self.verify()

    def test_recovery_success_flags_require_literal_booleans(self):
        for key, original in self.report.items():
            if type(original) is not bool:
                continue
            for value in (None, int(original), str(original), not original):
                self.write_json(self.active / "recovery-latest.json", dict(self.report, **{key: value}))
                with self.assertRaises(ValueError):
                    self.verify()

    def test_cli_failure_does_not_display_private_paths_values_or_tracebacks(self):
        (self.backup / "manifest.json").write_text("synthetic-private-value")
        self.checksums()
        result = subprocess.run(["python3", "-B", str(SCRIPT), str(self.backup), str(self.active),
                                 self.PROJECT, self.IMAGE, self.REVISION], capture_output=True, text=True)
        self.assertEqual(1, result.returncode)
        self.assertEqual("", result.stdout)
        self.assertEqual("Backup export validation failed; private values were not displayed.\n", result.stderr)

    def test_shell_is_valid_and_copies_only_ciphertext_without_service_mutations(self):
        shell = SCRIPT.with_suffix(".sh")
        result = subprocess.run(["bash", "-n", str(shell)], capture_output=True, text=True)
        self.assertEqual(0, result.returncode, result.stderr)
        source = shell.read_text()
        self.assertNotIn("docker ", source)
        self.assertNotIn("--passphrase", source)
        self.assertIn("--no-symkey-cache", source)
        self.assertIn("--decrypt", source)
        self.assertIn('< "$rs_work_directory/backup.tar.gpg"', source)
        self.assertIn('exec 9<> "$rs_state_directory/deployment.lock"', source)
        main = source[source.index("deployment_backup_export_main() {"):]
        self.assertLess(main.index("  export_check_backup || return 1"), main.index("  export_archive_and_copy"))
        self.assertLess(source.index('[[ "$rs_plain_sha" == "$rs_verified_sha" ]]'), source.index("rs_stage=nas_copy"))

    def run_export_flow(self, mode):
        state, nas = self.root / "state", self.root / "nas"
        state.mkdir()
        (state / "diagnostics").mkdir()
        nas.mkdir(mode=0o700)
        self.backup.chmod(0o700)
        # GnuPG and NFS are simulated. These tests exercise sequencing and failure cleanup, not encryption.
        shell = r'''
set -euo pipefail
umask 077
. "$RS_SCRIPT"
rs_state_directory="$RS_ROOT/state"
rs_active_directory="$RS_ROOT/active"
rs_backup="$RS_ROOT/backup"
rs_package="$RS_PACKAGE"
rs_expected_project="$RS_PROJECT"
rs_candidate_image="$RS_IMAGE"
rs_source_revision="$RS_REVISION"
rs_nas_root="$RS_ROOT/nas"
rs_work_directory=
rs_destination=
rs_success=no
rs_stage=preflight
stat() {
  python3 -c 'import os,sys; p=os.stat(sys.argv[-1]); print({"%u:%a":"0:"+oct(p.st_mode & 0o777)[2:], "%a":oct(p.st_mode & 0o777)[2:], "%s":str(p.st_size)}[sys.argv[2]])' "$@"
}
export_verify_nas() { :; }
export_as_nas_user() {
  if [[ $RS_MODE == transfer_corruption && $1 == sha256sum && $2 == *.partial ]]; then
    printf '%064d  synthetic\n' 0
  else
    "$@"
  fi
}
sync() { :; }
gpgconf() { :; }
gpg() {
  local decrypt=no output= last= argument
  while [[ $# -gt 0 ]]; do
    argument=$1; shift
    case "$argument" in
      --decrypt) decrypt=yes ;;
      --output) output=$1; shift ;;
      *) last=$argument ;;
    esac
  done
  if [[ $decrypt == yes ]]; then
    [[ $RS_MODE != decrypt_failure ]] || return 23
    if [[ $RS_MODE == wrong_passphrase ]]; then printf 'mismatch'; else cat "$last"; fi
  else
    [[ $RS_MODE != encryption_failure ]] || return 24
    cp "$last" "$output"
  fi
}
trap export_finish EXIT
export_check_backup
export_verify_nas
export_archive_and_copy
'''
        result = subprocess.run(["bash", "-c", shell], capture_output=True, text=True, env={**os.environ,
            "RS_SCRIPT": str(SCRIPT.with_suffix(".sh")), "RS_ROOT": str(self.root),
            "RS_PACKAGE": str(SCRIPT.parent), "RS_PROJECT": self.PROJECT, "RS_IMAGE": self.IMAGE,
            "RS_REVISION": self.REVISION, "RS_MODE": mode})
        self.assertFalse(list((state / "diagnostics").glob("nas-copy.*/backup.tar")))
        self.assertTrue((self.backup / "database.dump").is_file())
        self.assertTrue((self.backup / "COMPLETE").is_file())
        return result, nas

    def test_export_flow_retains_original_and_publishes_verified_new_destination(self):
        result, nas = self.run_export_flow("success")
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn('"status":"encrypted_layout_nas_copy_verified"', result.stdout)
        self.assertEqual(1, len(list(nas.glob("*/backup.tar.gpg"))))
        self.assertFalse(list(nas.glob("*/*.partial")))

    def test_encryption_failure_removes_temporary_plaintext_without_transfer(self):
        result, nas = self.run_export_flow("encryption_failure")
        self.assertNotEqual(0, result.returncode)
        self.assertIn("stage: encryption", result.stderr)
        self.assertEqual([], list(nas.iterdir()))
        self.assertNotIn('"status":"encrypted_layout_nas_copy_verified"', result.stdout)

    def test_decryption_failure_removes_temporary_plaintext_without_transfer(self):
        result, nas = self.run_export_flow("decrypt_failure")
        self.assertNotEqual(0, result.returncode)
        self.assertIn("stage: decryption_verification", result.stderr)
        self.assertEqual([], list(nas.iterdir()))

    def test_wrong_passphrase_comparison_stops_before_transfer(self):
        result, nas = self.run_export_flow("wrong_passphrase")
        self.assertNotEqual(0, result.returncode)
        self.assertIn("stage: decryption_verification", result.stderr)
        self.assertEqual([], list(nas.iterdir()))

    def test_corrupted_transfer_retains_only_incomplete_destination_and_reports_failure(self):
        result, nas = self.run_export_flow("transfer_corruption")
        self.assertNotEqual(0, result.returncode)
        self.assertIn("stage: nas_copy", result.stderr)
        self.assertEqual(1, len(list(nas.glob("*/backup.tar.gpg.partial"))))
        self.assertFalse(list(nas.glob("*/backup.tar.gpg")))
        self.assertNotIn('"status":"encrypted_layout_nas_copy_verified"', result.stdout)


if __name__ == "__main__":
    unittest.main()
