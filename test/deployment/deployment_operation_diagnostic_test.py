import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[2] / "deploy/private/deployment_operation_diagnostic.py"
SPEC = importlib.util.spec_from_file_location("operation_diagnostic", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class DeploymentOperationDiagnosticTest(unittest.TestCase):
    def setUp(self):
        self.current = {"Id": "synthetic", "Image": "retained", "Name": "/private-name",
            "Config": {"Env": ["PRIVATE=never-display"], "Labels": {"private-label": "private-value"}},
            "HostConfig": {"ConsoleSize": [0, 0], "OomKillDisable": False, "ReadonlyRootfs": True},
            "Mounts": [{"Destination": "/private/mount", "Source": "/private/source", "RW": False}],
            "NetworkSettings": {"Networks": {"private-network": {}}}, "State": {"Running": False, "Status": "exited"}}
        self.baseline = {"id": self.current["Id"], "image": self.current["Image"], "name": self.current["Name"],
            "config": copy.deepcopy(self.current["Config"]), "host": {key: value for key, value in self.current["HostConfig"].items() if key != "ConsoleSize"},
            "mounts": copy.deepcopy(self.current["Mounts"]), "networks": ["private-network"]}

    def compare(self):
        return MODULE.compare_inventory(self.baseline, self.current)

    def test_unchanged_frozen_inventory_and_console_size_do_not_report_drift(self):
        self.current["HostConfig"]["ConsoleSize"] = [24, 80]
        result = self.compare()
        self.assertEqual([], result["host_difference_fields"])
        self.assertTrue(result["same_identity_as_frozen"])
        self.assertTrue(result["ordered_mounts_equal"])
        self.assertEqual("unchanged", result["oom_default_transition"])

    def test_oom_direction_is_reported_without_normalizing_or_approving_it(self):
        self.current["HostConfig"]["OomKillDisable"] = None
        result = self.compare()
        self.assertEqual(["OomKillDisable"], result["host_difference_fields"])
        self.assertEqual("false_to_null", result["oom_default_transition"])
        self.assertFalse(result["oom_disable_true_present"])
        self.current["HostConfig"]["OomKillDisable"] = True
        self.assertTrue(self.compare()["oom_disable_true_present"])
        self.assertEqual("other", self.compare()["oom_default_transition"])

    def test_unknown_keys_values_and_paths_are_not_exported(self):
        self.current["Config"]["Env"] = ["PRIVATE=changed-secret"]
        self.current["Config"]["Labels"]["private-label"] = "changed-label"
        self.current["HostConfig"]["private-dynamic-key"] = "private-value"
        self.current["Mounts"][0]["Source"] = "/changed/private"
        result = self.compare()
        self.assertEqual(["Env", "Labels"], result["config_difference_fields"])
        self.assertEqual(["other_fields"], result["host_difference_fields"])
        self.assertEqual(["Source"], result["mount_difference_fields"])
        rendered = json.dumps(result)
        for private in ("never-display", "changed-secret", "private-label", "private-value", "changed-label", "private-dynamic-key", "/private", "/changed", "private-network"):
            self.assertNotIn(private, rendered)

    def test_boolean_false_and_numeric_zero_are_not_equal(self):
        self.current["HostConfig"]["OomKillDisable"] = 0
        self.assertEqual(["OomKillDisable"], self.compare()["host_difference_fields"])
        self.assertEqual("other", self.compare()["oom_default_transition"])

    def test_comparison_is_read_only_and_mount_order_is_not_a_content_change(self):
        extra = {"Destination": "/other", "Source": "/source", "RW": True}
        self.baseline["mounts"].append(copy.deepcopy(extra))
        self.current["Mounts"].insert(0, extra)
        original = json.dumps([self.baseline, self.current])
        self.assertTrue(self.compare()["ordered_mounts_equal"])
        self.assertEqual(original, json.dumps([self.baseline, self.current]))

    def test_only_the_fixed_operation_path_is_accepted_from_private_logs(self):
        root = Path("/var/opt/readersourcing/rs-server")
        path = root / "diagnostics/operation.Ab12Cd"
        self.assertEqual(path, MODULE.operation_path(f"Private diagnostics: {path}. Do not paste private data.", root))
        self.assertIsNone(MODULE.operation_path("Private diagnostics: /etc/shadow.", root))
        self.assertIsNone(MODULE.operation_path(f"Private diagnostics: {root}/diagnostics/operation.Ab12Cd/../../other.", root))
        with self.assertRaises(ValueError):
            MODULE.operation_path(f"Private diagnostics: {path}. Private diagnostics: {root}/diagnostics/operation.Xx12Yy.", root)

    def test_log_categories_never_return_log_contents(self):
        report = MODULE.categories("PRIVATE=changed-secret\nStartup inventory check failed\nPermission denied: /private/file")
        self.assertEqual(["inventory_validation", "permission_denied"], report)

    def test_public_manifest_rejects_drift_symlinks_and_unknown_names(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            lines = []
            for name in sorted(MODULE.PUBLIC_FILES):
                (root / name).write_text("synthetic public helper")
                lines.append(f"{hashlib.sha256((root / name).read_bytes()).hexdigest()}  {name}\n")
            manifest = root / "OPERATIONS-SHA256SUMS"
            manifest.write_text("".join(lines))
            self.assertTrue(MODULE.public_manifest_verified(root))
            (root / "startup_inventory.rb").write_text("changed")
            self.assertFalse(MODULE.public_manifest_verified(root))
            (root / "startup_inventory.rb").unlink()
            (root / "startup_inventory.rb").symlink_to(root / "candidate_restart.sh")
            self.assertFalse(MODULE.public_manifest_verified(root))
            manifest.write_text("".join(lines) + "0" * 64 + "  ../private\n")
            self.assertFalse(MODULE.public_manifest_verified(root))

    def test_permission_summary_checks_owner_mode_and_file_type(self):
        path = Path("/synthetic")
        for mode, uid, expected in ((0o100600, 0, True), (0o120600, 0, False), (0o100644, 0, False), (0o100600, 1000, False)):
            with patch.object(Path, "lstat", return_value=SimpleNamespace(st_mode=mode, st_uid=uid)):
                self.assertEqual(expected, MODULE.metadata_matches(path, 0o600))


if __name__ == "__main__":
    unittest.main()
