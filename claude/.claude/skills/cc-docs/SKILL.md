---
name: cc-docs
description: Use for ANY Claude Code question - features, commands, hooks, plugins, settings, what's new, how-to. Searches official docs AND local changelog for cutting-edge features.
---

# Claude Code Documentation Expert

When answering Claude Code questions, use ALL of these sources:

## 1. Official Documentation (WebFetch)

Key URLs to fetch:
- https://code.claude.com/docs/en/hooks.md - Hooks system
- https://code.claude.com/docs/en/plugins.md - Plugin system
- https://code.claude.com/docs/en/skills.md - Skills
- https://code.claude.com/docs/en/sub-agents.md - Custom agents
- https://code.claude.com/docs/en/memory.md - CLAUDE.md, rules/
- https://code.claude.com/docs/en/settings.md - Configuration
- https://code.claude.com/docs/en/slash-commands.md - Commands
- https://code.claude.com/docs/en/interactive-mode.md - Interactive features

## 2. Local Release Notes (for cutting-edge features)

@~/.claude/release-notes.md

## 3. Web Research (when docs aren't enough)

Use WebSearch for:
- "Claude Code [feature name]"
- "site:github.com/anthropics/claude-code [topic]"
- "site:anthropic.com Claude Code [feature]"

## Process

1. Check if the answer is in the local release notes first (fastest)
2. WebFetch the relevant official doc URL
3. If still unclear, WebSearch for community info
4. Clearly distinguish official docs vs changelog vs community sources
