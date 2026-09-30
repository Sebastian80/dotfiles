# AGENTS.md — dotfiles repo

## What this repo is

GNU Stow-managed dotfiles. Each top-level directory (`bash`, `git`, `tmux`, `ghostty`, …) is a stow
package mirroring `$HOME`; `make install` symlinks them. CLI tools come from Homebrew (`Brewfile`,
`brew bundle install`). System-level pieces (Docker Engine, sudoers) are documented in
`INSTALLATION.md` and `system/`.

**Note:** `claude/` is the stow package for the *global* `~/.claude` config (AGENTS.md, rules,
skills, hooks) — edits there change agent behavior in every project, not just this repo.

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
- Repo docs: `README.md` (overview), `INSTALLATION.md` (setup walkthrough), `SETUP-NOTES.md`
  (keyboard/terminal fixes), `SCRIPTS.md` (user scripts), `SECRET_MANAGEMENT.md` (Bitwarden, tokens).
- `make lint` covers scripts and this repo's prose; the trees under `claude/`, `agents/` and `pi/`
  are spellchecked but not format-linted.

## OS compatibility — Kubuntu 26.04 LTS (verified 2026-07)

Migration target from Ubuntu 24.04 is Kubuntu 26.04 LTS "Resolute Raccoon" (Plasma 6.6,
**Wayland-only** — the X11 session is not installed and not supported).

Verified compatible, no changes needed:

- **Homebrew**: Ubuntu 26.04 is Tier 1 since Homebrew 6.0.0 (bottle baseline glibc 2.39). All
  Brewfile formulae are pure CLI.
- **Stow setup**: pure symlinks; bootstrap apt deps (`stow`, `build-essential`, `procps`, `curl`,
  `file`, `git`) all exist in 26.04.
- **Docker CE**: Docker's apt repo has day-one `resolute` support — re-add the repo with the new
  codename.
- **Ghostty**: `ppa:mkasberg/ghostty-ubuntu` has resolute builds; Ghostty is also in the official
  26.04 universe repo (`apt install ghostty`, may lag the PPA). Runs natively on Wayland; the
  CSI-u/`.inputrc` notes in `SETUP-NOTES.md` are unaffected.

Resolved migration items (2026-09-30, on the fresh install):

- **Clipboard**: `bin/pbcopy` and `bin/pbpaste` use wl-clipboard under `$WAYLAND_DISPLAY` and fall
  back to xclip; the bash aliases, fzf Ctrl+Y, `bw copy` (with `--sensitive`, so Klipper skips it)
  and tmux copy-mode all go through them. tmux also sets `set-clipboard on` for OSC 52. Brewfile
  carries `wl-clipboard` instead of `xclip`.
- **Display and window scripts dropped**: `display-scale` (xrandr transform) became a per-monitor
  scale in Plasma, `window-to-screen` became KWin's built-in Window to Next Screen, and the GNOME
  dconf shortcuts, `make shortcuts`/`dump-shortcuts` and the Plank `make dock` are gone
  (see `system/README.md` for the Plasma equivalents).
- **`herdr-launch`** finds and raises the open Herdr window through KWin's window runner over
  D-Bus (`org.kde.KWin /WindowsRunner`) instead of xdotool/wmctrl, and leaves maximizing to
  Ghostty's `maximize = true`.

Open migration item — **`phpstorm-background` is X11-only.** It opens a project in PhpStorm without taking
focus by minimizing PhpStorm windows and handing focus back with `xdotool`/`xprop`, which cannot see or move
native Wayland windows. Copies live in `~/bin/phpstorm-background` (Pi's `start_ide`) and in the
`ecom-phpstorm-index` plugin's `bin/`, whose index-lookup gate calls it when PhpStorm is down. The branch
where PhpStorm already runs opens the project over the index MCP server and needs no window tool, so only a
cold start is affected. Re-test that path under Plasma before relying on it; KWin scripting is the likely
replacement for the focus handling.

No GTK stow package: Plasma's `kde-gtk-config` owns `~/.config/gtk-{3,4}.0/` (`gtk.css` imports its
`colors.css`, plus `settings.ini`), so a stowed file there breaks the Breeze colours in GTK apps.
Ghostty's tab styling rides on its own `gtk-custom-css = tab-style.css` instead.
