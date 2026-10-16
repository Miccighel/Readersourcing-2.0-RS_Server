"""Validate the recorded layout backup locally; never print its private contents."""

import hashlib
import json
import re
import stat
import sys
from pathlib import Path


BACKUP_FILES = (
    "database.dump", "publications.tar.gz", "source-configuration.tar.gz",
    "new-configuration.tar.gz", "mailpit-tmp.tar.gz", "source-definition.json",
    "source-containers.json", "manifest.json", "runtime-files.json",
    "database-fingerprint.jsonl", "publication-fingerprint.json",
)


def ordinary(path, directory=False):
    mode = path.lstat().st_mode
    if not (stat.S_ISDIR(mode) if directory else stat.S_ISREG(mode)):
        raise ValueError("Expected ordinary input")


def digest(path):
    ordinary(path)
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def read_json(path):
    ordinary(path)
    return json.loads(path.read_text())


def verify(backup, active, project, image, revision):
    if not (re.fullmatch(r"rs-private-[0-9a-f]{12}", project)
            and re.fullmatch(r"sha256:[0-9a-f]{64}", image)
            and re.fullmatch(r"[0-9a-f]{40}", revision)):
        raise ValueError("Invalid expected identity")
    ordinary(backup, directory=True)
    ordinary(active, directory=True)
    pointer = active / "backup-directory"
    ordinary(pointer)
    if pointer.read_text() != str(backup) + "\n":
        raise ValueError("Recorded backup differs")
    ordinary(backup / "COMPLETE")
    if (backup / "INCOMPLETE").exists() or (backup / "INCOMPLETE").is_symlink():
        raise ValueError("Incomplete backup")
    checksum_path = backup / "SHA256SUMS"
    ordinary(checksum_path)
    hashes = {}
    for line in checksum_path.read_text().splitlines():
        match = re.fullmatch(r"([0-9a-f]{64})  ([A-Za-z0-9.\-]+)", line)
        if not match or match[2] not in BACKUP_FILES or match[2] in hashes:
            raise ValueError("Unsafe checksum manifest")
        hashes[match[2]] = match[1]
    if set(hashes) != set(BACKUP_FILES):
        raise ValueError("Incomplete checksum manifest")
    for name, expected in hashes.items():
        if digest(backup / name) != expected:
            raise ValueError("Backup checksum differs")
    expected_identity = {"project": project, "application_image": image, "source_revision": revision}
    for record in (read_json(backup / "manifest.json"), read_json(active / "settings.json")):
        if any(record.get(key) != value for key, value in expected_identity.items()):
            raise ValueError("Backup identity differs")
    report = read_json(active / "recovery-latest.json")
    if (report.get("status") != "recovery_rehearsal_passed"
            or report.get("source_project") != project
            or report.get("backup_image") != image
            or report.get("restored_application_image") != image):
        raise ValueError("Recovery identity differs")
    for key in ("database_and_sequences_match_backup", "publication_inventory_matches_backup_before_probes",
                "database_unchanged_after_probes", "source_container_identities_and_lifecycle_unchanged",
                "recovery_services_stopped_after_checks"):
        if report.get(key) is not True:
            raise ValueError("Recovery not verified")
    for key in ("migrations_run", "ports_published", "images_pulled_or_built"):
        if report.get(key) is not False:
            raise ValueError("Unexpected recovery scope")
    if report.get("probe", {}).get("status") != "passed":
        raise ValueError("Application probe not verified")
    if report.get("database_fingerprint_sha256") != hashes["database-fingerprint.jsonl"]:
        raise ValueError("Recovery database differs")
    if report.get("publication_inventory") != read_json(backup / "publication-fingerprint.json"):
        raise ValueError("Recovery publications differ")
    return {"status": "layout_backup_export_inputs_verified", "backup_files_checked": len(hashes),
            "recorded_isolated_restore_matches_backup": True, "new_live_backup_created": False}


if __name__ == "__main__":
    try:
        if len(sys.argv) != 6:
            raise ValueError("Expected export inputs")
        print(json.dumps(verify(Path(sys.argv[1]), Path(sys.argv[2]), *sys.argv[3:])))
    except Exception:
        print("Backup export validation failed; private values were not displayed.", file=sys.stderr)
        sys.exit(1)
