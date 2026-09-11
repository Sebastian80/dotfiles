---
name: pi-crawler
description: Use this skill WHENEVER a code question needs broad exploration of code you are not editing, so a pi crawler agent answers it instead of your own context window. Triggers include "crawl", "spawn/start the pi crawler", "pi idx agent", "offload the code search", "ask pi", tracing a flow through Oro, Symfony, Magento or other vendor code ("how does Oro recalculate X", "where does our code hook in"), finding who calls or decorates or implements something across src/ and vendor/, service wiring and decorators, and "which of our classes ..." questions spanning our own vendor bundles. Also use it when the user wants to watch a crawler in a herdr pane or tab. Do NOT use it for the file you are editing or for a one- or two-call lookup.
---

# pi crawler

A pre-configured pi agent in `~/.pi/agent/crawler/` answers one code question from the PhpStorm
index and, in Oro projects, from Oro Mate's code and config tools. It reads a lot so you don't:
typically 25-45k characters of tool output condense into an answer of 30-40 lines with `file:line`
evidence, in 20-120 s. It runs on a Codex model with `read` plus read-only IDE and Mate tools: no
shell, no edits, no web, no production data.

Everything about the agent lives in that folder: `.pi/settings.json` (model, thinking, packages),
`.pi/APPEND_SYSTEM.md` (its prompt), `.mcp.json` (servers, with `${CRAWL_PROJECT}` for the project)
and `tools.txt` (the allowlist). You only supply the project and the question.

## Before you start

- PhpStorm must run. The endpoint antivirus fakes connects on dead local ports, so check the HTTP
  status, not curl's exit code: `curl -s -o /dev/null -m 2 -w '%{http_code}' http://127.0.0.1:29175/`
  prints `000` when PhpStorm is down. Then tell the user; never start PhpStorm yourself.
- The project does not need to be open in the IDE; the crawler's first call wakes it.
- For "our code" questions, pass the first-party list (see [references/first-party.md](references/first-party.md)).

## Ask it headless (your default)

Always as a background Bash task; a crawl outlives the foreground timeout. Run it from the agent
folder, never from the project: the MCP adapter merges the working directory's `.mcp.json`, and a
project's own config can expose Oro Mate's SQL, env and log tools to the Codex model.

```bash
cd ~/.pi/agent/crawler && HERDR_ENV= CRAWL_PROJECT=/abs/project/root \
  pi -p -a -ns --tools "$(paste -sd, tools.txt)" \
  "Project root: /abs/project/root
First-party code: src/, vendor/acme/*
Question: <one precise question>" </dev/null > <scratchpad>/crawl-<topic>.md 2>&1
```

- `-a` trusts the agent folder so its settings load; `-ns` drops your global skills; `--tools`
  is the allowlist. pi cannot drop globally installed extensions through project settings (the
  sandbox's `bash` would leak in), so these flags are not optional.
- `HERDR_ENV=` keeps herdr's state reporter from reporting the crawl into your own pane.
- When the task notification arrives, read the answer file. Spot-check one or two `file:line`
  claims before building on them; the last line lists the tools it used.

## Let the user watch (pane or tab)

Only when the user asks to see it. See [references/herdr.md](references/herdr.md): split a pane with
`--cwd ~/.pi/agent/crawler --env CRAWL_PROJECT=...`, start it with
`herdr agent start --kind pi ... -- -a -ns --tools ...`, send the question with
`herdr agent prompt --wait` as a background task, and read the pane when it returns. The session
stays open for the user's follow-ups.

## Rules

- Never add Oro Mate's data tools (`oro_sql_query`, `oro_env_get`, `oro_customer_snapshot`, log
  tools) to `.mcp.json` or `tools.txt`, and never run the crawler from a project directory.
- One question per crawl. Several independent questions: several background crawls in parallel.
- The crawler answers; you decide. Its `(inferred)` marks are guesses, not findings.
