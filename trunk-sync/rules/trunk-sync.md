# Trunk Sync

Every file write is auto-committed and pushed by a PostToolUse hook. Every edit is integrated to `origin/main` immediately — maximum continuous integration. This keeps multiple agents working against near-current trunk at all times.

## How it works

After every `Edit` or `Write`, the hook:

1. Commits the changed file with agent context
2. Pulls from `origin/main` (`--no-rebase`) and pushes to `origin/main`
3. Retries once if another agent pushed between pull and push

If another agent changed the same file, you get a merge conflict. The conflict and resolution work identically whether the other agent is in a local worktree or on a remote machine.

## When you see TRUNK-SYNC CONFLICT

Another agent changed the same file. Git left conflict markers in the file.

**Resolution — do exactly this:**
1. Read the conflicting file
2. Edit it to the correct content (remove the `<<<<<<<` / `=======` / `>>>>>>>` markers)
3. Done — the hook will detect the merge state and complete the sync automatically on your next edit

The hook handles all git operations — your only job is to fix the file contents using Edit.

## When you see TRUNK-SYNC CLOCK-IN

Another agent is working in this repo. Note the information (which agents, which branches, what tasks) and continue your work as planned. This is informational — no action is required unless you're concerned about a specific resource conflict (shared port, test database, etc.).

## Before you start

Run `git pull` once at the beginning of your session to start from the latest trunk. After that, the hook handles all pulls and pushes.

## Warning

- Do NOT run git commands — the hook handles all commits, pulls, pushes, and merge completions
- Do NOT edit or delete files in `.transcripts/` — these are auto-generated session snapshots
