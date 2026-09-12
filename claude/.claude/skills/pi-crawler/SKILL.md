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
- **A reachable port is not an open project.** The crawler holds read-only index tools only, so a
  project that is managed-but-closed makes it refuse every code-search question rather than answer
  from whichever project happens to be open — and parallel checkouts share relative paths and line
  numbers, so an answer from the wrong one is indistinguishable. Check `ide_project_status` for
  *this* path, and if it is closed, open it here in the preflight (the index MCP exposes
  `ide_open_project` over HTTP on the same port, even where `.pi/mcp.json` does not expose it to
  pi) and wait until `ide_index_status` reports `isIndexing: false`. Opening takes a while on a
  monorepo, and a half-built index answers partially instead of refusing. Never let the crawler
  open or wake a project itself.
- Mate's data tools (SQL, logs, profiler, queue, search indexes) need the project's stack running;
  code and config tools work with it down. Check `docker compose ps` here and ask before starting
  anything: a headless crawl has no UI, so it cannot ask and will just report the stack down.
- For "our code" questions, pass the first-party list (see [references/first-party.md](references/first-party.md)).

## Ask it headless (your default)

One pi process in the project. No parent, no subagent, no script: the agent file supplies the
prompt, so there is still one copy of it. Always as a background Bash task; a crawl outlives the
foreground timeout.

```bash
cd /abs/project/root && HERDR_ENV= pi -p -a -ns \
  --model openai-codex/gpt-5.6-terra --thinking medium -xt write,edit,bash \
  --append-system-prompt "$(sed -n '/^You are a read-only code crawler/,$p' ~/.pi/agent/agents/crawler.md)" \
  'Project root: /abs/project/root
First-party code: src/, vendor/acme/*
Question: <one precise question>' </dev/null > <scratchpad>/crawl-<topic>.md 2>&1
```

- `-xt write,edit,bash` drops the mutating builtins, which is shorter and safer than allowlisting
  53 tools; the IDE and Mate tools come from the project's `.pi/mcp.json`.
- The answer is on stdout. No run ids, no artifacts, no waiting.
- Spot-check one or two `file:line` claims before building on them; the last line lists the tools
  it used.

## When a pi session already exists (the agent)

In the pane orchestrator or Sebastian's own pi, delegate instead of starting a second process:
`subagent` with agent `crawler`, **`async: true`** — the crawler's tools are MCP tools and only a
background child loads the ambient adapter, so a foreground launch fails with a diagnostic and no
answer. An interactive session waits for the child itself; a `pi -p` parent needs `bg_wait`, or the
answer lands only in the newest
`~/.pi/agent/sessions/--<slug of project path>--/subagent-artifacts/*_crawler_output.md`.

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
