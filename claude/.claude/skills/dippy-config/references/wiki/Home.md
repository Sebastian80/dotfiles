**🐤 Less permission fatigue, more momentum. Dippy knows what’s safe to run and keeps Claude on track when plans change.**

<img src="images/dippy.gif" width="200">

## How It Works

```
AI requests command → Dippy analyzes → allow/ask/deny → Response to AI
```

| Decision  | Meaning                         |
| --------- | ------------------------------- |
| **allow** | Safe command, auto-approved     |
| **ask**   | Ambiguous, prompt user          |
| **deny**  | Dangerous, blocked with message |

## Quick Start

### Install

**Homebrew (recommended):**
```bash
brew tap ldayton/dippy
brew install dippy
```

**Manual:**
```bash
git clone https://github.com/ldayton/Dippy.git
```

### Configure

Add to `~/.claude/settings.json` (or use `/hooks` interactively):

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{ "type": "command", "command": "dippy" }]
      }
    ]
  }
}
```

If you installed manually, use the full path instead: `/path/to/Dippy/bin/dippy-hook`

### Customize (optional)

Create a config file at `~/.dippy/config` or `.dippy` in your project root:

```
allow git                        # Matches git, git commit, git push, etc.
deny rm -rf "Use trash instead"  # Matches rm -rf, rm -rf /, etc.
```

## Key Features

- **Zero dependencies** — Pure Python, hand-written bash parser
- **Multi-platform** — Claude Code, Cursor, Gemini CLI, Codex CLI
- **Allowlist-based** — Approves known-safe commands, asks about unknowns
- **Project configs** — `.dippy` file in project root for per-project rules
- **Audit logging** — Optional JSON log of all decisions

## Philosophy

Dippy is **not adversarial** — it protects against AI mistakes, not malicious actors. It uses conservative allowlists: approve what we know is safe, ask about everything else.

## Documentation

**Core:**
- [[Configuration]] — Config file syntax and options

**Extensions:**
- [[Afterthoughts]] — Post-command feedback to guide Claude
- [[MCP Tools]] — Rules for Model Context Protocol tools

**Proposals:**
- [[File Editing]] — Rules for file editing tools

## Links

- [GitHub Repository](https://github.com/ldayton/Dippy)
- [[Security Model|Security Model]]
