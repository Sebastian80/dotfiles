# trigger-eval results — index-lookup

Harness: `trigger-harness.py` (moved here from `ide-index-mcp/evals` on 2026-09-16). Each query runs
through `claude -p` in plan mode with every MCP server stripped, three cases in parallel, run from
an OroCommerce project with its vendor packages un-excluded. Metric: a `Skill` tool_use naming `index-lookup` within the first three tool calls.
Rows in `<arm>.jsonl`, summary in `<arm>-summary.json`.

## Method policy

Researched 2026-09-16 by two independent agents (a Sonnet subagent and a Pi scout in a Herdr pane) that
reached the same conclusions from largely different sources; the two skill-creator claims were verified
by reading the installed plugin.

- **One model per arm, and it is the model the users actually run**, together with its reasoning effort,
  the Claude Code version and the settings that shipped with it. skill-creator's own trigger loop passes
  the model powering the current session "so the triggering test matches what the user actually
  experiences" (`scripts/run_loop.py`, `SKILL.md:390`), and Anthropic's agent-eval writing treats the
  harness and the model as one object under test. A matrix over other models is a robustness and
  upgrade-risk signal, never the deciding number.
- **Never Fable.** `--model` is required by the harness and Fable is rejected outright, whatever the
  session default is. Sebastian's standing rule; it overrides "eval on the session model".
- **Never blend models.** Anthropic's prompting guide documents that Opus 4.5 and 4.6 respond more
  strongly to the system prompt, so wording tuned against undertriggering can overtrigger there. A
  description that wins on one model and loses on another is the documented norm, not a broken eval.
  Report each model as its own arm side by side.
- **Three runs per query, majority vote.** `run_eval.py` and `run_loop.py` default to
  `--runs-per-query 3` and `--trigger-threshold 0.5`; the harness now matches (`--runs`, `--threshold`).
- **A gap under three cases is noise.** Compare two descriptions as paired binary outcomes and look only
  at the discordant cases (McNemar; exact binomial when there are few). At n≈29, roughly six discordant
  pairs in one direction are needed to clear p<0.05, so require at least three to five net paired cases
  before calling a description better, and treat a one-case lead as a coin flip. Repeats of the same 29
  prompts are not independent samples; report Wilson intervals on the pass rate rather than a bare count.
- **Grow the case set before optimizing.** 29 cases is too few to tune against; add hard negatives and
  near-miss positives first.
- **Hold out cases before editing the description.** skill-creator splits 60/40 stratified by
  `should_trigger` and picks the winner on the held-out half. Not yet done here.
- **Shipping to several models** means picking the description that is acceptable everywhere, per the
  skill authoring best-practices checklist ("Tested with Haiku, Sonnet, and Opus"), which is in tension
  with the single-model policy above. That tension is Anthropic's, not ours to average away.

Sources: platform.claude.com prompt-engineering and agent-skills best-practices pages; code.claude.com
skills docs on description tuning and `tool_used: Skill` graders; anthropic.com/engineering
"Demystifying evals for AI agents" on trials and pass@k versus pass^k; the installed skill-creator
plugin; Mizrahi et al., arXiv:2401.00595, on prompt rankings reversing across models; the ICLR 2024
prompt-formatting sensitivity paper (openreview RIu5lyNXjT); the OPRO follow-up
(aclanthology 2024.findings-acl.100) on optimization gains depending on model capability; promptfoo,
OpenAI Evals, Braintrust and Inspect docs on model matrices and repeats.

Where the sources disagree: skill-creator pins the session model, while the skill authoring
best-practices checklist asks for Haiku, Sonnet and Opus. promptfoo defaults to a full prompt × provider
matrix, while every other framework treats one pinned configuration as the unit of truth. Both agents
landed on the same resolution: pin the deployment model for the score, matrix for robustness.

## Relation to the Netresearch eval repos

Read 2026-09-16, nothing executed.

- **`netresearch/skill-repo-skill`** runs a quality A/B (`scripts/run-ab-evals.sh`): the skill text is
  pasted into the system prompt in one arm and graded by regex assertions and a judge. It has no
  `should_trigger` concept, and its own `references/skill-quality.md` says that harness "cannot see"
  discovery failures and points to agent-system-evals. So this harness does not duplicate it. Its
  models are hardcoded (`EVAL_MODEL="sonnet"`, `GRADER_MODEL="haiku"`), so reusing that script would need
  a required `--model` flag first.
