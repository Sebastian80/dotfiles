---
name: parallel-agents
description: Use BEFORE spawning two or more write-agents at once, or before writing any Workflow script that fans out agents. Covers the ownership contract for agents sharing one checkout (worktree vs shared Docker stack, who edits shared files, who commits, which tests each agent runs, when a deliverable counts as done) and how to cap a workflow's agent count so it cannot explode from agent-produced lists.
---

# Parallel agents

## Parallel agents in one checkout

Give each write-agent its own worktree (`isolation: "worktree"`) when the project runs from any
checkout. When it can't — one Docker stack or database bound to this working copy — use this
contract (proven on a five-agent round: zero merge conflicts, three incidents behind these rules):

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
