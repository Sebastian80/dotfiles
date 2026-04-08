A custom statusline for Claude Code showing model, directory, git info, context usage, and MCP server status.

![Statusline](images/statusline.png)

## Features

- **Model name** — Current Claude model
- **Directory** — Basename of working directory
- **Git branch** — Current branch or detached HEAD indicator
- **Git changes** — Insertions/deletions vs HEAD
- **Context remaining** — Percentage until compaction
- **MCP servers** — Connected (green) and disconnected (red)
- **Dippy indicator** — Shows 🐤 when Dippy is configured

## Setup

Add a `statusLine` entry to `~/.claude/settings.json`:

```json
"statusLine": {
  "type": "command",
  "command": "dippy-statusline"
}
```

If you installed manually, use the full path instead: `/path/to/Dippy/bin/dippy-statusline`

## Configuration

The script uses a Molokai-inspired color scheme. Edit `STYLES` in the script to customize colors:

```python
STYLES = {
    "model": ("white", None),
    "directory": ("white", None),
    "branch": ("white", None),
    "branch_detached": ("bgYellow", None),
    "changes_clean": ("white", None),
    "changes_dirty": ("yellow", None),
    "context": ("white", None),
    "mcp_title": ("white", None),
    "mcp_connected": ("green", None),
    "mcp_disconnected": ("red", None),
}
```

## Logging

Debug logs are written to `~/.claude/dippy-statusline.log` (max 1MB, rotates automatically).

## Caching

Results are cached for 3 seconds per session to avoid slowing down Claude Code. MCP server status is cached separately for 10 seconds.
