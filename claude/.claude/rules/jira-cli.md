# Jira Usage

All Jira operations go through the `jira:jira-communication` skill (netresearch jira-integration plugin): `uv run <plugin>/skills/jira-communication/scripts/{core,workflow,utility}/<script>.py`. The former standalone `jira` CLI is removed — its syntax (`jira issue KEY --format ai`, `-X PATCH --custom`, `--text`) in old notes and tickets is obsolete.

## Formatting

- Comments and descriptions use Jira wiki markup, never Markdown: `[text|url]`, `h2.`, `{code:lang}`. Use the `jira:jira-syntax` skill before authoring content.

## Instance facts (jira.netresearch.de)

- JQL rejects localized display names AND some canonical status names: `status = "In Arbeit"` and even `status = "QA / Revision"` fail. Use internal English names (`In Arbeit` → `In Progress`) or status IDs (`status = 10000`). HMKG QA chain: Waiting for QA (10816), QA / Revision (10000), In Review (10215), UAT Stage (11319). Full list: `GET rest/api/2/status`.
- The qa/qa-fail verb status sets (`JIRA_QA_STATUS_NAMES` etc.) are exported in `~/.bash/exports/jira.bash` — they are read from the process environment ONLY; putting them in `~/.env.jira` has no effect.
- Link types: there is NO *follows / is followed by*. Release-ticket chaining uses `Relation`; dependencies use `Blockade` (blocks / is blocked by). For `Cause`: derive the call from the sentence you want ("bug X causes ticket K" → K shows "is caused by X") and ALWAYS verify direction after creating via the issue's `.inwardIssue`/`.outwardIssue` — the field naming is inverted vs. the displayed phrase. Wrong links are deletable via `jira-link.py delete`.
- NEVER change an issue's type via the edit API: Jira DC does not migrate the workflow step, leaving the issue on an orphaned status with broken transitions (learned on DHLGKP-388/389; telltale: a self-transition to the current status is offered). `jira-move.py --issue-type` uses that same endpoint — for type changes prefer the UI Move wizard (`https://jira.netresearch.de/secure/MoveIssue!default.jspa?id=<numeric-id>`), which forces proper status mapping and also repairs already-stranded issues.
- Converting a standard issue to a Sub-task is UI-only — the edit API rejects the `parent` field (atomic rejection). Hand the user the wizard link: `https://jira.netresearch.de/secure/ConvertIssueToSubTask!default.jspa?id=<numeric-issue-id>`.
- UAT INSTRUCTIONS go into the dedicated `UAT` field (`customfield_10071`, format `h4. UAT` / `h5. Voraussetzungen` + case table, see DHLGW-1550), NOT into comments; only UAT *results/evidence* are comments. Ignore `customfield_11489` "User Acceptance Tests" (unused template). The field is not on every issue type's screen (DHLGKP: `Technical task` has it, `Neue Aufgabe` does not).
- Don't curl attachment URLs (needs credentials Claude must not read) — `jira-attachment.py` carries auth for both upload and download.

## Conventions

- **After creating a ticket, ALWAYS add it to the project's active sprint** (`jira-sprint.py`). Skip only if the user says "backlog" or the project has no active sprint.
- When an MR exists for a ticket, attach it as a WEBLINK (`jira-weblink.py`, title `MR !N: <mr title>`), not only as a comment — comments scroll away, weblinks stay in the sidebar. Pattern: weblink for the MR + comment for evidence (test results, review verdicts).
- After any write operation, re-fetch to verify the content landed — Jira DC has a history of silent no-ops.
