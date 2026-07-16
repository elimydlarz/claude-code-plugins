import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { classifyCommand } from "./command-guard.js";

describe("Domain: command-guard", () => {
  describe("classifyCommand", () => {
    describe("when a command contains no recognized Git invocation", () => {
      it("then it is allowed, including compound shell commands", () => {
        for (const command of [
          "",
          "   ",
          "pnpm test",
          "cd repo && pnpm test",
          "FOO=x pnpm test",
          "env FOO=x pnpm test",
          "sudo -n true",
          "time pnpm test",
          "! false",
          "echo \"$(printf git)\"",
          "printf 'git push'",
          "printf \"git push; git commit\"",
          "printf \"value;$G push\"",
          "printf 'g$G push'",
          "printf '$(git push)'",
          "echo /bin/sh -c git push",
          "printf value > git",
        ]) {
          assert.deepEqual(classifyCommand(command), { exitCode: 0 }, command);
        }
      });
    });

    describe("when standalone git clone or a standalone git command only inspects repository, worktree, or history state", () => {
      it("then it is allowed, including with read-only global and subcommand options", () => {
        const commands = [
          "git annotate file.txt",
          "git cat-file -t HEAD",
          "git cherry main",
          "git count-objects -v",
          "git describe --always",
          "git clone source target",
          "git diff --stat",
          "git diff-files",
          "git diff-index HEAD",
          "git diff-tree HEAD",
          "git grep pattern",
          "git help status",
          "git log --oneline",
          "git ls-remote origin",
          "git show HEAD",
          "git show-branch",
          "git show-index",
          "git show-ref",
          "git status --short",
          "git merge-base HEAD HEAD",
          "git name-rev HEAD",
          "git range-diff HEAD~1 HEAD HEAD~1 HEAD",
          "git rev-list HEAD",
          "git shortlog HEAD",
          "git verify-commit HEAD",
          "git verify-pack pack.idx",
          "git verify-tag v1",
          "git version",
          "git whatchanged HEAD",
          "git branch --show-current",
          "git branch --column",
          "git branch",
          "git branch -a",
          "git branch -r",
          "git branch -v",
          "git branch -av",
          "git branch --all",
          "git branch --list trunk-sync/*",
          "git tag --list v*",
          "git tag -l v*",
          "git tag -n",
          "git tag -n3",
          "git tag",
          "git remote -v",
          "git remote --verbose",
          "git remote -v --verbose",
          "git remote",
          "git remote get-url origin",
          "git remote show origin",
          "git worktree list",
          "git stash list",
          "git stash show stash@{0}",
          "git reflog",
          "git reflog exists HEAD",
          "git reflog show --oneline",
          "git blame src/index.ts",
          "git ls-files --modified",
          "git ls-tree HEAD",
          "git rev-parse --show-toplevel",
          "git for-each-ref '--format=%(refname)'",
          "git config --get user.email",
          "git config --get-all user.email",
          "git config --get-regexp '^user\\.'",
          "git config --get-urlmatch url.https://example.com",
          "git config --list",
          "git config -l",
          "git config get user.email",
          "git config list",
          "git -c color.ui=false status --short",
          "git --config-env=credential.helper=HELPER status --short",
          "git --config-env credential.helper=HELPER status --short",
          "git --git-dir .git status --short",
          "git --namespace namespace status --short",
          "git --super-prefix prefix status --short",
          "git --work-tree . status --short",
          "  git   status   --short  ",
          "git --version",
          "git --help",
          "git --no-pager log --oneline",
          "git log --format='value;still-one-command'",
          "git log --format=\"value>still-one-command\"",
          "git log --format=value\\;still-one-command",
          "git status '$(printf main)'",
          "git status \"\\$(printf main)\"",
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

    describe("if a Git invocation is composed with another shell command", () => {
      it("then it is rejected with guidance to run standalone Git inspection", () => {
        const commands = [
          "cd repo && git commit -m forbidden",
          "git status && git push",
          "git status; pnpm test",
          "git status\npnpm test",
          "git status & pnpm test",
          "git status < input.txt",
          "git status > output.txt",
          "(git push)",
          "(((git push)))",
          "command git push",
          "command -p git push",
          "time git push",
          "! git push",
          "G=it; g$G push",
          "command /usr/bin/git push",
          "env git push",
          "env -i FOO=x git push",
          "FOO=x git push",
          "FOO='x y' git push",
          "_FOO1=x git push",
          "sudo git push",
          "sudo -n git push",
          "exec git push",
          "nice git push",
          "nohup git push",
          "/usr/bin/git push",
          "g\\it push",
          "echo $(git push)",
          "echo \"$(git push)\"",
          "echo `git push`",
          "sh -c 'git push'",
          "/bin/sh -c 'git push'",
          "/bin/sh -c 'g\\it push'",
          "/usr/bin/env sh -c 'git push'",
          "sudo /bin/sh -c 'git push'",
          "FOO=x /bin/sh -c 'git push'",
          "pnpm test && /bin/sh -c 'git push'",
          "bash --noprofile -c 'git push'",
          "bash -c \"git push\"",
          "eval 'git push'",
          "eval 'g\\it push'",
          "command eval 'git push'",
          "pnpm test && eval 'git push'",
          "$(printf git) push",
          "command $(printf git) push",
          "env FOO=x $(printf git) push",
          "G=git; $G push",
          "G=git; \"$G\" push",
          "G=git; \"${G}\" push",
          "G=/usr/bin; \"$G\"/git push",
          "G=/usr/bin; \"${G}\"/git push",
          "${GIT:-git} push",
          "git status \"$(eval 'git push')\"",
          "git status \"$(printf main)\"",
          "git status `printf main`",
          "git log --oneline | head",
        ];

        for (const command of commands) {
          const decision = classifyCommand(command);
          assert.equal(decision.exitCode, 2, command);
          if (decision.exitCode !== 2) continue;
          assert.match(decision.stderr, /standalone Git inspection/, command);
        }
      });

      it("and shell command-string wrappers with absolute paths or combined options, `eval`, escaped or quoted executable spellings, quoted assignment prefixes, executable command-position expansion, and substitutions inside Git arguments are rejected", () => {
        for (const command of [
          "/bin/sh -c 'git push'",
          "bash -lc 'git push'",
          "/bin/sh -xec 'git push'",
          "/bin/sh -c 'g\\it push'",
          "sudo /bin/sh -c 'git push'",
          "FOO=x /bin/sh -c 'git push'",
          "command eval 'git push'",
          "eval 'g\\it push'",
          "command -p git push",
          "time git push",
          "! git push",
          "G=it; g$G push",
          "\"git\" push",
          "'git' push",
          "g\"it\" push",
          "$'git' push",
          "g$(printf it) push",
          "FOO='x y' git push",
          "command $(printf git) push",
          "G=git; $G push",
          "G=git; \"$G\" push",
          "G=git; \"${G}\" push",
          "G=/usr/bin; \"$G\"/git push",
          "G=/usr/bin; \"${G}\"/git push",
          "${GIT:-git} push",
          "git status \"$(eval 'git push')\"",
        ]) {
          assert.equal(classifyCommand(command).exitCode, 2, command);
        }
      });
    });

    describe("if a git command can change repository, worktree, configuration, or remote state", () => {
      it("then it is rejected with guidance that inspection is allowed and trunk-sync owns git writes", () => {
        const commands = [
          "git add .",
          "git",
          "git --help extra",
          "git --version extra",
          "git branch feature",
          "git branch -d feature",
          "git branch --list -d feature",
          "git branch -d feature --list",
          "git branch -D feature",
          "git branch -m old new",
          "git branch -M old new",
          "git branch -c old new",
          "git branch -C old new",
          "git branch -f feature",
          "git branch -t feature",
          "git branch -u origin/main feature",
          "git branch --copy old new",
          "git branch --create-reflog feature",
          "git branch --delete=feature",
          "git branch --edit-description feature",
          "git branch --force feature",
          "git branch --move old new",
          "git branch --set-upstream-to=origin/main feature",
          "git branch --track feature origin/main",
          "git branch --unset-upstream feature",
          "git checkout main",
          "git clean -fd",
          "git commit -m forbidden",
          "git config user.email agent@example.com",
          "git diff --output=changed.patch",
          "git diff --output changed.patch",
          "git diff --ext-diff",
          "git diff --textconv",
          "git fetch origin",
          "git merge feature",
          "git pull",
          "git push",
          "git reflog delete HEAD@{0}",
          "git remote add upstream source",
          "git remote -v extra",
          "git remote --verbose extra",
          "git reset --hard",
          "git restore file.txt",
          "git stash pop",
          "git switch main",
          "git tag v1.0.0",
          "git worktree add ../feature feature",
          "git -C",
          "git -C repo",
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
