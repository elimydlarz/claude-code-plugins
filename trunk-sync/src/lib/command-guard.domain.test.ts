import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { classifyCommand } from "./command-guard.js";

describe("Domain: command-guard", () => {
  describe("classifyCommand", () => {
    describe("when a command does not start with git", () => {
      it("then it is allowed", () => {
        assert.deepEqual(classifyCommand("pnpm test"), { exitCode: 0 });
      });
    });

    describe("when git clone or a git command only inspects repository, worktree, or history state", () => {
      it("then it is allowed, including with read-only global and subcommand options", () => {
        const commands = [
          "git clone source target",
          "git diff --stat",
          "git log --oneline",
          "git log --oneline | head",
          "git show HEAD",
          "git status --short",
          "git branch --show-current",
          "git branch --list trunk-sync/*",
          "git tag --list v*",
          "git remote -v",
          "git remote get-url origin",
          "git worktree list",
          "git stash list",
          "git stash show stash@{0}",
          "git reflog show --oneline",
          "git blame src/index.ts",
          "git ls-files --modified",
          "git ls-tree HEAD",
          "git rev-parse --show-toplevel",
          "git for-each-ref --format=%(refname)",
          "git config --get user.email",
          "git -c color.ui=false status --short",
          "git --version",
          "git --no-pager log --oneline",
          "git -C repo clone source target",
          "git -C repo diff --stat",
          "git -C repo log --oneline",
          "git -C repo show HEAD",
          "git -C repo status --short",
        ];

        for (const command of commands) {
          assert.deepEqual(classifyCommand(command), { exitCode: 0 }, command);
        }
      });
    });

    describe("if a git command can change repository, worktree, configuration, or remote state", () => {
      it("then it is rejected with guidance that inspection is allowed and trunk-sync owns git writes", () => {
        const commands = [
          "git add .",
          "git branch feature",
          "git checkout main",
          "git clean -fd",
          "git commit -m forbidden",
          "git config user.email agent@example.com",
          "git fetch origin",
          "git merge feature",
          "git pull",
          "git push",
          "git reflog delete HEAD@{0}",
          "git remote add upstream source",
          "git reset --hard",
          "git restore file.txt",
          "git stash pop",
          "git switch main",
          "git tag v1.0.0",
          "git worktree add ../feature feature",
          "git status --short && git commit -m forbidden",
        ];

        for (const command of commands) {
          assert.deepEqual(classifyCommand(command), {
            exitCode: 2,
            stderr: "TRUNK-SYNC: Do NOT run write-side git commands. Read-only git inspection is allowed. Trunk-sync handles git writes; edit file contents instead.",
          }, command);
        }
      });
    });
  });
});
