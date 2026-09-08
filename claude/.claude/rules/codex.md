# Codex

## MCP tool

Codex is reached through the `codex` MCP server (`mcp__codex__codex`, and
`mcp__codex__codex-reply` to continue a thread by `threadId`). It runs the local
`codex` CLI as a stdio server, so client and server ship in one binary and cannot
drift apart.

- Never delegate to Codex proactively. When stuck per systematic-debugging, you may
  propose it as an option, but only call it when Sebastian explicitly asks.
- Pass `sandbox` on every call — it defaults to nothing and the tool can write.
  `read-only` for diagnosis and review; `workspace-write` only when a fix is
  explicitly requested. Pair it with `approval-policy: never` and an explicit `cwd`.
- Set `model` explicitly. Catalog of codex-cli 0.153.3, top down: `gpt-6-astra` (most capable),
  `gpt-5.6-sol` (frontier coding), `gpt-5.6-terra` (balanced), `gpt-5.6-luna` (fast, cheap). Efforts
  `low`..`max` everywhere; `ultra` on all but luna. Reasoning effort comes from `~/.codex/config.toml`
  (`model_reasoning_effort`) unless overridden via the `config` parameter
  (`config: {"model_reasoning_effort": "max"}`).
- `ultra` is not "think harder": the catalog defines it as "maximum reasoning with automatic task
  delegation" — Codex spawns its own subagents (at xhigh on astra). Use `max` for depth without
  fan-out; when ultra is wanted, cap it in the same call:
  `config: {"agents": {"max_concurrent_threads_per_session": 2, "max_depth": 1}}` (keys move under
  `features.multi_agent_v2` once that flag is on; it is off here).
- The MCP tool is not a Bash call, so it is not subject to the 120s foreground
  timeout. `codex exec` is — anything long-running through the CLI needs
  `--output-last-message <file>` and a background run.
- `codex mcp-server` prints a deprecation warning on startup. It is superseded by
  `codex app-server` but still gains features, with no announced removal date. If it
  ever disappears, `codex exec` and `codex exec review --base|--uncommitted|--commit`
  are the stable fallbacks.
- `bwrap: loopback: Failed RTM_NEWADDR` in Codex shell runs = host AppArmor userns
  restriction (`kernel.apparmor_restrict_unprivileged_userns=1`), fixed via the bwrap
  AppArmor profile in `/etc/apparmor.d/bwrap-userns` — not a Codex config issue.
- `!codex login` heals authentication; `~/.codex/auth.json` holds it.

Driving an interactive Codex agent inside a Herdr pane: use the `codex-in-herdr` skill.
