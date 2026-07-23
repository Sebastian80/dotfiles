# AGENTS.md — dotfiles repo

## What this repo is

GNU Stow-managed dotfiles. Each top-level directory (`bash`, `git`, `tmux`, `ghostty`, …) is a stow package mirroring `$HOME`; `make install` symlinks them. CLI tools come from Homebrew (`Brewfile`, `brew bundle install`). System-level pieces (Docker Engine, sudoers) are documented in `INSTALLATION.md` and `system/`.

**Note:** `claude/` is the stow package for the *global* `~/.claude` config (AGENTS.md, rules, skills, hooks) — edits there change agent behavior in every project, not just this repo.

## Commands

| Task | Command |
|------|---------|
| Dry-run symlinks | `make test` |
| Install all packages | `make install` |
| Restow after pull | `make update` |
| Install brew tools | `brew bundle install` |
| Full bootstrap | `./scripts/setup/bootstrap.sh` |

## Conventions

- Configs live in stow packages, never loose in the repo root.
- New CLI tools go into `Brewfile` with a one-line comment, grouped by section.
- Never commit secrets; see `SECRET_MANAGEMENT.md`.
- Repo docs: `README.md` (overview), `INSTALLATION.md` (setup walkthrough), `SETUP-NOTES.md` (keyboard/terminal fixes), `SCRIPTS.md` (user scripts).

## OS compatibility — Kubuntu 26.04 LTS (verified 2026-07)

Migration target from Ubuntu 24.04 is Kubuntu 26.04 LTS "Resolute Raccoon" (Plasma 6.6, **Wayland-only** — the X11 session is not installed and not supported).

Verified compatible, no changes needed:

- **Homebrew**: Ubuntu 26.04 is Tier 1 since Homebrew 6.0.0 (bottle baseline glibc 2.39). All Brewfile formulae are pure CLI.
- **Stow setup**: pure symlinks; bootstrap apt deps (`stow`, `build-essential`, `procps`, `curl`, `file`, `git`) all exist in 26.04.
- **Docker CE**: Docker's apt repo has day-one `resolute` support — re-add the repo with the new codename.
- **Ghostty**: `ppa:mkasberg/ghostty-ubuntu` has resolute builds; Ghostty is also in the official 26.04 universe repo (`apt install ghostty`, may lag the PPA). Runs natively on Wayland; the CSI-u/`.inputrc` fixes in `SETUP-NOTES.md` are unaffected.

Open migration item — **xclip is X11-only** and flaky under Wayland/XWayland clipboard bridging (pipe-and-exit loses selection ownership). Affected spots:

- `tmux/.tmux.conf:91` — copy-mode `y` pipes to `xclip -sel clip` (prefer `set -g set-clipboard on` / OSC 52, which Ghostty supports)
- `bash/.bash/aliases.bash` — `pbcopy`/`pbpaste` aliases
- `bash/.bash/functions/fzf.bash` — Ctrl+Y copy binding
- `bash/.bash/functions/bitwarden.bash` — password copy

Fix direction: install `wl-clipboard` and branch on `$WAYLAND_DISPLAY` (wl-copy/wl-paste, xclip fallback).

GTK stow package (`gtk.css` + bookmarks) is harmless on KDE, but don't add a `settings.ini` to it — Plasma's `kde-gtk-config` owns `~/.config/gtk-3.0/settings.ini`.
