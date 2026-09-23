---
paths:
  - "**/SKILL.md"
  - "**/.claude-plugin/**"
---

# Writing skills

- A skill's `description:` is its trigger: it sits in the always-loaded skill listing and is what the
  router matches on, so keep it pushy — trigger phrases, "use when…", MUST where it earns it. Explain
  in the body, which loads only once the skill fires. Anthropic's advice to dial back CRITICAL/MUST
  came from Opus 4.5/4.6 overtriggering; measure a description change on the skill's trigger eval
  before trusting it. (Stripping that vocabulary cost `ide-index-mcp` 4 of 13 positives on its own
  trigger eval, for zero gain on negatives.)
