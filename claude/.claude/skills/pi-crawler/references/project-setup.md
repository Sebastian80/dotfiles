# Enabling a project for the crawler

pi is configured once, globally: `~/.pi/agent/settings.json` loads `pi-mcp-adapter`, and
`~/.pi/agent/agents/crawler.md` is the agent. What is per project is the MCP server config.

pi does NOT read Claude Code's `~/.claude.json`, so the `phpstorm-index` server Claude uses is
invisible to it. pi merges six sources, later winning: `~/.config/mcp/mcp.json`,
`~/.agents/mcp.json`, `~/.agents/mcp/mcp.json`, `~/.pi/agent/mcp.json`, the cwd's `.mcp.json`,
and `<project>/.pi/mcp.json`.

Write `<project>/.pi/mcp.json`:

```json
{
  "settings": { "toolPrefix": "none" },
  "mcpServers": {
    "phpstorm-index": {
      "type": "http",
      "url": "http://127.0.0.1:29175/index-mcp/streamable-http",
      "directTools": true,
      "includeTools": [
        "ide_project_status", "ide_index_status",
        "ide_find_implementations", "ide_find_references", "ide_find_definition",
        "ide_find_super_methods", "ide_type_hierarchy", "ide_call_hierarchy",
        "ide_find_class", "ide_find_symbol", "ide_find_file", "ide_symbol_info",
        "ide_file_structure", "ide_search_text", "ide_read_file", "ide_diagnostics"
      ]
    },
    "symfony-ai-mate": {
      "command": "docker",
      "args": ["compose", "run", "--rm", "--no-deps", "-T", "mate"],
      "directTools": true,
      "toolPrefix": "none"
    }
  }
}
```

Then keep it out of the repo: `printf '.pi/\n' >> <project>/.git/info/exclude`.

Why each piece:

- `settings.toolPrefix: "none"` sits at the TOP level, not only per server. A per-server prefix is
  ignored for children (pi-subagents 0.67 bug), and the child then looks for
  `symfony-ai-mate_oro_service_list` and fails with "required MCP tools were unavailable".
- The Mate entry reuses the project's own server key, so it overrides the entry Mate's composer
  plugin wrote into `.mcp.json` for pi only, leaving Claude's config untouched. A different key
  would load both and register every `oro_*` tool twice.
- `--no-deps` means a Mate call reads the compiled container without starting the stack. Without
  it, a code question can boot containers.
- The IDE server carries `includeTools` because the full server also exposes refactoring and file
  creation. Mate has no `includeTools`: all 36 tools are wanted, including SQL and logs.
- Omit `lifecycle: eager` here. The crawler home used it to hide first-call latency, but in a
  shared project config it starts a Mate container for every pi session in that directory.

Non-Oro projects: leave the `symfony-ai-mate` entry out. The agent names it in its `tools:` list,
so verify a crawl there before relying on it.
