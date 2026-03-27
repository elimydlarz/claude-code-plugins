/** Raw JSON from Claude's PostToolUse hook stdin */
export interface HookInput {
  tool_name: string | null;
  tool_input: { file_path?: string };
  session_id: string | null;
  transcript_path: string | null;
}

/** Git state gathered before planning */
export interface RepoState {
  repoRoot: string;
  gitDir: string;
  /** file_path relative to repoRoot, or null if no file_path */
  relPath: string | null;
  /** true when file_path is inside the repo */
  insideRepo: boolean;
  /** true when file_path is gitignored */
  gitignored: boolean;
  /** true when origin remote exists */
  hasRemote: boolean;
  /** default branch on origin (e.g. "main"), empty when no remote */
  targetBranch: string;
  /** current branch name */
  currentBranch: string;
  /** true when MERGE_HEAD exists */
  inMerge: boolean;
  /** true when staging area has changes */
  hasStagedChanges: boolean;
  /** tracked files that have been deleted from the working tree */
  deletedFiles: string[];
  /** tracked files with modifications (content or permissions) in the working tree */
  modifiedFiles: string[];
}

export interface SyncPlan {
  targetBranch: string;
  currentBranch: string;
}

export interface CommitPlan {
  filesToStage: string[];
  filesToRemove: string[];
  subject: string;
  body: string | null;
}

export type HookPlan =
  | { action: "skip" }
  | { action: "commit-and-sync"; commit: CommitPlan; sync: SyncPlan | null; clockIn: ClockInPlan | null }
  | { action: "commit-merge"; message: string; sync: SyncPlan | null; clockIn: ClockInPlan | null };

/** An agent's timecard — persisted to .trunk-sync/timeclock/<session-id>.json */
export interface Timecard {
  sessionId: string;
  pid: number;
  hostname: string;
  clockedInAt: string; // ISO 8601
  lastActiveAt: string; // ISO 8601
  branch: string;
  task: string | null; // what the agent is working on (from transcript)
}

/** Plan for clocking in (writing/updating a timecard) */
export interface ClockInPlan {
  /** Relative path: .trunk-sync/timeclock/<session-id>.json */
  timecardPath: string;
  timecard: Timecard;
}

/** Runtime context not available in RepoState (I/O-derived) */
export interface RuntimeContext {
  pid: number;
  hostname: string;
}

export const HOOK_EXPLAINER =
  "A PostToolUse hook automatically commits and syncs every file change to keep multiple agents in sync on trunk.";
