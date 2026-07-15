# Toolchain

All tools are installed via Homebrew (`/home/linuxbrew/.linuxbrew/bin/`), except Docker (system) and Node (fnm).

## Package managers — use the right one

- **Python**: Use `uv` for everything (venv, install, run). Never use bare `pip` or `python -m pip`.
- **Node.js**: Managed via `fnm`. When a project has `.nvmrc` or `.node-version`, run `fnm use` before running Node commands. Use `pnpm` as default package manager unless the project has a `package-lock.json` (then `npm`) or `yarn.lock` (then `yarn`, install via `corepack enable && corepack prepare yarn@stable --activate` first). `bun` is available but not the default.
- **PHP**: Use `composer`. For projects running in Docker, run `composer` inside the container. On large Oro/monorepo projects NEVER use `composer clear-cache` or `composer update/install --no-cache`, and never bare `composer update` — each forces a multi-minute full metadata re-fetch / re-download of hundreds of deps across every repo (and can exhaust the GitHub API rate limit). To bump one package to a freshly pushed tag, do a cache-friendly partial update: `composer update vendor/pkg --no-scripts --no-install` (lock-only). Only if the new ref still isn't found, delete just that package's VCS cache subdir (`rm -rf "$(composer config --global cache-dir)"/vcs/*pkg*`) and retry. `composer clearcache --gc` (garbage-collect only) is the one safe blanket option.
- **Go**: Standard `go` toolchain via Homebrew.
- **System packages**: Use `brew install`. Never `apt`/`sudo apt`.

## CLI tools

- **Git hosting**: `gh` for GitHub, `glab` for GitLab (git.netresearch.de)
- **Docker**: `docker compose` (v2 syntax, no hyphen). Check if containers are running before exec'ing into them.
- **JSON**: `jq` is available for JSON processing in shell pipelines.
- **Code search**: `ast-grep` for structural/AST-based code search (use via ast-grep skill).
