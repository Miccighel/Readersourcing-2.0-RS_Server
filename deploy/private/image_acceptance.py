"""Operator-run isolated image check. No active configuration or backup is read."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time


class AcceptanceError(Exception):
    pass


def require(condition):
    if not condition:
        raise AcceptanceError("Acceptance guard failed")


def read_json(path):
    return json.loads(Path(path).read_text())


def verify_package(package):
    entries = (package / "SHA256SUMS").read_text().splitlines()
    require(bool(entries))
    for line in entries:
        digest, name = line.split("  ", 1)
        require(re.fullmatch(r"[0-9a-f]{64}", digest) and re.fullmatch(r"[A-Za-z0-9_.-]+", name))
        path = package / name
        require(not path.is_symlink() and path.is_file())
        require(hashlib.sha256(path.read_bytes()).hexdigest() == digest)
    require({line.split("  ", 1)[1] for line in entries} == {
        "image_acceptance.py", "image_acceptance_configuration.rb", "image_acceptance_probe.rb",
        "prepare.rb", "compose.yml.erb", "proxy.conf", "Reader.pdf", "candidate.json", "check_candidate.sh"})


def validate_spec(spec):
    require(re.fullmatch(r"sha256:[0-9a-f]{64}", spec["image_id"]) is not None)
    require(re.fullmatch(r"[0-9a-f]{40}", spec["revision"]) is not None)
    require(re.fullmatch(r"rs-private-[0-9a-f]{12}", spec["active_project"]) is not None)
    require(re.fullmatch(r"sha256:[0-9a-f]{64}", spec["active_image_id"]) is not None)
    require(spec["image_id"] != spec["active_image_id"])
    require(len(spec["evidence"]) == 2 and {item["kind"] for item in spec["evidence"]} == {"runtime", "scan"})
    for item in spec["evidence"]:
        require(re.fullmatch(r"[0-9a-f]{64}", item["sha256"]) is not None)
        expected = (r"/var/tmp/rs-server-ui-candidate\.[A-Za-z0-9]{6}/verification\.json" if item["kind"] == "runtime" else
                    r"/var/tmp/rs-server-ui-candidate\.[A-Za-z0-9]{6}/scan\.[A-Za-z0-9]{6}/scan-summary\.json")
        require(re.fullmatch(expected, item["path"]) is not None)


class Acceptance:
    def __init__(self, package):
        self.package = package
        verify_package(package)
        self.spec = read_json(package / "candidate.json")
        validate_spec(self.spec)
        self.work = Path(tempfile.mkdtemp(prefix="rs-server-image-acceptance.", dir="/var/tmp"))
        self.stage = "preflight"
        self.project = None
        self.started = False
        self.log = (self.work / "commands.log").open("xb")

    def run(self, args, *, data=None, timeout=240):
        result = subprocess.run(args, input=data, stdout=subprocess.PIPE, stderr=self.log, timeout=timeout, check=False)
        if result.returncode:
            self.log.write(result.stdout)
            self.log.flush()
            raise AcceptanceError("Command failed")
        return result.stdout

    def docker(self, *args, **options):
        return self.run(["docker", *args], **options)

    def ids(self, project):
        return self.docker("ps", "--all", "--filter", f"label=com.docker.compose.project={project}", "--quiet").decode().split()

    def lifecycle(self):
        ids = self.ids(self.spec["active_project"])
        require(len(ids) == 5)
        template = '{{json (index .Config.Labels "com.docker.compose.service")}} {{json .Id}} {{json .Image}} {{json .State.Running}} {{json .State.StartedAt}} {{json .RestartCount}}'
        values = sorted(self.docker("inspect", "--format", template, *ids).decode().splitlines())
        require(any(line.startswith('"rs_server_webapp" ') and self.spec["active_image_id"] in line for line in values))
        return values

    def image(self, reference):
        # Image metadata is public; container environment is never inspected.
        image = json.loads(self.docker("image", "inspect", reference))[0]
        require(image["Os"] == "linux" and image["Architecture"] == "amd64")
        return image

    def helper(self, *arguments):
        return self.docker("run", "--rm", "--pull=never", "--network", "none", "--user", "0:0",
            "--read-only", "--cap-drop=ALL", "--security-opt", "no-new-privileges:true",
            "--memory", "256m", "--pids-limit", "64", "--tmpfs", "/tmp:rw,noexec,nosuid,size=32m",
            "--mount", f"type=bind,src={self.package},dst=/helpers,readonly",
            "--mount", f"type=bind,src={self.work},dst={self.work}",
            "--entrypoint", "ruby", self.spec["image_id"], *arguments)

    def compose(self, *arguments, **options):
        return self.run(["docker", "compose", "--project-directory", str(self.base), "--project-name", self.project,
            "--file", str(self.work / "compose.json"), *arguments], **options)

    def stop_isolated(self):
        if self.started:
            ids = self.ids(self.project)
            require(not set(ids).intersection(self.ids(self.spec["active_project"])))
            if ids:
                self.docker("stop", "--time", "30", *ids)
                state = self.docker("inspect", "--format", "{{.State.Running}}", *ids).decode().split()
                require(all(value == "false" for value in state))
            self.started = False

    def execute(self):
        initial = self.lifecycle()
        try:
            image = self.image(self.spec["image_id"])
            labels = image["Config"]["Labels"]
            require(image["Id"] == self.spec["image_id"] and image["Config"]["User"] == "rails:rails")
            require(labels["org.opencontainers.image.revision"] == self.spec["revision"] and labels["org.opencontainers.image.version"] == "2.0.4")
            for evidence in self.spec["evidence"]:
                contents = Path(evidence["path"]).read_bytes()
                require(hashlib.sha256(contents).hexdigest() == evidence["sha256"])
                report = json.loads(contents)
                if evidence["kind"] == "runtime":
                    require(report["status"] == "passed" and report["image"]["id"] == self.spec["image_id"] and
                            report["image"]["revision"] == self.spec["revision"])
                else:
                    require(evidence["kind"] == "scan" and report["status"] == "scan_completed" and
                            report["image_id"] == self.spec["image_id"] and report["source_revision"] == self.spec["revision"])
            version = json.loads(self.docker("version", "--format", "{{json .Server.Version}}"))
            require(int(version.split(".")[0]) >= 28)
            self.base = self.work / "base"
            self.base.mkdir(mode=0o700)
            self.stage = "fresh_configuration"
            self.helper("/helpers/prepare.rb", str(self.base), "/helpers/compose.yml.erb", "/helpers/Reader.pdf")
            self.project = self.helper("/helpers/prepare.rb", "validate", str(self.base)).decode().strip()
            require(re.fullmatch(r"rs-private-[0-9a-f]{12}", self.project) and self.project != self.spec["active_project"])
            require(not self.ids(self.project))
            for kind in ("network", "volume"):
                require(not self.docker(kind, "ls", "--filter", f"label=com.docker.compose.project={self.project}", "--quiet").strip())
            for name in (f"{self.project}_database", f"{self.project}_publications"):
                require(not self.docker("volume", "ls", "--filter", f"name=^{name}$", "--quiet").strip())
            (self.base / "fixtures/Reader.pdf").chmod(0o644)  # Public fixture only, not secrets or parent directory.
            baseline = self.run(["docker", "compose", "--project-directory", str(self.base), "--file", str(self.base / "compose.yml"), "config", "--format", "json"])
            (self.work / "baseline.json").write_bytes(baseline)
            options = {"baseline": str(self.work / "baseline.json"), "destination": str(self.work / "compose.json"),
                "resolved": str(self.work / "resolved.json"), "configuration": {
                    "project": self.project, "active_project": self.spec["active_project"], "base_directory": str(self.base),
                    "application_image": self.spec["image_id"], "database_image": self.image("postgres:17")["Id"],
                    "mailpit_image": self.image("axllent/mailpit:v1.31.5")["Id"]}}
            (self.work / "options.json").write_text(json.dumps(options))
            self.helper("/helpers/image_acceptance_configuration.rb", str(self.work / "options.json"), "prepare")
            (self.work / "resolved.json").write_bytes(self.compose("config", "--format", "json"))
            self.helper("/helpers/image_acceptance_configuration.rb", str(self.work / "options.json"), "check")
            self.stage = "isolated_startup"
            self.started = True  # Also stop partially created services if compose fails.
            self.compose("up", "--detach", "--no-build", "--pull", "never", timeout=180)
            ids = self.ids(self.project)
            require(len(ids) == 4)
            deadline = time.monotonic() + 180
            web = None
            while time.monotonic() < deadline:
                web = self.compose("ps", "--quiet", "rs_server_webapp").decode().strip()
                if web and self.docker("inspect", "--format", "{{.State.Health.Status}}", web).strip() == b"healthy":
                    break
                time.sleep(2)
            else:
                raise AcceptanceError("Readiness timed out")
            # Only fixed safety fields, never private container environment.
            for container in ids:
                bindings = self.docker("inspect", "--format", "{{json .HostConfig.PortBindings}}", container)
                require(not json.loads(bindings))
            self.stage = "production_readiness"
            self.docker("exec", web, "./bin/rake", "deployment:check")
            self.stage = "application_probe"
            self.docker("exec", "--interactive", "--env", f"RS_IMAGE_ACCEPTANCE_PROJECT={self.project}", web,
                "./bin/rails", "runner", "-", data=(self.package / "image_acceptance_probe.rb").read_bytes())
            probe = json.loads(self.docker("exec", web, "cat", "/tmp/image-acceptance-report.json"))
            require(probe["status"] == "passed")
            self.stage = "stop_isolated_services"
            self.stop_isolated()
            require(initial == self.lifecycle())
            report = {"status": "isolated_image_acceptance_passed", "recorded_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                "image_id": self.spec["image_id"], "source_revision": self.spec["revision"], "project": self.project,
                "active_container_identities_and_lifecycle_unchanged": True, "fresh_database": True,
                "migrations_run_only_in_new_database": True, "ports_published": False, "images_pulled_or_built": False,
                "active_configuration_or_backups_read": False, "isolated_services_stopped": True,
                "isolated_volumes_retained": True, "private_trial_replaced": False, "registry_image_published": False,
                "host_packages_changed": False, "host_rebooted": False, "security_approval": False, "probe": probe}
            (self.work / "acceptance-summary.json").write_text(json.dumps(report, indent=2) + "\n")
            print(json.dumps(report, indent=2))
            print(f"Protected diagnostics and synthetic configuration retained at {self.work}; do not paste their contents.")
        except BaseException:
            try:
                self.stop_isolated()
            except BaseException:
                print("Stopping isolated services was not confirmed; inspect the protected diagnostics.", file=sys.stderr)
            try:
                unchanged = initial == self.lifecycle()
            except BaseException:
                unchanged = False
            print(json.dumps({"status": "isolated_acceptance_not_confirmed", "stage": self.stage,
                "active_lifecycle_unchanged_verified": unchanged, "private_values_displayed": False}), file=sys.stderr)
            print(f"Protected diagnostics: {self.work}; do not paste their contents.", file=sys.stderr)
            return 1
        finally:
            self.log.close()
        return 0


def main():
    require(sys.argv[1:] == ["--confirm-isolated-check"] and sys.platform == "linux" and os.geteuid() == 0)
    os.umask(0o077)
    return Acceptance(Path(__file__).resolve().parent).execute()


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        print("Isolated acceptance preflight failed; private values were not displayed.", file=sys.stderr)
        sys.exit(1)
