# Claude Code Usage

## Verifying review findings

- Before acting on a review finding (human, Codex, or subagent), decompose it into independently falsifiable claims — typically arithmetic/logic, external API behavior, and real-world reachability — and test each with the cheapest decisive instrument: unit-level repro against real objects, a direct API probe, a production-data query. Verdicts like "no-ship" often bundle one true claim with refutable ones.
- For framework-internal mechanisms, a minimal runtime experiment outranks any source-reading chain. Source-reading produces plausible mechanism stories that miss gates elsewhere in the call path (a source-verified UnitOfWork "reachability walk throws" analysis once missed the `commit()` nothing-to-do early return sitting BEFORE the assert — both the original claim and its refutation were part-wrong until a 60-row experiment settled it).

## Parallel agents in one checkout

Contract for several write-agents in one working copy (proven on a five-agent round: zero merge
conflicts, three incidents behind these rules):

- **Partition file ownership up front.** Agents never touch shared files (service registration,
  instructions, docs, skills); those ship as snippets in a per-agent handoff file. The integrator
  applies them and owns every shared-file edit and all commits — agents run no git at all.
- **Agents run only their own test files**, never the full suite; a sibling's mid-edit failures are
  not theirs. The integrator runs full gates.
- **Judge a deliverable only after the agent's completion message**, or have agents touch a
  gates-green marker file as their last act and compare its mtime against the sources. (A mid-edit
  scan found phpstan errors that were gone by completion; an mtime-based "no work on disk" nudge was
  itself stale seconds later.)
- **Brief agents to verify payload shapes against the LIVE system** and build fixtures from raw
  payloads; every live-verification pass in that round caught a bug green unit tests had missed.

## Workflow fan-out

- The number of agents a script can spawn must be a literal or a `slice()` to one — never the length
  of an agent-produced list. Batch items per topic or file group instead of one agent per item.
  (A research script asked five sweep agents for "every claim", got 254, and scheduled one verifier
  each; it had to be paused by hand.)
- State the worst-case agent count in the message that launches the workflow, and add a `+Nk` budget
  when the run is unattended.

## Bash tool denials

- A denied compound command ran **none** of its parts. Re-issue the parts you still need as
  separate calls before continuing. (A denied kill-then-relaunch sequence left a stale Ghostty
  instance alive; the next test window was silently absorbed into the live Herdr session.)

## Probing Claude Code settings

- A variable set in settings.json `env` beats a shell export: `VAR=x claude -p …` does not
  override it. Probe with `claude -p --settings '{"env":{"VAR":"x"}}'` and a cheap model.
- `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`: `0` lifts the limit (nesting allowed), `1` lets the
  main session spawn but blocks subagents from spawning. Verified live, not in the docs.

## Task tracking

- Never delete tasks without Sebastian's explicit approval.
