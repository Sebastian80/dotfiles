# Jira CLI Usage

- When piping `jira` CLI output to other tools, ALWAYS use `2>/dev/null` to suppress server startup messages. NEVER use `2>&1` as it merges startup noise into stdout and breaks JSON parsing.
- Prefer `--format ai` for reading ticket context, `--format json` only when programmatically extracting fields.
- Always use Jira wiki markup in comments and descriptions, never Markdown.
- To update issue fields (description, summary, etc.), use `jira update KEY --field value`. This is an alias for `PATCH /jira/issue/KEY`. Alternative: `jira issue KEY -X PATCH --field value`.
- Use dedicated endpoints for sub-resources: `jira comments KEY`, `jira attachments KEY`, `jira transitions KEY`. Don't parse the full issue JSON to extract comments or attachments.
- When parsing `--format json` output, fields are at `.data.fields`, NOT `.fields`. The CLI wraps responses in `{"success": true, "data": {...}}`.
- `jira search --jql '...'` JSON returns the issues array at `.data[]` directly, NOT `.data.issues[]`. The response shape is `{"success": true, "data": [...issues...], "pagination": {...}}`.
- `jira comment KEY --text "..."` — comment body flag is `--text`, NOT `--body`. The API field is `text`. Using `--body` errors with `"Field required: text"`.
- To set system fields not on the `jira update KEY` / `jira issue KEY -X PATCH` direct flag list (e.g. `fixVersions`, which has no `--fixVersions` flag despite being a standard system field), use `--custom` with a JSON object: `jira issue KEY -X PATCH --custom '{"fixVersions":[{"name":"X"}]}'`. `--custom` accepts arbitrary JSON for any field, not just custom fields. The array replaces existing values; use `{"fixVersions":[{"add":{"name":"X"}}]}` to add without removing.
- Use dedicated commands for links (`jira link`) and sprints (`jira sprint`). Unknown flags on `jira issue` are silently ignored — the GET response looks like success.
- `jira transition KEY --target X` treats `X` as a destination STATE and does multi-step pathfinding that **executes** intermediate transitions. Pass the destination state (the `.to` value from `jira transitions KEY`), NEVER a transition name — a transition name path-walks the ticket destructively. There is no transition-by-id flag. Always `--dryRun --maxSteps 1` first to confirm a single expected hop.
- **After creating a ticket, ALWAYS add it to the project's active sprint.** Two steps: `jira sprint/active/{project}` to get the active sprint ID, then `jira sprint/{sprint_id}/issues [POST] --issues KEY`. Skip only if user explicitly says "backlog" or the project has no active sprint (cli will say so).
- `jira transitions KEY --format json`: `.data[].to` is a plain string (the state name), NOT an object — don't parse `.to.name`.
- There is NO attachment **download** endpoint (only list/upload/delete). To read a screenshot's content, ask the user to describe it or paste it — don't curl the attachment URL (needs credentials Claude must not read).
- Multi-step transition pathfinding can report "No path" even when stepwise hops exist. Transition one hop at a time: `--target <next-state> --dryRun --maxSteps 1`, then execute, then re-list transitions.
