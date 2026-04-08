# IDE Index MCP - Tools Reference

Complete parameter reference for all IDE MCP tools.

## Common Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `project_path` | string, optional | Absolute path to project root. Only for multi-project workspaces. |
| `file` | string | Path relative to project root. Never absolute. |
| `line` | integer | **1-based** line number |
| `column` | integer | **1-based** column number. Must point to the **first character of the symbol name**. |

## Response Format

All tools return: `{ "content": [{"type": "text", "text": "<JSON>"}], "isError": false|true }`

Parse the `text` field as JSON for structured data.

---

## Navigation Tools

### ide_find_references
Find all usages of a symbol (semantic, not text search).

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `file` | string | yes | Relative file path |
| `line` | integer | yes | 1-based line |
| `column` | integer | yes | 1-based column — on symbol name |
| `maxResults` | integer | no | Default 100, max 500 |

**Returns**: `{ usages: [{file, line, column, context, usageType}], totalCount, truncated }`
**usageType values**: `method_call`, `field_access`, `import`, `parameter`, `variable`, `reference`

### ide_find_definition
Go to where a symbol is defined.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `file` | string | yes | Relative file path |
| `line` | integer | yes | 1-based line |
| `column` | integer | yes | 1-based column — on symbol name |
| `fullElementPreview` | boolean | no | Return full element code (default false) |
| `maxPreviewLines` | integer | no | Max lines for full preview (default 50, max 500) |

**Returns**: `{ file, line, column, preview, symbolName }`

### ide_find_class
Search for classes/interfaces by name.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `query` | string | yes | Class name pattern |
| `includeLibraries` | boolean | no | Include library classes (default false) |
| `language` | string | no | Filter by language |
| `matchMode` | enum | no | `substring` (default), `prefix`, `exact` |
| `limit` | integer | no | Default 25, max 100 |

**Returns**: `{ classes: [{name, qualifiedName, file, line, kind, language}], totalCount, query }`
**Matching**: CamelCase (`USvc` → `UserService`), substring, wildcard (`User*Impl`).

### ide_find_file
Search for files by name.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `query` | string | yes | File name pattern |
| `includeLibraries` | boolean | no | Include library files (default false) |
| `limit` | integer | no | Default 25, max 100 |

**Returns**: `{ files: [{name, path, directory}], totalCount, query }`

### ide_search_text
Search for exact words using IDE's pre-built word index. Fast O(1) lookups. **Not regex** — use `Grep` for patterns.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `query` | string | yes | Exact word |
| `context` | enum | no | `all` (default), `code`, `comments`, `strings` |
| `caseSensitive` | boolean | no | Default true |
| `limit` | integer | no | Default 100, max 500 |

**Returns**: `{ matches: [{file, line, column, context}], totalCount, query }`

### ide_find_implementations
Find implementations of interfaces, abstract classes, or abstract methods.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `file` | string | yes | Relative file path |
| `line` | integer | yes | 1-based line |
| `column` | integer | yes | 1-based column — on symbol name |

**Returns**: `{ implementations: [{file, line, column, name, containerName}], totalCount }`

### ide_find_symbol
Search for any symbol (classes, methods, fields, functions) by name.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `query` | string | yes | Symbol name pattern |
| `includeLibraries` | boolean | no | Default false |
| `language` | string | no | Filter by language |
| `matchMode` | enum | no | `substring` (default), `prefix`, `exact` |
| `limit` | integer | no | Default 25, max 100 |

**Returns**: `{ symbols: [{name, qualifiedName, file, line, kind, language}], totalCount, query }`

### ide_find_super_methods
Find parent methods that a given method overrides or implements.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `file` | string | yes | Relative file path |
| `line` | integer | yes | 1-based line |
| `column` | integer | yes | 1-based column |

**Returns**: `{ method: {name, class, file, line}, hierarchy: [{name, class, file, line, isInterface}], totalCount }`

### ide_type_hierarchy
Get complete type inheritance hierarchy (supertypes and subtypes).

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `className` | string | no | Fully qualified name |
| `file` | string | no | Relative file path (preferred) |
| `line` | integer | no | Required with file |
| `column` | integer | no | Required with file |

