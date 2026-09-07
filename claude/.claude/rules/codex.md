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

## Interactive Codex in a Herdr pane

Launch line that gives astra at high effort, read-only, no approval prompts:
`codex -m gpt-6-astra -c model_reasoning_effort=high -s read-only -a never`, started via
`herdr agent start <name> --kind codex --pane <id> -- <that line>`.

- **Read the screen before sending keys** (`herdr agent read <name> --source visible`). A fresh start can
  show, in turn, an update prompt, a hooks-review screen, and a directory-trust prompt; Herdr reports
  `agent_not_ready`/`blocked` for each. An esc that already closed a popup makes the next `/` land as
  literal text in the composer (`//hooks` once). `ctrl+u` clears the composer.
- **Update prompt:** skip it during incident work; an update mid-task exits the agent and the pane drops to
  a shell (`agent_not_found` on the next prompt), restart with the same launch line.
- **Hooks-review screen:** do not esc it away on Sebastian's behalf; `/hooks` reopens it. The hook is
  Herdr's SessionStart `herdr-agent-state.sh` from `~/.codex/hooks.json`.
- **Trust prompt:** answer yes only for Sebastian's own checkouts.
- **Fast mode:** the footer may read `gpt-6-astra high fast` after the first turn even though nothing in
  `config.toml` or the launch line asked for it (`/fast` = 2x speed, more usage). Sebastian wants it off for
  reviews; check the footer before the first prompt, `/fast` toggles it.
- **Cyber filter:** a review brief that spells out an exploit chain (endpoints, gadget classes, payload
  shape) makes astra investigate and then refuse to show the result ("We take extra caution with
  cybersecurity requests", Trusted Access link). Brief it as a defensive code review of the mitigation
  diff: name the layers, the facts it may rely on, and the regressions/bypass seams to check, without the
  attack recipe. That version completed in under three minutes and found a real regression.
- `herdr agent prompt --wait` can return `idle` while a startup dialog is still on screen; treat the first
  `idle` after a start as unverified until the composer shows "Ask Codex to do anything".
