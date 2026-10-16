"""Read only diagnosis of the recorded installed-command interruption; no raw values leave the host."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import stat

SPEC = importlib.util.spec_from_file_location("layout_diagnostic", Path(__file__).with_name("deployment_layout_diagnostic.py"))
LAYOUT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(LAYOUT)

PUBLIC_FILES = {"candidate_restart.sh", "candidate_startup.sh", "startup_inventory.rb", "publication_fingerprint.rb",
    "database_fingerprint.sql", "deployment_operations.sh", "deployment_layout_configuration.rb", "deployment_layout_inventory.rb",
    "deployment_layout_files.rb", "recovery_rehearsal.sh", "recovery_configuration.rb", "recovery_probe.rb",
    "candidate_configuration.rb", "deployment_recovery.sh", "deployment_recovery_configuration.rb", "OPERATIONS.md", "rs-server"}
PATTERNS = {"inventory_validation": r"Startup inventory check failed|Layout check failed",
    "permission_denied": r"permission denied|PermissionError", "read_only_filesystem": r"read.only file system|rootfs is marked read.only",
    "missing_shell_variable": r"parameter not set|unbound variable", "missing_file": r"No such file or directory|Errno::ENOENT",
    "image_unavailable": r"No such image|pull access denied", "mount_validation": r"invalid mount|invalid volume|error mounting",
    "compose_validation": r"validating |invalid compose|unsupported.*option|unknown flag|undefined network|undefined volume",
    "ruby_dependency_activation": r"already activated|Gem::LoadError|Bundler::GemNotFound"}


def same_json(first, second):
    return json.dumps(first, sort_keys=True) == json.dumps(second, sort_keys=True)


def changed(first, second, allowed):
    keys = {key for key in first.keys() | second.keys() if (key in first) != (key in second) or not same_json(first.get(key), second.get(key))}
    return sorted(keys & allowed) + (["other_fields"] if keys - allowed else [])


def categories(contents):
    return sorted(name for name, pattern in PATTERNS.items() if re.search(pattern, contents, re.I))


def log_tail(path):
    if not path.exists():
        return ""
    if not LAYOUT.regular(path):
        raise ValueError("Unsupported log")
    with path.open("rb") as handle:
        handle.seek(max(0, path.stat().st_size - 128 * 1024))
        return handle.read().decode("utf-8", errors="replace")


def protected_directory(path):
    info = path.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != 0 or stat.S_IMODE(info.st_mode) != 0o700:
        raise ValueError("Unsupported protected directory")


def operation_path(contents, state):
    # Only the exact operation path printed by the failed installed command may be inspected.
    matches = re.findall(r"Private diagnostics: (" + re.escape(str(state)) + r"/diagnostics/operation\.[A-Za-z0-9]{6})\.", contents)
    if not matches:
        return None
    if len(set(matches)) != 1:
        raise ValueError("Ambiguous operation record")
    return Path(matches[0])


def compare_inventory(expected, current):
    host = {key: value for key, value in current["HostConfig"].items() if key != "ConsoleSize"}
    old_host = expected["host"]
    old_mounts, new_mounts = expected["mounts"], current["Mounts"]
    ordered = lambda mounts: sorted(mounts, key=lambda mount: mount["Destination"])
    mount_fields = set()
    by_destination = lambda mounts: {mount["Destination"]: mount for mount in mounts}
    old_by, new_by = by_destination(old_mounts), by_destination(new_mounts)
    for destination in old_by.keys() | new_by.keys():
        mount_fields.update(changed(old_by.get(destination, {}), new_by.get(destination, {}), LAYOUT.LayoutDiagnostic.MOUNT_FIELDS))
    old_oom, new_oom = old_host.get("OomKillDisable"), host.get("OomKillDisable")
    oom = "unchanged"
    if not same_json(old_host, host):
        if "OomKillDisable" in old_host and "OomKillDisable" in host and old_oom is False and new_oom is None:
            oom = "false_to_null"
        elif "OomKillDisable" in old_host and "OomKillDisable" in host and old_oom is None and new_oom is False:
            oom = "null_to_false"
        elif not same_json(old_oom, new_oom) or ("OomKillDisable" in old_host) != ("OomKillDisable" in host):
            oom = "other"
    old_labels = expected["config"].get("Labels", {})
    new_labels = current["Config"].get("Labels", {})
    state = current["State"]
    host_fields = changed(old_host, host, LAYOUT.LayoutDiagnostic.HOST_FIELDS)
    details = [{"field": field, "source_shape": LAYOUT.LayoutDiagnostic.shape(old_host, field),
        "current_shape": LAYOUT.LayoutDiagnostic.shape(host, field)} for field in host_fields if field in LAYOUT.LayoutDiagnostic.HOST_FIELDS]
    return {"same_identity_as_frozen": expected["id"] == current["Id"], "same_image_as_frozen": expected["image"] == current["Image"],
        "same_name_as_frozen": expected["name"] == current["Name"], "running": state["Running"],
        "state": state.get("Status") if state.get("Status") in {"created", "running", "exited", "paused", "restarting", "removing", "dead"} else "unknown",
        "config_difference_fields": changed(expected["config"], current["Config"], LAYOUT.LayoutDiagnostic.CONFIG_FIELDS),
        "label_difference_fields": changed(old_labels, new_labels, LAYOUT.LayoutDiagnostic.LABEL_FIELDS),
        "host_difference_fields": host_fields, "host_difference_details": details,
        "oom_default_transition": oom, "oom_disable_true_present": old_oom is True or new_oom is True,
        "mount_difference_fields": sorted(mount_fields), "ordered_mounts_equal": same_json(ordered(old_mounts), ordered(new_mounts)),
        "networks_equal": expected["networks"] == sorted(current["NetworkSettings"]["Networks"])}


def public_manifest_verified(directory):
    manifest = directory / "OPERATIONS-SHA256SUMS"
    if not LAYOUT.regular(manifest):
        return False
    hashes = {}
    for line in manifest.read_text().splitlines():
        match = re.fullmatch(r"([0-9a-f]{64})  ([A-Za-z0-9_.-]+)", line)
        if not match or match[2] not in PUBLIC_FILES or match[2] in hashes:
            return False
        hashes[match[2]] = match[1]
    return set(hashes) == PUBLIC_FILES and all(LAYOUT.regular(directory / name) and hashlib.sha256((directory / name).read_bytes()).hexdigest() == digest for name, digest in hashes.items())


def recorded_equal(work, first, second):
    paths = [work / first, work / second]
    if not all(path.exists() and LAYOUT.regular(path) for path in paths):
        return None
    return paths[0].read_bytes() == paths[1].read_bytes()


def metadata_matches(path, mode, directory=False):
    try:
        info = path.lstat()
        kind = stat.S_ISDIR(info.st_mode) if directory else stat.S_ISREG(info.st_mode)
        return kind and info.st_uid == 0 and stat.S_IMODE(info.st_mode) == mode
    except OSError:
        return False


def main():
    if os.geteuid() != 0:
        raise ValueError("Root required")
    state = Path("/var/opt/readersourcing/rs-server")
    work = state / "diagnostics/layout-resume.mME6ZV"
    for path in (state, state / "active", work):
        protected_directory(path)
    contents = log_tail(work / "output.log") + "\n" + log_tail(work / "errors.log")
    operation = operation_path(contents, state)
    nested = ""
    if operation is not None:
        protected_directory(operation)
        nested = log_tail(operation / "output.log") + "\n" + log_tail(operation / "errors.log")
    baseline_path = state / "active/startup-inventory.json"
    baseline = LAYOUT.read_json(baseline_path)
    project = "rs-private-8955233c3d65"
    ids = LAYOUT.docker("ps", "--all", "--quiet", "--filter", f"label=com.docker.compose.project={project}").split()
    if len(ids) > 10 or not all(re.fullmatch(r"[0-9a-f]{12,64}", item) for item in ids):
        raise ValueError("Unexpected inspection selection")
    current = json.loads(LAYOUT.docker("inspect", *ids)) if ids else []
    services = {}
    for service in LAYOUT.LayoutDiagnostic.SERVICES:
        entries = [entry for entry in current if entry["Config"]["Labels"].get("com.docker.compose.service") == service and entry["Config"]["Labels"].get("com.docker.compose.project") == project]
        services[service] = {"container_count": len(entries)}
        if len(entries) == 1 and service in baseline:
            services[service].update(compare_inventory(baseline[service], entries[0]))
    configuration = Path("/etc/opt/readersourcing/rs-server")
    permissions = {"operations_parent": metadata_matches(Path("/opt/readersourcing"), 0o755, True),
        "operations": metadata_matches(Path("/opt/readersourcing/rs-server"), 0o755, True),
        "configuration_parent": metadata_matches(Path("/etc/opt/readersourcing"), 0o700, True),
        "configuration": metadata_matches(configuration, 0o700, True),
        "context": metadata_matches(configuration / "context.sh", 0o600),
        "inventory": metadata_matches(baseline_path, 0o600),
        "deployment_lock": metadata_matches(state / "deployment.lock", 0o600)}
    frozen = LAYOUT.read_json(state / "active/definition.json")
    settings = LAYOUT.read_json(state / "active/settings.json")
    context = configuration / "context.sh"
    context_matches = LAYOUT.regular(context) and hashlib.sha256(context.read_bytes()).hexdigest() == LAYOUT.read_json(state / "active/context-sha256.json")["sha256"]
    try:
        backup_ok = LAYOUT.backup_verified(state)
    except (OSError, ValueError):
        backup_ok = False
    print(json.dumps({"status": "read_only_installed_command_diagnostic", "files_or_services_changed": False,
        "private_values_or_log_contents_displayed": False, "installed_public_manifest_verified": public_manifest_verified(Path("/opt/readersourcing/rs-server")),
        "installed_path_permissions_match_requirements": permissions,
        "installed_context_matches_record": context_matches, "installed_definition_matches_record": same_json(frozen, LAYOUT.read_json(configuration / "compose.json")),
        "installed_settings_match_record": same_json(settings, LAYOUT.read_json(configuration / "settings.json")),
        "installed_operation_record_found": operation is not None, "outer_error_categories": categories(contents), "installed_error_categories": categories(nested),
        "installed_effective_configuration_matches_record": None if operation is None or not (operation / "effective.json").exists() else same_json(frozen, LAYOUT.read_json(operation / "effective.json")),
        "recorded_database_fingerprints_equal": recorded_equal(work, "before-database.jsonl", "after-database.jsonl"),
        "recorded_publication_fingerprints_equal": recorded_equal(work, "before-publications.json", "after-publications.json"),
        "backup_archive_checks_passed": backup_ok, "project_container_count": len(current), "services": services}, indent=2))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        print(json.dumps({"status": "diagnostic_not_confirmed", "files_or_services_changed": False, "private_values_or_log_contents_displayed": False}))
        raise SystemExit(1)
