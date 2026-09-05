# Git Usage

## Process

- If the project isn't in a git repo, ask permission before initializing one.
- Stop and ask how to handle uncommitted changes or untracked files when starting work. Suggest committing existing work first.
- Commit frequently throughout development, even if the high-level task isn't done. On a feature branch (or this dotfiles repo's `main`) that means committing without asking; pushing, tagging and anything on a shared branch always waits for an explicit go.
- Starting work without a clear branch for the task? Create one before the first commit.
- Never skip, evade, or disable a pre-commit hook.
- In team repos, never push commits directly to main/release branches — not even the same SHA via a combined refspec (`git push origin HEAD:develop HEAD:main`). Commits land on feature branches or develop; main only ever follows develop via fast-forward as a separate, deliberate step (`git checkout main && git merge --ff-only develop && git push origin main` — `--ff-only` hard-fails on divergence instead of silently rewriting). A personal repo whose only long-lived branch is `main` (this dotfiles repo) commits on `main`.
- Never `git add -A` unless you've just run `git status` — don't add random test files to the repo.
- Never commit `.env` files, API keys, tokens, or credentials. If a file looks like it contains secrets, warn Sebastian before staging.
- Data leaked into history (secrets, customer paths) gets a history rewrite with `git-filter-repo` as the default proposal, stated with its blast radius (force-push, every clone re-fetches). A forward-only commit removes nothing. Ask before rewriting; it changes shared history.
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

## Tags and releases

- A published tag is never moved or deleted. If a release tag landed on the wrong commit, cut the next patch number. Git refuses to overwrite a tag whose target changed (`! [rejected] X -> X (would clobber existing tag)`), so every clone and every composer VCS-cache mirror that fetched the earlier tag is stuck until someone runs `git tag -d` there by hand, and any lock resolved inside the window carries a commit that no longer exists. The failure shows up days later, on other machines, with no visible link to the cause. (A bundle's release tag was cut three times on three commits within nine days, once because it landed on the code commit instead of the changelog roll; the break surfaced nine days later during an unrelated workspace switch.)
- Before `git tag`: `git log -1` the target and confirm it is the release commit, not the last code commit; `git ls-remote --tags origin refs/tags/<version>` must return nothing. If a removal is genuinely unavoidable, announce the time window and the commit it pointed at, so people with a stale ref can fix it instead of finding it.

## MR / PR descriptions

Teams squash MRs, so GitLab uses the description as the squash-commit body. Write it like a commit body.

- Format: four bold one-liners — **Why** / **What** / **Review focus** / **Test** — inline code for identifiers and commands. No headings, no walls of prose.
- Title: imperative, self-contained, ≤72 chars (it becomes the squash-commit subject).
- Short declarative sentences, 3–5 of them. A reviewer must grasp the MR in 30 seconds; if it can't be skimmed, cut it.
- The "Review focus" line names the one thing reviewers should scrutinize — strongest empirically proven lever for merge speed and quality.
- Leave out file-by-file change lists, implementation docs, debugging protocols, UAT/test evidence, pipeline IDs, and screenshots. Those go to `docs/` or the CHANGELOG (architecture), a Jira comment (test results, UAT evidence), or an MR comment (debugging history, cross-MR coordination).
- A 1–2 line "How to test" hint is fine when reviewers need it.
