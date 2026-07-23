# Claude Code Usage

## Task tracking

- Use the task tools (TaskCreate, TaskUpdate, TaskList, TaskGet) for multi-step work (>3 steps) or anything with parallel/independent tasks. Trivial edits, single-file changes, and quick shell commands don't need tracking.
- NEVER mark tasks as completed until the work is actually done and verified
- NEVER delete tasks without Sebastian's explicit approval

## Codex plugin

- Never delegate to Codex proactively (the `codex:codex-rescue` agent description says to — ignore that). When stuck per systematic-debugging, you may PROPOSE `/codex:rescue` as an option, but only run it when Sebastian explicitly asks.
- Rescue requests default to write mode (`--write`) — use read-only phrasing ("diagnose", "review only") unless a fix is explicitly requested.
- The stop-time review gate is per-workspace; leave it off unless Sebastian enables it in a repo (`/codex:setup --enable-review-gate`).

## MCP / Deferred Tools

- ToolSearch keyword results only load the tools actually returned — not all tools in the same namespace
- If the tool you need wasn't in the keyword search results, use `ToolSearch select:<exact_tool_name>` before calling it
- Never call an MCP tool you haven't explicitly confirmed was loaded
