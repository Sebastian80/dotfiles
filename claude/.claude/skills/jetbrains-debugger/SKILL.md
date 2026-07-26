---
name: jetbrains-debugger
description: >-
  Drive a JetBrains IDE debugger over MCP — breakpoints, stepping, stack frames,
  live variable inspection and expression evaluation. USE THIS SKILL whenever
  answering would otherwise mean guessing at runtime behaviour: what a variable,
  parameter, request or context object actually holds at some point; where a good
  value turns bad between two points; the real call order; why something returns
  null/false/0/empty for one specific input; state at iteration N or for one
  record. Also whenever the user says "debug", "breakpoint", "step through",
  "inspect variable", "why is this returning X", "trace execution", or reports
  that the code, docblock or config contradicts what they actually observe.
  Reach for the debugger before reading more source and guessing — and consult
  this skill before starting a session, because a session can report success and
  never pause. Not for post-mortem log or stack-trace analysis, static analyzer
  findings, profiling, or IDE debugger settings.
---

# JetBrains Debugger MCP

Use these tools to **actually debug** applications in a JetBrains IDE rather than guessing from static code.

**Complete parameter reference:** See [references/tool-reference.md](references/tool-reference.md) for all tool parameters, types, defaults, and return schemas.

## Two debugger surfaces — know which one you are on

There may be **two** ways to drive the debugger, and they are not interchangeable:

| Surface | Shape | This skill documents |
|---|---|---|
| `mcp__phpstorm-debugger__*` | one tool per operation (`set_breakpoint`, `wait_for_pause`, …) | **yes** — every rule and return shape below |
| `mcp__phpstorm__execute_tool` with `command="xdebug_*"` | JetBrains' built-in server, dispatched through one universal tool | no |

The built-in server ships a parallel set (`xdebug_set_breakpoint`,
`xdebug_start_debugger_session`, `xdebug_get_stack`, `xdebug_evaluate_expression`
and friends). Same job, different names, different responses — the behaviours
documented here, notably the `status: "started"` trap in Critical Rule 9, were
observed on `phpstorm-debugger` and should not be assumed to transfer.

Pick one surface and stay on it for the whole session; mixing them means two
independent notions of "the current session". Use the built-in server for the
preflight below regardless, since `get_php_project_config` has no equivalent on
the other side.

## When to Use the Debugger

**USE the debugger when:**
- A bug involves runtime state (wrong values, unexpected nulls, incorrect flow)
- Reading code alone doesn't explain the behavior
- The user asks "why does X happen" or "what value does Y have"
- A test fails and the cause isn't obvious from the assertion message
- You need to verify a hypothesis about execution flow
- The user explicitly asks to debug

**DON'T use the debugger when:**
- The bug is a clear syntax error, typo, or missing import
- The fix is obvious from reading the code (e.g., off-by-one, wrong operator)
- There's no run configuration available to debug

## Core Workflow

### Standard Debugging Sequence

```
0. PREFLIGHT                        -- confirm Xdebug is actually loaded (see below)
1. list_run_configurations          -- Find a config with can_debug: true
2. set_breakpoint                   -- Set breakpoint(s) BEFORE starting
3. start_debug_session              -- Launch the debugger
4. wait_for_pause(timeout=60)       -- Block until breakpoint hit (returns full status)
5. evaluate_expression              -- Test hypotheses about values
6. step_over / step_into / step_out -- Navigate through code
7. wait_for_pause(timeout=10)       -- Wait for step to complete, get state
8. resume_execution                 -- Continue to next breakpoint
9. wait_for_pause(timeout=60)       -- Block until next breakpoint hit
10. stop_debug_session              -- Clean up when done
```

### Preflight: `can_debug: true` does not mean a breakpoint will be hit

`can_debug` reflects that a debugger is *configured* for the interpreter
(`debugger_id="php.debugger.XDebug"`). It says nothing about whether Xdebug is
*installed* on the PHP that will actually run. When it isn't, `start_debug_session`
still answers `{"status":"started"}`, the process runs to completion without
pausing, and the only trace is `Xdebug not found among available debuggers` in
`idea.log`, where you will not think to look.

Ask the IDE directly, via the JetBrains built-in MCP server:

