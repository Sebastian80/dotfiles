# Bash Completions

Custom bash completion configurations for tools not covered by system/Homebrew completions.

## Files

| File | Description |
|------|-------------|
| `bitwarden.bash` | Bitwarden CLI (bw) with shortcut support |
| `composer.bash` | PHP Composer (Symfony's official completion) |
| `dynamic.bash` | Lazy-loading completions for docker, git alias (g), npm |
| `ripgrep.bash` | Ripgrep (rg) search tool - lazy-loaded |

## Architecture

Completions are handled by multiple layers:

1. **Homebrew bash-completion** - Auto-discovers completions for installed tools (gh, bat, eza, etc.)
2. **System bash-completion** - `/usr/share/bash-completion/` (git, ssh, etc.)
3. **Custom completions** - This directory (tools needing special handling)

## Lazy-Loading Pattern

`dynamic.bash` uses the `return 124` pattern to defer loading expensive completions until first use:

```bash
_lazy_docker_completion() {
    # Load real completion
    source "$(docker completion bash)"
    # Return 124 tells bash to retry with new completion function
    return 124
}
complete -F _lazy_docker_completion docker
```

This reduces shell startup time by ~50-200ms per lazy-loaded tool.
