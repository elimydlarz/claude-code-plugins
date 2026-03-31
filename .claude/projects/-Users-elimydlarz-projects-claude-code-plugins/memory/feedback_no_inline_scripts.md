---
name: No inline scripting in Bash tool
description: Never pipe complex inline scripts — write reusable shell scripts to disk instead
type: feedback
---

Never write complex inline scripts (python one-liners, long pipes, heredocs) in the Bash tool. Write reusable shell scripts to the project, then invoke them.

**Why:** Inline scripts are unreadable, trigger permission prompts that are impossible to review, and waste context. The user will clear context if this happens again.

**How to apply:** Any time you need to process files (parse JSON, extract data, analyse transcripts), write a shell script to disk first, then run it. Keep Bash tool calls to simple, short commands.
