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

## Permissions and auto mode — measured behaviour

All of this was measured with a throwaway bare repo plus clone under the session scratchpad, after a
run of wrong assumptions cost an evening. Do not re-derive it from the schema; the schema does not say
most of it.

- **`git -C <dir> …` bypasses every git permission rule.** Rules match a command prefix, so a command
  starting `git -C` matches none of the `Bash(git push …)` entries. Measured: `git -C <dir> push origin
  main` ran while `cd <dir> && git push origin main` was denied by the very rule meant to stop it. Use
  `git -C` for read-only git only — never for push, and **never** as a way around a refusal.
- **A rule needs one entry per flag spelling.** `Bash(git push --force:*)` did not cover
  `--force-with-lease`; `--delete` does not cover `git push origin :branch`. The mechanism is not
  established (the prompt attributed the match to a bare-prefix glob, which contradicts a
  word-boundary theory), so rely on the observation, not on a story about pattern compilation.
- Follows from those two: **a prefix rule cannot guarantee anything**, because every command has
  spellings you did not enumerate. Guarantees belong in `autoMode` (`soft_deny`/`hard_deny`), which is
  judged semantically. Permission rules are for the common shape and for cutting noise.
- **`permissions.allow` is the only list that removes protection** — an allow rule suspends the
  classifier for that command (`autoMode.classifyAllShell` defaults false). Auditing what is in `allow`
  protects more than adding denies. The harness drops *some* allow rules itself, logging
  `Ignoring dangerous permission … (bypasses classifier)`, but it is not a safety net: it flagged
  `Bash(python -m pytest:*)` and did **not** flag `Bash(rm:*)` or `Bash(find:*)`.
- Prefer `ask` over `deny` for anything that is sometimes legitimate. A deny forces a copy-paste
  hand-off; an ask is one click. And a rule cannot see which repo it is in, so a deny meant for one
  project's `main` silently governs every repo touched in that session.
- **Settings edits apply mid-session — no restart.** The harness watches the settings files
  (`Watching for changes in setting files …` in the debug log). Proven both ways: adding a deny made the
  command fail immediately, removing it made the same command run again.
- **A safe probe cannot test the auto-mode classifier.** It is context-aware, so anything harmless
  enough to run is harmless enough for it to allow — `rm -rf` of a directory it just watched being
  created, a push to a bare repo in `/tmp`, `composer update` where there is no `composer.json`. String
  rules are testable this way; classifier behaviour is not. A green probe there proves nothing.
- **`claude -p "reply ok" --debug-file /tmp/x.log < /dev/null`** is the instrument for harness
  questions — it writes the harness's own log for grepping. It does *not* contain the classifier prompt,
  so it cannot answer whether project-level `autoMode` is read or whether those arrays merge across
  settings levels. That question is still open.

## Task tracking

- Never delete tasks without Sebastian's explicit approval.
