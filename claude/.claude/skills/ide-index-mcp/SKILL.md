---
name: ide-index-mcp
description: "MANDATORY for all code navigation and refactoring. You MUST invoke this skill whenever: finding where a function/method/class is called or used ('find usages of X', 'who calls X', 'where is X used'), going to a definition ('where is X defined', 'take me to X'), renaming any symbol, finding implementations of an interface or abstract class, tracing call hierarchies ('what calls X', 'what does X call'), checking file structure or class methods, checking errors/warnings/diagnostics in a file, finding classes/symbols by name, searching text or config values project-wide ('search the project for X', service ids, YAML keys, TODOs), type/inheritance hierarchies, syncing IDE after external file changes, reformatting code, or managing IDE projects (multi-project, sleep/wake, Power Save). Do NOT skip this and use Grep/Glob instead. If a user mentions any class name, method name, or symbol and wants to navigate to it, find its usages, rename it, or understand its relationships, this skill MUST be consulted first."
---

# IDE Index MCP - Agent Guide

The IDE Index MCP server exposes JetBrains IDE (IntelliJ, PyCharm, PhpStorm, WebStorm, etc.) indexing and refactoring capabilities. These tools provide **semantic** code understanding — types, inheritance, references, call chains — that text-based tools cannot.

## Core Rule

**Use IDE MCP tools as your primary search, navigation, and refactoring tools.** JetBrains indexes ALL project files — code, config, YAML, Markdown, etc. — so prefer `ide_search_text` and `ide_find_file` even for non-code searches. Fall back to Grep/Glob only for files outside the project, or when IDE Index is unavailable — `ide_search_text` now handles regex itself (see below).

