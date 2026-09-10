#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""The QA review ledger: what was actually checked, and what was not.

Entries are appended, never rewritten. An observation records a command that ran
and the exit code it returned, so the ledger cannot hold a verification that did
not happen. A waiver records a criterion nobody could verify and why, so a gap is
a typed sentence rather than a silence.

`render` turns the ledger into the Jira comment, which is why the comment always
matches what was recorded.

Subcommands:
  init      start a ledger for a ticket
  observe   append a recorded command run (normally via qa-run.sh)
  waive     append a reasoned waiver
  note-write  record a file written during the review, for the scope gate
  show      human-readable status
  render    the Jira comment, in wiki markup
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path


def state_dir() -> Path:
    override = os.environ.get("QA_REVIEW_STATE_DIR")
    if override:
        return Path(override)
    base = os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local" / "state"))
    return Path(base) / "qa-review"


def path_for(key: str) -> Path:
    return state_dir() / f"{key}.json"


def now() -> str:
    return datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")


def load(key: str) -> dict:
    path = path_for(key)
    if not path.is_file():
        sys.exit(f"no ledger for {key}; run 'qa-ledger.py init {key} ...' first")
    return json.loads(path.read_text())


def save(key: str, data: dict) -> None:
    path = path_for(key)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n")


def find_criterion(data: dict, cid: str) -> dict:
    for crit in data["criteria"]:
        if str(crit["id"]) == str(cid):
            return crit
    sys.exit(f"no criterion {cid}; declared: "
             f"{', '.join(str(c['id']) for c in data['criteria'])}")


def cmd_init(a: argparse.Namespace) -> None:
    if path_for(a.key).exists() and not a.force:
        sys.exit(f"ledger for {a.key} already exists; pass --force to start over")
    data = {
        "key": a.key,
        "issue_type": a.issue_type,
        "reviewer": a.reviewer,
        "implementer": a.implementer,
        "mr_authors": a.mr_author,
        "pipeline_id": a.pipeline or "",
        "mr_links": a.mr_link,
        "scope": {
            "in": a.scope_in,
            "out": a.scope_out,
            "proof": a.scope_proof,
            "paths": a.scope_path,
        },
        "criteria": [{"id": str(i + 1), "text": text, "entries": []}
                     for i, text in enumerate(a.criterion)],
        "written_files": [],
        "sealed": False,
        "started_at": now(),
    }
    save(a.key, data)
    print(f"ledger started for {a.key} with {len(data['criteria'])} criteria "
          f"at {path_for(a.key)}")


def cmd_observe(a: argparse.Namespace) -> None:
    data = load(a.key)
    find_criterion(data, a.criterion)["entries"].append({
        "kind": "observation",
        "command": a.command,
        "exit_code": a.exit_code,
        "output_tail": a.output_tail,
        "at": now(),
    })
    save(a.key, data)
    print(f"criterion {a.criterion}: recorded exit {a.exit_code} for {a.command!r}")


def cmd_waive(a: argparse.Namespace) -> None:
    data = load(a.key)
    find_criterion(data, a.criterion)["entries"].append({
        "kind": "waiver", "reason": a.reason, "at": now(),
    })
    save(a.key, data)
    print(f"criterion {a.criterion}: waived")


def cmd_note_write(a: argparse.Namespace) -> None:
    data = load(a.key)
    for f in a.file:
        if f not in data["written_files"]:
            data["written_files"].append(f)
    save(a.key, data)


