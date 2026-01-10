---
description: Systematic debugging workflow
---

Debug the following issue systematically: $ARGUMENTS

## Phase 1: Reproduce
- Understand the exact steps to reproduce
- Identify expected vs actual behavior
- Note any error messages or logs

## Phase 2: Isolate
- When did this start happening?
- What changed recently?
- Is it environment-specific?

## Phase 3: Investigate
- Check relevant logs: `make log`
- Add temporary debugging (xdebug, var_dump, logger)
- Trace the execution flow

## Phase 4: Root Cause
- Why is this happening?
- Is this a symptom of a deeper issue?
- Are there related issues?

## Phase 5: Fix
- Implement the minimal fix
- Ensure no side effects
- Add test to prevent regression

## Phase 6: Verify
- Confirm the fix works
- Run full test suite
- Clean up debug code
