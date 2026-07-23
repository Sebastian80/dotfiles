---
name: ide-index-mcp
description: "MANDATORY for all code navigation and refactoring. You MUST invoke this skill whenever: finding where a function/method/class is called or used ('find usages of X', 'who calls X', 'where is X used'), going to a definition ('where is X defined', 'take me to X', 'show me the source of X'), renaming any symbol, finding implementations of an interface or abstract class, tracing call hierarchies ('what calls X', 'what does X call'), checking file structure or class methods ('what methods does X have'), checking for errors/warnings/diagnostics in a file, finding classes or symbols by name, understanding type/inheritance hierarchies, syncing IDE after external file changes, reformatting code, or managing IDE projects (multi-project, sleep/wake, Power Save). Do NOT skip this and use Grep/Glob instead, even for seemingly simple tasks. If a user mentions any class name, method name, or symbol and wants to navigate to it, find its usages, rename it, or understand its relationships, this skill MUST be consulted first."
---

# IDE Index MCP - Agent Guide

The IDE Index MCP server exposes JetBrains IDE (IntelliJ, PyCharm, PhpStorm, WebStorm, etc.) indexing and refactoring capabilities. These tools provide **semantic** code understanding — types, inheritance, references, call chains — that text-based tools cannot.

## Core Rule

**Use IDE MCP tools as your primary search, navigation, and refactoring tools.** JetBrains indexes ALL project files — code, config, YAML, Markdown, etc. — so prefer `ide_search_text` and `ide_find_file` even for non-code searches. Fall back to Grep/Glob only for files outside the project, or when IDE Index is unavailable — `ide_search_text` now handles regex itself (see below).

**Availability:** the server only exists while the IDE is running. If no `ide_*`/`mcp__phpstorm-index__*` tools are present in the session, the IDE is closed — use the standard tools without ceremony and NEVER ask the user to launch the IDE for it. If tools were present but a call fails mid-session, check `ide_index_status` once, then fall back.

The IDE understands your code structurally. Grep sees text. When you need to find usages, trace calls, navigate definitions, rename symbols, check inheritance, or find implementations — always reach for an IDE tool first.

## Available Tools

### Navigation
| Tool | What it does | Key params |
|------|-------------|------------|
| `ide_find_references` | Find all usages of a symbol (calls, imports, field access) | `file`, `line`, `column` |
| `ide_find_definition` | Go to where a symbol is defined | `file`, `line`, `column` |
| `ide_find_class` | Search classes/interfaces by name (CamelCase: `USvc` → `UserService`) | `query` |
| `ide_find_file` | Search files by name (substring, wildcard) | `query` |
| `ide_find_symbol` | Search any symbol — classes, methods, fields, functions | `query` |
| `ide_search_text` | Text search via IDE word index; `regex: true` routes through Find-in-Files, `filePattern` masks files | `query`, `context`, `regex`, `filePattern` |
| `ide_find_implementations` | Find concrete implementations of interfaces/abstract classes | `file`, `line`, `column` |
| `ide_find_super_methods` | Find parent methods this method overrides/implements | `file`, `line`, `column` |
| `ide_type_hierarchy` | Full inheritance tree (supertypes + subtypes) | `file`+`line`+`column` or `className` |
| `ide_call_hierarchy` | Call tree — who calls this / what does this call | `file`, `line`, `column`, `direction` |
| `ide_file_structure` | File's class/method/field tree (like IDE Structure panel) | `file` |

### Refactoring
| Tool | What it does | Key params |
|------|-------------|------------|
| `ide_refactor_rename` | Rename a symbol + update all references atomically, OR rename the file itself | symbol: `file`, `line`, `column`, `newName` — file: `file`, `newName` (omit line/column) |
| `ide_move_file` | Move a file; IDE applies namespace/import updates where a semantic backend exists (PHP PSR-4 aware) | `file`, `destination` |
| `ide_optimize_imports` | Remove unused imports + organize the rest per project style (does NOT reformat) | `file` |
| `ide_reformat_code` | Reformat per project style (.editorconfig, IDE settings) | `file` |

### Intelligence
| Tool | What it does | Key params |
|------|-------------|------------|
| `ide_diagnostics` | Errors, warnings, quick fixes for a file | `file` |
| `ide_build_project` | Build project, surface compilation/type errors | (none required) |

### Project & Editor
| Tool | What it does | Key params |
|------|-------------|------------|
| `ide_index_status` | Check if IDE is ready (dumb mode = still indexing) | (none required) |
| `ide_sync_files` | Force sync after external file changes (Write/Edit) | `paths` (optional) |
| `ide_open_file` | Open file in IDE editor, optionally navigate to line | `file`, `line` |
| `ide_get_active_file` | Get currently open file(s) with cursor position | (none required) |
| `ide_read_file` | Read file content — use for library/vendored sources only | `file` or `qualifiedName` |

