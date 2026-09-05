# Jira Usage

Everything goes through `jira:jira-communication` (CLI mechanics, JQL, worklogs, attachments; wiki
markup via `jira:jira-syntax`) and `netresearch-jira` (team routing, custom field IDs, sprint board,
QA workflows). Syntax from the retired standalone `jira` CLI (`jira issue KEY --format ai`,
`-X PATCH --custom`, `--text`) still appears in old tickets — obsolete, don't copy it.

Below is only what neither skill knows.

## jira.netresearch.de

- JQL rejects localized **and** some canonical status names — `"In Arbeit"` and `"QA / Revision"` both
  fail. Use internal English names or status IDs (`GET rest/api/2/status`); per-project QA-chain ids
  live in that project's auto-memory.
- **Never change an issue's type via the edit API** — Jira DC does not migrate the workflow step and
  strands the issue on an orphaned status (telltale: a self-transition to the current status is
  offered; two issues lost this way). `jira-move.py --issue-type` hits the same endpoint. Use the UI
  wizard `…/secure/MoveIssue!default.jspa?id=<numeric-id>`, which also repairs stranded issues.
- Converting a standard issue to a Sub-task is UI-only —
  `…/secure/ConvertIssueToSubTask!default.jspa?id=<numeric-id>`; the edit API rejects `parent`.
- UAT is `customfield_10071` (basics in `netresearch-jira`); ignore `customfield_11489`. It is not on
  every issue type's screen and some projects use their own format — check the project's auto-memory.
- QA verb status sets (`JIRA_QA_STATUS_NAMES` etc.) are read from the process environment only —
  `~/.bash/exports/jira.bash`, not `~/.env.jira`.
- Never curl attachment URLs (needs credentials Claude must not read) — `jira-attachment.py` carries
  auth both ways.

## Conventions

- **Fetch the ticket and check the summary before any write** — a key quoted back at you may echo an
  earlier mistake; an evidence comment once landed on an entirely unrelated ticket that way.
- Re-fetch after every write. Jira DC has a history of silent no-ops.
- Release-ticket chaining uses the `Relation` link type.
