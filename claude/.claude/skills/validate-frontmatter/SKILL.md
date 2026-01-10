---
name: validate-frontmatter
description: >
  Validate YAML frontmatter in Claude Code components (skills, agents, commands).
  Use when creating or editing .md files in agents/, skills/, or commands/ directories.
  Use before committing changes to ensure schema compliance. Supports batch validation
  of entire directories with auto-detection of component type.
allowed-tools: Bash, Read
---

# Frontmatter Validator

Validates YAML frontmatter in Claude Code skills, agents, and commands against the official Anthropic schema.

## Quick Start

```bash
# Validate single file
uv run --with pyyaml ~/.claude/skills/validate-frontmatter/scripts/validate.py path/to/file.md

# Validate all user components
uv run --with pyyaml ~/.claude/skills/validate-frontmatter/scripts/validate.py ~/.claude/

# Validate project components
uv run --with pyyaml ~/.claude/skills/validate-frontmatter/scripts/validate.py .claude/
```

## Options

| Flag | Description |
|------|-------------|
| `--json` | Output JSON instead of human-readable |
| `--strict` | Treat warnings as errors (exit 1) |
| `--type TYPE` | Force component type (skill/agent/command) |
| `--quiet` | Only output errors/warnings |

## Schema Reference

### Skills (SKILL.md)
- **Required**: `name` (hyphen-case, max 64), `description` (max 1024)
- **Optional**: `license`, `allowed-tools`, `metadata`

### Agents (*.md in agents/)
- **Required**: `name` (hyphen-case, max 50), `description`
- **Optional**: `tools`, `model` (sonnet/opus/haiku/inherit), `permissionMode`, `skills`

### Commands (*.md in commands/)
- **All optional**: `description`, `allowed-tools`, `argument-hint`, `model`, `disable-model-invocation`

## Exit Codes

- `0` - All valid
- `1` - Errors found (or warnings with `--strict`)
