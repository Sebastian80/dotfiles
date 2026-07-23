# GitLab (glab) Usage

- The internal GitLab instance is `git.netresearch.de`.
- Composer authentication for internal GitLab: `composer config gitlab-token.git.netresearch.de <token>`
- To delete a remote branch: `git push <remote-url> --delete <branch>` — useful for cleaning up accidental pushes to wrong repos.
- A CI job failing with `couldn't find remote ref refs/heads/<branch>` right after an MR merge is the duplicate BRANCH pipeline racing the source-branch deletion — not a real failure. Dedupe with standard `workflow:` rules (prefer `merge_request_event`; suppress `$CI_COMMIT_BRANCH && $CI_OPEN_MERGE_REQUESTS`; keep branch/tag pipelines otherwise).
- `glab mr create --repo X` silently takes the MR SOURCE project from the current directory's git remote, not from `--repo` — run from another repo's checkout it fails with 422 "Source project is not a fork of the target project" (or worse, targets the wrong repo). Always `cd` into the repo the MR belongs to before `glab mr create`.

## Internal skill marketplace (coding-ai group)

- Internal Claude Code skills/plugins live in `coding-ai/<name>` repos on git.netresearch.de, registered via MR in `coding-ai/marketplace` (`.claude-plugin/marketplace.json`, source = git URL). Visibility `internal` — customer infrastructure details (project ids, hosts, IPs) belong HERE, never in the public GitHub marketplace (`netresearch/claude-code-marketplace` and its skill repos are PUBLIC).
- Plugin naming is team/domain-prefixed: `ecom-*` (eCom team), `dxp-*`, `typo3-*`, `netresearch-*`, `it-*`. Customer plugins get the team prefix too (e.g. `ecom-hmkg`), not the bare customer name.
- New repos in `coding-ai` get `main` protected by group policy after the first push — all subsequent changes go through MRs.
- The CI component (`ci-components/claude-code-skill`) requires in-repo: `scripts/validate-skill.sh` and `.markdownlint.jsonc` (120-char lines, code blocks/tables exempt) — copy both from `coding-ai/ecom-orocommerce-docker-skill` and run `sh scripts/validate-skill.sh` + `npx markdownlint-cli2 "**/*.md"` locally before pushing.
