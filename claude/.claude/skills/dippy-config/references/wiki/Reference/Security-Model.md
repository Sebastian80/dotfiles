## Threat Model

**What we protect against:** AI coding assistants making mistakes — running `rm -rf /` when they meant `rm -rf ./build`, force-pushing to main, overwriting important files.

**What we don't protect against:** Malicious actors, compromised AI, adversarial prompt injection. If someone is actively trying to bypass Dippy, they can.

## Core Philosophy

**Approve what we know is safe. Ask about everything else.**

Dippy uses a conservative allowlist approach. For each simple command, checks happen in this order:

1. **Config rules** (highest priority) — User-defined overrides
2. **Wrapper commands** — `time`, `timeout`, `command` are unwrapped; inner command analyzed
3. **Built-in allowlist** — Known safe read-only commands
4. **Version/help** — `--help`, `--version`, `-h` auto-approved on any command
5. **CLI handlers** — Tool-specific logic for git, docker, kubectl, etc.
6. **Default: ask** — Unknown commands always prompt

There's no blocklist of "dangerous" patterns — anything not explicitly safe requires approval.

## Architecture

```
┌──────────────────────────────────────────────────────────────────────┐
│                         Raw bash string                              │
│              "cd /tmp && rm -rf * > log.txt; echo done"              │
└──────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────────────┐
│                           Shell Parser                               │
│                                                                      │
│  Extracts:                                                           │
│  - Simple commands (no shell syntax)                                 │
│  - Redirect targets (file paths)                                     │
│  - Pipes, compounds, subshells → broken into parts                   │
└──────────────────────────────────────────────────────────────────────┘
                                   │
                    ┌──────────────┴──────────────┐
                    ▼                              ▼
┌─────────────────────────────┐    ┌─────────────────────────────┐
│      Simple Commands        │    │      Redirect Targets       │
│                             │    │                             │
│  1. "cd /tmp"     → allow   │    │  1. "log.txt" → ask         │
│  2. "rm -rf *"    → ask     │    │                             │
│  3. "echo done"   → allow   │    │                             │
└─────────────────────────────┘    └─────────────────────────────┘
                    │                              │
                    └──────────────┬──────────────┘
                                   ▼
                    ┌─────────────────────────────┐
                    │     Combine Decisions       │
                    │                             │
                    │  Most restrictive wins      │
                    │  Result: ASK                │
                    └─────────────────────────────┘
```

Each simple command is checked against the 6-step process. Decisions are combined — if ANY part requires approval, the whole pipeline requires approval.

## Decision Priority

Two different rules apply in different contexts:

**Config rules:** Last match wins (like gitconfig). This lets you allow broadly then deny specifics:
```
allow git
deny git push --force
```

**Combining decisions:** Most restrictive wins when merging results from different parts of a compound command:
```
deny > ask > allow
```

## What's Pre-Approved

**Built-in safe commands** — Over 200 read-only commands:

| Category             | Examples                                    |
| -------------------- | ------------------------------------------- |
| File viewing         | cat, head, tail, less, bat, zcat, hexdump   |
| Directory listing    | ls, tree, exa, eza, dir                     |
| Search               | grep, rg, ag, ack, locate, mdfind           |
| Info                 | stat, file, wc, du, df, pwd, readlink       |
| Text processing      | cut, uniq, diff, jq, tr, paste, nl          |
| System info          | ps, whoami, hostname, uname, date, uptime   |
| Network diagnostics  | ping, dig, netstat, host, whois             |
| Binary analysis      | nm, objdump, otool, ldd, readelf            |
| Checksums            | md5sum, sha256sum, shasum, cksum            |
| Conditionals         | `[`, test (arguments checked for cmdsubs)   |

**CLI handlers** — Over 80 tools with subcommand-aware logic:

| Tool      | Safe                      | Needs Approval              |
| --------- | ------------------------- | --------------------------- |
| git       | status, log, diff, branch | push, commit, reset, rebase |
| docker    | ps, images, inspect       | run, rm, stop, build        |
| kubectl   | get, describe, logs       | delete, apply, exec         |
| aws       | s3 ls, ec2 describe-*     | s3 rm, ec2 terminate-*      |
| terraform | plan, show, validate      | apply, destroy              |
| gh        | pr list, issue view       | pr merge, repo delete       |
| npm       | list, outdated, view      | install, publish, uninstall |
| brew      | list, info, search        | install, uninstall, upgrade |

Other handlers: 7z, ansible, auth0, awk, azure, black, cargo, cdk, curl, dmesg, env, fd, find, fzf, gcloud, helm, ifconfig, ip, isort, journalctl, openssl, packer, pip, pre-commit, prometheus, pytest, python, ruff, sed, sort, tar, tee, uv, wget, xargs, xxd, yq