**Availability:** the server only exists while the IDE is running. If no `ide_*`/`mcp__phpstorm-index__*` tools are present in the session, the IDE is closed — use the standard tools without ceremony and NEVER ask the user to launch the IDE for it. If tools were present but a call fails mid-session, check `ide_index_status` once, then fall back. A call that *succeeds* but comes back empty is a different case entirely — see [Before you trust a result](#before-you-trust-a-result).

The IDE understands your code structurally. Grep sees text. When you need to find usages, trace calls, navigate definitions, rename symbols, check inheritance, or find implementations — always reach for an IDE tool first.

**The tool list is not documented here.** Each `mcp__phpstorm-index__*` tool carries its own
description, parameters and examples, and that is the authoritative surface — it changes when
the plugin updates or you enable tools in Settings → Tools → Index MCP Server → **Exposed Tools**
(its own child page since plugin 5.9.3; the main page keeps port, history, projects and lifecycle).
A table in this file can only go stale: one here once listed 37 tools while the server served 45.
Read the tool schemas; this file covers what they don't say.

**A tool the server withholds and one it never registered are indistinguishable** — both answer
`Tool <name> not found`. The disabled set persists application-wide in
`~/.config/JetBrains/<Product><Version>/options/mcp-plugin.xml` under `disabledTools`, so read that
file to tell the two apart; toggle in the UI, since the running IDE rewrites it on exit.

## Before you trust a result

An IDE tool that returns *successfully* has not necessarily answered your question.

**An empty result is only an answer for a project the IDE actually has open.** A query made from
a working directory whose project is closed gets answered by whichever project *is* open, and
comes back `{"symbols":[],"totalCount":0,"stale":false}` — indistinguishable from "the symbol does
not exist". `stale:false` does not mean authoritative. Before believing any empty semantic result,
check that `ide_project_status` lists your working directory.

**This state arrives on its own.** Lifecycle management closes an idle managed project after
~10 minutes, so a project you opened earlier in the session can be shut behind you, re-arming the
trap mid-task with nothing having changed on your side.

**With exactly one project open there is no error to warn you.** `multiple_projects_open` only
fires with two or more; a single open project answers silently from the wrong index. So run
`ide_project_status` first, not after a surprising zero.

**`ide_open_project` blocks until indexed** and on a large repo will exceed the MCP client timeout,
reporting failure for a call that is still succeeding. Confirm with `ide_project_status` rather
than retrying.

## Writes: when an IDE tool beats Edit

Use an IDE write when the change has consequences **beyond the file** — that is what the IDE knows
and `Edit` does not:

- `ide_change_signature` — updates every call site
- `ide_refactor_rename` — updates every reference
- `ide_move_file` — fixes PSR-4 namespace and imports
- `ide_structural_search_replace` — AST-aware, so it will not match inside comments or strings
- `ide_optimize_imports` / `ide_reformat_code` — apply project code style

`ide_edit_member`, `ide_insert_member` and `ide_replace_member` look like the structural way to do
exactly this, and are **Java/Kotlin only**: PhpStorm exposes all three, and every PHP file gets
*"Member editing not supported for PHP. Supported: Java, Kotlin."* Don't route PHP edits through
them — `Edit`, or `ide_change_signature` when call sites must follow.

For a local text change with no such consequence, `Edit` is the right tool and the cheaper one:
`ide_create_file` and `ide_replace_text_in_file` take an arbitrary path, so they bypass the path-based
deny rules that protect `Edit` and are judged by the auto-mode classifier instead.

## Project Lifecycle & Multi-Project

One MCP server per IDE **process**; all projects open in that process are served over the same port and routed via `project_path`. Lifecycle management auto-sleeps and wakes projects to keep many of them open cheaply.

**Ports are fixed per IDE product, never per project or window** (index: PhpStorm 29175, IntelliJ 29170, PyCharm 29172, WebStorm 29173; debugger: same scheme at 29190+, PhpStorm 29195). A second process of the SAME product fails with "Port already in use" — it needs a manual port change (Settings → Tools → Index MCP Server) plus its own MCP registration under a different name; the supported model is one process with several project windows, not several processes. Different IDE products coexist without conflict.

**Git worktrees:** `project_path` resolves only against open projects (exact root → module content root → subdirectory). A worktree path that isn't opened in the IDE returns PROJECT_NOT_FOUND — open the worktree as its own project, or pass the indexed main checkout's path.

| Tool | What it does | Key params |
|------|-------------|------------|
| `ide_project_status` | One table of every open + managed project with its mode — **start here for any multi-project question** | (none required) |
| `ide_open_project` | Open a project by absolute path, **blocks until indexed** (default timeout 600 s) | `path`, `timeoutSeconds` |
| `ide_close_project` | Close a project window (non-blocking); refuses to close the last open project | `project_path` |
| `ide_enroll_all_projects` | Enroll all open projects in lifecycle management (already-managed skipped) | (none required) |
| `ide_get_project_modes` | List managed projects with current mode | (none required) |
| `ide_set_project_mode` | Set one project's mode: `active` / `background` / `dormant` / `closed` | `mode`, `project_path` |
| `ide_set_all_project_modes` | Set mode for all managed open projects (`closed` not allowed here) | `mode` |
| `ide_release_project` | Unenroll one project from lifecycle management (accepts `path` for closed ones) | `path` or `project_path` |
| `ide_release_all_projects` | Unenroll everything, disable Power Save | (none required) |
| `ide_set_power_save_mode` | IDE-wide Power Save on/off (inspections off, index + MCP stay functional) | `enabled` |
| `ide_lifecycle_log` | Last ≤500 lifecycle events (open/close/transition/enroll/release/wake + trigger) — diagnose unexpected sleeps/closes | `limit`, `project` |
| `ide_set_lifecycle_log_file` | Toggle writing lifecycle events to a tail-able log file (ring buffer always on) | `enabled` |
| `ide_reload_project` | Force-reload linked **Maven/Gradle** build models (JVM projects only — no-op for pure PHP) | (none required) |
| `ide_restart` | Restart the IDE — **kills this MCP server; must be the final call** | (none required) |
| `ide_install_plugin` | Install a plugin zip (defaults to the project's `build/distributions/*.zip`); needs `ide_restart` after | `path` |

**Lifecycle modes** (managed projects move automatically): `active` (full IDE, Power Save off) → `background` (Power Save on, index + MCP fully functional — the default while MCP works) → `dormant` (editors closed, PSI cache freed; after ~2 min MCP inactivity) → `closed` (fully unloaded; after ~10 min inactivity). Any MCP call **auto-wakes** the project — a call against a `closed` managed project auto-reopens it with a 5–15 s delay, so a slow first response after idle time is normal, not an error. Waking is **user-visible**: the IDE opens the project window again, exactly as if it had been picked from Recent Projects (verified — one `ide_index_status` call carrying a closed project's `project_path` put a second PhpStorm window on screen). So a routine tool call can rearrange the user's desktop. With two managed projects the pair oscillates: whichever you touch wakes, the other drifts `dormant` → `closed`, which is what keeps producing the single-open-project state. `ide_release_project` takes one out of lifecycle management and stops it.

**Multi-project workflow:**
1. `ide_project_status` first — see what's open, managed, and in which mode.
2. With more than one project open, pass `project_path` (absolute project root) on **every** call — omitting it returns an error listing the candidates. For workspace projects use the sub-project path.
3. With exactly one project open there is no disambiguation error and a query from the wrong working directory is answered silently — see [Before you trust a result](#before-you-trust-a-result). If `ide_project_status` doesn't list your working directory, `ide_open_project` it rather than falling back to Grep/rg on a false negative. A call carrying `project_path` for a managed-but-closed project auto-wakes it (5–15 s), so an explicit open is only needed for a project the IDE has never had open.
4. Enrollment is automatic on the first real semantic call per project; `ide_enroll_all_projects` only needed to opt in projects you haven't touched yet.
5. Don't micro-manage modes — the lifecycle handles sleep/wake. Set modes explicitly only to pre-warm (`background`) before a batch, or to free memory now (`dormant`/`closed`).
6. `ide_open_project` on a never-before-opened project can hang on the modal "Trust project?" dialog only a human can answer — if it times out, ask the user.
7. If a project closed or slept unexpectedly, read `ide_lifecycle_log` before assuming a bug.

## Two JetBrains MCPs — routing rule

When both this plugin (`mcp__phpstorm-index__*` / `mcp__intellij-index__*`) and the JetBrains built-in server (`mcp__phpstorm__*` / `mcp__intellij__*`) are connected, they are **not interchangeable**:

| Need | Use |
|------|-----|
| Code navigation, search, diagnostics, rename, move, run tests | index plugin (`*-index`) |
| Terminal, running non-test processes, Symfony service lookup (`locate_symfony_service`) | built-in server only |

The built-in server is **not a fallback** for the index plugin: it cannot do semantic code search, and during dumb mode it fails the same way. Dumb mode / stale index are transient — wait and retry the index plugin, or use the Grep/rg fallbacks below; don't reroute to the built-in server.

## When to use built-in tools instead

- **Regex pattern matching** → `ide_search_text` with `regex: true` + optional `filePattern` (in-project regex no longer needs `Grep`; routes through IntelliJ Find in Files)
- **Finding files by extension/path glob pattern** → `Glob` (e.g. `**/*.py`, `src/**/*.yaml`)
- **Files outside the project root** → `Grep`/`Glob` (IDE indexes project + libraries; for paths beyond both, use Grep)
- **Reading project file content** → `Read` (`ide_read_file` is for library/jar sources)
- **Code in IDE-excluded folders** → `rg -uu <path>` (peels off `.gitignore` and hidden-file filters; `-uuu` also searches binaries). The IDE MCP returns nothing for explicitly-excluded paths regardless of `scope`. Typical case: a heavyweight `vendor/<thing>/*` excluded for IDE perf — `rg -uu vendor/oro` etc.

## Pre-Flight

If an IDE tool fails unexpectedly, check `ide_index_status`. When `isDumbMode: true`, the IDE is still indexing — wait and retry. Tools that work in dumb mode: `ide_index_status`, `ide_sync_files`, `ide_reformat_code`, `ide_open_file`, `ide_get_active_file`.

## File Sync

After creating or modifying files outside the IDE (via Write/Edit), call `ide_sync_files` before using search tools. Omit `paths` to sync the entire project.

## Parameter Essentials

1. **Line and column are 1-based** (first line = 1, first column = 1)
2. **File paths are relative** to project root — never absolute. Exception: when a tool *returns* an absolute path or `jar://` URL for a library/dependency file (e.g. under `vendor/`), pass it back **unchanged** to read-only navigation tools or `ide_read_file` — rewriting it to a relative path breaks library navigation.
3. **Column must point to the first character of the symbol name** — not keywords (`def`, `class`, `function`), whitespace, or punctuation. A wrong column silently resolves to the wrong symbol.
4. **project_path** — required on every call when multiple projects are open in the IDE instance (absolute project root; sub-project path for workspace projects); omit with a single project
5. **Default `scope: project_and_libraries`** for every tool that accepts a `scope` parameter (`ide_find_class`, `ide_find_file`, `ide_find_symbol`, `ide_find_references`, `ide_find_implementations`, `ide_type_hierarchy`, `ide_call_hierarchy`). The MCP server defaults to `project_files`, which covers only what the IDE classifies as project source roots. Whether that includes `vendor/` / `node_modules/` is **project-dependent**: when they're marked as External Libraries or Excluded (common in Symfony/Node setups) `project_files` silently omits them; when they're configured as content/source roots — as in Magento, which indexes `vendor/` as source — they're included. Since you usually can't tell which applies, default to `project_and_libraries` (a superset) so dependency code is never silently missed. Only narrow to `project_files` when you specifically want to exclude libraries; use `project_production_files` / `project_test_files` for test-aware filtering.
6. **`language`+`symbol` form is supported for PHP** on five tools: `ide_find_references`, `ide_find_definition`, `ide_find_implementations`, `ide_find_super_methods`, `ide_call_hierarchy`. In PhpStorm the only accepted `language` is `PHP`; pass a fully-qualified `symbol` instead of `file`+`line`+`column` — e.g. `\App\Service\UserService::find()`, `::$property` for properties, `::CASE` for enum cases (see [tools-reference.md](references/tools-reference.md) for full PHP symbol syntax). **`ide_refactor_rename` does NOT accept symbol mode** — it needs `file`+`line`+`column`. Name/query tools (`ide_find_symbol`, `ide_find_class`, `ide_type_hierarchy` with `className`) work across languages including PHP.

To get exact positions, use `ide_find_class` or `ide_file_structure` first, then place the column on the symbol name's first character.

## Tool Selection by Task

### Understanding how X is used
1. `ide_find_references` — all call sites, field accesses, imports
2. `ide_call_hierarchy` with `direction: "callers"` — full call chain upward

### Understanding what X is
1. `ide_symbol_info` — resolved signature and doc comment without reading the file. In PHP it
   degrades to the raw declaration line (`parameters`, `returnType`, `visibility` all null), and the
   `symbol` form wants `\App\Entity\Plant::getName` — not the `#` syntax its own schema shows.
2. `ide_find_definition` — jump to source
3. `ide_type_hierarchy` — inheritance chain (prefer `file`+`line`+`column` over `className`)
4. `ide_find_super_methods` — what interface/base method it implements

### Finding a class/file/symbol
1. `ide_find_class` — classes by name (supports CamelCase: `USvc` → `UserService`)
2. `ide_find_symbol` — any symbol (classes, methods, fields, functions)
3. `ide_find_file` — files by name
4. `ide_search_text` — word occurrences across project (`regex: true` for patterns)

**CamelCase caveat:** matching is reliable for **capital-initial** queries (`CSRM` → `CarrierServiceResponseMapper`), but mixed-case multi-segment abbreviations (`CarSvcRespMap`) silently return zero even when a class matches. When a CamelCase guess comes back empty, retry with just the capital initials or a plain substring before assuming the class doesn't exist.

### Refactoring
1. Before renaming, run `ide_search_text` on the old name — semantic references miss call sites in dynamic dispatch (`__call` decorators) and string expressions in config/templates (e.g. Oro `layout.yml` `'=data[...].method(...)'` — functional call sites a rename silently breaks). The text sweep tells you up front which stragglers need manual Edit.
2. `ide_refactor_rename` — rename a symbol + all references atomically (`file`+`line`+`column`+`newName`). Omit `line`/`column` to rename the **file** itself (updates references; works for any file type).
3. After rename, **verify with `ide_search_text`/Grep** for the old name — expect 0 matches. Fix stragglers with Edit, then `ide_sync_files`.
4. `ide_move_file` — relocate a file; IDE updates namespace/imports where a semantic backend exists (PHP PSR-4 aware)
5. `ide_optimize_imports` — strip unused imports + organize the rest (no reformatting)
6. `ide_reformat_code` — apply project code style

### Checking for problems
1. `ide_diagnostics` — one file: errors, warnings, and the quick fixes available at a position
2. `ide_project_diagnostics` — many files or the whole project. It carries a fail-closed coverage
   contract the single-file tool does not: an empty `problems` list is a clean signal **only** when
   `complete: true`. Check that flag and `incompleteFiles` before reporting "no problems".
3. `ide_build_project` — full project build to surface compilation/type errors

### Finding implementations
1. `ide_find_implementations` — cursor on interface/abstract class/method

### Tracing call chains
1. `ide_call_hierarchy` with `direction: "callers"` — who calls this?
2. `ide_call_hierarchy` with `direction: "callees"` — what does this call?
3. Cursor must be on the method/function name on its declaration line. Use `ide_file_structure` to find the exact line first.
4. If the IDE returns empty callers but you know callers exist, fall back to Grep.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| "No method/function found at position" | Cursor isn't on a method name on its declaration line. Use `ide_file_structure` to find the right line and column. |
| `ide_find_definition` returns wrong symbol | Column is off. Read the line, count to the exact first character of the symbol. |
| Tool returns empty/stale results after file changes | Call `ide_sync_files`, then retry. |
| Tool errors unexpectedly | Check `ide_index_status` — IDE may be in dumb mode (indexing). Wait and retry. |
| `ide_call_hierarchy` returns element but zero callers | Known limitation for some language constructs. Fall back to Grep. |
| `ide_refactor_rename` misses some references | Language-specific limitation. Grep for the old name, fix remaining with Edit. |
| `ide_find_implementations` returns empty for structural types | Some languages use structural typing (e.g. Python Protocols) which IDE can't resolve. Use Grep with class name pattern. |
| `ide_find_references` times out | Huge reference fan-out (e.g. a core vendor class used platform-wide). Narrow to `scope: project_files` for the first-party answer, or switch to `ide_search_text` with a `filePattern` mask. |
| Freshly opened project returns empty for EVERYTHING despite `ide_index_status` ready | The project has no configured content/source roots (never set up in this IDE — common for ad-hoc opened repos). The index has nothing to serve; fall back to `rg` on disk, or configure source roots in the IDE. |
| Tool returns empty for a class/file you can see on disk in `vendor/`/library | Folder is in the IDE's Excluded list (Settings → Directories → right column). The `scope: project_and_libraries` parameter doesn't override this — exclusion wins at the index level. Either remove the exclusion (re-indexes the folder), or fall back to `rg -uu <path>` for that subtree. Verify by running `ide_find_class` on a class you know exists in the folder. |
| `ide_find_definition`/`ide_find_references` don't follow Symfony service-YAML ↔ class links | Known index-plugin gap (resolves only the primary `getReference()`, not the IDE's provider-based Go-to-Declaration). Use the **JetBrains MCP Server's `locate_symfony_service`** instead, or `ide_search_text`. See [Framework DI / YAML navigation](#framework-di--yaml-navigation-symfony-etc). |

## Framework DI / YAML navigation (Symfony, etc.)

`ide_find_definition`/`ide_find_references` follow only a symbol's *primary* reference — provider-contributed references (Symfony service-YAML ↔ PHP class links) are invisible to them even though Ctrl+B in the GUI navigates them fine. When YAML navigation returns the YAML node instead of the PHP class, or a service class's YAML registration is missing from its references: read [references/symfony-di.md](references/symfony-di.md) for the symptoms, the JetBrains-MCP-Server `locate_symfony_service` fix, and the `ide_search_text` fallback.

## Detailed Tool Parameters

For complete parameter reference, see [tools-reference.md](references/tools-reference.md).
