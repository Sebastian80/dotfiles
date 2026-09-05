---
name: qa
description: MUST use for QA of a Jira ticket with linked MRs — "QA this ticket", "verify PROJ-123", "check the fix on the reference env". Reads ticket and MRs first, echoes a scope contract, verifies each acceptance criterion live, posts evidence to Jira and transitions with the project's own done state.
---

# QA a ticket

Argument: a ticket key (`$ARGUMENTS`). Jira access goes through `jira:jira-communication`; German
comments through `german-technical-writing`; status names and QA chain per project come from that
project's auto-memory or `netresearch-jira`. Never guess a status name.

## 1. Scope contract first

Read the ticket, its sub-tasks and every linked MR (description, diff, pipeline) before touching code,
vendor directories or pipeline traces. Then reply with exactly three lines and wait for "confirmed":

```
IN SCOPE: <what the ticket and MRs actually change>
OUT OF SCOPE: <adjacent things you will not touch>
PROOF I WILL PRODUCE: <pipeline id, test counts, screenshots, URLs>
```

## 2. Reproduce, then verify

- Reproduce the reported behaviour on the reference environment before applying anything; paste the
  observed output. A bug you cannot reproduce is reported as such, not verified by reading the diff.
- Apply the MR state (checkout or patch), then verify every acceptance criterion live — storefront,
  admin, CLI, browser via `agent-browser` — and quote the observed output or screenshot per criterion.
- Check the MR pipeline; record pipeline id, job ids and pass/fail counts.
- A regression test that covers the bug follows `rules/testing.md`: it must have been red before the
  fix and green after, and both runs are pasted.

## 3. Report back to Jira

- Post one comment per verified state with the evidence (German, wiki markup, per `jira-syntax`),
  linking MRs and pipelines in `[text|url]` form.
- Transition to the project's done state for QA. Re-fetch the issue after every write and confirm the
  transition landed.
- Findings outside the ticket become a new sub-task or ticket, linked, not fixed inline.

## Done means

Every acceptance criterion has a quoted observation, the pipeline id is in the comment, and the issue
shows the intended status on re-fetch. Anything not observed is listed as unverified, not omitted.
