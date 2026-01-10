# Claude Code Release Notes (Cutting Edge)

Last updated: 2025-12-11
Update with: claude -p "/release-notes" > ~/.claude/release-notes.md

## Version 2.0.65 (Latest)
- Added ability to switch models while writing a prompt using alt+p (linux, windows), option+p (macos)
- Added context window information to status line input
- Added `fileSuggestion` setting for custom `@` file search commands
- Added `CLAUDE_CODE_SHELL` environment variable to override automatic shell detection
- Fixed prompt not being saved to history when aborting a query with Escape
- Fixed Read tool image handling to identify format from bytes instead of file extension

## Version 2.0.64
- Made auto-compacting instant
- Agents and bash commands can run asynchronously and send messages to wake up the main agent
- /stats now provides users with interesting CC stats (favorite model, usage graph, usage streak)
- Added named session support: `/rename` to name sessions, `/resume <name>` or `claude --resume <name>`
- Added support for .claude/rules/ - See https://code.claude.com/docs/en/memory
- Added image dimension metadata when images are resized
- Improved `/resume` screen with grouped forked sessions and keyboard shortcuts (P=preview, R=rename)

## Version 2.0.62
- Added "(Recommended)" indicator for multiple-choice questions
- Added `attribution` setting to customize commit and PR bylines (deprecates `includeCoAuthoredBy`)

## Version 2.0.60
- Added background agent support - agents run in background while you work
- Start background tasks with `&` prefix in your message
- Added --disable-slash-commands CLI flag
- Added model name to "Co-Authored-By" commit messages
- /mcp enable/disable [server-name] to quickly toggle servers

## Version 2.0.59
- Added --agent CLI flag to override agent setting for current session
- Added `agent` setting to configure main thread with specific agent's system prompt

## Version 2.0.58
- Pro users now have access to Opus 4.5

## Version 2.0.57
- Added feedback input when rejecting plans

## Version 2.0.51
- Added Opus 4.5!
- Claude Code for Desktop released
- Plan Mode builds more precise plans

## Version 2.0.45
- Added support for Microsoft Foundry
- Added `PermissionRequest` hook
- Send background tasks with `&` prefix

## Version 2.0.43
- Added `permissionMode` field for custom agents
- Added skills frontmatter field to declare skills to auto-load for subagents
- Added `SubagentStart` hook event

## Version 2.0.41
- Added `model` parameter to prompt-based stop hooks

## Version 2.0.37
- Added `keep-coding-instructions` option to output styles frontmatter

## Version 2.0.35
- Added `CLAUDE_CODE_EXIT_AFTER_STOP_DELAY` env var for automated workflows

## Version 2.0.34
- Improved file path suggestion with native Rust-based fuzzy finder

## Version 2.0.32
- Un-deprecated output styles based on community feedback
- Added `companyAnnouncements` setting

## Version 2.0.30
- Added `allowUnsandboxedCommands` sandbox setting
- Added `disallowedTools` field to custom agent definitions
- Added prompt-based stop hooks

## Version 2.0.28
- Plan mode: introduced new Plan subagent
- Subagents can now be resumed
- Claude can dynamically choose model for subagents

## Version 2.0.24
- Sandbox mode released for BashTool on Linux & Mac

## Version 2.0.22
- Added interactive AskUserQuestion tool
- Claude asks questions more often in plan mode

## Version 2.0.21
- Support MCP `structuredContent` field

## Version 2.0.20
- Added support for Claude Skills

## Version 2.0.17
- Introducing the Explore subagent (powered by Haiku)

## Version 2.0.12
- Plugin System Released
- /plugin install, enable, disable, marketplace commands

## Version 2.0.10
- PreToolUse hooks can now modify tool inputs
- Ctrl-G to edit prompt in system text editor

## Version 2.0.0
- New native VS Code extension
- /rewind to undo code changes
- /usage for plan limits
- Tab to toggle thinking
- Ctrl-R for history search
