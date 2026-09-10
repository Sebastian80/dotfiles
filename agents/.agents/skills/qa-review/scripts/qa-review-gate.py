#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""Mechanical check on a QA review before the ticket transitions.

The review itself is judgement work. This is not. It checks that the reviewer
accounted for every acceptance criterion, did not review their own work, left an
evidence trail somebody else can follow, and stayed inside the declared scope.

It never judges whether an observation is *good*. A criterion verified with a red
test run is accounted for; a criterion nobody mentioned is not. The gate fails on
silence, not on the absence of tests, because plenty of tickets have neither a
suite to run nor a frontend to drive.

READ-ONLY by design, same rule as jira-qa-gate.py. It reads one ledger file and
prints a verdict. It talks to nothing.

Checks, each PASS / FAIL with its evidence:

- ``coverage``     every declared criterion carries an observation or a waiver
- ``waivers``      every waiver carries a reason of substance
- ``self-review``  the reviewer is neither the implementer nor an MR author
- ``evidence``     a pipeline id and at least one MR link were recorded
- ``scope``        every file written during the review matches scope.paths

Exit code mirrors the verdict, so callers can branch on it without parsing.
"""

from __future__ import annotations

import fnmatch
import json
import os
import sys
from pathlib import Path

MIN_WAIVER_WORDS = 4
MIN_WAIVER_CHARS = 15

REQUIRED_FIELDS = ("key", "reviewer", "criteria", "scope")


def state_dir() -> Path:
    override = os.environ.get("QA_REVIEW_STATE_DIR")
    if override:
        return Path(override)
    base = os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local" / "state"))
    return Path(base) / "qa-review"


class Report:
    def __init__(self) -> None:
        self.lines: list[str] = []
        self.failed = False

    def ok(self, check: str, evidence: str) -> None:
        self.lines.append(f"PASS  {check:<12} {evidence}")

    def bad(self, check: str, evidence: str) -> None:
        self.lines.append(f"FAIL  {check:<12} {evidence}")
        self.failed = True

    def emit(self) -> int:
        for line in self.lines:
            print(line)
        verdict = "fail" if self.failed else "pass"
        print(f"QA-REVIEW-RESULT: {verdict}")
        return 1 if self.failed else 0


def load(key: str, report: Report) -> dict | None:
    path = state_dir() / f"{key}.json"
    if not path.is_file():
        report.bad("ledger", f"no ledger at {path}; nothing was recorded for {key}")
        return None
    try:
        data = json.loads(path.read_text())
    except (json.JSONDecodeError, OSError) as exc:
        report.bad("ledger", f"{path} is unreadable: {exc}")
        return None
    if not isinstance(data, dict):
        report.bad("ledger", f"{path} does not contain an object")
        return None
    missing = [f for f in REQUIRED_FIELDS if f not in data]
    if missing:
        report.bad("ledger", f"missing required field(s): {', '.join(missing)}")
        return None
    report.ok("ledger", f"{path}")
    return data


def effective(crit: dict) -> dict | None:
    """The entry that counts: the most recent one.

    Entries are append-only so the audit trail keeps every attempt, but a
    reviewer who replaces a junk waiver with a real reason must be able to reach
    pass. A gate you can never satisfy is a gate people route around.
    """
    entries = crit.get("entries") or []
    return entries[-1] if entries else None


def check_coverage(data: dict, report: Report) -> None:
    criteria = data.get("criteria") or []
    if not criteria:
        report.bad("coverage", "no acceptance criteria declared; a review with no "
                               "criteria verifies nothing")
        return
    silent = [c.get("id", "?") for c in criteria if effective(c) is None]
    if silent:
        report.bad("coverage", f"criteria with neither observation nor waiver: "
                               f"{', '.join(map(str, silent))}")
        return
    kinds = [effective(c).get("kind") for c in criteria]
    report.ok("coverage", f"{len(criteria)} criteria accounted for "
                          f"({kinds.count('observation')} observed, "
                          f"{kinds.count('waiver')} waived)")


def check_waivers(data: dict, report: Report) -> None:
    bad: list[str] = []
    total = 0
    for crit in data.get("criteria") or []:
        entry = effective(crit)
        if entry is None or entry.get("kind") != "waiver":
            continue
        total += 1
        reason = (entry.get("reason") or "").strip()
        if len(reason) < MIN_WAIVER_CHARS or len(reason.split()) < MIN_WAIVER_WORDS:
            bad.append(f"{crit.get('id', '?')} ({reason!r})")
    if bad:
        report.bad("waivers", "waiver without a reason of substance: " + "; ".join(bad))
        return
    report.ok("waivers", f"{total} effective waiver(s), each with a stated reason")


def check_self_review(data: dict, report: Report) -> None:
    reviewer = (data.get("reviewer") or "").strip()
    if not reviewer:
        report.bad("self-review", "no reviewer recorded; cannot prove this was a peer review")
        return
    implementer = (data.get("implementer") or "").strip()
    authors = [a.strip() for a in (data.get("mr_authors") or []) if a]
    if reviewer == implementer:
        report.bad("self-review", f"{reviewer} implemented this ticket")
        return
    if reviewer in authors:
        report.bad("self-review", f"{reviewer} authored a linked merge request")
        return
    report.ok("self-review", f"reviewer {reviewer}, implementer {implementer or 'unknown'}")


def check_evidence(data: dict, report: Report) -> None:
    pipeline = (data.get("pipeline_id") or "").strip()
    links = [link for link in (data.get("mr_links") or []) if link]
    problems = []
    if not pipeline:
        problems.append("no pipeline id recorded")
    if not links:
        problems.append("no merge request link recorded")
    if problems:
        report.bad("evidence", "; ".join(problems))
        return
    report.ok("evidence", f"pipeline {pipeline}, {len(links)} MR link(s)")


def check_scope(data: dict, report: Report) -> None:
    scope = data.get("scope") or {}
    patterns = [p for p in (scope.get("paths") or []) if p]
    if not patterns:
        report.bad("scope", "no scope.paths declared; the scope gate cannot compare "
                            "file paths against prose")
        return
    written = [f for f in (data.get("written_files") or []) if f]
    stray = [f for f in written if not any(fnmatch.fnmatch(f, p) for p in patterns)]
    if stray:
        report.bad("scope", f"written outside declared scope: {', '.join(stray)}")
        return
    report.ok("scope", f"{len(written)} file(s) written, all within "
                       f"{len(patterns)} declared path pattern(s)")


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: qa-review-gate.py <TICKET-KEY>", file=sys.stderr)
        print("QA-REVIEW-RESULT: fail")
        return 1

    report = Report()
    data = load(argv[1], report)
    if data is not None:
        check_coverage(data, report)
        check_waivers(data, report)
        check_self_review(data, report)
        check_evidence(data, report)
        check_scope(data, report)
    return report.emit()


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv))
    except Exception as exc:  # fail closed: an exception is never a pass
        print(f"FAIL  internal    gate raised: {exc.__class__.__name__}: {exc}")
        print("QA-REVIEW-RESULT: fail")
        sys.exit(1)
