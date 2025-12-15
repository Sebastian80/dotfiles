-- Yazi Plugin Initialization
-- This file runs synchronously on startup

-- ========================================
-- Zoxide Integration (built-in)
-- ========================================
-- Adds visited directories to zoxide database automatically
-- Press 'z' to open zoxide interactive search
require("zoxide"):setup {
    update_db = true,  -- Update zoxide database when navigating
}

-- ========================================
-- Oh-My-Posh Header Integration
-- ========================================
-- Displays oh-my-posh prompt in yazi header
-- Uses your existing oh-my-posh theme
require("omp"):setup()
