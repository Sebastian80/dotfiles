# Jira CLI Usage

- When piping `jira` CLI output to other tools, ALWAYS use `2>/dev/null` to suppress server startup messages. NEVER use `2>&1` as it merges startup noise into stdout and breaks JSON parsing.
- Prefer `--format ai` for reading ticket context, `--format json` only when programmatically extracting fields.
- Always use Jira wiki markup in comments and descriptions, never Markdown.
