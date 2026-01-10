---
description: Review current branch changes for bugs, security, and code quality
---

Review the changes in the current branch thoroughly:

## 1. Get Context
```bash
git log --oneline develop..HEAD
git diff develop...HEAD --stat
```

## 2. Security Review
- [ ] No hardcoded credentials or secrets
- [ ] No SQL injection vulnerabilities
- [ ] No XSS vulnerabilities
- [ ] Proper input validation
- [ ] Authorization checks in place

## 3. Code Quality Review
- [ ] Follows PSR-12 / project code style
- [ ] No code duplication
- [ ] Clear naming conventions
- [ ] Appropriate error handling
- [ ] No unnecessary complexity

## 4. Logic Review
- [ ] Business logic is correct
- [ ] Edge cases handled
- [ ] No race conditions
- [ ] Database queries are efficient

## 5. Test Coverage
- [ ] New code has tests
- [ ] Existing tests still pass
- [ ] Edge cases are tested

## 6. Summary
Provide a summary with:
- **Issues Found**: List any problems
- **Suggestions**: Improvements to consider
- **Verdict**: Ready to merge / Needs changes

$ARGUMENTS
