"""Read only, redacted diagnostics for a stopped layout migration."""
import copy
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess


class LayoutDiagnostic:
    SERVICES = ("access", "database", "mailpit", "rs_server_setup", "rs_server_webapp")
    REPLACED = ("access", "mailpit", "rs_server_webapp")
    FILES = {"access": ("proxy.conf",), "database": (), "mailpit": ("smtp.crt", "smtp.key", "smtp.auth", "ui.auth"), "rs_server_webapp": ("smtp.crt",)}
    GENERATED = ("com.docker.compose.config-hash", "com.docker.compose.project.config_files", "com.docker.compose.project.working_dir", "com.docker.compose.replace", "com.docker.compose.depends_on")
    CONFIG_FIELDS = {"Hostname", "Domainname", "User", "AttachStdin", "AttachStdout", "AttachStderr", "ExposedPorts", "Tty", "OpenStdin", "StdinOnce", "Env", "Cmd", "Healthcheck", "ArgsEscaped", "Image", "Volumes", "WorkingDir", "Entrypoint", "NetworkDisabled", "MacAddress", "OnBuild", "Labels", "StopSignal", "StopTimeout", "Shell"}
    HOST_FIELDS = {"Mounts", "Binds", "Runtime", "AutoRemove", "RestartPolicy", "ReadonlyRootfs", "Memory", "MemorySwap", "MemoryReservation", "NanoCpus", "PidsLimit", "SecurityOpt", "CapAdd", "CapDrop", "GroupAdd", "NetworkMode", "IpcMode", "CgroupnsMode", "PortBindings", "Tmpfs", "LogConfig", "ShmSize", "Privileged", "Devices", "DeviceRequests", "ConsoleSize", "Init", "MaskedPaths", "ReadonlyPaths"}
    # Fixed top level JSON names from Moby's HostConfig and embedded Resources schema.
    HOST_FIELDS |= {"ContainerIDFile", "VolumeDriver", "VolumesFrom", "Annotations", "Dns", "DnsOptions", "DnsSearch", "ExtraHosts",
        "Cgroup", "Links", "OomScoreAdj", "PidMode", "PublishAllPorts", "StorageOpt", "UTSMode", "UsernsMode", "Sysctls", "Isolation",
        "CpuShares", "CgroupParent", "BlkioWeight", "BlkioWeightDevice", "BlkioDeviceReadBps", "BlkioDeviceWriteBps",
        "BlkioDeviceReadIOps", "BlkioDeviceWriteIOps", "CpuPeriod", "CpuQuota", "CpuRealtimePeriod", "CpuRealtimeRuntime",
        "CpusetCpus", "CpusetMems", "DeviceCgroupRules", "KernelMemory", "KernelMemoryTCP", "MemorySwappiness", "OomKillDisable",
        "Ulimits", "CpuCount", "CpuPercent", "IOMaximumIOps", "IOMaximumBandwidth"}
    MOUNT_FIELDS = {"Type", "Source", "Destination", "Mode", "RW", "Propagation", "Name", "Driver"}
    LABEL_FIELDS = set(GENERATED) | {"com.docker.compose.image", "com.docker.compose.version", "com.docker.compose.container-number", "com.docker.compose.project", "com.docker.compose.service", "com.docker.compose.oneoff", "org.opencontainers.image.revision", "org.opencontainers.image.version"}
    BACKUP_FILES = {"database.dump", "publications.tar.gz", "source-configuration.tar.gz", "new-configuration.tar.gz", "mailpit-tmp.tar.gz", "source-definition.json", "source-containers.json", "manifest.json", "runtime-files.json", "database-fingerprint.jsonl", "publication-fingerprint.json"}

    def __init__(self, source, target):
        self.source, self.target = source, target

    @staticmethod
    def changed(before, after, allowed):
        keys = {key for key in before.keys() | after.keys() if before.get(key) != after.get(key) or (key in before) != (key in after)}
        return sorted(keys & allowed) + (["other_fields"] if keys - allowed else [])

    @staticmethod
    def shape(mapping, field):
        if field not in mapping:
            return "missing"
        value = mapping[field]
        if value is None:
            return "null"
        if isinstance(value, bool):
            return "boolean"
        if isinstance(value, (int, float)):
            return "zero_number" if value == 0 else "nonzero_number"
        if isinstance(value, str):
            return "empty_string" if not value else "nonempty_string"
        if isinstance(value, list):
            return "empty_array" if not value else "nonempty_array"
        if isinstance(value, dict):
            return "empty_object" if not value else "nonempty_object"
        return "other"

    def host_details(self, before, after):
        fields = self.changed(before, after, self.HOST_FIELDS)
        return [{"field": field, "source_shape": self.shape(before, field), "replacement_shape": self.shape(after, field),
            "null_empty_array_pair": {self.shape(before, field), self.shape(after, field)} == {"null", "empty_array"}}
            for field in fields if field in self.HOST_FIELDS]

    def relocate(self, source, service):
        for name in self.FILES.get(service, ()):
            if source == f"{self.target}/runtime/{name}":
                return f"{self.source}/runtime/{name}"
        return source

    def normalize(self, container, service, replacement):
        item = copy.deepcopy(container)
        config, host = item["Config"], item["HostConfig"]
        config.pop("Image", None)
        if config.get("Hostname") == item["Id"][:12]:
            config["Hostname"] = "<container-id>"
        for key in self.GENERATED:
            config["Labels"].pop(key, None)
        config["Env"] = sorted(config.get("Env") or [])
        host.pop("ConsoleSize", None)
        for mount in host.get("Mounts") or []:
            if replacement and mount["Type"] == "bind":
                mount["Source"] = self.relocate(mount["Source"], service)
        if host.get("Mounts") is not None:
            host["Mounts"].sort(key=lambda mount: mount["Target"])
        if host.get("Binds") is not None:
            binds = []
            for bind in host["Binds"]:
                parts = bind.split(":", 2)
                if replacement:
                    parts[0] = self.relocate(parts[0], service)
                binds.append(":".join(parts))
            host["Binds"] = sorted(binds)
        for mount in item["Mounts"]:
            if replacement and mount["Type"] == "bind":
                mount["Source"] = self.relocate(mount["Source"], service)
        item["Mounts"].sort(key=lambda mount: mount["Destination"])
        return item

    def compare(self, before, after, definition, service):
        old, current = self.normalize(before, service, False), self.normalize(after, service, True)
        labels = after["Config"]["Labels"]
        options = definition["services"].get(service, {})
        expected = sorted(f"{name}:{dependency['condition']}:{str(dependency.get('restart', False)).lower()}" for name, dependency in options.get("depends_on", {}).items() if name in self.REPLACED)
        old_mounts = {mount["Destination"]: mount for mount in old["Mounts"]}
        new_mounts = {mount["Destination"]: mount for mount in current["Mounts"]}
        fields = set()
        for key in old_mounts.keys() | new_mounts.keys():
            fields.update(self.changed(old_mounts.get(key, {}), new_mounts.get(key, {}), self.MOUNT_FIELDS))
        state = after["State"]
        status = state.get("Status")
        return {"same_identity_as_source": before["Id"] == after["Id"], "same_image_as_source": before["Image"] == after["Image"],
            "running": state["Running"], "state": status if status in {"created", "running", "paused", "restarting", "removing", "exited", "dead"} else "unknown",
            "ever_started": not state.get("StartedAt", "").startswith("0001-"),
            "source_lifecycle_preserved": all(before["State"].get(key) == state.get(key) for key in ("Running", "StartedAt")) and before["RestartCount"] == after["RestartCount"],
            "config_difference_fields": self.changed(old["Config"], current["Config"], self.CONFIG_FIELDS),
            "host_difference_fields": self.changed(old["HostConfig"], current["HostConfig"], self.HOST_FIELDS),
            "host_difference_details": self.host_details(old["HostConfig"], current["HostConfig"]),
            "mount_difference_fields": sorted(fields),
            "other_label_difference_fields": self.changed(old["Config"]["Labels"], current["Config"]["Labels"], self.LABEL_FIELDS),
            "networks_equal": sorted(before["NetworkSettings"]["Networks"]) == sorted(after["NetworkSettings"]["Networks"]),
            "container_name_equal": before["Name"] == after["Name"],
            "replacement_label_expected": (labels.get("com.docker.compose.replace") == options.get("container_name", f"{service}-{before['Config']['Labels'].get('com.docker.compose.container-number', '')}")) if service in self.REPLACED else None,
            "dependency_label_expected": (sorted(filter(None, labels.get("com.docker.compose.depends_on", "").split(","))) == expected) if service in self.REPLACED else None,
            "configuration_location_labels_expected": (labels.get("com.docker.compose.project.config_files") == f"{self.target}/compose.json" and labels.get("com.docker.compose.project.working_dir") == self.target) if service in self.REPLACED else None}