- **`netresearch/agent-system-evals`** is a Harbor whole-stack benchmark (built instances, 3 trials per
  arm, Fisher-exact, 8-dimension MET/PARTIAL/NOT_MET rubric, unpublished holdout). Too heavy for one
  skill description, but the right shape for judging the lookup worker's answers later.
- **Adopted from them:** a provenance block in every summary (model, CLI version, eval-set hash), and
  runs with no assistant turn counted as non-answers instead of misses. Covered by the offline test
  `test-trigger-harness.sh` (fake `claude` on PATH, no model calls).
- **Corroboration for the required `--model`:** their `docs/instrument-failures.md` records a run started
  without the flag that silently took the Opus default at about forty times the intended cost.
- **Not adopted:** `skill-quality.md` asks for a `Use when <trigger>` opener and 100 to 300 characters.
  This description opens with MANDATORY and runs about 950 characters, because stripping that framing
  cost `ide-index-mcp` four of thirteen positives. Their own `docs/composition-sweep.md` refutes the idea
  that description wording predicts routing ("Shared words predict nothing"), so the convention is not
  evidence against a measured result. Worth an A/B under the method policy above before changing.

## 2026-09-16, worker-only routing

Context: from this day on the main session has no index server; `ide-index-mcp` is model-hidden and
preloaded into the `oro-index-lookup` subagent, and this skill is the only visible entry. The eval set
was relabelled accordingly: rename, diagnostics, sync, indexing status, open project, window lifecycle
and power save are negatives now (no agent exposes them yet), and five framework-lookup positives were
added (service id and tags, entity fields, template usages, creating factory, class existence in vendor).

| arm | positives (11) | negatives (18) |
| --- | --- | --- |
| description as committed 2026-09-16, Fable 5.1, 1 run per case | 10 | 1 |

This run predates the method policy above: one run per case, and the parent model was whatever the
settings default was that day. It stands as a smoke test, not as a comparison.

Miss: "is there a CustomerUserRoleRepository class anywhere, in our code or in vendor/oro?" went to Bash
first. False trigger: "rename getPimField to getPimAttribute ... update every caller" invoked the skill,
presumably to enumerate callers before editing; the fork answers such a task with `OUT OF SCOPE`, so the
cost is one wasted subagent call, not a wrong edit. One run per query, so both are single-flip noise
level; the description stays as is.

## 2026-09-16, "Use when" description under the method policy

First run that follows the policy above: Sonnet, 3 runs per query, majority threshold, provenance in the
summary. The routing surface changed first: the Pi-backed crawler agent was removed, and the project's
routing rule now names this skill.

| arm | description | positives | false triggers |
| --- | --- | --- | --- |
| `use-when-sonnet-2026-09-16` | "Use when" wording as committed in d2bed47 | 11/11 | 2/18 |
| `ide-exclusion-recheck-sonnet-2026-09-16` | plus "not for problems with PhpStorm itself" | 12/12 | 0/5 |

The two false triggers of the first arm, each in 2 of 3 runs:

- "i edited a bunch of files with a script outside phpstorm and now find usages returns stale results"
  is an IDE sync problem the worker cannot touch. The description now excludes problems with PhpStorm
  itself (indexing, stale results after external edits, project windows, power save); the recheck
  scored it 0 of 3.
- "rename getPimField to getPimAttribute ... update every caller" was **relabelled positive**, not
  fixed. No agent offers IDE refactoring, so the first step of a rename is finding every caller, which
  is this skill's job; `ide-first.sh` already tells the main session to sweep the old name through it.

The recheck covered all positives (to catch a loss from the new exclusion) and the five IDE-state
negatives it targets, not the other 13 negatives. Those scored 0 by majority in the first arm, and a
clause that only excludes cannot plausibly make them trigger; that is an inference, not a measurement.
"is phpstorm still indexing?" still invokes the skill in 1 of 3 runs, below the threshold.

## 2026-09-16, full set on the final description

Closes the two caveats of the previous section. Two hard negatives were added where the request names
the file to edit, so reading it is correct and the index is not; they replace the negative coverage the
rename relabel removed. All 31 queries, Sonnet, 3 runs, majority (`final-full-sonnet-2026-09-16`).

| positives | false triggers |
| --- | --- |
| 11/12 | 0/19 |

The miss is the relabelled rename query at 1 of 3 runs; it scored 2 of 3 in both earlier arms, so it
sits near the threshold and flips between runs. Kept as a positive and not tuned for. Four negatives
invoke the skill in 1 of 3 runs (a breakpoint request, the migration request, the docblock request with
a given path, and the rename-adjacent Explore routes), all below the threshold.