```
mcp__phpstorm__execute_tool  command="get_php_project_config"  projectPath=<root>
```

One call returns the selected interpreter (including whether it is a container),
the real PHP version, every loaded extension, and a `debuggers` array. If `xdebug`
is absent from `loadedExtensions`, stop and fix that first — no breakpoint will
ever be hit.

Do **not** try to answer this from `.idea/php.xml`. PhpStorm buffers settings and
flushes them lazily, so the file lags the live state: a project with a correctly
selected interpreter can show no `interpreter_name` on disk at all.

If that MCP server isn't connected, you cannot preflight — fall back to detecting
the failure after the fact (Critical Rule 9).

**Container interpreters (DDEV, Docker Compose).** A run configuration bound to the
host PHP is the common trap: the container has Xdebug and the host does not, so
everything looks configured and nothing ever pauses. `homePath` starting
`docker-compose://` confirms the interpreter is the container one. Getting there
needs the DDEV Integration plugin (or a hand-made Docker Compose interpreter),
`ddev xdebug on`, and the project's default CLI interpreter switched to it in
Settings → PHP. The IDE reports `isRemote: true` when it is right.

### Critical Rules

1. **Set breakpoints BEFORE starting the session.** Breakpoints can be set without an active session. Setting them first ensures the program pauses where you need it.

2. **After `resume_execution` or any step command, use `wait_for_pause` to block until the session pauses.** It returns the full session status (variables, stack, source, location) when the pause occurs — no polling needed. Step/resume commands return immediately with `newState: "running"` and do NOT wait for the program to pause.

3. **Use `get_debug_session_status` to re-inspect state without waiting.** It returns variables, stack trace, source context, and current location in ONE call. Do NOT call `get_variables`, `get_stack_trace`, and `get_source_context` separately unless you need specific parameters (e.g., a different frame index or more context lines).

4. **Line numbers are 1-based.** When setting breakpoints or using `run_to_line`, use the line numbers as they appear in the editor (starting from 1).

5. **File paths must be absolute.** For `set_breakpoint`, `run_to_line`, and `get_source_context`, always use absolute file paths (e.g., `/Users/dev/project/src/Main.java`).

6. **`session_id` is optional for single-session debugging.** When only one debug session exists, all tools auto-select it. Only specify `session_id` when multiple sessions are active.

7. **`project_path` is required when multiple projects are open.** If omitted with multiple projects, tools return an error listing available projects.

8. **`evaluate_expression` may be safety-filtered by IDE settings.** If a call is blocked, prefer `get_variables`, simple field/arithmetic expressions, or a narrower expression that avoids method calls and risky APIs. Do not retry blocked process, filesystem, network, reflection, native-loading, or environment/system-property operations unless the user explicitly changes the IDE setting.

9. **`status: "started"` is not a live session.** `start_debug_session` returns `{"status":"started","state":"running"}` even when the process dies on launch — for example when the run configuration's interpreter has no Xdebug (the IDE logs `Xdebug not found among available debuggers` and the session is gone before you can attach). The tell is `isCurrent` on the returned session: `false` means it never became the active session. Confirm with `wait_for_pause`, or `list_debug_sessions` — an empty list means dead, not idle. When a session dies this way, the interpreter is the first thing to check, not the breakpoint.

## Debugging Patterns

### Pattern: Find Why a Value is Wrong
```
1. set_breakpoint at the line where the wrong value is used
2. start_debug_session with the appropriate run configuration
3. wait_for_pause(timeout=60) -- blocks until breakpoint hit, returns full status
4. Inspect variables in the response -- the wrong value and its inputs are visible
5. evaluate_expression to test alternative calculations
6. If the value was already wrong here, set_breakpoint earlier in the call chain
7. resume_execution, then wait_for_pause(timeout=60) -- repeat
```

### Pattern: Debug a Specific Loop Iteration
```
1. set_breakpoint with condition (e.g., condition: "i == 50")
2. start_debug_session
3. wait_for_pause(timeout=120) -- debugger runs at full speed until condition is true
4. Inspect variables in the response -- state at exactly iteration 50
```

