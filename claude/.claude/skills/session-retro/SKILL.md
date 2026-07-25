---
name: session-retro
description: Use at the end of a non-trivial session, or when Sebastian asks for a retro / "what did we learn", to surface what was actually learned and propose where each item belongs (AGENTS.md, project CLAUDE.md, rules/, a skill, an ADR, or auto-memory). Invoke before context is lost — after shipping a fix, closing a ticket, or finishing a debugging session.
---

# Session retro

List what was actually learned this session. For each item, name where it belongs:

| Kind of learning | Destination |
|---|---|
| General rule that applies broadly | `~/.claude/AGENTS.md` |
| Project-specific convention | project `CLAUDE.md` or `.claude/rules/` |
| Multi-step workflow that will repeat | a skill |
| Architectural decision with rationale | an ADR |
| Fact about how the system actually behaves | auto-memory |

## Rules

- Don't auto-write any of these. Surface the list with concrete proposed edits and let Sebastian decide what to commit.
- A retro that produces no proposals is fine. Most sessions don't generate persistent learnings, and the ETH AGENTbench finding that LLM-generated rules *hurt* applies here.
- Prefer one well-earned entry over five plausible ones. If a candidate rule is derivable from the code, the git history, or an existing rule, drop it.
- An entry earns its place only if a future session would get it wrong without it. Name the incident that proves that.
