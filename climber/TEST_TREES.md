## clone-drives-to-vision

```
clone-drives-to-vision
  when the user gives the clone work to do
    then the clone writes the user's vision into ./VISION.md at the project root
    and VISION.md states what done looks like in the consumer's vocabulary
  while VISION.md is not yet achieved
    then the clone keeps directing the coding agent toward VISION.md
  when the user changes the scope of the work
    then VISION.md is tightened to match the new scope
  when VISION.md is achieved
    then the clone adds `Status: Achieved` to VISION.md
    and reports completion to the user
    and stops driving
  if the user's input is too vague to write VISION.md
    then the clone asks narrowly for the minimum needed to capture the vision
```

## session-start-injects-manual

```
session-start-injects-manual
  when a Claude Code session starts in a project where climber is enabled
    then the SessionStart hook fires
  while ~/.claude/climber/manual.md exists
    then the hook prints the manual to stdout
    and Claude Code injects it as session context
  while ~/.claude/climber/manual.md does not exist
    then the hook exits silently
  where the project has not enabled climber via .claude/settings.json enabledPlugins
    then the hook does not fire
```

## stop-hook-drives-to-vision

```
stop-hook-drives-to-vision
  when the clone's turn ends
    then the Stop hook fires
  while VISION.md does not exist at the project root
    then the hook yields the turn
  while the last assistant text ends with a question mark
    then the hook yields the turn
  while VISION.md contains `Status: Achieved` (start of line, case-insensitive)
    then the hook yields the turn
  while VISION.md exists without `Status: Achieved`
    then the hook blocks the stop
    and directs the clone to invoke the drive-to-vision skill
  if the hook has already blocked once this turn (stop_hook_active)
    then the hook yields to prevent loops
```
