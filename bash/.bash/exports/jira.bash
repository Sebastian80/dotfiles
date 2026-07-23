#!/usr/bin/env bash
# ~/.bash/exports/jira.bash
# Jira workflow status sets for the netresearch jira-integration plugin
#
# Purpose:
#   The plugin's qa/qa-fail intent verbs classify status transitions by
#   exact-match against these sets. The built-in defaults are English-only;
#   these unions add the jira.netresearch.de names (German + HMKG workflow).
#
# Note:
#   Read from the process environment only — putting them in ~/.env.jira
#   has no effect (that file feeds auth vars, not os.environ).

export JIRA_QA_STATUS_NAMES="QA,Review,In Review,Code Review,Ready for QA,QA2,UAT,Acceptance,Testing,Waiting for QA,QA / Revision,UAT Stage,UAT Prod,QA Stage,QA Prod"
export JIRA_WORKING_STATUS_NAMES="In Progress,Open,Reopened,To Do,In Development,Backlog,QA failed,In Arbeit,Offen,Neueröffnet,New,Analyse,Zu erledigen"
export JIRA_RESOLVED_STATUS_NAMES="Closed,Resolved,Done,Won't Fix,Cancelled,Fertig,Geschlossen,Erledigt"
