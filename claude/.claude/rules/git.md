# Git Usage

## Process

- If the project isn't in a git repo, ask permission before initializing one.
- Stop and ask how to handle uncommitted changes or untracked files when starting work. Suggest committing existing work first.
- Commit frequently throughout development, even if the high-level task isn't done.
- Never skip, evade, or disable a pre-commit hook.
- Never push commits directly to main/release branches — not even the same SHA via a combined refspec (`git push origin HEAD:develop HEAD:main`). Commits land on feature branches or develop; main only ever follows develop via fast-forward as a separate, deliberate step (`git checkout main && git merge --ff-only develop && git push origin main` — `--ff-only` hard-fails on divergence instead of silently rewriting).
- Never `git add -A` unless you've just run `git status` — don't add random test files to the repo.
- Never commit `.env` files, API keys, tokens, or credentials. If a file looks like it contains secrets, warn Sebastian before staging.
- `**/CLAUDE.md` is globally gitignored (`~/.config/git/ignore`, deliberate). In repos, write `AGENTS.md` and add a local `CLAUDE.md` symlink — a created CLAUDE.md silently never stages, so never expect it to commit.

## Remotes and submodules

- Before pushing, verify `git remote -v` points at the right repository — especially after working in `vendor/` or a submodule.
- Vendor packages installed via composer usually have no `.git` directory, so git commands inside `vendor/` operate on the parent project's repo. To work on a vendor package, clone it separately or confirm `.git` exists in the package directory first.
- A `git remote set-url` in a subdirectory changes the nearest parent `.git` config, not just that subdirectory.
- `git ls-remote <url> refs/heads/* refs/tags/*` compares remote branch/tag state without cloning.

## Commit and branch conventions

- Commit subject: `TICKET-123: Brief description`. Always reference the ticket when one exists.
- Without a ticket, use conventional prefixes (`feat:`, `fix:`, `refactor:`, `chore:`, `docs:`, `test:`).
- Branch with a ticket: the ticket key alone — `TICKET-123`, no description suffix. Check `git branch -r` if unsure; existing repo convention always wins.
- Branch without a ticket: `feature/`, `bugfix/`, or `hotfix/` + descriptive name.
- Before `glab mr create` / `gh pr create`, verify the base: `git log --oneline <target>..HEAD` must list only your own commits. A workspace checked out on a long-lived side branch silently makes every new branch fork from it, and the MR drags the side branch into the target. (An MR created from a workspace sitting on an experiment branch nearly dragged 18 unrelated commits into develop; only the merge-conflict refusal stopped it.)

## MR / PR descriptions

Teams squash MRs, so GitLab uses the description as the squash-commit body. Write it like a commit body.

- Format: four bold one-liners — **Why** / **What** / **Review focus** / **Test** — inline code for identifiers and commands. No headings, no walls of prose.
- Title: imperative, self-contained, ≤72 chars (it becomes the squash-commit subject).
- Short declarative sentences, 3–5 of them. A reviewer must grasp the MR in 30 seconds; if it can't be skimmed, cut it.
- The "Review focus" line names the one thing reviewers should scrutinize — strongest empirically proven lever for merge speed and quality.
- Leave out file-by-file change lists, implementation docs, debugging protocols, UAT/test evidence, pipeline IDs, and screenshots. Those go to `docs/` or the CHANGELOG (architecture), a Jira comment (test results, UAT evidence), or an MR comment (debugging history, cross-MR coordination).
- A 1–2 line "How to test" hint is fine when reviewers need it.