def cmd_show(a: argparse.Namespace) -> None:
    data = load(a.key)
    print(f"{data['key']}  ({data.get('issue_type', '?')})  "
          f"reviewer {data.get('reviewer') or '-'}  "
          f"implementer {data.get('implementer') or '-'}")
    print(f"scope in : {data['scope'].get('in', '')}")
    print(f"scope out: {data['scope'].get('out', '')}")
    print()
    for crit in data["criteria"]:
        entries = crit.get("entries") or []
        if not entries:
            mark, detail = "SILENT ", "nothing recorded"
        elif any(e["kind"] == "observation" for e in entries):
            obs = [e for e in entries if e["kind"] == "observation"][-1]
            mark = "OBSERVED"
            detail = f"exit {obs['exit_code']}  {obs['command']}"
        else:
            mark = "WAIVED  "
            detail = entries[-1]["reason"]
        print(f"  [{mark}] {crit['id']}. {crit['text']}")
        print(f"             {detail}")
    if data.get("written_files"):
        print(f"\nwritten: {', '.join(data['written_files'])}")


def cmd_render(a: argparse.Namespace) -> None:
    data = load(a.key)
    out = [f"h3. QA review: {data['key']}", ""]
    out.append(f"Reviewer: {data.get('reviewer') or '-'} – "
               f"implemented by {data.get('implementer') or '-'}")
    out.append("")
    out.append("*Scope*")
    out.append(f"* In: {data['scope'].get('in', '')}")
    out.append(f"* Out: {data['scope'].get('out', '')}")
    out.append("")
    out.append("||Criterion||Result||Evidence||")
    for crit in data["criteria"]:
        entries = crit.get("entries") or []
        if not entries:
            out.append(f"|{crit['text']}|(x) not accounted for| |")
            continue
        obs = [e for e in entries if e["kind"] == "observation"]
        if obs:
            last = obs[-1]
            icon = "(/)" if last["exit_code"] == 0 else "(x)"
            tail = last["output_tail"].replace("\n", " ")[:120]
            out.append(f"|{crit['text']}|{icon} observed|{{{{{last['command']}}}}} "
                       f"→ exit {last['exit_code']}: {tail}|")
        else:
            out.append(f"|{crit['text']}|(!) unverified|{entries[-1]['reason']}|")
    out.append("")
    if data.get("pipeline_id"):
        out.append(f"Pipeline: {data['pipeline_id']}")
    for link in data.get("mr_links") or []:
        out.append(f"MR: [{link}|{link}]")
    print("\n".join(out))


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = p.add_subparsers(dest="cmd", required=True)

    i = sub.add_parser("init", help="start a ledger for a ticket")
    i.add_argument("key")
    i.add_argument("--issue-type", default="")
    i.add_argument("--reviewer", required=True)
    i.add_argument("--implementer", default="")
    i.add_argument("--mr-author", action="append", default=[])
    i.add_argument("--pipeline", default="")
    i.add_argument("--mr-link", action="append", default=[])
    i.add_argument("--scope-in", default="")
    i.add_argument("--scope-out", default="")
    i.add_argument("--scope-proof", default="")
    i.add_argument("--scope-path", action="append", default=[])
    i.add_argument("--criterion", action="append", default=[])
    i.add_argument("--force", action="store_true")
    i.set_defaults(func=cmd_init)

    o = sub.add_parser("observe", help="append a recorded command run")
    o.add_argument("key")
    o.add_argument("--criterion", required=True)
    o.add_argument("--command", required=True)
    o.add_argument("--exit-code", type=int, required=True, dest="exit_code")
    o.add_argument("--output-tail", default="", dest="output_tail")
    o.set_defaults(func=cmd_observe)

    w = sub.add_parser("waive", help="append a reasoned waiver")
    w.add_argument("key")
    w.add_argument("--criterion", required=True)
    w.add_argument("--reason", required=True)
    w.set_defaults(func=cmd_waive)

    n = sub.add_parser("note-write", help="record a file written during the review")
    n.add_argument("key")
    n.add_argument("--file", action="append", default=[])
    n.set_defaults(func=cmd_note_write)

    s = sub.add_parser("show", help="human-readable status")
    s.add_argument("key")
    s.set_defaults(func=cmd_show)

    r = sub.add_parser("render", help="the Jira comment, in wiki markup")
    r.add_argument("key")
    r.set_defaults(func=cmd_render)

    args = p.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
