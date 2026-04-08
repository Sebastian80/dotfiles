---
name: dippy-config
description: Manage dippy permission rules in ~/.dippy/config (allow/ask/deny/deny-redirect/aliases). Use whenever the user says things like "allow X without asking", "wildcard add Y to dippy", "stop dippy from prompting for Z", "make dippy ask before W", "block dippy from V", "why does dippy block/allow/ask for command Q", "add an exception for", "narrow ask for destructive variant", or otherwise needs to add, remove, debug, or audit dippy autopilot rules. Knows the prefix-tokenized fnmatch syntax, last-match-wins precedence, the trailing-` *` fallback trick for end-of-command flags, the dotfile symlink layout, and the verification flow via direct `echo {...} | dippy --claude` invocation. Always reads the current config first, places rules in the correct section, and proves the change with a positive/negative test matrix before declaring done.
---

# Dippy Config Skill

Maintain `~/.dippy/config` (the dippy autopilot's allow/ask/deny ruleset) with rigour: read-first, write minimal, verify-before-commit.

Dippy is the PreToolUse Bash gate that decides allow/ask/deny for every shell command Claude Code wants to run. Its decision is driven by the rules in `~/.dippy/config`. This skill manages that config.

## Architecture (read once, then keep in mind)

1. `~/.claude/settings.json` wildcard-allows the `Bash` tool in `permissions.allow`
2. A `PreToolUse` hook on the `Bash` matcher pipes the tool input JSON to `dippy` (binary at `/home/linuxbrew/.linuxbrew/bin/dippy`, source at `/home/linuxbrew/.linuxbrew/Cellar/dippy/<version>/libexec/src/dippy/`)
3. `dippy` reads `~/.dippy/config`, applies rules in file order (last-match-wins), and returns a JSON decision
4. The decision JSON shape: `{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"|"ask"|"deny", "permissionDecisionReason": "🐤 ..."}}`
5. Claude Code consumes the decision and either runs the command, prompts the user, or blocks

The config file `~/.dippy/config` is a **symlink** to the dotfiles repo at `~/dotfiles/dippy/.dippy/config`. **Always edit through the dotfile path** so the change lands in git, not just in the symlink target.

## When to use this skill

Trigger on any of:

- "allow `<tool>`" / "auto-approve `<tool>`" / "wildcard `<tool>`" / "stop prompting for `<tool>`"
- "ask before `<command>`" / "prompt me for `<command>`" / "confirm before `<command>`"
- "block `<command>`" / "deny `<command>`" / "never run `<command>`"
- "why does dippy block / allow / ask for `<command>`" — debugging an existing decision
- Any mention of `.dippy/config` or "dippy permissions" or "dippy rules" or "the autopilot"
- "wildcard bash and only ask on destructive stuff" — describes the existing architecture; verify it's still in place + add narrow asks/denies as requested

If the user is asking about the **Claude Code** permission system in `~/.claude/settings.json` (the `permissions.allow`/`permissions.deny` arrays) rather than dippy, use the `update-config` skill instead. Dippy and the Claude Code static permissions are two different layers — `Bash` is wildcard-allowed at the static layer and dippy provides the actual gating.

## Rule syntax cheatsheet

| Directive | Form | What it does |
|---|---|---|
| `allow <pattern>` | `allow git status` | Auto-approve matching commands |
| `ask <pattern> "<message>"` | `ask rm -rf "Confirm?"` | Prompt user with the message shown |
| `deny <pattern> "<message>"` | `deny pip install "Use uv"` | Block; message goes back to the model so it can adapt |
| `deny-redirect <glob> "<message>"` | `deny-redirect ~/.ssh/**` | Block shell redirects writing to matching paths (the only writeguard if sandbox is off) |
| `allow-redirect <glob>` | `allow-redirect /tmp/**` | Whitelist a redirect target |
| `allow-mcp <pattern>` | `allow-mcp mcp__github__list_*` | MCP tool allowlist |
| `ask-mcp <pattern>` | `ask-mcp mcp__*__delete_*` | MCP tool asklist |
| `deny-mcp <pattern> "<msg>"` | `deny-mcp mcp__*__delete_*` | MCP tool blocklist |
| `alias <source> <target>` | `alias ~/bin/gh gh` | Map wrapper to canonical name |
| `set default <decision>` | `set default ask` | Default for unknowns (default: ask) |
| `set log <path>` | `set log ~/.dippy/audit.log` | Audit log path |
| `set log-full` | `set log-full` | Include full command text in log |
| `# comment` | `# this is a comment` | Line comment, also inline trailing |

## Pattern matching rules

Patterns are tokenized on spaces. Matching is **fnmatch-based** (Python's `fnmatch.fnmatch`, not glob — `*` matches across path separators).

### Default: prefix matching

```
allow git status
```
Matches `git status`, `git status -s`, `git status --porcelain`, `git status anything else`. The pattern is implicitly suffixed with ` *` for matching.

### Exact match (anchored)

```
allow git status|
```
The trailing `|` is dippy's "exact" anchor — only matches `git status` with no arguments.

### Wildcards

| Char | Meaning |
|---|---|
| `*` | Any sequence (including spaces). Use freely, even mid-pattern. |
| `?` | Single character |
| `[abc]` | Character class |
| `**` | Recursive directory match (paths only — `_glob_to_regex` in `core/config.py`) |

### CRITICAL: trailing-` *` fallback

Dippy has a special-case at `core/config.py:673-677`: a glob pattern ending with ` *` ALSO matches the bare command (zero trailing args). This is the key to writing one rule that catches both end-of-command flags and middle-of-command flags.

Example: `ask jira * -X DELETE *` matches **all** of:
- `jira issue KEY -X DELETE` (DELETE at the very end — caught by the fallback)
- `jira issue KEY -X DELETE --foo bar` (DELETE with trailing args — caught by direct fnmatch)
- `jira sprint 920 issues --issues KEY -X DELETE` (long arg list before DELETE)
- `jira comment KEY 12345 -X DELETE`

You **don't** need a separate rule for "DELETE at end of command". Use the trailing ` *` and rely on the fallback.

## Last-match-wins precedence

Rules evaluate **in file order** and the **last** match wins. Therefore:

1. Broad allows go FIRST (early in the file)
2. Narrow asks/denies that override the allow go AFTER (later in the file)

Standard section layout (matches the existing `~/dotfiles/dippy/.dippy/config`):

```
#---- Allows: non-destructive dev commands ----#
allow <broad pattern>

#---- Asks: destructive variants prompt for confirmation ----#
ask <broad> <destructive variant> "<message>"

#---- Denies: hard blocks - must come LAST to win ----#
deny <hard block> "<message>"

#---- Deny-redirect: secrets-write protection ----#
deny-redirect <secret path glob> "<message>"
```

If you put a narrow `ask` BEFORE the broad `allow`, the allow overrides the ask and your prompt never fires. **Order is everything.**

## Workflow (always follow in this order)

### Step 1 — Read the current config

```bash
cat ~/.dippy/config
```

Note:
- Which sections exist (Allows / Asks / Denies / Deny-redirect)
- What's already allowed broadly (dev tools, git subcommands, etc.)
- What's already in `ask` and `deny`
- The order of the file (last-match-wins is order-sensitive)

### Step 2 — Check what dippy currently decides for the target command

Use the direct invocation pattern (no need to edit anything yet):

```bash
echo '{"tool_name":"Bash","tool_input":{"command":"<exact command>"}}' | dippy --claude | jq -r '.hookSpecificOutput | "\(.permissionDecision) - \(.permissionDecisionReason // "no rule")"'
```

Save the result as the "before" baseline. If dippy already returns the desired decision, **stop — no rule change needed**.

### Step 3 — Decide intent + section + position

| Intent | Directive | Section | Position |
|---|---|---|---|
| Auto-approve a tool's whole CLI | `allow` | Allows | Anywhere in Allows |
| Auto-approve only specific safe subcommands | `allow tool subcommand` | Allows | Anywhere in Allows |
| Override a broad allow for destructive variants | `ask` | Asks | After the broad allow |
| Hard-block a tool/command class | `deny` | Denies | Last in file |
| Block writes to a path glob | `deny-redirect` | Deny-redirect | Anywhere in Deny-redirect |

### Step 4 — Construct the pattern

Decide on:
- **Prefix vs glob vs exact**: prefix is the default; use glob `*`/`**` for variable middle-args; use `|` for exact-only
- **Trailing ` *` fallback**: if you're matching a flag that may or may not have args after it, use the `<command> <flag> *` form
- **Specificity**: narrower patterns are safer — match exactly what you mean to gate

Test the pattern with positive AND negative cases (next step) BEFORE you commit it to disk.

### Step 5 — Edit `~/dotfiles/dippy/.dippy/config`

Use the Edit tool. Place the new rule in the correct section. Add an inline comment if the rule isn't self-explanatory. If you're adding multiple related rules, group them.

**Always edit the dotfile path**, not the symlink at `~/.dippy/config`. The dotfile path is `/home/sebastian/dotfiles/dippy/.dippy/config`.

### Step 6 — Verify with a test matrix (mandatory)

Build a 4-quadrant matrix and run it via `dippy --claude`:

```bash
test_cmd() {
  local label="$1" cmd="$2"
  printf "%-58s -> " "$label"
  echo "{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$cmd\"}}" \
    | dippy --claude \
    | jq -r '.hookSpecificOutput | "\(.permissionDecision) (\(.permissionDecisionReason // "no rule"))"'
}

# 1. Positive: command that SHOULD trigger the new rule
test_cmd "[positive] should match new rule"          "<your target command>"

# 2. Adjacent positive: variation that SHOULD also match
test_cmd "[adjacent positive] same intent, different shape"  "<variation>"

# 3. Adjacent negative: similar command that SHOULD NOT match (proves the rule is narrow enough)
test_cmd "[adjacent negative] similar but different intent"  "<close-but-not>"

# 4. Far negative: unrelated common command (proves you didn't break anything else)
test_cmd "[far negative] unrelated common command"   "<unrelated>"
```

The output must show:
- Positive cases → the expected new decision (`ask` or `deny`)
- Negative cases → unchanged (likely `allow` from a broader rule, or `ask` as default)

### Step 7 — Show the user the decision matrix

Always print the test output to the user before saying "done". They need to see that:
- The new rule fired for the intended commands
- Other commands are unaffected
- The `permissionDecisionReason` mentions the right pattern

### Step 8 — Don't commit unless the user asks

Edits land in `~/dotfiles/dippy/.dippy/config` (a tracked dotfile in the dotfiles repo). Per the global CLAUDE.md "NEVER commit changes unless the user explicitly asks you to" — leave the change as a working-tree modification and tell the user it's ready.

## Common patterns (reach for these first)

### Allow a whole tool's CLI

```
allow mytool
```

### Allow specific safe subcommands only

```
allow mytool list
allow mytool show
allow mytool status
```
Combined with `set default ask` (the default), all other `mytool` subcommands will prompt.

### Wildcard a tool but ask on destructive variants

```
allow git
ask git push --force          "Force push - confirm?"
ask git push * --force        "Force push - confirm?"
ask git reset --hard          "Hard reset - discards uncommitted changes"
deny git push --no-verify     "Hooks exist for a reason"
```

### Catch a destructive flag anywhere in command line

```
allow tool
ask tool * --dangerous *      "tool --dangerous - confirm?"
```
The leading `tool * --dangerous` matches the flag regardless of where it appears after the command name. The trailing ` *` lets it also catch the flag when it's the last token via dippy's fallback.

### Block writes to secret paths

```
deny-redirect ~/.ssh/**       "SSH keyring is protected"
deny-redirect ~/.gnupg/**     "GPG keyring is protected"
deny-redirect **/.env*        "Never write .env files"
```

### Alias a wrapper script

```
alias ~/bin/mycli mycli
allow mycli list
```
Now `~/bin/mycli list` matches the `allow mycli list` rule.

## Anti-patterns (avoid)

| Mistake | Why it's wrong | Fix |
|---|---|---|
| Putting an `ask` BEFORE the matching `allow` | last-match-wins → the broader allow overrides | Move the `ask` AFTER the `allow` |
| Writing `ask jira -X DELETE` (no wildcards) | Only matches the literal command `jira -X DELETE` (no subcommand) | Use `ask jira * -X DELETE *` |
| Writing `ask jira * -X DELETE` (no trailing ` *`) | Misses commands with trailing args after `DELETE` | Add the trailing ` *` so the fallback also catches the bare end |
| Editing `~/.dippy/config` directly (the symlink target on disk) | Edits don't land in the dotfiles repo for git | Edit `~/dotfiles/dippy/.dippy/config` |
| Skipping the verification step | Easy to write a rule that matches too much or too little | ALWAYS run the test matrix before claiming done |
| Ignoring the dippy defaults | Dippy ships with built-in safe-command lists in `core/allowlists.py` (`SIMPLE_SAFE`) — your config only ADDS to those | Read `core/allowlists.py` if confused about why a command is already allowed |
| Multi-line patterns | Dippy parses one rule per line | Split into separate lines |
| Using `*` for path-like patterns | `*` doesn't recurse into subdirectories | Use `**` for recursive paths in `deny-redirect` |
| Forgetting that `allow` defaults to **prefix** match | `allow git` matches `git push --force` too | Use `allow git status` for narrow allows, then `ask git push --force` to override |

## Debugging an existing decision

When the user asks "why does dippy block/allow/ask for `<command>`":

1. Run the command through dippy directly:
```bash
echo '{"tool_name":"Bash","tool_input":{"command":"<command>"}}' | dippy --claude | jq
```
2. Look at `permissionDecisionReason` — it tells you which rule matched (e.g., `🐤 jira (jira)` means the `allow jira` rule matched)
3. If the reason is `🐤` with no rule mentioned, it's a built-in `SIMPLE_SAFE` allowlist or the default
4. Read `~/.dippy/config` to find the matching pattern
5. If the pattern is wrong, fix it via Steps 1-7 above

## File locations

| Path | Purpose |
|---|---|
| `~/.dippy/config` | Dippy config (symlink) |
| `~/dotfiles/dippy/.dippy/config` | Dotfile target (edit here) |
| `/home/linuxbrew/.linuxbrew/bin/dippy` | Dippy binary on PATH |
| `/home/linuxbrew/.linuxbrew/Cellar/dippy/<version>/libexec/src/dippy/core/config.py` | Pattern matching source (line 639 `_match_words`, 660 prefix logic, 673 trailing-` *` fallback) |
| `/home/linuxbrew/.linuxbrew/Cellar/dippy/<version>/libexec/src/dippy/core/allowlists.py` | Built-in `SIMPLE_SAFE` allowlist |
| `~/.claude/settings.json` | Claude Code permissions + the PreToolUse hook that calls dippy |
| `references/wiki/` (this skill) | Mirror of the dippy GitHub wiki |

## References (full dippy wiki, mirrored from upstream)

The complete [dippy wiki](https://github.com/ldayton/Dippy/wiki) is mirrored under `references/wiki/`:

- `references/wiki/Home.md` — overview, install, quick start, philosophy
- `references/wiki/Configuration.md` — the canonical config syntax doc (read this first if unsure)
- `references/wiki/Extensions/Afterthoughts.md` — post-command feedback to guide Claude
- `references/wiki/Extensions/MCP-Tools.md` — MCP tool rules (`allow-mcp`, `ask-mcp`, `deny-mcp`)
- `references/wiki/Extras/Statusline.md` — dippy statusline integration
- `references/wiki/Extras/VSCode.md` — VSCode integration
- `references/wiki/Proposals/File-Editing.md` — proposed file-editing rules
- `references/wiki/Reference/Handler-Model.md` — dippy's CLI handler model
- `references/wiki/Reference/Security-Model.md` — dippy's security threat model

Read these on demand when:
- The cheatsheet above doesn't cover the syntax you need (`Configuration.md`)
- The user asks about MCP rules (`Extensions/MCP-Tools.md`)
- You need to understand WHY dippy makes a decision (`Reference/Handler-Model.md` + `Reference/Security-Model.md`)
- The user asks about Afterthoughts, statusline, VSCode integration

Source of truth: <https://github.com/ldayton/Dippy/wiki>. To refresh the mirror: `git clone https://github.com/ldayton/Dippy.wiki.git /tmp/dippy-wiki && cp -r /tmp/dippy-wiki/{Home.md,Configuration.md,Extensions,Extras,Proposals,Reference,_Sidebar.md} ~/dotfiles/claude/.claude/skills/dippy-config/references/wiki/`.
