#!/bin/bash
cat << 'EOF'

    TMUX CHEAT SHEET (Ctrl+B)
    ─────────────────────────────────────────

    SPLITS                 PANES
    =  horizontal          h/j/k/l  navigate
    -  vertical            H/J/K/L  resize
                           z        zoom

    WINDOWS                SESSIONS
    c    new               s  picker
    n/p  next/prev         S  new session
    0-9  select            d  detach

    Alt+1-9  quick window switch (no prefix)
    r  reload config    /  search scrollback

EOF
read -n 1 -s -r -p "    Press any key to close..."
