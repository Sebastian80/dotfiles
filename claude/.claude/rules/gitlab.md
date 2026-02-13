# GitLab (glab) Usage

- The internal GitLab instance is `git.netresearch.de`.
- Composer authentication for internal GitLab: `composer config gitlab-token.git.netresearch.de <token>`
- When checking remote refs across repos, prefer `git ls-remote` over cloning.
- To delete a remote branch: `git push <remote-url> --delete <branch>` — useful for cleaning up accidental pushes to wrong repos.
