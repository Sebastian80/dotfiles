# First-party code for "our code" questions

The index files vendor packages as libraries, so a question about "our" classes stops at `src/`
unless the crawler knows which vendor packages are the team's own. Build the list from the
project's Composer lock data: packages whose source or dist URL points at the company GitLab or
GitHub org. A vendor prefix whose packages are all first-party collapses to `vendor/<prefix>/*`.

Run in the project root:

```bash
jq -r '(.packages // .) as $all
  | [$all[] | select(((.source.url // "") + " " + (.dist.url // ""))
      | test("git\\.netresearch\\.de|github\\.com[:/]netresearch"; "i")) | .name] as $own
  | [($own | map(split("/")[0]) | unique)[] as $p
      | ([$all[] | select(.name | startswith($p + "/"))] | length) as $total
      | [$own[] | select(startswith($p + "/"))] as $mine
      | if ($mine | length) == $total then "vendor/\($p)/*" else ($mine[] | "vendor/\(.)") end]
  | join(", ")' vendor/composer/installed.json
```

Prefix the result with the project's source directories (`src/`, or `app/code/` in Magento) and
put it on the `First-party code:` line of the question. The list never narrows the search: Oro,
Symfony and every other vendor package stay in scope.
