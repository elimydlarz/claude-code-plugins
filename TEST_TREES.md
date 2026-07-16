# Test Trees

## Adapter: plugin-release

```
Adapter: plugin-release (src: scripts/bump-plugin-version.js, scripts/publish-contree.sh, scripts/publish-trunk-sync.sh, trunk-sync/scripts/bump-plugin-manifests.js, trunk-sync/package.json, trunk-sync/tsconfig.json, trunk-sync/.gitignore, contree/.claude-plugin/plugin.json, contree/.codex-plugin/plugin.json, trunk-sync/.claude-plugin/plugin.json, trunk-sync/.codex-plugin/plugin.json; adapter: test/adapter/plugin-release.adapter.test.mjs)

  when either release command is missing a semantic version change kind
    then it fails before release side effects and identifies patch, minor, and major as valid kinds
  if either release command receives an unknown argument
    then it fails before release side effects and identifies the unknown argument
  when either release command is missing release notes
    then it fails before release side effects and provides the scoped history command for preparing them
  if the supplied release-notes path does not exist
    then it fails before release side effects and identifies the missing path
  if Trunk Sync source changes are uncommitted
    then publishing fails before building, bumping, or publishing and identifies the dirty source
  if Trunk Sync has no checked-out branch
    then publishing fails before building, bumping, or publishing and requires a checked-out branch
  if Contree source changes are uncommitted
    then publishing fails before bumping or publishing and identifies the dirty source
  if Contree has no checked-out branch
    then publishing fails before bumping or publishing and requires a checked-out branch
  if either Contree plugin manifest cannot be written
    then publishing fails and both manifests retain their original contents
  when the Trunk Sync release command publishes
    then it builds the marketplace runtime files without running tests
    and stale or untracked runtime output is replaced by the generated bundle
    and the release commit includes the generated marketplace runtime files
    and unrelated staged changes remain outside the release commit
    and it atomically pushes the release commit and annotated tag before creating the GitHub release
    if either ref is rejected by the remote
      then neither ref is published and no GitHub release is created
      and the generated local release commit and tag are removed so the same version bump can be retried
  when the Contree release command has a semantic version change kind
    then it does not build or run tests
  when the Contree release command publishes
    then it atomically pushes the release commit and annotated tag before creating the GitHub release
    and it refreshes the marketplace installation
    and unrelated staged changes remain outside the release commit
    if either ref is rejected by the remote
      then neither ref is published and no GitHub release is created
      and the generated local release commit and tag are removed so the same version bump can be retried
  when the Contree release command publishes from a version with build metadata
    then the requested semantic component advances from the base version and the released version is canonical
```
