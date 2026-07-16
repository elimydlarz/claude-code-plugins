export interface HookInput {
  tool_name: string | null;
  tool_input: { file_path?: string };
  turn_id: string | null;
  session_id: string | null;
  transcript_path: string | null;
  cwd?: string | null;
}

export interface RepoState {
  repoRoot: string;
  gitDir: string;
  relPath: string | null;
  insideRepo: boolean;
  gitignored: boolean;
  hasRemote: boolean;
  currentBranch: string;
  inMerge: boolean;
  deletedFiles: string[];
  modifiedFiles: string[];
  untrackedFiles: string[];
}

export interface SyncPlan {
  currentBranch: string;
}

export interface CommitPlan {
  changedPaths: string[];
  subject: string;
  body: string | null;
}

export type HookPlan =
  | { action: "skip" }
  | { action: "commit-and-sync"; commit: CommitPlan; sync: SyncPlan | null }
  | { action: "commit-merge"; commit: CommitPlan; sync: SyncPlan | null };

export interface Timecard {
  sessionId: string;
  hostname: string;
  clockedInAt: string;
  lastActiveAt: string;
  branch: string;
}

export interface RuntimeContext {
  hostname: string;
}

export const HOOK_EXPLAINER =
  "A PostToolUse hook automatically commits and syncs every file change to keep multiple agents in sync on trunk.";
