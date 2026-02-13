# Toolchain

All tools are installed via Homebrew (`/home/linuxbrew/.linuxbrew/bin/`), except Docker (system) and Node (fnm).

## Package managers — use the right one

- **Python**: Use `uv` for everything (venv, install, run). Never use bare `pip` or `python -m pip`.
- **Node.js**: Managed via `fnm`. When a project has `.nvmrc` or `.node-version`, run `fnm use` before running Node commands. Use `pnpm` as default package manager unless the project has a `package-lock.json` (then `npm`) or `yarn.lock` (then `yarn`, install via `corepack enable && corepack prepare yarn@stable --activate` first). `bun` is available but not the default.
- **PHP**: Use `composer`. For projects running in Docker, run `composer` inside the container.
- **Go**: Standard `go` toolchain via Homebrew.
- **System packages**: Use `brew install`. Never `apt`/`sudo apt`.

## CLI tools

- **Git hosting**: `gh` for GitHub, `glab` for GitLab (git.netresearch.de)
- **Docker**: `docker compose` (v2 syntax, no hyphen). Check if containers are running before exec'ing into them.
- **JSON**: `jq` is available for JSON processing in shell pipelines.
- **Code search**: `ast-grep` for structural/AST-based code search (use via ast-grep skill).
