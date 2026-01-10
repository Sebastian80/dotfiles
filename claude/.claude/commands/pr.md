---
description: Create a pull request for the current branch
---

Create a pull request for the current branch:

## 1. Verify Branch State
```bash
git status
git log --oneline develop..HEAD
```

## 2. Run Checks
- Run `composer analysis` to ensure no errors
- Verify all tests pass

## 3. Create PR
- Target branch: develop
- Title format: `HMKG-XXX: Brief description`
- Include:
  - Summary of changes
  - Testing done
  - Screenshots if UI changes
  - Any deployment notes

## 4. Additional Context
$ARGUMENTS
