#!/usr/bin/env python3
"""Verdict matrix for qa-review-gate.

A gate that fails open still exits 0 with entirely plausible output, so every
case asserts the expected verdict rather than printing what happened.

Run: python3 tests/test_gate.py
"""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
GATE = HERE.parent / "scripts" / "qa-review-gate.py"

NOW = "2026-09-11T09:00:00+02:00"


def observation(command="make test", exit_code=0, tail="OK (3 tests)"):
    return {
        "kind": "observation",
        "command": command,
        "exit_code": exit_code,
        "output_tail": tail,
        "at": NOW,
    }


def waiver(reason="No admin fixture on the reference env; covered by MR review only."):
    return {"kind": "waiver", "reason": reason, "at": NOW}


def ledger(**overrides):
    """A ledger that passes every gate, so each test changes exactly one thing."""
    base = {
        "key": "PROJ-123",
        "issue_type": "Bug",
        "reviewer": "sebastian",
        "implementer": "colleague",
        "mr_authors": ["colleague"],
        "pipeline_id": "88421",
        "mr_links": ["https://git.example.org/group/repo/-/merge_requests/7"],
        "scope": {
            "in": "Coupon removal recalculation",
            "out": "Checkout payment step",
            "proof": "Unit run on the reference env",
            "paths": ["src/Bundle/Cart/**", "tests/Bundle/Cart/**"],
        },
        "criteria": [
            {"id": "1", "text": "Total recalculates", "entries": [observation()]},
            {"id": "2", "text": "Grid sorts by net", "entries": [waiver()]},
        ],
        "written_files": [],
        "sealed": False,
    }
    base.update(overrides)
    return base


class GateMatrix(unittest.TestCase):
    def verdict(self, data, key="PROJ-123"):
        """Run the real gate against a ledger and return its verdict line."""
        with tempfile.TemporaryDirectory() as state:
            if data is not None:
                (Path(state) / f"{key}.json").write_text(json.dumps(data))
            env = dict(os.environ, QA_REVIEW_STATE_DIR=state)
            proc = subprocess.run(
                [sys.executable, str(GATE), key],
                capture_output=True, text=True, env=env,
            )
        out = proc.stdout + proc.stderr
        for line in out.splitlines():
            if line.startswith("QA-REVIEW-RESULT:"):
                got = line.split(":", 1)[1].strip()
                # exit code must mirror the verdict, or the gate lies to callers
                expected_code = 0 if got == "pass" else 1
                self.assertEqual(
                    proc.returncode, expected_code,
                    f"verdict {got} but exit {proc.returncode}\n{out}",
                )
                return got
        self.fail(f"gate printed no verdict line:\n{out}")

    def assertVerdict(self, expected, data, key="PROJ-123"):
        self.assertEqual(expected, self.verdict(data, key), f"case: {self._testMethodName}")

    # --- passing cases ------------------------------------------------------

    def test_every_criterion_observed(self):
        led = ledger()
        led["criteria"][1]["entries"] = [observation()]
        self.assertVerdict("pass", led)

    def test_mixed_observations_and_reasoned_waivers(self):
        self.assertVerdict("pass", ledger())

    def test_written_file_inside_scope(self):
        self.assertVerdict("pass", ledger(written_files=["src/Bundle/Cart/Total.php"]))

    def test_failing_observation_still_counts_as_accounted(self):
        # The gate checks that the reviewer accounted for the criterion,
        # never whether the result was green. A red run is a real observation.
        led = ledger()
        led["criteria"][0]["entries"] = [observation(exit_code=1, tail="FAILURES! 1 failed")]
        self.assertVerdict("pass", led)

    # --- coverage -----------------------------------------------------------

    def test_no_ledger_at_all(self):
        self.assertVerdict("fail", None)

    def test_criterion_with_no_entries(self):
        led = ledger()
        led["criteria"][1]["entries"] = []
        self.assertVerdict("fail", led)

    def test_no_criteria_declared(self):
        self.assertVerdict("fail", ledger(criteria=[]))

    # --- waiver quality -----------------------------------------------------

    def test_waiver_with_empty_reason(self):
        led = ledger()
        led["criteria"][1]["entries"] = [waiver(reason="")]
        self.assertVerdict("fail", led)

    def test_waiver_with_one_word_reason(self):
        led = ledger()
        led["criteria"][1]["entries"] = [waiver(reason="nope")]
        self.assertVerdict("fail", led)

    def test_waiver_with_whitespace_reason(self):
        led = ledger()
        led["criteria"][1]["entries"] = [waiver(reason="   \n  ")]
        self.assertVerdict("fail", led)

    def test_corrected_waiver_supersedes_the_bad_one(self):
        # Entries are append-only for the audit trail, but the gate judges the
        # effective (latest) entry. Otherwise a reviewer who fixes a junk reason
        # can never reach pass, and the gate becomes something to work around.
        led = ledger()
        led["criteria"][1]["entries"] = [
            waiver(reason="nope"),
            waiver(reason="No admin fixture on the reference env; covered by MR review."),
        ]
        self.assertVerdict("pass", led)

    def test_waiver_downgraded_to_junk_still_fails(self):
        led = ledger()
        led["criteria"][1]["entries"] = [
            waiver(reason="No admin fixture on the reference env; covered by MR review."),
            waiver(reason="nope"),
        ]
        self.assertVerdict("fail", led)

    def test_observation_after_waiver_is_effective(self):
        led = ledger()
        led["criteria"][1]["entries"] = [waiver(reason="nope"), observation()]
        self.assertVerdict("pass", led)

    # --- self-review --------------------------------------------------------

    def test_reviewer_is_implementer(self):
        self.assertVerdict("fail", ledger(reviewer="colleague"))

    def test_reviewer_is_mr_author(self):
        self.assertVerdict("fail", ledger(reviewer="someone", implementer="other",
                                          mr_authors=["someone"]))

    def test_reviewer_missing(self):
        self.assertVerdict("fail", ledger(reviewer=""))

    # --- evidence trail -----------------------------------------------------

    def test_missing_pipeline_id(self):
        self.assertVerdict("fail", ledger(pipeline_id=""))

    def test_missing_mr_links(self):
        self.assertVerdict("fail", ledger(mr_links=[]))

    # --- scope --------------------------------------------------------------

    def test_write_outside_declared_scope(self):
        self.assertVerdict("fail", ledger(written_files=["src/Bundle/Checkout/Pay.php"]))

    def test_no_scope_paths_declared(self):
        led = ledger()
        led["scope"]["paths"] = []
        self.assertVerdict("fail", led)

    # --- fail closed --------------------------------------------------------

    def test_corrupt_ledger(self):
        with tempfile.TemporaryDirectory() as state:
            (Path(state) / "PROJ-123.json").write_text("{not json")
            env = dict(os.environ, QA_REVIEW_STATE_DIR=state)
            proc = subprocess.run([sys.executable, str(GATE), "PROJ-123"],
                                  capture_output=True, text=True, env=env)
        self.assertIn("QA-REVIEW-RESULT: fail", proc.stdout + proc.stderr)
        self.assertEqual(1, proc.returncode)

    def test_ledger_missing_required_fields(self):
        self.assertVerdict("fail", {"key": "PROJ-123"})


if __name__ == "__main__":
    unittest.main(verbosity=2)
