---
name: tdd
description: "Enforces test-driven development with human-readable test tree output. TRIGGER when: changing behaviour, interfaces, or tests."
---

# Test-driven development
*All behaviour and/or logic changes must be test driven.* Are you implementing? Ensure you have already written a test! No untested changes!

## Test Tree Format
Structure tests so the output reads as a human-readable specification of operating principles:

**GOOD** — describes operating principles (valid, available components are rendered with props):
```text
GeneratedComponent
  when component is valid
    and props are available
      then component is rendered with props
    and props are NOT available
      then component is NOT rendered
  when component is invalid
    then component is NOT rendered
```

**GOOD** — describes operating principles (accepts 0-3 queries):
```text
searchMemoryTool
  parameters schema
    when <= 3 queries provided
      then accepts
    when > 3 queries provided
      then rejects
```

**BAD** — Enumerates specific cases and leaves the reader to infer operating principles (accepts up to 3 queries):
```text
searchMemoryTool
  parameters schema
    when 0 queries provided then accepts
    when 1 query provided then accepts
    when 2 query provided then accepts
    when 3 queries provided then accepts
    when 4 queries provided then rejects
```

## Tests as Contract
*Your test trees are contracts with me* - what you promise our software is doing. That's why you always write tests that produce behaviour-descriptive, human-readable test output when run. You structure such that the output is a *test tree*.

## Tests as Documentation
Tests must describe operating principles, not just specific cases.

This is *BAD*:
```
searchMemoryTool
  parameters schema
    when 1 query provided then accepts
    when 3 queries provided then accepts
    when 0 queries provided then rejects
    when 4 queries provided then rejects
```
It describes specific cases, but not the key operating principles - in this case <= 3 queries are accepted, and > 3 queries are rejected.

So a *GOOD* approach would be:
```
searchMemoryTool
  parameters schema
    when <= 3 queries provided then accepts
    when > 3 queries provided then rejects
```
This is more descriptive, and also less reading and less test code.

It's also important to name the test subject. The top level `describe` should name the export being tested. If there are multiple exports being tested we should describe the implementation filename, with describe blocks for each export nested within.

During TDD, you may create many tests that ultimately exercise the same handling, and elide the same operating principle. In such cases, you can refactor the tests into a smaller, more descriptive set as above.

## Process
1. **RED** Write a failing test for the next most obvious behavior - something that the current implementation gets wrong, or has not approached yet:
   - Ensure test output will produce a great test tree.
2. **IMPLEMENT** Write only enough code to make the test pass, avoiding over-engineering (YAGNI)
3. **GREEN** Confirm tests pass (ideally run generic fast change verification command).
4. **REFACTOR** Rework implementation for:
   - Simplicity (KISS)
   - Expressiveness
5. **REPEAT** (GOTO 1)

## Style
You practice London-school TDD, but it's _really_ about being consumer-driven:
- Think about all changes from the perspective of the consumer.
- You only implement things that you *know* you need, because you have already created a consumer that needs them.
Here, that means:
- You start with the outermost surface (typically the UI) - and work your way to the innermost layer (typically some DB).
- You may have to mock things in tests, and implement some stubs to make type checking happy. That's OK.

## Rules
- Always create unit tests.
- Only create integration tests when explicitly directed:
  - Integration tests do NOT obviate the need for unit tests.
- Colocate each test file with the test subject file.
- When in plan mode or otherwise discussing changes with the user, always explain proposed behaviour changes using test trees.
- *Only one failing test at a time*
- If you see an unrelated test is failing, stop and suggest fixing it first.
- If you see a related test is failing, fix it and continue your work.
- If you see a test file is missing, in the wrong place, or has the wrong name, fix it:
  - Make sure the test file is actually missing and not just renamed or in the wrong place before creating a new one.
- Interpose `.unit.test` (for unit tests) or `.int.test` (for integration tests) in between the test subject file name and suffix.
  - E.g `some-subject.ts` might have test files `some-subject.unit.test.ts` and `some-subject.int.test.ts`
- *Fail fast* when deciding what scenarios to test and what to expect, allow errors for unexpected scenarios unless they will be incomprehensible at runtime (assume good observability).

