// Project configuration for the sandcastle orchestrator.
//
// Everything project-specific lives in `.sandcastle/config.json`. The schema
// below documents each field and supplies a default, so a new project only has
// to declare what actually differs.
//
// The defaults below are Node-shaped, as shipped upstream. This repo is an Xcode
// project and overrides them in `config.json`; see `.sandcastle/PORTING.md` for
// what else the toolchain change required.

import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { z } from "zod";

const SANDCASTLE_DIR = dirname(dirname(fileURLToPath(import.meta.url)));

const configSchema = z.object({
  linear: z.object({
    /** Linear project name. Omit to select on label + team alone. */
    project: z.string().nullable().default(null),
    /** Only issues carrying this label are eligible for agent work. */
    label: z.string().default("ready-for-agent"),
    /** Workflow state applied once a feature's PR is open. */
    reviewState: z.string().default("In Review"),
  }),
  git: z.object({
    /** Remote to push integration branches to, and to resolve the GitHub repo from. */
    remote: z.string().default("origin"),
    /** Branch the work is based on, and the PR target. */
    baseBranch: z.string().default("main"),
    /** Prefix for per-issue working branches. Must be deterministic. */
    branchPrefix: z.string().default("sandcastle/issue-"),
    /**
     * GitHub repo as `owner/name`. Derived from the remote URL when omitted —
     * pinning it matters in forks, where `gh` otherwise targets the upstream.
     */
    repo: z.string().nullable().default(null),
  }),
  agent: z.object({
    model: z.string().default("claude-opus-4-8"),
    /** Retry rounds per feature before giving up. */
    retryRounds: z.number().int().positive().default(10),
    /** Iteration budget for a single issue's implementer. */
    implementIterations: z.number().int().positive().default(100),
  }),
  sandbox: z.object({
    /** Run inside the sandbox once it is ready. */
    installCommand: z.string().default("npm install"),
    /** Host paths copied into each worktree, to avoid a cold install. */
    copyToWorktree: z.array(z.string()).default(["node_modules"]),
  }),
  project: z.object({
    /** Commands the agents must run before committing, and after each merge. */
    verifyCommands: z.array(z.string()).min(1).default(["npm test"]),
    /** Prefix every agent commit message starts with. */
    commitPrefix: z.string().default("RALPH:"),
    /** Coding standards the reviewer applies, as a path from the repo root. */
    codingStandardsFile: z.string().default(".sandcastle/CODING_STANDARDS.md"),
  }),
});

export type Config = z.infer<typeof configSchema>;

/** `git@github.com:owner/repo.git` and `https://github.com/owner/repo.git` alike. */
function repoFromRemote(remote: string): string {
  const url = execFileSync("git", ["remote", "get-url", remote], {
    encoding: "utf8",
  }).trim();

  const match = url.match(/[:/]([^/:]+\/[^/]+?)(?:\.git)?$/);
  if (!match) {
    throw new Error(
      `Cannot derive owner/repo from remote "${remote}" (${url}). Set git.repo in .sandcastle/config.json.`,
    );
  }

  return match[1]!;
}

function load(): Config {
  const path = join(SANDCASTLE_DIR, "config.json");

  let raw: unknown;
  try {
    raw = JSON.parse(readFileSync(path, "utf8"));
  } catch (cause) {
    throw new Error(`Cannot read ${path}: ${(cause as Error).message}`);
  }

  const parsed = configSchema.safeParse(raw);
  if (!parsed.success) {
    throw new Error(`Invalid ${path}:\n${z.prettifyError(parsed.error)}`);
  }

  const config = parsed.data;
  return {
    ...config,
    git: {
      ...config.git,
      repo: config.git.repo ?? repoFromRemote(config.git.remote),
    },
  };
}

export const config = load();

/** Substituted by sandcastle itself; passing them via promptArgs is rejected. */
const BUILT_IN_PROMPT_ARGS = new Set(["SOURCE_BRANCH", "TARGET_BRANCH"]);

/**
 * Fail loudly on an unsubstituted `{{TOKEN}}`. Sandcastle leaves unknown
 * placeholders in the prompt verbatim, so a missed wiring reaches the agent as
 * literal braces and is never noticed.
 */
export function checkedPromptArgs(
  promptFile: string,
  args: Record<string, string>,
): Record<string, string> {
  const body = readFileSync(promptFile, "utf8");
  const tokens = new Set(
    [...body.matchAll(/\{\{([A-Z0-9_]+)\}\}/g)].map((m) => m[1]!),
  );

  const missing = [...tokens].filter(
    (token) => !(token in args) && !BUILT_IN_PROMPT_ARGS.has(token),
  );
  if (missing.length > 0) {
    throw new Error(
      `${promptFile}: no value for ${missing.map((t) => `{{${t}}}`).join(", ")}`,
    );
  }

  return args;
}
