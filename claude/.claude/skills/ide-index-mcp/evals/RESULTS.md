# trigger-eval results — 2026-07-26

Three arms over the same 24 cases, same environment (shop + magento-shop both open
in PhpStorm, `ide-first.sh` hook active). Metric: did the run reach any
`mcp__phpstorm-index__*` tool, and was the skill itself invoked.

| arm                          | positives (13)        | negatives (11)       |
| ---------------------------- | --------------------- | -------------------- |
| description with MANDATORY/MUST | 7 skill, **12** ide | 0 skill, 3 ide       |
| description rewritten, coercion removed | 2 skill, **8** ide | 0 skill, 3 ide |
| skill disabled entirely      | 0 skill, **11** ide   | 0 skill, **2** ide   |

## What this establishes

**As a router, the skill is close to redundant.** Disabling it costs one positive
case; rewriting its description cost four. The routing work is done by the
`ide-first.sh` PreToolUse hook and by the MCP tool descriptions themselves, which
are discoverable via tool search without the skill. No arm ever produced a false
skill invocation, and the disabled arm was the *best* on negatives.

**Coercive wording in a `description:` is doing retrieval work, not behavioural
work.** Anthropic's Claude 5 guidance to strip MANDATORY/MUST framing targets
always-loaded context (system prompts, CLAUDE.md) where redundant rules make the
model deliberate instead of act. A `description:` is what the skill router matches
against — removing trigger vocabulary from it reduces retrieval. These are
different mechanisms and the advice does not transfer. The rewrite was reverted.

## What this does NOT establish

A trigger eval measures whether you *reach* the tools. It cannot see whether the
tools then *mislead* you. The failure that actually cost time on 2026-07-26 was
`ide_find_symbol` returning `{"symbols":[],"totalCount":0,"stale":false}` because
the queried project was not open — an authoritative-looking false negative, with
the skill installed and not invoked. That class of failure is invisible to every
arm above, and is the skill's real value (see "Multi-project workflow" step 3 and
the availability note in SKILL.md).

Do not read these numbers as "delete the skill". They measure the routing half only.

## Reproducing

No runner ships with the skill. The 2026-07-26 harness ran each `query` through
`claude -p --permission-mode plan --output-format stream-json --verbose`, five at a
time, and scored the emitted `tool_use` names. Roughly 25-35 min per arm.

Caveat for future runs: with two projects open, IDE calls that omit `project_path`
error with `multiple_projects_open`. Four cases per arm burned a call recovering.
Keep the project set identical across arms rather than "clean" in one.
