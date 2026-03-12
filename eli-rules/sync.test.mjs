import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { execFileSync } from "node:child_process";
import {
  mkdirSync,
  readdirSync,
  readFileSync,
  writeFileSync,
  rmSync,
} from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

const syncScript = join(import.meta.dirname, "sync.mjs");
const rulesDir = join(import.meta.dirname, "rules");
const sourceRules = readdirSync(rulesDir).filter((f) => f.endsWith(".md"));

function runSync(targetDir) {
  return execFileSync("node", [syncScript], {
    env: { ...process.env, INIT_CWD: targetDir },
    encoding: "utf-8",
  });
}

function listTargetRules(targetDir) {
  return readdirSync(join(targetDir, ".claude", "rules")).sort();
}

describe("sync", () => {
  let targetDir;

  beforeEach(() => {
    targetDir = join(tmpdir(), `eli-rules-test-${Date.now()}-${Math.random()}`);
    mkdirSync(targetDir, { recursive: true });
  });

  afterEach(() => {
    rmSync(targetDir, { recursive: true, force: true });
  });

  describe("when target directory has no existing rules", () => {
    it("creates .claude/rules/ directory", () => {
      runSync(targetDir);

      const files = listTargetRules(targetDir);
      expect(files.length).toBeGreaterThan(0);
    });

    it("copies all source rule files", () => {
      runSync(targetDir);

      const files = listTargetRules(targetDir);
      expect(files.length).toBe(sourceRules.length);
    });

    it("prefixes each file with the namespaced package name", () => {
      runSync(targetDir);

      const files = listTargetRules(targetDir);
      for (const file of files) {
        expect(file).toMatch(/^susu-eng--eli-rules--/);
      }
    });

    it("preserves original filename after the prefix", () => {
      runSync(targetDir);

      const files = listTargetRules(targetDir);
      const unprefixed = files.map((f) =>
        f.replace(/^susu-eng--eli-rules--/, ""),
      );
      expect(unprefixed.sort()).toEqual([...sourceRules].sort());
    });

    it("preserves file contents", () => {
      runSync(targetDir);

      const sourceContent = readFileSync(join(rulesDir, "kiss.md"), "utf-8");
      const targetContent = readFileSync(
        join(targetDir, ".claude", "rules", "susu-eng--eli-rules--kiss.md"),
        "utf-8",
      );
      expect(targetContent).toBe(sourceContent);
    });
  });

  describe("when target already has namespaced rules", () => {
    it("overwrites existing namespaced files with latest content", () => {
      runSync(targetDir);

      const targetPath = join(
        targetDir,
        ".claude",
        "rules",
        "susu-eng--eli-rules--kiss.md",
      );
      writeFileSync(targetPath, "stale content");

      runSync(targetDir);

      const content = readFileSync(targetPath, "utf-8");
      expect(content).not.toBe("stale content");
      expect(content).toBe(readFileSync(join(rulesDir, "kiss.md"), "utf-8"));
    });
  });

  describe("when target has non-namespaced files", () => {
    it("leaves files not prefixed with the package namespace untouched", () => {
      const rulesPath = join(targetDir, ".claude", "rules");
      mkdirSync(rulesPath, { recursive: true });
      writeFileSync(join(rulesPath, "my-custom-rule.md"), "custom content");
      writeFileSync(
        join(rulesPath, "other-pkg--rule.md"),
        "other package content",
      );

      runSync(targetDir);

      expect(readFileSync(join(rulesPath, "my-custom-rule.md"), "utf-8")).toBe(
        "custom content",
      );
      expect(readFileSync(join(rulesPath, "other-pkg--rule.md"), "utf-8")).toBe(
        "other package content",
      );
    });
  });

  describe("stdout", () => {
    it("logs the number of synced rules and target path", () => {
      const output = runSync(targetDir);

      expect(output.trim()).toBe(
        `@susu-eng/eli-rules: synced ${sourceRules.length} rules to ${join(targetDir, ".claude", "rules")}`,
      );
    });
  });
});
