---
name: oro-xdebug
description: Use when debugging Oro Commerce PHP code with Xdebug in a Docker environment — enabling Xdebug in the phpfpm container, setting the XDEBUG_SESSION cookie via agent-browser, and hooking up the PhpStorm debugger MCP.
---

# Xdebug in Dockerized Oro projects

Applies to all local Oro environments (oro-6.1-dev, hmkg-6.1, hmkg, …). Xdebug is never enabled by default.

**Enable Xdebug** — via the project's compose override (file name varies per project; check for `docker-compose.xdebug.yml` or a make target like `make xdebug-enable`):
```bash
docker compose -f docker-compose.yml -f docker-compose.xdebug.yml up -d phpfpm
```

**Verify it's loaded:** `docker compose exec phpfpm php -m | grep xdebug`

**Start a debug session:**
1. Set the XDEBUG_SESSION cookie in the browser:
   ```bash
   agent-browser eval "document.cookie = 'XDEBUG_SESSION=PHPSTORM; path=/'"
   ```
2. Set a breakpoint via the PhpStorm MCP, using the project root as `project_path`:
   ```
   mcp__phpstorm-debugger__set_breakpoint
     file_path: <absolute path to file>.php
     line: <line>
     project_path: <project root>
   ```
3. Trigger the request via agent-browser, then check:
   ```
   mcp__phpstorm-debugger__get_debug_session_status
     project_path: <project root>
     include_variables: true
   ```
4. For stepping, variable inspection, and session control, follow the `jetbrains-debugger` skill.
5. Clean up breakpoints when done: `mcp__phpstorm-debugger__remove_breakpoint`.
