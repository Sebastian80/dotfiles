---
name: codex-in-herdr
description: Use this skill WHENEVER running an interactive Codex agent inside a Herdr pane — starting one with `herdr agent start --kind codex`, prompting or reading it, or recovering when it reports agent_not_ready, agent_not_found or blocked. Load it BEFORE sending any keys to a Codex pane. Covers the launch line for astra at high effort, the three startup dialogs that swallow input (update prompt, hooks review, directory trust), fast mode showing up uninvited, and how to brief a security review so the model does not refuse to show its findings. Also use when a Codex pane answers idle but nothing happened, or when a review brief comes back with a cybersecurity refusal.
---

# Interactive Codex in a Herdr pane

Launch line that gives astra at high effort, read-only, no approval prompts:

```
codex -m gpt-6-astra -c model_reasoning_effort=high -s read-only -a never
```

Start it with `herdr agent start <name> --kind codex --pane <id> -- <that line>`.

## Read the screen before sending keys

`herdr agent read <name> --source visible`. A fresh start can show, in turn, an update prompt, a
hooks-review screen and a directory-trust prompt, and Herdr reports `agent_not_ready` or `blocked`
for each. An `esc` that already closed a popup makes the next `/` land as literal text in the
composer, which once produced `//hooks`. `ctrl+u` clears the composer.

- **Update prompt:** skip it during incident work. An update mid-task exits the agent and the pane
  drops to a shell, so the next prompt returns `agent_not_found`; restart with the same launch line.
- **Hooks-review screen:** do not esc it away on Sebastian's behalf. `/hooks` reopens it. The hook is
  Herdr's SessionStart `herdr-agent-state.sh` from `~/.codex/hooks.json`.
- **Trust prompt:** answer yes only for Sebastian's own checkouts.

`herdr agent prompt --wait` can return `idle` while a startup dialog is still on screen. Treat the
first `idle` after a start as unverified until the composer shows "Ask Codex to do anything".

## Fast mode turns itself on

The footer may read `gpt-6-astra high fast` after the first turn even though nothing in
`config.toml` or the launch line asked for it. Fast mode doubles speed and usage. Sebastian wants it
off for reviews, so check the footer before the first prompt; `/fast` toggles it.

## Briefing a security review

A brief that spells out an exploit chain (endpoints, gadget classes, payload shape) makes astra
investigate and then refuse to show the result, citing extra caution with cybersecurity requests and
linking Trusted Access. Brief it instead as a defensive code review of the mitigation diff: name the
layers, the facts it may rely on, and the regressions or bypass seams to check, without the attack
recipe. That version completed in under three minutes and found a real regression.
