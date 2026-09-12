# QA review with gates and boundaries

Design for a harness-neutral QA review skill that runs as a subagent under either
Claude Code or pi, produces machine-checkable evidence, and leaves the Jira write
to the orchestrator session a human is watching.

## Problem

QA review today is prose. The `qa` skill says to reproduce before verifying and to
quote observations per acceptance criterion, but nothing checks that any of it
happened. Confident prose about a verification that never ran looks exactly like
the real thing at the moment the ticket transitions.

The handover *into* QA is already mechanical: `jira-qa-gate.py` checks weblinks,
the UAT field, a work summary and MR pipeline status, and a PreToolUse hook blocks
the transition until they pass. The review side has no equivalent.

## What already exists

Do not rebuild these.

| Thing | Where | Covers |
|---|---|---|
| `jira-qa-gate.py` | `netresearch-jira` plugin | implementer handover into QA, read-only, config-driven |
| PreToolUse gate hook | same plugin | blocks gated transitions by name |
| `qa` skill | `dotfiles/claude/.claude/skills/qa/` | reviewer lifecycle, prose only |
| `peer-qa-review` | `netresearch/peer-qa-review-skill` (GitHub, not installed) | peer-review ritual, claim stage, severity vocabulary |
| `rules/testing.md` | dotfiles | red-before/green-after, no mocks in e2e, pristine output |

## Decisions

1. **The gate bites at the Jira write.** The transition path refuses without a
   passing verdict. Both harnesses call the same CLI, so enforcement does not
   depend on which agent is running.
2. **Evidence is captured, not retyped.** A wrapper records the commands actually
   run, with exit codes. The gate never judges whether an observation is *good*.
3. **The gate fails on silence, not on absence of tests.** Not every ticket has a
   test suite or a frontend to drive. Every declared criterion needs an observation
   *or* a waiver with a reason. Only an unaccounted criterion fails.
4. **Review and write are separate roles.** A reviewer subagent verifies and fills
   the ledger. The orchestrator session shows the result to a human, then
   transitions. The subagent's Jira boundary is declared in frontmatter, with the
   transition gate as the backstop.
5. **One implementation, two thin agent definitions.** Portability comes from the
   scripts, not from duplicated logic.

## Components

```text
dotfiles/agents/.agents/skills/qa-review/
├── SKILL.md                     lifecycle, gate rules, waiver rule
├── scripts/qa-run.sh            wrapper: records command, exit code, output tail
├── scripts/qa-ledger.py         init criteria, add waiver, render comment, verdict
├── scripts/qa-review-gate.py    the four gates, read-only, PASS/FAIL/WARN
└── agents/
    ├── qa-reviewer.pi.md        pi agent definition
    └── qa-reviewer.claude.md    Claude Code agent definition
```

Stowed to `~/.agents/skills/qa-review/`, which pi discovers natively. Claude Code
does not read that directory, so a committed symlink at
`dotfiles/claude/.claude/skills/qa-review` points at the same tree.

## Ledger

`~/.local/state/qa-review/<KEY>.json`, per ticket and per user. Outside any repo,
so no customer data lands in a project tree and nothing needs gitignoring.

```json
{
  "key": "PROJ-123",
  "issue_type": "Bug",
  "reviewer": "sebastian",
  "implementer": "colleague",
  "scope": {
    "in": "Coupon removal recalculation in the cart bundle",
    "out": "Checkout payment step, untouched",
    "proof": "Unit run + admin grid check on the reference env",
    "paths": ["src/Bundle/Cart/**", "tests/Bundle/Cart/**"]
  },
  "criteria": [
    {
      "id": "1",
      "text": "Cart total recalculates after coupon removal",
      "entries": [
        {
          "kind": "observation",
          "command": "make test-unit -- --filter CartTotal",
          "exit_code": 0,
          "output_tail": "OK (14 tests, 31 assertions)",
          "at": "2026-09-11T09:12:04+02:00"
        }
      ]
    },
    {
      "id": "2",
      "text": "Admin grid column sorts by net value",
      "entries": [
        {
          "kind": "waiver",
          "reason": "No admin fixture on the reference env; covered by MR review only.",
          "at": "2026-09-11T09:20:41+02:00"
        }
      ]
    }
  ],
  "sealed": false
}
```

An entry is only ever appended. `output_tail` is bounded; the wrapper keeps the
full output beside the ledger and references it.

## Verdict contract

`qa-review-gate.py <KEY>` prints one machine-readable line as its last output:

```text
QA-REVIEW-RESULT: pass
QA-REVIEW-RESULT: fail
```

Exit code mirrors it (0 / 1). Every check prints PASS, FAIL or WARN with its
evidence, in `jira-qa-gate.py`'s style, so the two read the same way.

## Gates

| Gate | Fails when |
|---|---|
| Coverage | a declared criterion has neither an observation nor a waiver |
| Self-review | the reviewer is the implementer or an MR author on the ticket |
| Evidence trail | the ledger carries no pipeline id, or no MR link |
| Scope | a file written during the review falls outside `scope.paths` |

The scope contract's `in` and `out` lines stay prose for humans. The gate compares
against `scope.paths`, a list of globs declared alongside them, because a gate
cannot diff file paths against a sentence. Declaring the globs is part of the scope
contract, not an extra step.

A waiver needs a non-empty reason of substance; a blank or single-word reason is a
failure, not a pass. Waivers are rendered into the Jira comment, visible to whoever
reads it.

## Ticket-type defaults

The Jira issue type suggests which criteria to declare. It never adds hard
requirements.

- **Bug**: reproduce the failure before the fix, verify it is gone after, plus a
  test run with counts.
- **Story / feature**: an agent-browser pass per acceptance criterion.
- **Anything else**: only what the scope contract declares.

## Flow

1. Reviewer subagent reads the ticket and every linked MR.
2. It declares the scope contract, and the criteria go into the ledger.
3. It verifies through `qa-run`, which records what actually ran.
4. Anything unrunnable gets a typed waiver with a reason.
5. `qa-review-gate.py` computes the verdict.
6. The orchestrator shows the per-criterion table and the waivers to the human.
7. The human looks. The orchestrator renders the comment and transitions.
8. The transition path re-checks the gate, so nothing passes on the orchestrator's
   say-so alone.

## Failure posture

Fail closed, everywhere. Missing ledger, a silent criterion, a blank waiver
reason, an unreadable ticket, or the gate script raising all produce `fail`. There
is no default-pass path.

## Testing

A verdict matrix, asserting the expected verdict per case rather than printing what
happened. A gate that fails open still exits 0 with entirely plausible output.

| Case | Expected |
|---|---|
| No ledger for the key | fail |
| Criterion with no entries | fail |
| Waiver with empty reason | fail |
| Waiver with one-word reason | fail |
| Every criterion observed | pass |
| Mixed observations and reasoned waivers | pass |
| Reviewer is the implementer | fail |
| Reviewer is an MR author | fail |
| Comment missing pipeline id | fail |
| Write outside declared scope | fail |
| Gate script raises | fail |

## Out of scope

- Replacing `jira-qa-gate.py`. The handover gate stays as it is.
- Replacing the `qa` skill. It keeps its own trigger; overlap in trigger wording is
  resolved when this lands.
- Publishing to either marketplace. Local first, decide later.
- Severity vocabulary and verdict routing. `peer-qa-review` already has those and
  can be installed alongside.

## Open items

- Whether `qa-run` should also capture agent-browser screenshots into the ledger
  directory or only reference their paths.
- How the scope gate learns which files were written: a git status diff against the
  review's start point is the cheapest candidate.
