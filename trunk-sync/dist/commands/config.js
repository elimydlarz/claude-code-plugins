import { execSync } from "node:child_process";
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { getGitRoot } from "../lib/git.js";
const DEFAULTS = {
    "commit-transcripts": "true",
    "target-branch": "agents",
};
const USAGE = `Usage: trunk-sync config                   Show all config
       trunk-sync config <key>               Get a value
       trunk-sync config <key>=<value>       Set a value
       trunk-sync config --unset <key>       Remove a key

Config file: .trunk-sync/config in the repo (key=value format), committed and synced like timecards and transcripts.`;
function configPath(repoRoot) {
    return join(repoRoot, ".trunk-sync", "config");
}
export function readConfig(repoRoot) {
    const map = new Map();
    let content;
    try {
        content = readFileSync(configPath(repoRoot), "utf-8");
    }
    catch {
        return map;
    }
    for (const line of content.split("\n")) {
        const trimmed = line.trim();
        if (!trimmed || trimmed.startsWith("#"))
            continue;
        const eq = trimmed.indexOf("=");
        if (eq === -1)
            continue;
        map.set(trimmed.slice(0, eq), trimmed.slice(eq + 1));
    }
    return map;
}
function writeConfig(repoRoot, map) {
    const lines = [];
    for (const [key, value] of map) {
        lines.push(`${key}=${value}`);
    }
    const path = configPath(repoRoot);
    mkdirSync(dirname(path), { recursive: true });
    writeFileSync(path, lines.join("\n") + "\n");
}
function escapeForShell(s) {
    return s.replace(/"/g, '\\"');
}
/**
 * A manual command, not something riding along on the next hook fire — so it
 * stages, commits, and best-effort pushes the change itself. Push failure
 * doesn't fail the command; the commit stands locally for the next sync.
 */
function commitAndSyncConfig(repoRoot, message) {
    execSync(`git add -- ".trunk-sync/config"`, { cwd: repoRoot, stdio: "ignore" });
    try {
        execSync(`git commit -m "${escapeForShell(message)}"`, { cwd: repoRoot, stdio: "ignore" });
    }
    catch {
        return; // nothing changed
    }
    try {
        execSync("git remote get-url origin", { cwd: repoRoot, stdio: "ignore" });
    }
    catch {
        return; // no remote to push to
    }
    const targetBranch = readConfig(repoRoot).get("target-branch") ?? DEFAULTS["target-branch"];
    try {
        execSync(`git push origin "HEAD:${targetBranch}"`, { cwd: repoRoot, stdio: "ignore" });
    }
    catch {
        // best-effort — the commit stands locally for the next sync to pick up
    }
}
function resolveRepoRoot() {
    const existing = getGitRoot();
    if (existing)
        return existing;
    execSync("git init", { stdio: "ignore" });
    return getGitRoot();
}
export function configCommand(args) {
    if (args.includes("--help") || args.includes("-h")) {
        console.log(USAGE);
        return;
    }
    const repoRoot = resolveRepoRoot();
    const unsetIndex = args.indexOf("--unset");
    if (unsetIndex !== -1) {
        const key = args[unsetIndex + 1];
        if (!key) {
            console.error("Usage: trunk-sync config --unset <key>");
            process.exit(1);
        }
        const map = readConfig(repoRoot);
        if (!map.has(key)) {
            console.error(`Key not found: ${key}`);
            process.exit(1);
        }
        map.delete(key);
        writeConfig(repoRoot, map);
        commitAndSyncConfig(repoRoot, `auto: unset ${key}`);
        console.log(`Unset ${key}`);
        return;
    }
    const positional = args.filter((a) => !a.startsWith("--"));
    if (positional.length === 0) {
        const merged = new Map(Object.entries(DEFAULTS));
        for (const [key, value] of readConfig(repoRoot)) {
            merged.set(key, value);
        }
        for (const [key, value] of merged) {
            console.log(`${key}=${value}`);
        }
        return;
    }
    const arg = positional[0];
    const eq = arg.indexOf("=");
    if (eq === -1) {
        // Single key — read its value
        const map = readConfig(repoRoot);
        const value = map.get(arg) ?? DEFAULTS[arg];
        if (value === undefined) {
            console.error(`Unknown key: ${arg}`);
            process.exit(1);
        }
        console.log(value);
        return;
    }
    const key = arg.slice(0, eq);
    const value = arg.slice(eq + 1);
    const map = readConfig(repoRoot);
    map.set(key, value);
    writeConfig(repoRoot, map);
    commitAndSyncConfig(repoRoot, `auto: config ${key}=${value}`);
    console.log(`Set ${key}=${value}`);
}
