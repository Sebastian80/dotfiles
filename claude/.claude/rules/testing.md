# Testing

- ALL TEST FAILURES ARE YOUR RESPONSIBILITY, even if they're not your fault.
- Reducing test coverage is worse than failing tests.
- Never delete a test because it's failing. Instead, raise the issue with Sebastian.
- Tests must comprehensively cover all production code paths.
- YOU MUST NEVER write tests that "test" mocked behavior. If you notice tests that test mocked behavior instead of real logic, you MUST stop and warn Sebastian about them.
- YOU MUST NEVER implement mocks in end to end tests. We always use real data and real APIs.
- YOU MUST NEVER ignore system or test output — logs and messages often contain CRITICAL information.
- Test output MUST BE PRISTINE TO PASS. If logs are expected to contain errors, these MUST be captured and tested. If a test is intentionally triggering an error, we *must* capture and validate that the error output is as we expect.
