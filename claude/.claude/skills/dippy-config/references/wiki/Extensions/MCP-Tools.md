> ⚠️ **Note:** Dippy's configuration is evolving. Syntax and behavior may change without warning.

[Model Context Protocol](https://modelcontextprotocol.io/) lets AI assistants use tools beyond shell commands — GitHub API, filesystem operations, databases, and more. Dippy can filter these too.

## Setup

MCP filtering isn't enabled by default. Add this alongside your existing `PreToolUse` Bash hook in `~/.claude/settings.json`:

```json
{
  "matcher": "mcp__.*",
  "hooks": [{ "type": "command", "command": "dippy" }]
}
```

If you installed manually, use the full path instead: `/path/to/Dippy/bin/dippy-hook`

Without this, Dippy only sees shell commands.

## Your First MCP Rule

Add to your config:

```
deny-mcp mcp__*__delete_* "Deletions need manual approval"
```

Now any MCP tool with "delete" in its name gets blocked across all servers.

## Tool Name Anatomy

MCP tools follow a three-part pattern:

```
mcp__<server>__<action>
```

| Part     | Example             | Meaning          |
| -------- | ------------------- | ---------------- |
| `mcp__`  | —                   | Fixed prefix     |
| `server` | `github`            | Which MCP server |
| `action` | `get_file_contents` | What it does     |

Full example: `mcp__github__get_file_contents`

This structure lets you write rules that target:
- A specific tool: `mcp__github__get_me`
- All actions on a server: `mcp__github__*`
- An action across servers: `mcp__*__delete_*`

## Building Patterns

Start specific, generalize with wildcards.

**Exact tool:**
```
allow-mcp mcp__github__get_me
```

**All "get" actions on GitHub:**
```
allow-mcp mcp__github__get_*
```

**All "delete" actions on any server:**
```
deny-mcp mcp__*__delete_*
```

**All tools on a server:**
```
ask-mcp mcp__slack__*
```

Like command rules, **last match wins**, so you can allow broadly then deny specifics:

```
allow-mcp mcp__github__*
deny-mcp mcp__github__delete_*
deny-mcp mcp__github__merge_* "Review PRs in browser first"
```

## Common Scenarios

**GitHub: reads allowed, writes prompted, destructive blocked**
```
allow-mcp mcp__github__get_*
allow-mcp mcp__github__list_*
allow-mcp mcp__github__search_*
allow-mcp mcp__github__*_read
ask-mcp mcp__github__create_*
ask-mcp mcp__github__update_*
deny-mcp mcp__github__delete_* "Deletions need manual approval"
deny-mcp mcp__github__merge_* "Review PRs in browser first"
```

**Filesystem: prefer Claude's native tools**
```
allow-mcp mcp__filesystem__read_*
allow-mcp mcp__filesystem__list_*
allow-mcp mcp__filesystem__search_*
allow-mcp mcp__filesystem__get_*
deny-mcp mcp__filesystem__write_* "Use Claude's Write tool instead"
deny-mcp mcp__filesystem__edit_* "Use Claude's Edit tool instead"
```

**Unknown servers: ask by default**
```
# Allow known servers
allow-mcp mcp__github__get_*
allow-mcp mcp__filesystem__read_*

# Ask for everything else
ask-mcp mcp__*
```

## Quick Reference

**Directives:**

| Directive   | Syntax                                                 |
| ----------- | ------------------------------------------------------ |
| `allow-mcp` | `allow-mcp <pattern>`                                  |
| `ask-mcp`   | `ask-mcp <pattern>`                                    |
| `deny-mcp`  | `deny-mcp <pattern>` or `deny-mcp <pattern> "message"` |

**GitHub tools:**

| Safe (allow)         | Destructive (ask/deny)  |
| -------------------- | ----------------------- |
| `get_file_contents`  | `create_pull_request`   |
| `get_me`             | `merge_pull_request`    |
| `list_commits`       | `create_or_update_file` |
| `list_issues`        | `delete_file`           |
| `list_pull_requests` | `push_files`            |
| `search_code`        | `create_branch`         |

**Filesystem tools:**

| Safe (allow)          | Destructive (ask/deny) |
| --------------------- | ---------------------- |
| `read_file`           | `write_file`           |
| `read_multiple_files` | `create_directory`     |
| `list_directory`      | `move_file`            |
| `search_files`        | `edit_file`            |
| `get_file_info`       |                        |
