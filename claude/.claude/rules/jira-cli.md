# Jira Usage

Everything goes through two skills: `jira:jira-communication` (CLI mechanics —
JQL, worklogs, attachments, wiki markup via `jira:jira-syntax`) and
`netresearch-jira` (NR conventions — team routing, custom field IDs, sprint
board, linking conventions, QA workflows). The old standalone `jira` CLI is
gone — its syntax (`jira issue KEY --format ai`, `-X PATCH --custom`, `--text`)
survives in old notes and tickets and is obsolete.

Below is only what neither skill knows: traps and conventions earned on our
own tickets.

## jira.netresearch.de instance facts

- JQL rejects localized display names **and** some canonical status names:
  `status = "In Arbeit"` and even `status = "QA / Revision"` fail. Use internal
  English names (`In Arbeit` → `In Progress`) or status IDs (`status = 10000`).
  PROJX QA chain: Waiting for QA (10816), QA / Revision (10000), In Review (10215),
  UAT Stage (11319). Full list: `GET rest/api/2/status`.
- The QA verb status sets (`JIRA_QA_STATUS_NAMES` etc.) are exported in
  `~/.bash/exports/jira.bash` and are read from the **process environment only** —
  putting them in `~/.env.jira` has no effect, despite that being where the rest
  of the Jira config lives.
- **Never change an issue's type via the edit API.** Jira DC does not migrate the
  workflow step, leaving the issue on an orphaned status with broken transitions
  (PROJY-388/389; telltale: a self-transition to the current status is offered).
  `jira-move.py --issue-type` uses that same endpoint. Use the UI Move wizard —
  `https://jira.netresearch.de/secure/MoveIssue!default.jspa?id=<numeric-id>` —
  which forces proper status mapping and also repairs stranded issues.
- Converting a standard issue to a Sub-task is UI-only; the edit API rejects the
  `parent` field. Hand over the wizard link:
  `https://jira.netresearch.de/secure/ConvertIssueToSubTask!default.jspa?id=<numeric-id>`.
- UAT field (`customfield_10071`) basics are in `netresearch-jira`; three DHL
  deltas: our format is `h4. UAT` / `h5. Voraussetzungen` + case table (see
  PROJZ-1550), not the plugin's `h2.` bullet example. Ignore `customfield_11489`
  "User Acceptance Tests" (unused template). Not on every issue type's screen —
  PROJY `Technical task` has it, `Neue Aufgabe` does not.
- Don't curl attachment URLs — that needs credentials Claude must not read.
  `jira-attachment.py` carries auth for both directions.

## Conventions

- **Before any write, fetch the ticket and check the summary matches the intent.**
  A key quoted back at you may echo an earlier mistake — a delete-guard evidence
  comment once landed on PROJX-2322 (PIM import) instead of PROJX-2272 this way.
- Release-ticket chaining uses the `Relation` link type.
- Re-fetch after any write to confirm it landed. Jira DC has a history of silent
  no-ops.
