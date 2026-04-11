# Git Usage

## Process

- If the project isn't in a git repo, STOP and ask permission to initialize one.
- STOP and ask how to handle uncommitted changes or untracked files when starting work. Suggest committing existing work first.
- When starting work without a clear branch for the current task, create a feature branch.
- Track all non-trivial changes in git.
- Commit frequently throughout development, even if high-level tasks aren't done.
- NEVER SKIP, EVADE OR DISABLE A PRE-COMMIT HOOK.
- NEVER use `git add -A` unless you've just done a `git status` — don't add random test files to the repo.
- Never commit `.env` files, API keys, tokens, or credentials. If a file looks like it contains secrets, warn Sebastian before staging.

## Remotes and submodules

- Before pushing, ALWAYS verify `git remote -v` points to the correct repository. Especially after working in vendor/ or submodule directories.
- Vendor packages installed via composer typically have NO `.git` directory. Running git commands inside vendor/ operates on the parent project's repo. To work on a vendor package's repo, clone it separately (e.g., to /tmp/) or verify `.git` exists in the package directory.
- Never assume a `git remote set-url` in a subdirectory only affects that subdirectory — it changes the nearest parent `.git` config.
- Use `git ls-remote <url> refs/heads/* refs/tags/*` to compare remote branch/tag states without cloning.

## Commit conventions

- Format: `TICKET-123: Brief description`
- Always reference ticket in commit message when a ticket exists
- For work without a ticket, use conventional commit prefixes:
  - `feat: Brief description` — new feature
  - `fix: Brief description` — bug fix
  - `refactor: Brief description` — restructuring without behavior change
  - `chore: Brief description` — config, tooling, maintenance
  - `docs: Brief description` — documentation only
  - `test: Brief description` — test additions or fixes

## Branch naming

- With ticket: `TICKET-123-brief-description`
- Feature: `feature/descriptive-name`
- Bugfix: `bugfix/descriptive-name`
- Hotfix: `hotfix/descriptive-name`
