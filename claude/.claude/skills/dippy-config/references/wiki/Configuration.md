> ⚠️ **Note:** Dippy's configuration is evolving. Syntax and behavior may change without warning.

## Your First Config

Create `~/.dippy/config` (or `.dippy` in a project root):

```
deny rm -rf "Use trash instead of rm -rf"
```

That's it. Now when an AI tries to run `rm -rf anything`, Dippy blocks it and shows the message.

## Allow, Ask, Deny

Three decisions, three directives:

| Directive | What happens                  |
| --------- | ----------------------------- |
| `allow`   | Auto-approved, AI continues   |
| `ask`     | You're prompted to approve    |
| `deny`    | Blocked, AI sees your message |

```
allow git status         # Safe, let it through
ask docker run           # I want to see what it's running
deny rm -rf "Use trash"  # Block with guidance
```

Without any config, Dippy defaults to `ask` for unknown commands.

## Patterns

Patterns without wildcards do **prefix matching** by default—they match the command with or without additional arguments.

**Prefix match (default):**
```
allow git status
```
Matches `git status`, `git status -s`, `git status --porcelain`, etc.

**Exact match only:**
```
allow git status|
```
The `|` anchor restricts matching to exactly `git status` with no arguments.

**Explicit wildcard:**
```
allow git *
```
Matches any git command. Equivalent to prefix matching but explicit.

**Wildcards:**
- `*` matches anything (including spaces)
- `?` matches one character
- `[abc]` matches a, b, or c
- `|` at end = exact match only (no additional arguments)

## Overriding Rules

Rules are evaluated in order. **Last match wins.**

This lets you allow broadly, then carve out exceptions:

```
# Allow all git commands (prefix match)
allow git

# But block the dangerous ones
deny git push --force
deny git push * --force
deny git reset --hard
deny git clean -fd
```

Order matters. If you flip it, the `allow git` would override your denials.

## Common Scenarios

**Git: reads allowed, writes prompted, force operations blocked**
```
allow git status
allow git log
allow git diff
allow git show
allow git branch -l
ask git
deny git push --force "Force push is disabled"
deny git reset --hard "Hard reset is disabled"
```

**Docker: inspection allowed, execution prompted**
```
allow docker ps
allow docker images
allow docker inspect
allow docker logs
ask docker
```

**Protect system paths:**
```
deny * /etc/* "Don't modify system config"
deny * /usr/* "Don't modify system files"
deny * ~/.ssh/* "Don't touch SSH keys"
```

## Project Configs

For project-specific rules, create `.dippy` in the project root. Dippy searches upward from the working directory (like `.git`).

**Precedence (highest wins):**
1. `$DIPPY_CONFIG` environment variable
2. `.dippy` in project (or parent directories)
3. `~/.dippy/config` global

**Example:** Your global config allows `npm install`, but a project blocks it:

```
# Project .dippy
deny npm install "Use pnpm install instead"
```

## Controlling File Writes

Dippy analyzes redirects in commands. Block writes to sensitive paths:

```
allow-redirect /tmp/**
allow-redirect ./dist/**
deny-redirect ~/.ssh/** "SSH directory is protected"
deny-redirect /etc/** "System config is protected"
```

Path patterns use `**` for recursive matching, `*` for single directory level.

See [[File Editing]] for details.

## MCP Tools

For Model Context Protocol tools (named `mcp__server__action`):

```
allow-mcp mcp__github__get_*
allow-mcp mcp__github__list_*
deny-mcp mcp__*__delete_* "Deletions need manual approval"
```

See [[MCP Tools]] for details.

## Aliases

Map wrapper scripts or custom commands to their canonical names:

```
alias ~/bin/gh gh
alias mygit git
allow gh
allow git status
```

Now `~/bin/gh pr list` matches `allow gh` and `mygit status` matches `allow git status`.

**Path handling:**
- `~` expands to home directory
- Relative paths (`./bin/tool`) resolve against the working directory at match time
- Absolute paths work as-is

**Notes:**
- Only the first word (command name) is aliased; arguments pass through unchanged
- Single-level replacement only (no transitive `a → b → c` chains)
- Later configs override earlier aliases for the same source

## Settings

**Change the default decision:**
```
set default allow    # Auto-approve unknowns (use with caution)
```

**Enable audit logging:**
```
set log ~/.dippy/audit.log
set log-full         # Include full command text
```

## Comments

```
# Full line comment
allow git status  # Inline comment
```

## Quick Reference

| Directive        | Syntax                                         |
| ---------------- | ---------------------------------------------- |
| `allow`          | `allow <pattern>`                              |
| `ask`            | `ask <pattern>` or `ask <pattern> "message"`   |
| `deny`           | `deny <pattern>` or `deny <pattern> "message"` |
| `allow-redirect` | `allow-redirect <path-pattern>`                |
| `deny-redirect`  | `deny-redirect <path-pattern> "message"`       |
| `allow-mcp`      | `allow-mcp <tool-pattern>`                     |
| `ask-mcp`        | `ask-mcp <tool-pattern>`                       |
| `deny-mcp`       | `deny-mcp <tool-pattern> "message"`            |
| `alias`          | `alias <source> <target>`                      |
| `set default`    | `set default allow` or `set default ask`       |
| `set log`        | `set log <path>`                               |
| `set log-full`   | `set log-full`                                 |
