# test-trees

Claude Code plugin that enforces outside-in TDD with test trees at every layer.

## Principles

1. **Outside-in, always.** Every behaviour change starts with a failing functional test, then TDDs inward through unit layers. You only build what a real consumer demands.
2. **Tests are specifications.** Test tree output reads as a human-readable description of operating principles — not an enumeration of cases. The tree is the contract.
3. **Two test layers, different jobs.** Functional tests prove the system works end-to-end (no mocks). Unit tests drive internal design with fast, precise feedback (mocked collaborators). Neither replaces the other.
4. **One failing test at a time.** Red → green → refactor, one step at a time, layer by layer.
5. **Mutation testing validates finished work.** Stryker checks whether unit tests actually assert meaningful behaviour. It runs at the end of completed work, not during the TDD cycle.
6. **Tree output at every layer.** Unit tests, functional tests — all produce nested, indented, tree-shaped output by default.

## Skills

- **`tdd`** — instructs Claude to follow the outside-in TDD cycle when changing behaviour, interfaces, or tests. Not a slash command — activates via its description field when relevant.
- **`setup-test-trees`** (`/setup-test-trees`) — one-time project setup. Configures unit test runner, functional test runner, Stryker, tree-style reporters, and changed-test runners. Updates the project's CLAUDE.md with concrete commands.

## Install

```
claude plugin marketplace add elimydlarz/claude-code-plugins
claude plugin install test-trees
```
