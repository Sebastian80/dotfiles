---
name: pi-crawler
description: Use this skill WHENEVER a code question needs broad exploration of code you are not editing, so the pi `crawler` agent answers it instead of your own context window. Triggers include "crawl", "spawn/start the pi crawler", "pi idx agent", "offload the code search", "ask pi", tracing a flow through Oro, Symfony, Magento or other vendor code ("how does Oro recalculate X", "where does our code hook in"), finding who calls or decorates or implements something across src/ and vendor/, service wiring and decorators, "which of our classes ..." questions spanning our own vendor bundles, and runtime questions an Oro stack can answer (how many records, what the container holds, what the logs say). Also use it when the user wants to watch a crawler in a herdr pane, and when a project should be enabled for it. Do NOT use it for the file you are editing or for a one- or two-call lookup.
---

# pi crawler

`crawler` is a pi agent (`~/.pi/agent/agents/crawler.md`): read-only, Codex terra at medium, with
the PhpStorm index and, in Oro projects, every Oro Mate tool. It reads a lot so you don't:
typically 25-45k characters of tool output condense into 30-40 lines with `file:line` evidence.

You never run it directly. A pi session running **in the project directory** spawns it as a
background child, and that session gets its MCP servers from the project (see
[references/project-setup.md](references/project-setup.md)).

## Before you start

- The project must be enabled: `<project>/.pi/mcp.json` must exist. If it doesn't, offer the
  setup from [references/project-setup.md](references/project-setup.md) instead of falling back
  to a worse answer.
- PhpStorm must run. The endpoint antivirus fakes connects on dead local ports, so check the HTTP
  status, not curl's exit code: `curl -s -o /dev/null -m 2 -w '%{http_code}' http://127.0.0.1:29175/`
  prints `000` when PhpStorm is down. Then tell the user; never start PhpStorm yourself.
- Mate's data tools (SQL, logs, profiler, queue, search indexes) need the project's stack running;
  code and config tools work with it down.
- For "our code" questions, pass the first-party list (see [references/first-party.md](references/first-party.md)).

## Ask it headless (your default)

Always as a background Bash task; a crawl outlives the foreground timeout. The parent is a cheap
model whose only tool is `subagent`; the crawler does the work.

```bash
cd /abs/project/root && HERDR_ENV= pi -p -a -ns \
  --model openai-codex/gpt-5.6-luna --thinking low --tools subagent \
  'Call the subagent tool once with agent "crawler" and async set to true, then bg_wait for that
run, then print the child answer verbatim and nothing else.

Project root: /abs/project/root
First-party code: src/, vendor/acme/*
Question: <one precise question>' </dev/null > <scratchpad>/crawl-<topic>.md 2>&1
```

- **`async: true` is not optional.** The crawler's tools are MCP tools, and only a background
  child loads the ambient adapter. A foreground launch fails with a diagnostic and no answer.
- **`bg_wait` is what makes print mode wait.** Without it the parent exits with a run id and the
  answer lands in the artifact instead: newest
  `~/.pi/agent/sessions/--<slug of project path>--/subagent-artifacts/*_crawler_output.md`.
- Spot-check one or two `file:line` claims before building on them; the last line lists the tools
  it used.

## Let the user watch (pane)

Only when the user asks. See [references/herdr.md](references/herdr.md): split a pane with
`--cwd` the project, start pi there with `herdr agent start --kind pi`, send the same delegation
prompt with `herdr agent prompt --wait` as a background task, then read the pane. The session
stays open for follow-ups.

## Rules

- One question per crawl. Several independent questions: several crawls in parallel.
- Point it only at local stacks loaded with PII-stripped dumps: Mate's data tools send database
  rows, log lines and env values to OpenAI.
- The crawler answers; you decide. Its `(inferred)` marks are guesses, not findings.
