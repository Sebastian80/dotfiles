# Jira Usage

Everything goes through the `jira:jira-communication` skill (netresearch
jira-integration plugin). The old standalone `jira` CLI is gone — its syntax
(`jira issue KEY --format ai`, `-X PATCH --custom`, `--text`) survives in old
notes and tickets and is obsolete.

Below is only what that plugin does **not** know: facts about our own Jira
instance and our team conventions. For link semantics, sprint mechanics, JQL,
worklogs, attachments and wiki markup, use the skill and its references.

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
- UAT instructions go in the dedicated `UAT` field (`customfield_10071`, format
  `h4. UAT` / `h5. Voraussetzungen` + case table, see PROJZ-1550), not in comments;
  only UAT *results* are comments. Ignore `customfield_11489` "User Acceptance
  Tests" (unused template). Not on every issue type's screen — PROJY
  `Technical task` has it, `Neue Aufgabe` does not.
- Sprint field is `customfield_10480`; the eCom board is `119`.
- Don't curl attachment URLs — that needs credentials Claude must not read.
  `jira-attachment.py` carries auth for both directions.

## Conventions

- **Before any write, fetch the ticket and check the summary matches the intent.**
  A key quoted back at you may echo an earlier mistake — a delete-guard evidence
  comment once landed on PROJX-2322 (PIM import) instead of PROJX-2272 this way.
- **After creating a ticket, add it to the project's active sprint** unless the
  user says backlog or the project has no active sprint.
- When an MR exists, attach it as a **weblink** (title `MR !N: <mr title>`), not
  only as a comment — comments scroll away, weblinks stay in the sidebar. Pattern:
  weblink for the MR, comment for evidence (test results, review verdicts).
- Release-ticket chaining uses the `Relation` link type.
- Re-fetch after any write to confirm it landed. Jira DC has a history of silent
  no-ops.
