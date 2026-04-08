---
name: ide-index-mcp
description: "MANDATORY for all code navigation and refactoring. You MUST invoke this skill whenever: finding where a function/method/class is called or used ('find usages of X', 'who calls X', 'where is X used'), going to a definition ('where is X defined', 'take me to X', 'show me the source of X'), renaming any symbol, finding implementations of an interface or abstract class, tracing call hierarchies ('what calls X', 'what does X call'), checking file structure or class methods ('what methods does X have'), checking for errors/warnings/diagnostics in a file, finding classes or symbols by name, understanding type/inheritance hierarchies, syncing IDE after external file changes, or reformatting code. This applies even for seemingly simple tasks — do NOT skip this skill and use Grep/Glob instead. If a user mentions any class name, method name, or symbol and wants to navigate to it, find its usages, rename it, or understand its relationships, this skill MUST be consulted first."
argument-hint: [task description or symbol to investigate]
model: haiku
---

# IDE Index MCP - Agent Guide

The IDE Index MCP server exposes JetBrains IDE (IntelliJ, PyCharm, PhpStorm, WebStorm, etc.) indexing and refactoring capabilities. These tools provide **semantic** code understanding — types, inheritance, references, call chains — that text-based tools cannot.

## Core Rule

**Use IDE MCP tools as your primary search, navigation, and refactoring tools.** JetBrains indexes ALL project files — code, config, YAML, Markdown, etc. — so prefer `ide_search_text` and `ide_find_file` even for non-code searches. Fall back to Grep/Glob only for regex patterns, files outside the project, or when IDE Index is unavailable.

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
| `ide_search_text` | Exact word search via IDE word index (fast, NOT regex) | `query`, `context` |
| `ide_find_implementations` | Find concrete implementations of interfaces/abstract classes | `file`, `line`, `column` |
| `ide_find_super_methods` | Find parent methods this method overrides/implements | `file`, `line`, `column` |
| `ide_type_hierarchy` | Full inheritance tree (supertypes + subtypes) | `file`+`line`+`column` or `className` |
| `ide_call_hierarchy` | Call tree — who calls this / what does this call | `file`, `line`, `column`, `direction` |
| `ide_file_structure` | File's class/method/field tree (like IDE Structure panel) | `file` |

### Refactoring
| Tool | What it does | Key params |
|------|-------------|------------|
| `ide_refactor_rename` | Rename symbol + update all references atomically | `file`, `line`, `column`, `newName` |
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

## When to use built-in tools instead

- **Regex pattern matching** → `Grep` (IDE search is exact-word only, no regex)
- **Finding files by extension/path glob pattern** → `Glob` (e.g. `**/*.py`, `src/**/*.yaml`)
- **Files outside the project** → `Grep`/`Glob` (IDE only indexes project files)
- **Reading project file content** → `Read` (`ide_read_file` is for library/jar sources)

## Pre-Flight

If an IDE tool fails unexpectedly, check `ide_index_status`. When `isDumbMode: true`, the IDE is still indexing — wait and retry. Tools that work in dumb mode: `ide_index_status`, `ide_sync_files`, `ide_reformat_code`, `ide_open_file`, `ide_get_active_file`.

## File Sync

After creating or modifying files outside the IDE (via Write/Edit), call `ide_sync_files` before using search tools. Omit `paths` to sync the entire project.

## Parameter Essentials

1. **Line and column are 1-based** (first line = 1, first column = 1)
2. **File paths are relative** to project root — never absolute
3. **Column must point to the first character of the symbol name** — not keywords (`def`, `class`, `function`), whitespace, or punctuation. A wrong column silently resolves to the wrong symbol.
4. **project_path** — only needed for multi-project workspaces, omit otherwise

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
4. `ide_search_text` — exact word occurrences across project (not regex)

### Refactoring
1. `ide_refactor_rename` — rename symbol + all references atomically
2. After rename, **verify with Grep** for the old name — IDE rename can miss some call sites depending on language. Fix stragglers with Edit.
3. `ide_reformat_code` — apply project code style

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

## Detailed Tool Parameters

For complete parameter reference, see [tools-reference.md](references/tools-reference.md).
