# Running the crawler in a herdr pane or tab

For when the user wants to watch the crawler work or ask it follow-ups. Split next to your own pane
unless they ask for a tab; several crawlers at once belong in tabs, because stacked splits get too
narrow to read.

```bash
# 1. A pane next to yours, in the agent folder, with the project in the environment.
#    A pane's shell does not inherit your environment, so CRAWL_PROJECT goes through --env.
P=$(herdr pane split --current --direction right --no-focus \
      --cwd ~/.pi/agent/crawler --env CRAWL_PROJECT=/abs/project/root | jq -r '.result.pane.pane_id')
#    For a tab instead:
#    P=$(herdr tab create --workspace "${HERDR_PANE_ID%%:*}" --label crawler --no-focus \
#          --cwd ~/.pi/agent/crawler --env CRAWL_PROJECT=/abs/project/root | jq -r '.result.root_pane.pane_id')
#    Without --workspace, herdr opens the tab where the user is looking, not where you are.

# 2. Start the agent. Names must be unique while the agent lives.
N=idx-$(date +%H%M%S)
herdr agent start "$N" --kind pi --pane "$P" -- -a -ns --tools "$(paste -sd, ~/.pi/agent/crawler/tools.txt)"

# 3. Ask, as a background Bash task. --wait watches from the submission and returns when the turn
#    ends; it fails fast with agent_prompt_stalled if the question never started running.
herdr agent prompt "$N" "Project root: /abs/project/root
Question: <question>" --wait --until idle --until done --until blocked --timeout 600000

# 4. When the task returns, read the answer from the pane.
herdr agent read "$N" --source recent-unwrapped --lines 200
```

- Leave the pane open: the user reads the answer and asks follow-ups there. Close it only when
  they are done, with `herdr pane close "$P"`.
- herdr knows pi's state only through its pi integration (`herdr integration status` must list
  `pi: current`). Without it, every pi reads idle and step 3 returns early.
- A `--timeout` that fires first means the crawl is still running, not failed: read the pane and
  wait again.
