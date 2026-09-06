# fzf Configuration

```
~/.config/fzf/config             # Shell-agnostic options, loaded via FZF_DEFAULT_OPTS_FILE
~/.bash/exports/fzf.bash         # Bash integration: Ctrl+T / Ctrl+R / Alt+C, previews with bat/eza
```

`FZF_DEFAULT_OPTS_FILE` is exported in `bash/.bash/exports/fzf.bash`, so `config` is the place for
layout, borders, colours and key bindings. Mode-specific options (`FZF_CTRL_T_OPTS` and friends) and
anything that needs shell logic stay in the bash export.

Reload after editing: `exec bash`.
