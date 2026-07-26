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

**A green answer here is necessary but not sufficient on container interpreters.**
PhpStorm caches remote `phpinfo` and does not revalidate it when the container
changes underneath. Measured on 2026-07-26: with Xdebug provably off — `ddev xdebug
status` disabled, `php -m` showing no xdebug, `20-xdebug.ini` not present on disk —
`get_php_project_config` still reported `xdebug` in `loadedExtensions`,
`20-xdebug.ini` among the ini files, and `debuggers: [xdebug 3.5.3]`. Every field
stale, every field confident. A session started on that basis returns
`isCurrent: true`, passes the Rule 9 tell, and runs to completion without pausing.

So for a container interpreter, confirm against the container itself:

```bash
ddev xdebug status          # or: ddev exec XDEBUG_MODE=off php -m | grep -i xdebug
```

That is ground truth. `idea.log` is not a fallback either — its "Xdebug not found
among available debuggers" line can be hours old and refer to a previous run.

Ask the IDE rather than reading project files, because the answer is split across
two of them and it is easy to read the wrong half:

| What | Where |
|---|---|
| *Which* interpreter the project selected | `.idea/workspace.xml` → `<component name="PhpWorkspaceProjectConfiguration" interpreter_name="…">` |
| What that interpreter *is* (path, container, debugger id) | `.idea/php.xml` → `<interpreter name="…" home="…">` |

A checker that looks for `interpreter_name` in `php.xml` finds nothing and reports
"no interpreter selected" for a project that is configured correctly and debugging
fine. One such script was written and deleted on 2026-07-26 for exactly that.

Two neighbouring traps worth knowing when breakpoints misbehave:

- **Path mappings, not `DOCKER_REMOTE_PROJECT_PATH`, bind breakpoints.** A DDEV
  interpreter can record `DOCKER_REMOTE_PROJECT_PATH="/opt/project"` while the
  active mapping is `$PROJECT_DIR$ → /var/www/html`. The mapping wins and matches
  the real mount. If a verified breakpoint never binds, check the mappings first.
- **Static analysis and debugging can run on different PHPs.** Here PHPStan and
  Psalm point at the host `/home/linuxbrew/.linuxbrew/bin/php` (8.5, no Xdebug)
  while the debugger and tests use the container's 8.3. Neither is wrong; just
  don't infer one interpreter's extensions from the other's.

**Xdebug on + IDE listening makes shell PHP hang.** With `xdebug.start_with_request=yes`
(DDEV's default once Xdebug is enabled) *every* CLI PHP process opens a DBGp session
against the listening IDE. A plain `ddev exec php -m` or `docker exec … php -v` then
blocks until it times out, and leaves a paused session named `stdin` behind — each of
which holds its process. Symptoms: shell one-liners mysteriously taking >60 s, and a
growing list in `list_debug_sessions` that you did not start.

Workaround for a one-off: `ddev exec XDEBUG_MODE=off php -m`.

Permanent fix — drop this in `.ddev/php/zzz-xdebug-trigger.ini` (the name must sort
after DDEV's own `20-xdebug.ini` so it wins):

```ini
xdebug.start_with_request=trigger
```

Xdebug then connects only when `XDEBUG_TRIGGER`/`XDEBUG_SESSION` is present. IDE
debugging is unaffected because PhpStorm passes its own
`-dxdebug.start_with_request=yes` on the command line when it launches a run
configuration; browser debugging still works via the cookie. Verified on this stack:
after the change `ddev exec php -v` runs in 0.48 s with no workaround, and a
breakpoint in the PHPUnit bootstrap still pauses.

If `list_debug_sessions` shows stray paused `stdin` entries, they are this — stop
them to free the processes.

**`ddev xdebug on` does not survive `ddev restart`.** It is a runtime toggle;
`.ddev/config.yaml` ships `xdebug_enabled: false`, so any restart silently turns
Xdebug back off and you are back to sessions that start and never pause. If a
setup that worked an hour ago stops pausing, check `ddev xdebug status` before
anything else. Set `xdebug_enabled: true` in `config.yaml` to make it stick, at the
cost of a permanent performance hit.

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

### `wait_for_pause` can hand you someone else's breakpoint

A pause is not necessarily *your* pause. Any other breakpoint in the project —
left by a colleague, an earlier run, or a concurrent agent — stops the same
process, and `wait_for_pause` returns that frame. Its variables look entirely
plausible: a stray breakpoint in a PHPUnit bootstrap yields `$this`, `$_ENV` and
`$_SERVER`, which is exactly the shape of a real answer. Reading them as though
they were your target produces a confident, wholly fabricated result.

Two defences, cheap and worth doing every time:

- Compare `breakpointHit.breakpointId` in the response against the id
  `set_breakpoint` gave you. Different id → resume and keep waiting.
- Or pass `breakpoint_ids: ["<your id>"]` to `wait_for_pause`, which auto-resumes
  non-matching pauses for you.

`list_breakpoints` before starting also tells you what else is armed. Remove only
ids you created — someone else's breakpoints are not yours to clear.

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
