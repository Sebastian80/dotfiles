#!/bin/bash
# tmux command palette - comprehensive actions with keybindings

actions=(
    # Splits & Panes
    "split-horizontal                    =:tmux split-window -h -c '#{pane_current_path}'"
    "split-vertical                      -:tmux split-window -v -c '#{pane_current_path}'"
    "pane-zoom-toggle                    z:tmux resize-pane -Z"
    "pane-kill                           x:tmux kill-pane"
    "pane-break-to-window                !:tmux break-pane"
    "pane-join-from                       :tmux command-prompt -p 'Join pane from (e.g. 1.2):' 'join-pane -s \"%%\"'"
    "pane-swap-up                        {:tmux swap-pane -U"
    "pane-swap-down                      }:tmux swap-pane -D"
    "pane-mark-toggle                    m:tmux select-pane -m"
    "pane-swap-marked                     :tmux swap-pane"
    "pane-rotate                       C-o:tmux rotate-window"
    "pane-show-numbers                   q:tmux display-panes"

    # Pane Navigation
    "pane-left                           h:tmux select-pane -L"
    "pane-right                          l:tmux select-pane -R"
    "pane-up                             k:tmux select-pane -U"
    "pane-down                           j:tmux select-pane -D"
    "pane-last                           ;:tmux last-pane"
    "pane-next                           o:tmux select-pane -t :.+"

    # Pane Resize
    "pane-resize-left                    H:tmux resize-pane -L 10"
    "pane-resize-right                   L:tmux resize-pane -R 10"
    "pane-resize-up                      K:tmux resize-pane -U 5"
    "pane-resize-down                    J:tmux resize-pane -D 5"

    # Layouts
    "layout-even-horizontal            M-1:tmux select-layout even-horizontal"
    "layout-even-vertical              M-2:tmux select-layout even-vertical"
    "layout-main-horizontal            M-3:tmux select-layout main-horizontal"
    "layout-main-vertical              M-4:tmux select-layout main-vertical"
    "layout-tiled                      M-5:tmux select-layout tiled"
    "layout-next                     Space:tmux next-layout"

    # Windows
    "window-new                          c:tmux new-window -c '#{pane_current_path}'"
    "window-kill                         &:tmux kill-window"
    "window-rename                       ,:tmux command-prompt -I '#W' 'rename-window \"%%\"'"
    "window-next                         n:tmux next-window"
    "window-prev                         p:tmux previous-window"
    "window-last                          :tmux last-window"
    "window-picker                       w:tmux choose-tree -Zw"
    "window-find                         f:tmux command-prompt 'find-window -Z \"%%\"'"
    "window-move-left                     :tmux swap-window -t -1"
    "window-move-right                    :tmux swap-window -t +1"
    "window-select-0                     0:tmux select-window -t :=0"
    "window-select-1                     1:tmux select-window -t :=1"
    "window-select-2                     2:tmux select-window -t :=2"
    "window-select-3                     3:tmux select-window -t :=3"
    "window-select-4                     4:tmux select-window -t :=4"
    "window-select-5                     5:tmux select-window -t :=5"

    # Sessions
    "session-new                         S:tmux command-prompt -p 'Session name:' 'new-session -s \"%%\"'"
    "session-kill                         :tmux kill-session"
    "session-rename                      \$:tmux command-prompt -I '#S' 'rename-session \"%%\"'"
    "session-picker                      s:tmux choose-tree -Zs"
    "session-next                        ):tmux switch-client -n"
    "session-prev                        (:tmux switch-client -p"
    "session-last                         :tmux switch-client -l"
    "session-detach                      d:tmux detach"

    # Copy Mode & Buffers
    "copy-mode                           [:tmux copy-mode"
    "buffer-paste                        ]:tmux paste-buffer -p"
    "buffer-choose                       #:tmux choose-buffer -Z"
    "buffer-list                          :tmux list-buffers"
    "buffer-clear                         :tmux delete-buffer"
    "history-clear                        :tmux clear-history"
    "capture-pane                        P:tmux capture-pane -p -S -10000 > /tmp/tmux-capture.txt && tmux display 'Saved to /tmp/tmux-capture.txt'"
    "scrollback-search                   /:tmux copy-mode \\; send-keys ?"

    # Info & Config
    "show-hotkeys                        ?:~/.tmux-cheatsheet.sh"
    "show-keybindings                     :tmux display-popup -E -w 80 -h 30 'tmux list-keys | less'"
    "show-options                         :tmux display-popup -E -w 80 -h 30 'tmux show-options -g | less'"
    "show-environment                     :tmux show-environment"
    "show-messages                       ~:tmux show-messages"
    "show-pane-info                      i:tmux display-message"
    "reload-config                       r:tmux source-file ~/.tmux.conf && tmux display 'Config reloaded!'"

    # Misc
    "clock                               t:tmux clock-mode"
    "command-prompt                      ::tmux command-prompt"
    "suspend-client                    C-z:tmux suspend-client"
    "refresh-client                       :tmux refresh-client"
)

# Format for fzf: show label with keybinding
selected=$(printf '%s\n' "${actions[@]}" | cut -d: -f1 | fzf \
    --prompt="  " \
    --pointer="▶" \
    --marker="●" \
    --height=100% \
    --reverse \
    --border=rounded \
    --border-label=" tmux " \
    --border-label-pos=3 \
    --color="bg:#1e1e2e,fg:#cdd6f4,header:#f38ba8,info:#cba6f7" \
    --color="prompt:#89b4fa,pointer:#f5e0dc,marker:#f5e0dc,spinner:#f5e0dc" \
    --color="hl:#f38ba8,hl+:#f38ba8,gutter:#1e1e2e" \
    --color="selected-bg:#313244,selected-fg:#cdd6f4" \
    --color="border:#89b4fa,label:#89b4fa")

# Find and execute the matching command
if [[ -n "$selected" ]]; then
    for action in "${actions[@]}"; do
        label="${action%%:*}"
        cmd="${action#*:}"
        if [[ "$label" == "$selected" ]]; then
            eval "$cmd"
            break
        fi
    done
fi
