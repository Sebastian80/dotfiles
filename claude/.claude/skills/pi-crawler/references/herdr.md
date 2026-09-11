# Running the crawler in a herdr pane

For when the user wants to watch the crawl or ask follow-ups. Split next to your own pane unless
they ask for a tab; several at once belong in tabs, because stacked splits get too narrow to read.

```bash
# 1. A pane next to yours, in the PROJECT: that is where the MCP servers come from.
P=$(herdr pane split --current --direction right --no-focus \
      --cwd /abs/project/root | jq -r '.result.pane.pane_id')
#    For a tab instead:
#    P=$(herdr tab create --workspace "${HERDR_PANE_ID%%:*}" --label crawler --no-focus \
#          --cwd /abs/project/root | jq -r '.result.root_pane.pane_id')
#    Without --workspace, herdr opens the tab where the user is looking, not where you are.

# 2. Start a cheap orchestrator. It only delegates, so low effort is enough.
N=orch-$(date +%H%M%S)
herdr agent start "$N" --kind pi --pane "$P" -- -a --model openai-codex/gpt-5.6-luna --thinking low

# 3. Ask, as a background Bash task. An interactive session CAN wait for the async child
#    (it calls bg_wait itself), so the answer appears in the pane.
herdr agent prompt "$N" 'Use the subagent tool once with agent "crawler" and async set to true,
with the task below. When the child result arrives, print the child answer verbatim and nothing else.

Project root: /abs/project/root
Question: <question>' --wait --until idle --until done --until blocked --timeout 900000

# 4. When the task returns, read the answer from the pane.
herdr agent read "$N" --source recent-unwrapped --lines 60
```

- Leave the pane open: the user reads the answer and asks follow-ups there. Close it only when
  they are done, with `herdr pane close "$P"`.
- herdr knows pi's state only through its pi integration (`herdr integration status` must list
  `pi: current`). Without it, every pi reads idle and step 3 returns early.
- A `--timeout` that fires first means the crawl is still running, not failed: read the pane and
  wait again.
- Wide answers (tables) wrap badly in a narrow split. The full text is in the child's artifact:
  newest `~/.pi/agent/sessions/--<slug of project path>--/subagent-artifacts/*_crawler_output.md`.
