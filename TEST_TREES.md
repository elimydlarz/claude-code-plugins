# Test Trees

## Adapter: plugin-release

```
Adapter: plugin-release (src: scripts/publish-contree.sh, scripts/publish-trunk-sync.sh; adapter: test/adapter/plugin-release.adapter.test.mjs)

  when either release command is missing a semantic version change kind
    then it fails before release side effects and identifies patch, minor, and major as valid kinds
  when either release command has a semantic version change kind
    then it does not build or run tests
    and it leaves pushing commits and tags to trunk-sync
```