### Pattern: Trace Execution Without Stopping
```
1. set_breakpoint with log_message and suspend_policy: "none"
   Example: log_message: "Entering process() with id={id}, count={items.size()}"
2. start_debug_session
3. resume_execution
4. Check IDE console output for trace log -- execution never pauses
```

### Pattern: Inspect a Different Stack Frame
```
1. get_debug_session_status -- see the stack summary
2. select_stack_frame with the frame_index of interest (0 = current, 1 = caller, etc.)
3. get_variables -- now shows variables from the selected frame
4. evaluate_expression -- expressions evaluated in the selected frame's context
```

### Pattern: Test a Fix Without Restarting
```
1. Pause at the point of interest
2. evaluate_expression with the corrected logic to verify it produces the right result
3. set_variable to inject the correct value
4. resume_execution to see if the fix resolves the downstream issue
```

## Common Mistakes to Avoid

| Mistake | Correct Approach |
|---------|-----------------|
| Calling `get_variables` + `get_stack_trace` + `get_source_context` separately | Use `get_debug_session_status` -- returns all three in one call |
| Starting debug session without setting breakpoints first | Set breakpoints BEFORE `start_debug_session` |
| Assuming `step_over` returns the new state | Call `wait_for_pause` after stepping to block until paused and get the new state |
| Using 0-based line numbers | Line numbers are **1-based** (as shown in the editor) |
| Using relative file paths | Always use **absolute** file paths |
| Not waiting after `resume_execution` | Use `wait_for_pause` to block until the next breakpoint is hit |
| Calling `evaluate_expression` with method calls in Rust/C++/Go | Use `get_variables` for native languages; method calls may fail in LLDB/GDB |
| Retrying an `evaluate_expression` blocked by safety settings | Use `get_variables` or a simpler read-only expression; blocked categories are controlled by the user in IDE settings |
| Treating `start_debug_session`'s `status: "started"` as proof a session is live | Check `isCurrent` on the returned session, then `wait_for_pause` / `list_debug_sessions` |
| Guessing variable values from source code | Use the debugger to inspect actual runtime values |
| Forgetting to `stop_debug_session` when done | Always clean up debug sessions |

## Language-Specific Notes

### Full Support (Java, Kotlin, Python, JavaScript, TypeScript, PHP, Ruby)
- All tools work as documented
- `evaluate_expression` supports method calls, field access, arithmetic
- `set_variable` works for all types including objects and strings

### Limited Support (Rust, C++, C, Go, Swift)
These use native debuggers (LLDB/GDB) with restrictions:
- `evaluate_expression`: Variable inspection works, but method calls (e.g., `s.len()`, `vec.size()`) may fail
- `set_variable`: Works for primitives (int, float, bool). Complex types (String, Vec, structs) may fail
- **Workaround:** Use `get_variables` to inspect values instead of `evaluate_expression` with method calls

## Tool Quick Reference

| Tool | Purpose | Requires Paused |
|------|---------|:---:|
| `list_run_configurations` | Find debuggable configurations | No |
| `execute_run_configuration` | Run or debug a configuration | No |
| `start_debug_session` | Start debugging | No |
| `stop_debug_session` | End debugging | No |
| `list_debug_sessions` | See active sessions | No |
| `get_debug_session_status` | **Primary inspector** -- variables, stack, source, location | No (but most useful when paused) |
| `set_breakpoint` | Set line breakpoint (with optional condition/log) | No |
| `remove_breakpoint` | Remove a breakpoint | No |
| `list_breakpoints` | See all breakpoints | No |
| `resume_execution` | Continue running | **Yes** |
| `wait_for_pause` | Block until session pauses, return full status | No |
| `pause_execution` | Pause running program | No (must be running) |
| `step_over` | Next line (skip into functions) | **Yes** |
| `step_into` | Enter function call | **Yes** |
| `step_out` | Finish current function | **Yes** |
| `run_to_line` | Run to specific line | **Yes** |
| `get_stack_trace` | Full call stack | **Yes** |
| `select_stack_frame` | Change frame context | **Yes** |
| `list_threads` | See all threads | **Yes** |
| `get_variables` | Variables in current frame | **Yes** |
| `set_variable` | Modify a variable at runtime | **Yes** |
| `get_source_context` | Source code around a location | No |
| `evaluate_expression` | Evaluate any expression | **Yes** |