def regular(path):
    return stat.S_ISREG(path.lstat().st_mode)


def read_json(path):
    if not regular(path):
        raise ValueError("Unsupported input")
    return json.loads(path.read_text())


def docker(*args):
    result = subprocess.run(["docker", *args], capture_output=True, text=True, check=False)
    if result.returncode:
        raise RuntimeError("Docker read check failed")
    return result.stdout


def backup_verified(state):
    marker = state / "active/backup-directory"
    if not regular(marker):
        return False
    value = marker.read_text().strip()
    if not re.fullmatch(re.escape(str(state)) + r"/backups/layout\.[A-Za-z0-9]{6}", value):
        return False
    backup = Path(value)
    info = backup.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != 0 or stat.S_IMODE(info.st_mode) != 0o700:
        return False
    if not regular(backup / "COMPLETE") or os.path.lexists(backup / "INCOMPLETE"):
        return False
    if not regular(backup / "SHA256SUMS"):
        return False
    hashes = {}
    for line in (backup / "SHA256SUMS").read_text().splitlines():
        match = re.fullmatch(r"([0-9a-f]{64})  ([A-Za-z0-9.-]+)", line)
        if not match or match[2] not in LayoutDiagnostic.BACKUP_FILES or match[2] in hashes:
            return False
        hashes[match[2]] = match[1]
    if set(hashes) != LayoutDiagnostic.BACKUP_FILES:
        return False
    for name, digest in hashes.items():
        path = backup / name
        if not regular(path):
            return False
        value = hashlib.sha256()
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                value.update(chunk)
        if value.hexdigest() != digest:
            return False
    return True


