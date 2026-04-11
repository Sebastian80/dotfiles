# Claude Code Usage

## Task tracking

- Use the task tools (TaskCreate, TaskUpdate, TaskList, TaskGet) to track your work
- NEVER mark tasks as completed until the work is actually done and verified
- NEVER delete tasks without Sebastian's explicit approval

## MCP / Deferred Tools

- ToolSearch keyword results only load the tools actually returned — not all tools in the same namespace
- If the tool you need wasn't in the keyword search results, use `ToolSearch select:<exact_tool_name>` before calling it
- Never call an MCP tool you haven't explicitly confirmed was loaded
