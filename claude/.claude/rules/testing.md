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

- Reducing test coverage is worse than failing tests. Never delete a failing test — raise it with Sebastian instead.
- Tests cover all production code paths.
- Assert on real logic, never on mocked behavior — if you find such a test, stop and warn Sebastian. End-to-end tests use no mocks at all.
- Output must be pristine: a test that triggers an error on purpose captures it and asserts it is the expected one.
- No reflection in tests. Use stub classes (override the accessor, constructor-settable values) instead.
- Never commit tests that cannot be executed (no runner/infrastructure exists yet). A test that has never been red or green is an assertion of hope, not verification. If truly unavoidable, mark it explicitly as never-run and file the ticket that makes it runnable. (3 of 6 blind-written functional tests failed on their first-ever execution.)
