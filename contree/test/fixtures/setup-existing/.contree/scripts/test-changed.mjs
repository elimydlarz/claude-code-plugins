import { createHash } from 'node:crypto'
import { existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from 'node:fs'
import { spawnSync } from 'node:child_process'
import { join, relative } from 'node:path'

const root = process.cwd()
const stateDir = join(root, '.contree', 'state')
const stateFile = join(stateDir, 'test-files.json')
const excluded = new Set(['.git', '.codex-home', 'node_modules'])

function filesIn(directory) {
  return readdirSync(directory, { withFileTypes: true }).flatMap(entry => {
    if (excluded.has(entry.name) || directory === stateDir) return []
    const path = join(directory, entry.name)
    return entry.isDirectory() ? filesIn(path) : [relative(root, path)]
  })
}

function snapshot() {
  return Object.fromEntries(filesIn(root).sort().map(path => [
    path,
    createHash('sha256').update(readFileSync(join(root, path))).digest('hex'),
  ]))
}

function run(command, args) {
  return spawnSync(command, args, { cwd: root, stdio: 'inherit' }).status ?? 1
}

const current = snapshot()
if (!existsSync(stateFile)) {
  const status = run('npm', ['test'])
  if (status !== 0) process.exit(status)
  mkdirSync(stateDir, { recursive: true })
  writeFileSync(stateFile, JSON.stringify(current))
  process.exit(0)
}

const previous = JSON.parse(readFileSync(stateFile, 'utf8'))
const changed = [...new Set([...Object.keys(previous), ...Object.keys(current)])]
  .filter(path => previous[path] !== current[path])

if (changed.length === 0) process.exit(0)

const shared = new Set(['package.json', 'package-lock.json', 'vitest.config.js'])
const status = changed.some(path => shared.has(path))
  ? run('npm', ['test'])
  : run('npx', ['vitest', 'related', '--config', 'vitest.config.js', ...changed])

if (status !== 0) process.exit(status)
writeFileSync(stateFile, JSON.stringify(current))
