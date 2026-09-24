# Claude Code Usage

## Verifying review findings

- Before acting on a review finding (human, Codex, or subagent), decompose it into independently falsifiable claims — typically arithmetic/logic, external API behavior, and real-world reachability — and test each with the cheapest decisive instrument: unit-level repro against real objects, a direct API probe, a production-data query. Verdicts like "no-ship" often bundle one true claim with refutable ones.
- For framework-internal mechanisms, a minimal runtime experiment outranks any source-reading chain. Source-reading produces plausible mechanism stories that miss gates elsewhere in the call path (a source-verified UnitOfWork "reachability walk throws" analysis once missed the `commit()` nothing-to-do early return sitting BEFORE the assert — both the original claim and its refutation were part-wrong until a 60-row experiment settled it).

## Bash tool denials

- A denied compound command ran **none** of its parts. Re-issue the parts you still need as
  separate calls before continuing. (A denied kill-then-relaunch sequence left a stale Ghostty
  instance alive; the next test window was silently absorbed into the live Herdr session.)

## Task tracking

- Never delete tasks without Sebastian's explicit approval.