**Provide either** `className` **or** `file`+`line`+`column`. Prefer `file`+`line`+`column` — it works reliably across all languages.
**Returns**: `{ element: {name, qualifiedName, file, line}, supertypes: [...], subtypes: [...] }`

### ide_call_hierarchy
Build call tree showing who calls a method or what a method calls.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `file` | string | yes | Relative file path |
| `line` | integer | yes | 1-based line — must be the method/function declaration line |
| `column` | integer | yes | 1-based column — must be on the method/function name |
| `direction` | enum | yes | `callers` or `callees` |
| `depth` | integer | no | Recursion depth (default 3, max 5) |

**Returns**: `{ element: {name, file, line}, calls: [{name, file, line, children: [...]}] }`
Cursor must be on a method/function name on its declaration line. Use `ide_file_structure` to find the exact position.

### ide_file_structure
Get hierarchical file structure like IDE's Structure panel.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `file` | string | yes | Relative file path |

**Returns**: `{ file, language, structure }` (formatted tree with types, modifiers, signatures, line numbers)

---

## Intelligence Tools

### ide_diagnostics
Analyze a file for errors, warnings, and available quick fixes.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `file` | string | yes | Relative file path |
| `line` | integer | no | For intention lookup (default 1) |
| `column` | integer | no | For intention lookup (default 1) |
| `startLine` | integer | no | Filter problems to range |
| `endLine` | integer | no | Filter problems to range |

**Returns**: `{ problems: [{message, severity, line, column, source}], intentions: [{name, description, familyName}], problemCount, intentionCount }`
**Severity levels**: `ERROR`, `WARNING`, `WEAK_WARNING`, `INFO`

### ide_build_project
Build the project using IDE's build system.

**Returns**: build output with errors and warnings.

---

## Refactoring Tools

### ide_refactor_rename
Rename a symbol and update all references (semantic rename, not find-replace).

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `file` | string | yes | Relative file path |
| `line` | integer | yes | 1-based line |
| `column` | integer | yes | 1-based column — on symbol name |
| `newName` | string | yes | New name for the symbol |
| `overrideStrategy` | enum | no | `rename_base` (default), `rename_only_current`, `ask` |

**Returns**: `{ success, affectedFiles: [paths], changesCount, message }`
Supports IDE undo (Ctrl+Z). After rename, verify with Grep that no old references remain.

### ide_reformat_code
Reformat code per project style (.editorconfig, IDE settings).

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `file` | string | yes | Relative file path |
| `startLine` | integer | no | 1-based start (requires endLine) |
| `endLine` | integer | no | 1-based end (requires startLine) |
| `optimizeImports` | boolean | no | Default true |
| `rearrangeCode` | boolean | no | Default true |

**Returns**: `{ success, affectedFiles, changesCount, message }`

---

## Project Tools

### ide_index_status
Check if IDE is ready for code intelligence operations.

**Returns**: `{ isDumbMode, isIndexing, indexingProgress? }`
When `isDumbMode: true`, most tools will fail. Wait and retry.

### ide_sync_files
Force sync IDE's virtual file system with external file changes.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `paths` | string[] | no | Relative paths to sync (empty = sync entire project) |

**Returns**: `{ syncedPaths, syncedAll, message }`

---

## Editor Tools

### ide_get_active_file
Get currently active file(s) in editor with cursor position.

**Returns**: `{ activeFiles: [{file, line, column, selectedText, language}] }`

### ide_open_file
Open a file in the editor with optional navigation.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `file` | string | yes | Relative or absolute path |
| `line` | integer | no | 1-based line to navigate to |
| `column` | integer | no | 1-based column (requires line) |

**Returns**: `{ file, opened, message }`

### ide_read_file
Read file content, including library/vendored sources not on disk.

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `file` | string | yes | File path |

Use the built-in `Read` tool for normal project files. Use `ide_read_file` only for library or vendored sources that aren't directly accessible on the filesystem.
