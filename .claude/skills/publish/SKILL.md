---
name: publish
description: "Publish a plugin from this repo end-to-end: review commits since the last tag, draft release notes, run the publish script. TRIGGER when the user says 'publish <plugin>', 'release <plugin>', 'cut a release', 'ship contree/trunk-sync', or asks to publish without specifying how."
---

# Publish a plugin

Drives `scripts/publish-<plugin>.sh` end-to-end. The script requires `--notes-file`; this skill produces the notes file from the actual commit history so the human never has to draft notes manually.

## Plugins and their tag prefixes

| Plugin | Script | Tag prefix |
|---|---|---|
| `contree` | `publish-contree.sh` | `contree-v` |
| `trunk-sync` | `publish-trunk-sync.sh` | `v` |

## Process

### 1. Resolve plugin and bump

From the user's request, pick `<plugin>` and `<bump>` (`patch`/`minor`/`major`). If bump isn't given, default to `patch` — that's almost always the right call for these plugins.

### 2. Review commits since last tag

`git` commands may be blocked by trunk-sync. Use `.git/refs/tags/` directly to discover the last tag, and rely on conversation context (what you just did) for the substance of the changes:

```
ls .git/refs/tags/ | grep <tag-prefix> | sort -V | tail -1
```

Then read the actual diff for any commit whose message is uninformative (the `auto(...)` commits from trunk-sync usually need this) so the notes describe real user-visible changes, not commit-message noise. Group related commits into one bullet rather than one-per-commit.

**Concurrent sessions publish on this trunk too.** Before drafting notes, confirm the work isn't already shipped: `git diff <last-tag> -- <plugin>/` — if empty, another session already published exactly this state (check `gh release view <last-tag>` to confirm); stop and report that instead of re-publishing. If non-empty, the diff is what's actually pending — draft notes from that, not from everything since the tag.

### 3. Draft notes

Write to `/tmp/<plugin>-notes.md`. Format:

```markdown
## What's new

- **<Headline change>.** One sentence on user-visible impact.
- **<Next change>.** One sentence.
```

Notes describe **what changed for users**, not what files were touched. If a change is purely internal (refactor, test-only, hook plumbing with no behavioural effect), say so plainly — don't pad. Skip notes-worthy framing for changes that don't reach the user.

Do not pause for sign-off — proceed.

### 4. Run the publish

```
pnpm publish:<plugin> <bump> --notes-file /tmp/<plugin>-notes.md
```

The script handles: clean-source check, version bump, commit, annotated tag, push with `--follow-tags`, GitHub release. trunk-sync also publishes to npm.

**Auth:** trunk-sync's publish script reads `TRUNK_SYNC_PUBLISHER` from `$REPO_ROOT/.env`, writes it to a temp `trunk-sync/.npmrc` as `//registry.npmjs.org/:_authToken`, and runs `pnpm publish --no-git-checks`. The token is a scoped npm publish token with 2FA disabled. If publish fails with E401/E404, the `.env` token is stale or scope-restricted — the user regenerates it.

**Never verify a publish with a global install** (`npm install -g` / `pnpm add -g`). Nothing in this repo tracks or cleans up global installs, so each one is permanent local machine state that silently drifts from the published version — this is exactly how the machine ended up with three dead trunk-sync identities (`trunk-sync@2.2.0` unscoped, `@susu-eng/trunk-sync`, and stale `@elimydlarz/trunk-sync` versions) before a 2026-07-05 cleanup. To confirm a publish reached the registry, use `npm view @elimydlarz/trunk-sync version` (no local state) or `npx --yes @elimydlarz/trunk-sync@latest --version` (ephemeral, not installed).

### 5. Update local marketplace and reinstall

Both publish scripts do this automatically: refresh the local marketplace cache, then `claude plugin update <plugin>@elimydlarz` (falling back to `install` if it's not installed yet). `install` alone is a no-op once a plugin is already present — it doesn't check for a newer version — so `update` is required to actually pick up the new version on an existing install.

### 6. If it fails

- **"Uncommitted changes"** — stop and surface the dirty files. Do not auto-commit; the user owns scope.
- **"tag exists locally but has not been pushed"** — this used to happen with lightweight tags; the scripts now use annotated tags so `--follow-tags` carries them. If it recurs, fix the script, don't paper over with a manual push.
- **`gh release create` fails for any other reason** — the commit and tag are already on GitHub. Re-run only the release step: `gh release create <tag> --title "<plugin> v<version>" --notes-file /tmp/<plugin>-notes.md`.
- **npm deprecate fails** — deprecation targets a different scope than publish, so the publish token may lack write access. The scoped publish token covers `@elimydlarz`; deprecating `@susu-eng/trunk-sync` requires a token with write access to `@susu-eng`. Use the global `~/.npmrc` token (may require `--otp`), or create an automation token for the old scope.

## What this skill is not

It is not a place to discuss whether to publish, what should be in the release, or whether the version bump is right. Those are upstream decisions. By the time this skill runs, the user has decided to ship — execute.
