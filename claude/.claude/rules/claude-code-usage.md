# Claude Code Usage

## Codex

Codex is reached through the `codex` MCP server (`mcp__codex__codex`, and
`mcp__codex__codex-reply` to continue a thread by `threadId`). It runs the local
`codex` CLI as a stdio server, so client and server ship in one binary and cannot
drift apart.

- Never delegate to Codex proactively. When stuck per systematic-debugging, you may
  propose it as an option, but only call it when Sebastian explicitly asks.
- Pass `sandbox` on every call — it defaults to nothing and the tool can write.
  `read-only` for diagnosis and review; `workspace-write` only when a fix is
  explicitly requested. Pair it with `approval-policy: never` and an explicit `cwd`.
- Set `model` explicitly; `gpt-5.6-sol` and `gpt-5.6-terra` are the only slugs that
  support `ultra` effort. Reasoning effort comes from `~/.codex/config.toml`
  (`model_reasoning_effort`) unless overridden via the `config` parameter.
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

## Permission rules and auto mode

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

## Task tracking

- Never delete tasks without Sebastian's explicit approval.
