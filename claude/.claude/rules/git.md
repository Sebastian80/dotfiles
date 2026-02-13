# Git Usage

- Before pushing, ALWAYS verify `git remote -v` points to the correct repository. Especially after working in vendor/ or submodule directories.
- Vendor packages installed via composer typically have NO `.git` directory. Running git commands inside vendor/ operates on the parent project's repo. To work on a vendor package's repo, clone it separately (e.g., to /tmp/) or verify `.git` exists in the package directory.
- Never assume a `git remote set-url` in a subdirectory only affects that subdirectory — it changes the nearest parent `.git` config.
- Use `git ls-remote <url> refs/heads/* refs/tags/*` to compare remote branch/tag states without cloning.

## Commit conventions

- Format: `TICKET-123: Brief description`
- Always reference ticket in commit message when a ticket exists
- For work without a ticket (dotfiles, config, exploratory), use `chore: Brief description`

## Branch naming

- With ticket: `TICKET-123-brief-description`
- Feature: `feature/descriptive-name`
- Bugfix: `bugfix/descriptive-name`
- Hotfix: `hotfix/descriptive-name`
