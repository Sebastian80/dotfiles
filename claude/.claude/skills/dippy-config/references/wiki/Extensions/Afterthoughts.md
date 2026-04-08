> ⚠️ **Note:** Dippy's configuration is evolving. Syntax and behavior may change without warning.

Afterthoughts send feedback to Claude *after* commands run successfully. Use them to nudge Claude toward better patterns, remind it of conventions, or provide context it might need for next steps.

## Setup

Afterthoughts require a `PostToolUse` hook. Add this alongside your existing `PreToolUse` hook in `~/.claude/settings.json`:

```json
"PostToolUse": [
  {
    "matcher": "Bash",
    "hooks": [{ "type": "command", "command": "dippy" }]
  }
]
```

If you installed manually, use the full path instead: `/path/to/Dippy/bin/dippy-hook`

Without `PostToolUse`, afterthought rules in your config are ignored.

## Your First Afterthought

Add to your config:

```
after git commit "Now push with git push"
```

After any `git commit` runs, Claude sees: "Now push with git push"

## Use Cases

**Workflow reminders:**
```
after git commit "Push your changes"
after npm test "Fix any failures before committing"
after pytest "Check coverage report"
```

**Convention enforcement:**
```
after python "Remember: use uv run python for project scripts"
after pip install "Add to requirements.txt"
after brew install "Update Brewfile"
```

**Next steps:**
```
after git checkout -b "Create a draft PR early"
after docker build "Test locally before pushing"
```

## Pattern Matching

Afterthoughts use the same pattern matching as other rules:

**Exact command:**
```
after git push "Open PR if not already created"
```

**Prefix match:**
```
after npm "Check package-lock.json for changes"
```

**Wildcards:**
```
after docker * "Document any new containers"
```

## MCP Afterthoughts

For MCP tools, use `after-mcp`:

```
after-mcp mcp__github__create_pull_request "Share the PR link"
after-mcp mcp__github__create_issue "Add to the project board"
```

MCP afterthoughts require an MCP matcher in `PostToolUse`:

```json
"PostToolUse": [
  {
    "matcher": "Bash",
    "hooks": [{ "type": "command", "command": "dippy" }]
  },
  {
    "matcher": "mcp__.*",
    "hooks": [{ "type": "command", "command": "dippy" }]
  }
]
```

If you installed manually, use the full path instead: `/path/to/Dippy/bin/dippy-hook`

## Quick Reference

| Directive   | Syntax                          | Scope         |
| ----------- | ------------------------------- | ------------- |
| `after`     | `after <pattern> "message"`     | Bash commands |
| `after-mcp` | `after-mcp <pattern> "message"` | MCP tools     |
