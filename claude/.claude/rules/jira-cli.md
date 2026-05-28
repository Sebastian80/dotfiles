# Jira CLI Usage

- When piping `jira` CLI output to other tools, ALWAYS use `2>/dev/null` to suppress server startup messages. NEVER use `2>&1` as it merges startup noise into stdout and breaks JSON parsing.
- Prefer `--format ai` for reading ticket context, `--format json` only when programmatically extracting fields.
- Always use Jira wiki markup in comments and descriptions, never Markdown.
- To update issue fields (description, summary, etc.), use `jira update KEY --field value`. This is an alias for `PATCH /jira/issue/KEY`. Alternative: `jira issue KEY -X PATCH --field value`.
- Use dedicated endpoints for sub-resources: `jira comments KEY`, `jira attachments KEY`, `jira transitions KEY`. Don't parse the full issue JSON to extract comments or attachments.
- When parsing `--format json` output, fields are at `.data.fields`, NOT `.fields`. The CLI wraps responses in `{"success": true, "data": {...}}`.
- Use dedicated commands for links (`jira link`) and sprints (`jira sprint`). Unknown flags on `jira issue` are silently ignored — the GET response looks like success.
- `jira transition KEY --target X` treats `X` as a destination STATE and does multi-step pathfinding that **executes** intermediate transitions. Pass the destination state (the `.to` value from `jira transitions KEY`), NEVER a transition name — a transition name path-walks the ticket destructively. There is no transition-by-id flag. Always `--dryRun --maxSteps 1` first to confirm a single expected hop.
