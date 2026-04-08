> ⚠️ **Proposal:** This feature is not yet implemented.

Dippy analyzes shell commands for output redirects and can control which paths are writable.

## Setup

File editing filtering isn't enabled by default. Add this alongside your existing `PreToolUse` Bash hook in `~/.claude/settings.json`:

```json
{
  "matcher": "Edit|Write",
  "hooks": [{ "type": "command", "command": "dippy" }]
}
```

If you installed manually, use the full path instead: `/path/to/Dippy/bin/dippy-hook`

## Your First Redirect Rule

Add to your config:

```
deny-redirect ~/.ssh/** "SSH keys are protected"
```

Now any command that tries to write to `~/.ssh/` gets blocked.

## Path Patterns

Redirect rules match against file paths:

```
allow-redirect <path-pattern>
deny-redirect <path-pattern>
deny-redirect <path-pattern> "message"
```

**Pattern syntax:**

| Pattern | Matches                            |
| ------- | ---------------------------------- |
| `*`     | Anything except `/`                |
| `**`    | Anything including `/` (recursive) |
| `?`     | Single character                   |

**Examples:**

| Pattern     | Matches                                  |
| ----------- | ---------------------------------------- |
| `/tmp/*`    | `/tmp/foo` but not `/tmp/foo/bar`        |
| `/tmp/**`   | `/tmp/foo`, `/tmp/foo/bar`, `/tmp/a/b/c` |
| `./dist/**` | Anything under `./dist/`                 |
| `./*.log`   | `./app.log`, `./error.log`               |

Paths are normalized before matching:
- `~` → home directory
- `./relative` → absolute path

## Common Scenarios

**Protect sensitive directories:**
```
deny-redirect ~/.ssh/** "SSH keys are protected"
deny-redirect ~/.aws/** "AWS credentials are protected"
deny-redirect ~/.gnupg/** "GPG keys are protected"
deny-redirect /etc/** "System config is protected"
```

**Allow temp and build output:**
```
allow-redirect /tmp/**
allow-redirect ./dist/**
allow-redirect ./build/**
allow-redirect ./target/**
```

**Project: allow artifacts, protect source:**
```
# Build output
allow-redirect ./dist/**
allow-redirect ./coverage/**
allow-redirect ./.pytest_cache/**

# Logs
allow-redirect ./logs/**
allow-redirect ./*.log

# Protect source from shell redirects
deny-redirect ./src/** "Use the AI's file editing tools instead"
```

**CI/CD: restrict to workspace:**
```
allow-redirect $GITHUB_WORKSPACE/**
deny-redirect /** "Writes outside workspace not allowed"
```

## How Redirects Interact with Commands

Redirect rules are checked **in addition to** command rules. A command must pass both:

```
allow git log
deny-redirect /etc/**
```

Result: `git log > /tmp/out` is allowed, but `git log > /etc/foo` is denied.

Like command rules, **last match wins** for redirects.

## What Gets Analyzed

Dippy extracts redirect targets from:

| Construct       | Example              |
| --------------- | -------------------- |
| Output redirect | `> file`, `>> file`  |
| Stderr redirect | `2> file`, `&> file` |
| Here-document   | `<< EOF`             |
| tee             | `cmd                 | tee file` |
| dd              | `dd of=file`         |

If any redirect target is denied, the entire command is denied.

## Quick Reference

| Directive        | Syntax                                                                     |
| ---------------- | -------------------------------------------------------------------------- |
| `allow-redirect` | `allow-redirect <path-pattern>`                                            |
| `deny-redirect`  | `deny-redirect <path-pattern>` or `deny-redirect <path-pattern> "message"` |
