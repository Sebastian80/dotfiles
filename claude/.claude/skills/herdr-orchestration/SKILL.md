---
name: herdr-orchestration
description: Use when a Claude Code session drives other agents in Herdr panes or tabs while a human is still talking to it — starting workers, prompting them, waiting for results, reading their output. Also use when `herdr agent prompt --wait` or `herdr agent wait` is about to run in a foreground Bash call, when a wait returned `idle` but the work looks unfinished, or when the human complains the orchestrator went quiet. Requires the `herdr` skill.
---

# Herdr Orchestration

Overlay on the `herdr` skill (which is upstream's own file, `herdr --skill`, and stays
unmodified). It changes one thing: how the orchestrator waits.

**REQUIRED BACKGROUND:** the `herdr` skill for CLI mechanics, IDs and lifecycle states.

## Core principle

The orchestrator is a single-turn session. A foreground `herdr agent wait` or
`prompt --wait` occupies its turn until the worker settles, so the human cannot reach it,
and the Bash timeout kills the wait with no result. Waiting therefore happens in the
background; the harness re-invokes the session when the wait exits.

## The pattern

```bash
# 1. Fire without waiting. Returns as soon as the prompt is delivered.
herdr agent prompt worker "Run the full test suite and report pass/fail counts."

# 2. Wait in the background (Bash tool: run_in_background=true), log the outcome.
{ herdr agent wait worker --until idle --until done --until blocked --timeout 900000
  echo "EXIT=$?"; } > "<scratchpad>/worker-wait.log" 2>&1   # the session scratchpad dir

# 3. End the turn. Talk to the human. The completion notification wakes you.

# 4. On wake-up: the state, then the evidence.
herdr agent get worker
herdr agent read worker --source recent-unwrapped --lines 120
```

`--timeout` is a check-in interval, not a deadline. If it fires before the worker settles,
read the pane and start another background wait. The Bash tool caps a single foreground
call at `BASH_MAX_TIMEOUT_MS`; a background call has no such cap.

`idle` means the worker's turn ended, not that its task is done. A worker that pushed the
work into its own background shell reports `idle` within seconds. Read the pane before
declaring anything finished.

## Quick reference

| Situation | Do |
|---|---|
| Send work | `herdr agent prompt <name> "<text>"` (no `--wait`) |
| Need the result later | background `herdr agent wait <name> --until idle --until done --until blocked --timeout <interval>` |
| Worker may ask a question | include `--until blocked`; on wake-up read the dialog, ask the human before answering |
| Several workers | one background wait per worker; each wakes the orchestrator separately |
| Wait exited on timeout | read the pane, re-arm the wait |
| Worker `idle` but output incomplete | its task runs in a background shell; poll with `agent read`, or ask it to report when done |
| Sub-second reply expected (a yes/no) | foreground `prompt --wait --timeout 30000` is fine |

## Common mistakes

- **`prompt --wait` for anything longer than a few seconds.** The human is locked out and
  the call dies at the Bash ceiling. Fire, then background-wait.
- **Omitting `--timeout` on a background wait.** Upstream documents that waits without a
  timeout can run forever. Always set an interval.
- **Treating `idle`/`done` as task completion.** They are turn boundaries. Evidence is in
  `agent read`.
- **Starting the wait before the prompt returned.** `agent prompt` must have returned
  `agent_prompted` first, else the wait matches the pre-prompt idle state instantly.
- **Launching `herdr` from inside a pane.** Nested herdr is disabled by default; workers are
  started with `herdr agent start` in an existing pane, never by running `herdr`.
