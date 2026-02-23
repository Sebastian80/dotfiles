# Jira CLI Usage

- When piping `jira` CLI output to other tools, ALWAYS use `2>/dev/null` to suppress server startup messages. NEVER use `2>&1` as it merges startup noise into stdout and breaks JSON parsing.
- Prefer `--format ai` for reading ticket context, `--format json` only when programmatically extracting fields.
- Always use Jira wiki markup in comments and descriptions, never Markdown.
- To update issue fields (description, summary, etc.), use `-X PATCH`: `jira issue KEY -X PATCH --description "..."`. Without `-X PATCH` it's a GET that silently ignores write flags.
- Use dedicated endpoints for sub-resources: `jira comments KEY`, `jira attachments KEY`, `jira transitions KEY`. Don't parse the full issue JSON to extract comments or attachments.
- When parsing `--format json` output, fields are at `.data.fields`, NOT `.fields`. The CLI wraps responses in `{"success": true, "data": {...}}`.
