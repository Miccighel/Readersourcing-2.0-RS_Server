import copy
import importlib.util
import json
from pathlib import Path
import unittest

SCRIPT = Path(__file__).resolve().parents[2] / "deploy/private/deployment_layout_diagnostic.py"
SPEC = importlib.util.spec_from_file_location("layout_diagnostic", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class LayoutDiagnosticTest(unittest.TestCase):
    def setUp(self):
        self.checker = MODULE.LayoutDiagnostic("/old", "/new")
        self.definition = {"services": {"access": {}}}
        self.source = {"Id": "a" * 64, "Name": "/retained-name", "Image": "retained-image", "RestartCount": 0,
            "Config": {"Hostname": "a" * 12, "Image": "old-tag", "Env": ["PRIVATE=never-display", "OTHER=synthetic"],
                "Labels": {"com.docker.compose.container-number": "1", "com.docker.compose.project.working_dir": "/old", "com.docker.compose.depends_on": ""}},
            "HostConfig": {"ConsoleSize": [0, 0], "Memory": 1024, "Binds": ["/old/runtime/proxy.conf:/trial/proxy.conf:ro"]},
            "Mounts": [{"Type": "bind", "Source": "/old/runtime/proxy.conf", "Destination": "/trial/proxy.conf", "RW": False}],
            "NetworkSettings": {"Networks": {"private_network": {}}},
            "State": {"Running": True, "StartedAt": "2026-10-15T00:00:00Z", "Status": "running"}}
        self.current = copy.deepcopy(self.source)
        self.current["Id"] = "b" * 64
        self.current["Config"]["Hostname"] = "b" * 12
        self.current["Config"]["Image"] = "retained-image"
        self.current["Config"]["Env"].reverse()
        self.current["Config"]["Labels"].update({"com.docker.compose.replace": "access-1", "com.docker.compose.project.working_dir": "/new", "com.docker.compose.project.config_files": "/new/compose.json"})
        self.current["HostConfig"]["Binds"] = ["/new/runtime/proxy.conf:/trial/proxy.conf:ro"]
        self.current["Mounts"][0]["Source"] = "/new/runtime/proxy.conf"
        self.current["State"] = {"Running": False, "StartedAt": "0001-01-01T00:00:00Z", "Status": "created"}

    def compare(self):
        return self.checker.compare(self.source, self.current, self.definition, "access")

    def test_expected_relocation_and_metadata_changes_do_not_expose_values(self):
        result = self.compare()
        self.assertEqual([], result["config_difference_fields"])
        self.assertEqual([], result["host_difference_fields"])
        self.assertEqual([], result["mount_difference_fields"])
        self.assertTrue(result["same_image_as_source"])
        self.assertFalse(result["same_identity_as_source"])
        self.assertFalse(result["ever_started"])
        self.assertTrue(result["replacement_label_expected"])
        self.assertTrue(result["configuration_location_labels_expected"])
        self.assertNotIn("never-display", json.dumps(result))
        self.assertNotIn("/new", json.dumps(result))

    def test_differences_report_only_fixed_schema_fields_and_never_secret_keys_or_values(self):
        self.current["Config"]["Env"] = ["PRIVATE=changed-secret"]
        self.current["Config"]["Labels"]["private-unknown-key"] = "private-label-value"
        self.current["HostConfig"]["Memory"] = 2048
        self.current["HostConfig"]["private-dynamic-key"] = "never-display"
        self.current["Mounts"][0]["RW"] = True
        result = self.compare()
        self.assertEqual(["Env", "Labels"], result["config_difference_fields"])
        self.assertEqual(["Memory", "other_fields"], result["host_difference_fields"])
        self.assertEqual(["RW"], result["mount_difference_fields"])
        self.assertEqual(["other_fields"], result["other_label_difference_fields"])
        for private in ("private-unknown-key", "private-label-value", "private-dynamic-key", "never-display", "changed-secret"):
            self.assertNotIn(private, json.dumps(result))

    def test_comparison_does_not_mutate_the_retained_source(self):
        original = json.dumps(self.source)
        self.compare()
        self.assertEqual(original, json.dumps(self.source))


if __name__ == "__main__":
    unittest.main()
