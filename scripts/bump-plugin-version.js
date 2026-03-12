#!/usr/bin/env node
// Bumps the version in a plugin.json file by the given increment (patch/minor/major).
// Usage: node bump-plugin-version.js <path-to-plugin.json> <patch|minor|major>

import { readFileSync, writeFileSync } from 'fs';

const [pluginPath, bump] = process.argv.slice(2);

if (!pluginPath || !['patch', 'minor', 'major'].includes(bump)) {
  console.error('Usage: bump-plugin-version.js <plugin.json> <patch|minor|major>');
  process.exit(1);
}

const plugin = JSON.parse(readFileSync(pluginPath, 'utf8'));
const [major, minor, patch] = plugin.version.split('.').map(Number);

if (bump === 'major') plugin.version = `${major + 1}.0.0`;
else if (bump === 'minor') plugin.version = `${major}.${minor + 1}.0`;
else plugin.version = `${major}.${minor}.${patch + 1}`;

writeFileSync(pluginPath, JSON.stringify(plugin, null, 2) + '\n');
console.log(plugin.version);