### Project Lifecycle & Multi-Project

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

**Lifecycle modes** (managed projects move automatically): `active` (full IDE, Power Save off) → `background` (Power Save on, index + MCP fully functional — the default while MCP works) → `dormant` (editors closed, PSI cache freed; after ~2 min MCP inactivity) → `closed` (fully unloaded; after ~10 min inactivity). Any MCP call **auto-wakes** the project — a call against a `closed` managed project auto-reopens it with a 5–15 s delay, so a slow first response after idle time is normal, not an error.

**Multi-project workflow:**
1. `ide_project_status` first — see what's open, managed, and in which mode.
2. With more than one project open, pass `project_path` (absolute project root) on **every** call — omitting it returns an error listing the candidates. For workspace projects use the sub-project path.
3. Enrollment is automatic on the first real semantic call per project; `ide_enroll_all_projects` only needed to opt in projects you haven't touched yet.
4. Don't micro-manage modes — the lifecycle handles sleep/wake. Set modes explicitly only to pre-warm (`background`) before a batch, or to free memory now (`dormant`/`closed`).
5. `ide_open_project` on a never-before-opened project can hang on the modal "Trust project?" dialog only a human can answer — if it times out, ask the user.
6. If a project closed or slept unexpectedly, read `ide_lifecycle_log` before assuming a bug.

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
2. **File paths are relative** to project root — never absolute
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
1. `ide_find_definition` — jump to source
2. `ide_type_hierarchy` — inheritance chain (prefer `file`+`line`+`column` over `className`)
3. `ide_find_super_methods` — what interface/base method it implements

### Finding a class/file/symbol
1. `ide_find_class` — classes by name (supports CamelCase: `USvc` → `UserService`)
2. `ide_find_symbol` — any symbol (classes, methods, fields, functions)
3. `ide_find_file` — files by name
4. `ide_search_text` — word occurrences across project (`regex: true` for patterns)

**CamelCase caveat:** matching is reliable for **capital-initial** queries (`CSRM` → `CarrierServiceResponseMapper`), but mixed-case multi-segment abbreviations (`CarSvcRespMap`) silently return zero even when a class matches. When a CamelCase guess comes back empty, retry with just the capital initials or a plain substring before assuming the class doesn't exist.

### Refactoring
1. `ide_refactor_rename` — rename a symbol + all references atomically (`file`+`line`+`column`+`newName`). Omit `line`/`column` to rename the **file** itself (updates references; works for any file type).
2. After rename, **verify with Grep** for the old name — IDE rename can miss some call sites depending on language. Fix stragglers with Edit.
3. `ide_move_file` — relocate a file; IDE updates namespace/imports where a semantic backend exists (PHP PSR-4 aware)
4. `ide_optimize_imports` — strip unused imports + organize the rest (no reformatting)
5. `ide_reformat_code` — apply project code style

### Checking for problems
1. `ide_diagnostics` — errors, warnings, quick fixes
2. `ide_build_project` — full project build to surface compilation/type errors

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
| Tool returns empty for a class/file you can see on disk in `vendor/`/library | Folder is in the IDE's Excluded list (Settings → Directories → right column). The `scope: project_and_libraries` parameter doesn't override this — exclusion wins at the index level. Either remove the exclusion (re-indexes the folder), or fall back to `rg -uu <path>` for that subtree. Verify by running `ide_find_class` on a class you know exists in the folder. |
| `ide_find_definition`/`ide_find_references` don't follow Symfony service-YAML ↔ class links | Known index-plugin gap (resolves only the primary `getReference()`, not the IDE's provider-based Go-to-Declaration). Use the **JetBrains MCP Server's `locate_symfony_service`** instead, or `ide_search_text`. See [Framework DI / YAML navigation](#framework-di--yaml-navigation-symfony-etc). |

## Framework DI / YAML navigation (Symfony, etc.)

`ide_find_definition`/`ide_find_references` follow only a symbol's *primary* reference — provider-contributed references (Symfony service-YAML ↔ PHP class links) are invisible to them even though Ctrl+B in the GUI navigates them fine. When YAML navigation returns the YAML node instead of the PHP class, or a service class's YAML registration is missing from its references: read [references/symfony-di.md](references/symfony-di.md) for the symptoms, the JetBrains-MCP-Server `locate_symfony_service` fix, and the `ide_search_text` fallback.

## Detailed Tool Parameters

For complete parameter reference, see [tools-reference.md](references/tools-reference.md).
