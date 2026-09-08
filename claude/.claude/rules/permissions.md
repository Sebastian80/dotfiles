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
