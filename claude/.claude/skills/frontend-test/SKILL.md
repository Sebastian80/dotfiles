---
name: frontend-test
description: Use when testing UI with logged-in sessions, testing authenticated flows, or when chrome MCP tools would bloat main context. Triggers - "test the login", "verify the form", "check if button works", needing cookies/auth preserved.
---

# Frontend Test Agent

Spawns isolated Claude instance with chrome-in-chrome for browser testing. Your Chrome session (cookies, auth) is preserved. Main context stays clean.

## When to Use

- Testing sites where you're **already logged in**
- Verifying UI flows that need **your auth session**
- Browser testing without **polluting main context**
- Multi-step UI verification (navigate → fill → click → verify)

## When NOT to Use

| Scenario | Use Instead |
|----------|-------------|
| Headless CI/CD testing | Playwright MCP |
| Fresh browser (no cookies needed) | Playwright MCP |
| One quick page check | Direct `claude --chrome` |
| Screenshot only | `mcp__claude-in-chrome__*` directly |

## Quick Reference

Always use `tmux-cli` - it works inside and outside tmux, and `wait_idle` beats guessing sleep times.

| Command | Usage |
|---------|-------|
| **Launch** | `tmux-cli launch "bash"` |
| **Send** | `tmux-cli send "text" --pane=$PANE` |
| **Wait** | `tmux-cli wait_idle --pane=$PANE --idle-time=10` |
| **Capture** | `tmux-cli capture --pane=$PANE` |
| **Kill** | `tmux-cli kill --pane=$PANE` |

## Timing Guide (for wait_idle --idle-time)

| Task Type | Idle Time |
|-----------|-----------|
| Simple navigation | 5-10s |
| Form fill + submit | 10-15s |
| Multi-step flow | 15-20s |
| Screenshot/recording | 10-15s |
| Complex SPA | 20-30s |

## Core Pattern

```bash
# 1. Launch
PANE=$(tmux-cli launch "bash" 2>&1 | tail -1)
tmux-cli send "claude --chrome" --pane="$PANE"
sleep 5  # Wait for Claude to initialize

# 2. Send task
tmux-cli send "Your test task here" --pane="$PANE"

# 3. Wait for completion
tmux-cli wait_idle --pane="$PANE" --idle-time=15 --timeout=120

# 4. Capture output
tmux-cli capture --pane="$PANE"

# 5. (Optional) Follow-up
tmux-cli send "Additional task" --pane="$PANE"
tmux-cli wait_idle --pane="$PANE" --idle-time=10

# 6. Cleanup
tmux-cli send "/exit" --pane="$PANE"
sleep 2
tmux-cli kill --pane="$PANE"
```

## Success Criteria

Look for in captured output:
- `Navigation completed` - page loaded
- `⎿ Done` or `●` markers - tool executed
- Actual results text - agent's findings
- No `Error:` or `Permission denied`

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Using sleep instead of wait_idle | `tmux-cli wait_idle` is smarter |
| Pane ID wrong | Check output of launch command |
| Chrome not connected | Click extension icon in Chrome to wake it |
| Permission prompts | Add `mcp__claude-in-chrome__*` to settings.json allow list |
| Orphaned panes | `tmux-cli cleanup` or `tmux list-panes` |
| Site blocked | Grant permission in Chrome extension settings |

## Troubleshooting

**"Extension not connected"**: Click Claude icon in Chrome toolbar.

**"Permission denied"**: Add to `~/.claude/settings.json`:
```json
"permissions": { "allow": ["mcp__claude-in-chrome__*"] }
```

**Site-specific denial**: Grant permission in Chrome extension for that domain.

**Output empty**: Increase `--idle-time` value.

## Capabilities

Navigate, click, fill forms, screenshot, read content, run JS, check console, monitor network - all with your logged-in session.
