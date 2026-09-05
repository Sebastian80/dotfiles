# Toolchain

All tools are installed via Homebrew (`/home/linuxbrew/.linuxbrew/bin/`), except Docker and yt-dlp (system packages), Node (fnm) and npm-global CLIs such as `codex` (live under fnm's Node).

## Package managers — use the right one

- **Python**: Use `uv` for everything (venv, install, run). Never use bare `pip` or `python -m pip`.
- **Node.js**: Managed via `fnm`. When a project has `.nvmrc` or `.node-version`, run `fnm use` before running Node commands. Use `pnpm` as default package manager unless the project has a `package-lock.json` (then `npm`) or `yarn.lock` (then `yarn`, install via `corepack enable && corepack prepare yarn@stable --activate` first). `bun` is available but not the default.
- **PHP**: Use `composer`. For projects running in Docker, run `composer` inside the container. On large Oro/monorepo projects NEVER use `composer clear-cache` or `composer update/install --no-cache`, and never bare `composer update` — each forces a multi-minute full metadata re-fetch / re-download of hundreds of deps across every repo (and can exhaust the GitHub API rate limit). To bump one package to a freshly pushed tag, do a cache-friendly partial update: `composer update vendor/pkg --no-scripts --no-install` (lock-only). Only if the new ref still isn't found, delete just that package's VCS cache subdir (`rm -rf "$(composer config --global cache-dir)"/vcs/*pkg*`) and retry. `composer clearcache --gc` (garbage-collect only) is the one safe blanket option.
- **System packages**: Use `brew install`. Never `apt`/`sudo apt`.

## CLI tools

- **Git hosting**: `gh` for GitHub, `glab` for GitLab (git.netresearch.de)
- **Docker**: `docker compose` (v2 syntax, no hyphen). Check if containers are running before exec'ing into them. `docker compose run` consumes the caller's stdin even with `-T` — inside a shell loop reading from a heredoc, feed each run `< /dev/null` or the loop ends after one iteration.
- **JSON**: `jq` is available for JSON processing in shell pipelines.
- **yt-dlp**: "Precondition check failed" + HTTP 400 means the installed binary is stale against YouTube's API; don't debug flags, run `uvx yt-dlp` for the latest.
- **Locale**: prefix awk/sort/printf pipelines that parse or emit decimal numbers with `LC_ALL=C` — the German locale turns `%.2f` into comma decimals and silently breaks joins/greps on dot-decimal data.
- **ripgrep in pipelines**: the ripgreprc forces line numbers even on piped output — any `rg` whose output is consumed as data (paths into `head`/loops/`xargs`) needs `-N`, or downstream reads fail on `1:`-prefixed paths.
