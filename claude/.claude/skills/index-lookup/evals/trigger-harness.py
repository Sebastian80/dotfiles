#!/usr/bin/env python3
"""Trigger eval for an installed skill: does `claude -p <query>` invoke it?

Runs each query N times via claude -p in plan mode with all MCP servers stripped
(so no IDE load), scores a Skill tool_use whose skill name matches, and stops each
run as soon as the verdict is known. A case counts as triggered when the trigger
rate over its runs is >= the threshold, matching skill-creator's own run_eval.py
defaults (3 runs, 0.5). Writes JSONL + a summary.

--model is REQUIRED on purpose. Trigger behaviour is model-specific (Anthropic
documents Opus 4.5/4.6 overtriggering on language tuned against undertriggering
elsewhere), so pass the model your users actually run and report each model as its
own arm instead of blending them. Falling back to the settings default is banned
here because that default is Fable, which must never be spent on evals.

usage: trigger-harness.py <eval.json> <skill-name> <arm-label> <out-dir> --model m
                          [--workers 3] [--runs 3] [--threshold 0.5]
                          [--effort e] [--cwd path, default: current directory]
"""
import hashlib, json, os, subprocess, sys, time, concurrent.futures as cf
from datetime import datetime, timezone
from pathlib import Path


def arg(name, default=None, cast=str):
    return cast(sys.argv[sys.argv.index(name) + 1]) if name in sys.argv else default


eval_path, skill, arm, out_dir = sys.argv[1:5]
workers = arg("--workers", 3, int)
runs_per_query = arg("--runs", 3, int)
threshold = arg("--threshold", 0.5, float)
model = arg("--model")
if not model:
    sys.exit("--model is required: never let an eval fall back to the settings default (Fable).")
if "fable" in model.lower():
    sys.exit(f"refusing to run an eval on {model}: Fable is never used for eval runs.")
effort = arg("--effort")
cwd = arg("--cwd", os.getcwd())
cases = json.load(open(eval_path))
Path(out_dir).mkdir(parents=True, exist_ok=True)
env = {k: v for k, v in os.environ.items() if k != "CLAUDECODE"}


def one_run(query):
    cmd = ["claude", "-p", query, "--output-format", "stream-json", "--verbose",
           "--permission-mode", "plan", "--strict-mcp-config", "--mcp-config", '{"mcpServers":{}}',
           "--max-turns", "3"]
    if model:
        cmd += ["--model", model]
    if effort:
        cmd += ["--effort", effort]
    t0 = time.time()
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, env=env,
                         cwd=cwd, stdin=subprocess.DEVNULL)
    invoked = False
    answered = False
    tools = []
    skills = []
    try:
        for line in p.stdout:
            try:
                ev = json.loads(line)
            except json.JSONDecodeError:
                continue
            if ev.get("type") == "assistant":
                answered = True
                for c in ev.get("message", {}).get("content", []):
                    if c.get("type") == "tool_use":
                        tools.append(c.get("name"))
                        if c.get("name") == "Skill":
                            name = str(c.get("input", {}).get("skill", ""))
                            skills.append(name)
                            if skill in name:
                                invoked = True
                if invoked or len(tools) >= 3:
                    break
            if time.time() - t0 > 150:
                break
    finally:
        p.kill()
    return {"invoked": invoked, "answered": answered, "skills": skills, "first_tools": tools[:3],
            "seconds": round(time.time() - t0, 1)}


def run_case(case):
    trials = [one_run(case["query"]) for _ in range(runs_per_query)]
    # A run with no assistant turn at all (rate limit, auth failure, CLI crash) is a
    # non-answer, not a miss: scoring it as "not invoked" would fake a routing failure.
    answered = [t for t in trials if t["answered"]]
    hits = sum(t["invoked"] for t in answered)
    rate = hits / len(answered) if answered else None
    return {"query": case["query"][:80], "should_trigger": case["should_trigger"],
            "invoked": None if rate is None else rate >= threshold, "trigger_rate": rate,
            "runs": len(trials), "non_answers": len(trials) - len(answered),
            "skills": sorted({s for t in trials for s in t["skills"]}),
            "first_tools": trials[0]["first_tools"],
            "seconds": round(sum(t["seconds"] for t in trials), 1)}


results = []
with cf.ThreadPoolExecutor(max_workers=workers) as ex:
    for r in ex.map(run_case, cases):
        results.append(r)
        print(json.dumps(r), flush=True)

with open(Path(out_dir) / f"{arm}.jsonl", "w") as f:
    for r in results:
        f.write(json.dumps(r) + "\n")
scored = [r for r in results if r["invoked"] is not None]
pos = [r for r in scored if r["should_trigger"]]
neg = [r for r in scored if not r["should_trigger"]]
cli = subprocess.run(["claude", "--version"], capture_output=True, text=True, env=env).stdout.strip()
# Provenance: a trigger rate quoted without the model, CLI version and exact eval set
# cannot be compared with anything later.
summary = {"arm": arm, "model": model, "effort": effort, "claude_cli": cli,
           "eval_set": os.path.basename(eval_path),
           "eval_set_sha256": hashlib.sha256(open(eval_path, "rb").read()).hexdigest()[:16],
           "skill": skill, "cwd": cwd, "finished_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
           "runs_per_query": runs_per_query, "threshold": threshold,
           "unscored_cases": len(results) - len(scored),
           "positives": len(pos), "pos_invoked": sum(r["invoked"] for r in pos),
           "negatives": len(neg), "neg_invoked": sum(r["invoked"] for r in neg)}
print("SUMMARY", json.dumps(summary))
json.dump(summary, open(Path(out_dir) / f"{arm}-summary.json", "w"))
