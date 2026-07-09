# Describe/It Drift Fixture

A tiny Bookmark module used by Contree functional tests to verify sync reporting.

## Install

No install step is required for the fixture.

## Configure

No configuration is required.

## Use

```js
import { parseUrl } from './src/bookmark.js'

parseUrl('https://example.com')
```

## Test

The fixture is exercised by `test/journey/docker-entrypoint.sh describe-it-drift`.
