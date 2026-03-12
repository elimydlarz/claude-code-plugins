#!/usr/bin/env node

import { readdirSync, readFileSync, copyFileSync, mkdirSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));

const projectRoot = process.env.INIT_CWD || process.cwd();

const pkg = JSON.parse(
  readFileSync(join(__dirname, "package.json"), "utf-8"),
);
const prefix = pkg.name.replace(/@/g, "").replace(/\//g, "--");

const sourceDir = join(__dirname, "rules");
const targetDir = join(projectRoot, ".claude", "rules");

mkdirSync(targetDir, { recursive: true });

const ruleFiles = readdirSync(sourceDir).filter((f) => f.endsWith(".md"));

for (const file of ruleFiles) {
  const targetName = `${prefix}--${file}`;
  copyFileSync(join(sourceDir, file), join(targetDir, targetName));
}

console.log(`${pkg.name}: synced ${ruleFiles.length} rules to ${targetDir}`);
