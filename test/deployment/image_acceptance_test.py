import importlib.util
from pathlib import Path
import unittest

MODULE = Path(__file__).resolve().parents[2] / "deploy/private/image_acceptance.py"
SPEC = importlib.util.spec_from_file_location("image_acceptance", MODULE)
acceptance = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(acceptance)


class ImageAcceptanceTest(unittest.TestCase):
    def spec(self):
        return {"image_id": "sha256:" + "1" * 64, "active_image_id": "sha256:" + "2" * 64,
                "revision": "3" * 40, "active_project": "rs-private-8955233c3d65", "evidence": [
                    {"kind": "runtime", "sha256": "4" * 64, "path": "/var/tmp/rs-server-ui-candidate.123456/verification.json"},
                    {"kind": "scan", "sha256": "5" * 64, "path": "/var/tmp/rs-server-ui-candidate.123456/scan.abcdef/scan-summary.json"}]}

    def test_identity_requires_pinned_different_images(self):
        acceptance.validate_spec(self.spec())
        for change in ({"image_id": "candidate:latest"}, {"revision": "HEAD"},
                       {"active_project": "other"}, {"image_id": self.spec()["active_image_id"]}):
            with self.assertRaises(acceptance.AcceptanceError):
                acceptance.validate_spec(dict(self.spec(), **change))

    def test_stop_refuses_any_active_container(self):
        check = acceptance.Acceptance.__new__(acceptance.Acceptance)
        check.started = True
        check.project = "rs-private-123456abcdef"
        check.spec = self.spec()
        check.ids = lambda project: ["same-container"]
        check.docker = lambda *args: self.fail("Docker stop must not execute")
        with self.assertRaises(acceptance.AcceptanceError):
            check.stop_isolated()

    def test_rejects_private_evidence_paths_or_missing_scan(self):
        spec = self.spec()
        spec["evidence"][0]["path"] = "/etc/opt/readersourcing/rs-server/configuration.json"
        with self.assertRaises(acceptance.AcceptanceError):
            acceptance.validate_spec(spec)
        spec = self.spec()
        spec["evidence"] = spec["evidence"][:1]
        with self.assertRaises(acceptance.AcceptanceError):
            acceptance.validate_spec(spec)

    def test_stop_only_targets_the_isolated_containers(self):
        check = acceptance.Acceptance.__new__(acceptance.Acceptance)
        check.started = True
        check.project = "rs-private-123456abcdef"
        check.spec = self.spec()
        check.ids = lambda project: ["isolated"] if project == check.project else ["active"]
        calls = []
        def docker(*args):
            calls.append(args)
            return b"false\n" if args[0] == "inspect" else b""
        check.docker = docker
        check.stop_isolated()
        self.assertEqual(calls[0], ("stop", "--time", "30", "isolated"))
        self.assertFalse(check.started)

    def test_pre_start_cleanup_does_not_call_docker(self):
        check = acceptance.Acceptance.__new__(acceptance.Acceptance)
        check.started = False
        check.docker = lambda *args: self.fail("No resources have been created")
        check.stop_isolated()


if __name__ == "__main__":
    unittest.main()
