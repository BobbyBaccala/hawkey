"""The check runner must not turn failed or skipped validation into a green build."""
import contextlib
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET

from tools.check_project import classify, run_check, write_reports


class ProjectChecksTests(unittest.TestCase):
    def test_script_error_with_zero_exit_fails(self):
        self.assertEqual(classify("test_match", 0, "SCRIPT ERROR: Invalid call")[0], "failed")
        self.assertEqual(classify("test_match", 0, "Failed to load script")[0], "failed")

    def test_only_explicit_optional_mocap_skip_allowed(self):
        self.assertEqual(classify("test_mocap", 0, "skipped: clips not installed")[0], "skipped")
        self.assertEqual(classify("test_roster_database", 0, "skipped: clips not installed")[0], "failed")
        self.assertEqual(classify("test_mocap", 1, "skipped: clips not installed")[0], "failed")

    def test_expected_io_fault_diagnostic_does_not_fail_passing_suite(self):
        self.assertEqual(classify("test_save_store", 0, "ERROR: Could not create directory /proc/test\n0 failures")[0], "passed")

    def test_engine_version_is_pinned(self):
        self.assertEqual(classify("engine_version", 0, "4.6.3.stable.official")[0], "passed")
        self.assertEqual(classify("engine_version", 0, "4.6.2.stable.official")[0], "failed")

    def test_empty_success_is_not_validation(self):
        self.assertEqual(classify("test_match", 0, "Godot Engine 4.6.3")[0], "failed")
        self.assertEqual(classify("python", 0, "Ran 0 tests")[0], "failed")
        self.assertEqual(classify("python", 0, "Ran 24 tests")[0], "passed")

    def test_timeout_is_failed_and_persists_report(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            with contextlib.redirect_stdout(io.StringIO()):
                result = run_check("timeout", [sys.executable, "-c", "import time; time.sleep(5)"], output, {}, .05)
            self.assertEqual(result["status"], "failed")
            self.assertEqual(result["returncode"], 124)
            report = write_reports(output, [result], "4.6.3")
            self.assertEqual(report["counts"]["failed"], 1)
            self.assertEqual(json.loads((output / "results.json").read_text())["checks"][0]["returncode"], 124)
            self.assertIsNotNone(ET.parse(output / "junit.xml").find("testcase/failure"))

    def test_missing_executable_is_failed(self):
        with tempfile.TemporaryDirectory() as directory:
            with contextlib.redirect_stdout(io.StringIO()):
                result = run_check("missing", [str(Path(directory) / "missing")], Path(directory), {}, 1)
            self.assertEqual(result["status"], "failed")
            self.assertEqual(result["returncode"], 127)
