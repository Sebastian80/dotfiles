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

## MR / PR descriptions

- Teams squash MRs: GitLab takes the MR description as the squash-commit body. Write it like a commit body.
- 3–5 sentences covering WHAT changed and WHY. A reviewer must grasp the MR in 30 seconds.
- NEVER include: file-by-file change lists, implementation documentation, debugging protocols, UAT/test evidence, pipeline IDs, screenshots of passing tests.
- Where that content belongs instead:
  - architecture / implementation details → `docs/` in the repo (or CHANGELOG)
  - test results, UAT evidence → Jira ticket comment
  - debugging history → MR comment or ticket comment, never the description
- A 1–2 line "How to test" hint is fine when reviewers need it.
- Short declarative sentences — a 5-sentence wall of clause-heavy prose violates the spirit. If it can't be skimmed in 30 seconds, cut it.
- Cross-MR coordination notes (conflicts, ordering) → MR comment, not the description.
- Title: imperative, self-contained, ≤72 chars (it becomes the squash-commit subject).
- Add a "Review focus:" line naming the one thing reviewers should scrutinize — strongest empirically proven lever for merge speed/quality.
- Format: four bold one-liners — **Why** / **What** / **Review focus** / **Test** — with inline code for identifiers/commands. No headings, no walls of prose.