def main():
    if os.geteuid() != 0:
        raise ValueError("Root required")
    state = Path("/var/opt/readersourcing/rs-server")
    work = state / "diagnostics/layout.P5SS0d"
    for path in (state, work, state / "active"):
        info = path.lstat()
        if not stat.S_ISDIR(info.st_mode) or info.st_uid != 0 or stat.S_IMODE(info.st_mode) != 0o700:
            raise ValueError("Unsupported input")
    source = read_json(work / "source-containers.json")
    definition = read_json(state / "active/definition.json")
    project = "rs-private-8955233c3d65"
    ids = docker("ps", "--all", "--quiet", "--filter", f"label=com.docker.compose.project={project}").split()
    current = json.loads(docker("inspect", *ids)) if ids else []
    checker = LayoutDiagnostic("/var/tmp/rs-server-private.HRmrwq", "/etc/opt/readersourcing/rs-server")
    services = {}
    for role in checker.SERVICES:
        originals = [item for item in source if item["Config"]["Labels"].get("com.docker.compose.service") == role]
        candidates = [item for item in current if item["Config"]["Labels"].get("com.docker.compose.service") == role]
        services[role] = {"container_count": len(candidates)}
        if len(originals) == len(candidates) == 1:
            services[role].update(checker.compare(originals[0], candidates[0], definition, role))
    categories = set()
    patterns = {"inventory_validation": r"Layout check failed|Startup inventory check failed", "permission_denied": r"permission denied|PermissionError",
        "read_only_filesystem": r"read.only file system|rootfs is marked read.only", "container_name_conflict": r"name.*already in use",
        "image_unavailable": r"No such image|image.*not found|pull access denied", "mount_validation": r"invalid mount|invalid volume|error mounting",
        "compose_validation": r"validating |invalid compose|unsupported.*option|unknown flag|undefined network|undefined volume"}
    for name in ("activation-errors.log", "activation-output.log"):
        path = work / name
        if path.exists() and regular(path):
            with path.open("rb") as handle:
                handle.seek(max(0, path.stat().st_size - 128 * 1024))
                contents = handle.read().decode("utf-8", errors="replace")
            categories.update(category for category, pattern in patterns.items() if re.search(pattern, contents, re.I))
    try:
        backup_ok = backup_verified(state)
    except (OSError, ValueError):
        backup_ok = False
    print(json.dumps({"status": "read_only_layout_diagnostic", "files_or_services_changed": False, "private_values_or_log_contents_displayed": False,
        "project_container_count": len(current), "recorded_replacement_inspection_present": (work / "replacement-containers.json").is_file(),
        "installed_startup_inventory_present": (state / "active/startup-inventory.json").is_file(), "backup_archive_checks_passed": backup_ok,
        "error_categories": sorted(categories), "services": services}, indent=2))


if __name__ == "__main__":
    try:
        main()
    except Exception:
        print(json.dumps({"status": "diagnostic_not_confirmed", "files_or_services_changed": False, "private_values_or_log_contents_displayed": False}))
        raise SystemExit(1)
