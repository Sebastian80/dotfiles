# Claude Code Usage

## Task tracking

- Use the task tools (TaskCreate, TaskUpdate, TaskList, TaskGet) for multi-step work (>3 steps) or anything with parallel/independent tasks. Trivial edits, single-file changes, and quick shell commands don't need tracking.
- NEVER mark tasks as completed until the work is actually done and verified
- NEVER delete tasks without Sebastian's explicit approval

## Codex plugin

- Never delegate to Codex proactively (the `codex:codex-rescue` agent description says to — ignore that). When stuck per systematic-debugging, you may PROPOSE `/codex:rescue` as an option, but only run it when Sebastian explicitly asks.
- Rescue requests default to write mode (`--write`) — use read-only phrasing ("diagnose", "review only") unless a fix is explicitly requested.
- The stop-time review gate is per-workspace; leave it off unless Sebastian enables it in a repo (`/codex:setup --enable-review-gate`).
- Codex runtime ops (learned 2026-07-24): `bwrap: loopback: Failed RTM_NEWADDR` in Codex shell runs = host AppArmor userns restriction (`kernel.apparmor_restrict_unprivileged_userns=1`), fixed via the bwrap AppArmor profile in `/etc/apparmor.d/bwrap-userns` — not a Codex config issue. The shared broker respawns lazily on the next `task` call; `!codex login` heals auth (setup's `loggedIn:false` with a broker.sock ENOENT means dead broker, not bad auth). The runtime can die silently mid-run: >10 min without output events → check `pgrep -f app-server-broker` and the output file's mtime; the job status file then shows a stale "running".

## Verifying review findings

- Before acting on a review finding (human, Codex, or subagent), decompose it into independently falsifiable claims — typically arithmetic/logic, external API behavior, and real-world reachability — and test each with the cheapest decisive instrument: unit-level repro against real objects, a direct API probe, a production-data query. Verdicts like "no-ship" often bundle one true claim with refutable ones.

## MCP / Deferred Tools

- ToolSearch keyword results only load the tools actually returned — not all tools in the same namespace
- If the tool you need wasn't in the keyword search results, use `ToolSearch select:<exact_tool_name>` before calling it
- Never call an MCP tool you haven't explicitly confirmed was loaded