## Rule Matching

**Commands** are normalized and matched against patterns:

```
Command: rm -rf /tmp/build
Pattern: ask rm
Result:  MATCH → ask for approval (prefix match)
```

Path normalization happens before matching:
- `./foo` → `/absolute/path/foo`
- `~/bar` → `/home/user/bar`
- `../baz` → resolved against cwd

**Redirects** are extracted and matched separately:

```
Command: echo "data" > ~/.ssh/authorized_keys
Redirect: ~/.ssh/authorized_keys
Pattern:  ask-redirect ~/.ssh/*
Result:   MATCH → ask for approval
```

Even if the command itself is allowed, the redirect can trigger review. Output redirects (`>`, `>>`, `2>`, etc.) with no matching rule default to **ask**.

## Parser Behavior

**What the parser handles** — bash syntax is broken down BEFORE rule matching:

| Syntax      | Example    | Parser Output                 |
| ----------- | ---------- | ----------------------------- |
| Semicolon   | `a; b`     | commands: `a`, `b`            |
| And         | `a && b`   | commands: `a`, `b`            |
| Or          | `a \|\| b` | commands: `a`, `b`            |
| Pipe        | `a \| b`   | commands: `a`, `b`            |
| Subshell    | `(a; b)`   | commands: `a`, `b`            |
| Command sub | `a $(b)`   | commands: `b`, `a $(...)`     |
| Redirect    | `a > f`    | commands: `a`, redirects: `f` |
| Here-doc    | `a <<EOF`  | commands: `a`                 |

The rule engine never sees shell metacharacters — only simple command strings.

**What the parser does NOT handle:**

- **Variable expansion:** `$HOME` stays as `$HOME` (shell expands it later)
- **Glob expansion:** `*.txt` stays as `*.txt` (shell expands it later)
- **Alias resolution:** We don't know what shell aliases exist

These are expanded by the shell AFTER approval. We match the literal string.

## Edge Cases

**cd tracking:** When a compound command starts with `cd <literal>`, subsequent commands have paths resolved relative to that directory:
```bash
cd /tmp && rm -rf *   # paths resolved relative to /tmp, not original cwd
```

**Nested command substitution:**
```bash
echo $(cat $(find . -name "*.txt"))
```
Parser extracts innermost first: `find`, then `cat $(...)`, then `echo $(...)`.

**Cmdsub injection protection:**
```bash
git push $(echo origin) main
```
Even if the inner command is safe, passing a pure `$(...)` as an argument to a CLI handler that needs approval triggers an ask.

**Redirects in subshells:**
```bash
(echo foo > /tmp/a) > /tmp/b
```
Both `/tmp/a` and `/tmp/b` are checked against redirect rules.

**Unquoted heredocs:**
```bash
cat <<EOF
$(rm -rf /)
EOF
```
Command substitutions in unquoted heredocs are analyzed. Quoted heredocs (`<<'EOF'`) are treated as data.

**Cmdsubs in expressions:** Command substitutions are analyzed inside:
- Arithmetic: `(( x = $(cmd) ))`
- Parameter expansions: `${x:-$(cmd)}`
- C-style for loops: `for (( i=$(cmd); ... ))`

## Trust Assumptions

1. **Parser correctness:** We trust our shell parser to correctly decompose bash syntax. A parser bug could let commands slip through.

2. **AI cooperation:** The AI isn't actively encoding malicious commands in ways designed to evade parsing (base64, eval tricks, etc.).

3. **Single-layer execution:** The command runs in one shell. We don't trace into scripts or binaries that are executed.

## Pattern Tips

**Effective patterns:**
```
# These work because parser extracts the rm command
ask rm -rf
ask rm -rf /

# Catches dangerous git operations
ask git push --force
ask git reset --hard

# Protect sensitive files (redirect patterns still use globs)
ask-redirect /etc/*
ask-redirect ~/.ssh/*
ask-redirect **/.env*
```

**What patterns can't catch:**
```
# Can't see inside scripts
./malicious-script.sh    # Pattern "ask rm" won't help

# Can't see after variable expansion
rm -rf $DANGEROUS_PATH   # We see literal "$DANGEROUS_PATH"

# Can't resolve shell aliases
ll                       # If aliased to "ls -la", we see "ll"
```

## Summary

**Rule matching operates on parsed commands, not raw bash.**

- `echo hi; rm -rf /` → two commands, each matched separately
- Patterns are simple globs, not shell-aware
- Parser handles the complexity, rule engine stays simple
- Unknown syntax → ask (fail safe)
