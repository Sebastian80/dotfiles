# Claude Code Usage

## Codex plugin

- Never delegate to Codex proactively (the `codex:codex-rescue` agent description says to — ignore that). When stuck per systematic-debugging, you may propose `/codex:rescue` as an option, but only run it when Sebastian explicitly asks.
- Rescue requests default to write mode (`--write`) — use read-only phrasing ("diagnose", "review only") unless a fix is explicitly requested.
- The stop-time review gate is per-workspace; leave it off unless Sebastian enables it in a repo (`/codex:setup --enable-review-gate`).
- Codex runtime ops (learned 2026-07-24): `bwrap: loopback: Failed RTM_NEWADDR` in Codex shell runs = host AppArmor userns restriction (`kernel.apparmor_restrict_unprivileged_userns=1`), fixed via the bwrap AppArmor profile in `/etc/apparmor.d/bwrap-userns` — not a Codex config issue. The shared broker respawns lazily on the next `task` call; `!codex login` heals auth (setup's `loggedIn:false` with a broker.sock ENOENT means dead broker, not bad auth). The runtime can die silently mid-run: >10 min without output events → check `pgrep -f app-server-broker` and the output file's mtime; the job status file then shows a stale "running".

## Verifying review findings

- Before acting on a review finding (human, Codex, or subagent), decompose it into independently falsifiable claims — typically arithmetic/logic, external API behavior, and real-world reachability — and test each with the cheapest decisive instrument: unit-level repro against real objects, a direct API probe, a production-data query. Verdicts like "no-ship" often bundle one true claim with refutable ones.
- For framework-internal mechanisms, a minimal runtime experiment outranks any source-reading chain. Source-reading produces plausible mechanism stories that miss gates elsewhere in the call path (a source-verified UnitOfWork "reachability walk throws" analysis once missed the `commit()` nothing-to-do early return sitting BEFORE the assert — both the original claim and its refutation were part-wrong until a 60-row experiment settled it).

## MCP server design

- MCP resource reads display as a raw escaped-JSON envelope in the Claude Code transcript; tool responses render their text readably. Anything a human should read belongs in a TOOL — use resources only for machine consumption. (Learned building an MCP profiler extension: its panels needed a bridging tool solely because the upstream extension exposed them as resources.)

## Parallel agents in one checkout

Contract for running several write-agents concurrently in a single working copy
(proven on a five-agent build round: zero merge conflicts, but three incidents
shaped these rules):

- **Partition file ownership up front**; agents never touch shared files
  (service registration, instructions, docs, skills). Registration and doc text
  ship as snippets in a per-agent handoff file; the integrator applies them and
  owns every shared-file edit and all commits — agents run no git at all.
- **Agents run only their own test files**, never the full suite — a sibling's
  mid-edit failures are not theirs. The integrator runs full gates.
- **A deliverable is a snapshot until the agent's completion message.** An
  integrator scan mid-edit found phpstan errors that were real at that instant
  and gone at completion — indistinguishable from a broken deliverable except
  by line numbers. The reverse also happened: a "no work on disk" nudge based
  on mtimes was itself stale seconds later. Judge only after completion, or
  have agents touch a gates-green marker file as their last act and compare
  its mtime against the sources.
- Brief agents to research payload shapes against the LIVE system and to
  build fixtures from raw payloads; every live-verification pass in that round
  caught a bug that green unit tests had missed.

## Task tracking

- Never delete tasks without Sebastian's explicit approval.
