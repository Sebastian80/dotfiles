# GitLab (glab) Usage

- The internal GitLab instance is `git.netresearch.de`.
- Composer authentication for internal GitLab: `composer config gitlab-token.git.netresearch.de <token>`
- To delete a remote branch: `git push <remote-url> --delete <branch>` — useful for cleaning up accidental pushes to wrong repos.
- A CI job failing with `couldn't find remote ref refs/heads/<branch>` right after an MR merge is the duplicate BRANCH pipeline racing the source-branch deletion — not a real failure. Dedupe with standard `workflow:` rules (prefer `merge_request_event`; suppress `$CI_COMMIT_BRANCH && $CI_OPEN_MERGE_REQUESTS`; keep branch/tag pipelines otherwise).
