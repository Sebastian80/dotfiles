---
paths:
  - "**/*Test.php"
  - "**/Tests/**"
  - "**/tests/**"
  - "**/*.feature"
  - "**/phpunit.xml*"
  - "**/behat.yml*"
  - "**/test_*.py"
  - "**/*_test.py"
---

# Testing

- Every test failure on the path you touch is yours to fix immediately, even the ones you didn't cause. Failures elsewhere get noted, not chased (see AGENTS.md).
- Reducing test coverage is worse than failing tests. Never delete a failing test — raise it with Sebastian instead.
- Tests cover all production code paths.
- Never write a test that asserts on mocked behavior instead of real logic. If you find one, stop and warn Sebastian.
- No mocks in end-to-end tests — real data, real APIs.
- Test output must be pristine to pass. Expected errors get captured and asserted on, not ignored; a test that intentionally triggers an error must validate that the error output is what we expect.
- No reflection in tests. Use stub classes (override the accessor, constructor-settable values) instead.
- Never commit tests that cannot be executed (no runner/infrastructure exists yet). A test that has never been red or green is an assertion of hope, not verification. If truly unavoidable, mark it explicitly as never-run and file the ticket that makes it runnable. (Lesson from 6 blind-written functional tests: 3 of 6 blind-written functional tests failed on their first-ever execution.)
