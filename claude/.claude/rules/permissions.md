---
paths:
  - "**/.claude/settings*.json"
  - "**/settings.reference.json"
---

# Permission rules and auto mode

Measured with a throwaway repo under the scratchpad, after an evening lost to assuming:

- `git -C <dir> …` matches no `Bash(git push …)` rule — rules match a command prefix. Never for a push,
  never to get past a refusal (`git -C … push origin main` ran; the same push via `cd &&` was denied).
- One entry per flag spelling: `--force` missed `--force-with-lease`, `--delete` misses `push origin :branch`.
  So a prefix rule guarantees nothing; what must hold regardless of phrasing goes in `autoMode`.
- `permissions.allow` is the only list that REMOVES protection — an allow rule suspends the classifier.
  Audit it. The harness drops some itself (`Ignoring dangerous permission …`) but flagged
  `python -m pytest` and not `rm`.
- Prefer `ask` to `deny`: a deny forces a copy-paste hand-off, an ask is one click — and a rule can't see
  which repo it's in, so one project's `main` deny governs every repo in the session.
- Settings apply mid-session, no restart (the harness watches the files — proven both directions).
- A safe probe can't test the classifier: context-aware, so anything harmless enough to run is harmless
  enough to allow. `claude -p "reply ok" --debug-file /tmp/x.log` is the honest instrument.
- A docs summary or claude-code-guide answer is a hypothesis, not a verdict, for anything the harness
  enforces (directory bounds, deny rules, `cd`). Settle it with `claude -p`: prompt via stdin
  (`--allowedTools` is variadic and eats a positional prompt), `--permission-mode default` to keep the
  classifier out, a control case that must pass, and a `want=` per case. (The guide claimed `--add-dir`
  leaves the cd block in place; two runs showed the opposite.)

## Probing Claude Code settings

- A variable set in settings.json `env` beats a shell export: `VAR=x claude -p …` does not
  override it. Probe with `claude -p --settings '{"env":{"VAR":"x"}}'` and a cheap model.
- `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` counts layers below the main session (default 3); `1`
  turns nesting off. Anything but a positive integer is ignored, so `0` silently means 3 — there is
  no unlimited setting.
- `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS` caps Agent-tool spawns only. Workflow runs have their own
  cap (`CLAUDE_CODE_WORKFLOW_MAX_CONCURRENT_AGENTS`, default 16).
- `CLAUDE_CODE_SUBAGENT_MODEL` is only a default since v2.1.251: a model passed at spawn or set in
  an agent definition wins. `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` makes it binding.
