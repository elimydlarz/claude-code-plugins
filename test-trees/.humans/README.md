# test-trees

A Claude Code plugin that enforces outside-in TDD with human-readable test tree output.

## What it does

When installed, this plugin teaches Claude to:

1. **Start every behaviour change with a failing functional test** — proving what the system should do from the user's perspective, end-to-end, no mocks.
2. **TDD inward through unit tests** — one failing test at a time, mocking collaborators, driving the internal design from the outside in.
3. **Rise back up** — when enough unit-level code exists, the functional test passes.
4. **Validate with mutation testing** — at the end of completed work, Stryker checks that your unit tests actually assert something meaningful.

All test output is **tree-shaped** — nested, indented, and readable as a specification of what the software does:

```
UserRegistration
  when a new user registers with valid details
    then the user account is created
    and a welcome email is sent
  when a new user registers with a duplicate email
    then registration is rejected
```

## Principles

1. **Outside-in, always.** Functional test first, then unit tests inward. You only build what's needed.
2. **Tests are specifications.** Tree output describes operating principles, not case enumerations.
3. **Two test layers, different jobs.** Functional = end-to-end proof. Unit = design driver + fast feedback.
4. **One failing test at a time.** Discipline in the cycle.
5. **Mutation testing validates finished work.** Not during development — only at the end.
6. **Tree output at every layer.** Nested, indented, readable by default.

## Setup

```bash
# Add the marketplace and install
claude plugin marketplace add elimydlarz/claude-code-plugins
claude plugin install test-trees

# Then run the setup skill in your project
/setup-test-trees
```

The setup skill will configure your test runners, Stryker, tree-style reporters, and update your project's CLAUDE.md with the right commands.

## Skills

| Skill | Invocation | What it does |
|-------|-----------|--------------|
| `tdd` | Automatic (when changing behaviour/interfaces/tests) | Enforces the outside-in TDD cycle |
| `setup-test-trees` | `/setup-test-trees` | One-time project setup for all test layers |
