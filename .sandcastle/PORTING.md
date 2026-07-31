# Porting sandcastle to another project

Upstream, this setup assumes a **Node project**: the kit ships a Node Dockerfile
and `sandbox.installCommand` defaults to `npm install`. Another toolchain needs its
own Dockerfile and install command — config alone won't cover it.

## How this repo diverges

DynamicNotch is an Xcode project, so building and testing it needs macOS + Xcode,
which no Linux container has. This port therefore:

- runs agents with `noSandbox()` — directly on the host, isolated only by their git
  worktree — and drops the Dockerfile entirely (host `linear` and `gh` are used);
- passes `permissionMode: "auto"` to `claudeCode()`, since host runs get no
  `--dangerously-skip-permissions` and would otherwise stall on the first prompt;
- runs leaves and roots **serially** — one screen, one Xcode, one singleton
  `DynamicNotch.app`, so concurrent agents break each other's verification;
- verifies through `./scripts/sandcastle-verify.sh` (CLI build + serial unit tests,
  with the environmental display-geometry tests skipped);
- keeps `npm` only for the orchestrator itself (`package.json` is tooling-only).

The steps below are the generic recipe.

## Steps

1. **Copy `.sandcastle/`** into the target repo. Drop `logs/`, `worktrees/` and
   `.env` — they are gitignored and machine-local anyway.

2. **Edit `.sandcastle/config.json`.** Every field has a default (see the schema
   in `lib/config.mts`); only declare what differs.

   | Field | What it is |
   |---|---|
   | `linear.project` | Linear project name, or `null` to select on label alone |
   | `linear.label` | Label marking an issue as agent-workable |
   | `linear.reviewState` | State applied once the PR is open |
   | `git.remote` / `git.baseBranch` | Where to push, and the PR target |
   | `git.branchPrefix` | Prefix for per-issue branches; must stay deterministic |
   | `git.repo` | `owner/name`. Derived from the remote when `null` — **pin it in a fork**, or `gh` will target the upstream |
   | `agent.model` / `retryRounds` / `implementIterations` | Agent budget |
   | `sandbox.installCommand` / `copyToWorktree` | Sandbox warm-up |
   | `project.verifyCommands` | What agents run before committing. **Only list commands that exist** — a missing script wastes iterations |
   | `project.commitPrefix` | Prefix on every agent commit |
   | `project.codingStandardsFile` | What the reviewer applies |

3. **Create `.linear.toml`** at the repo root — it lives outside `.sandcastle/`
   and the `linear` CLI is useless without it:

   ```toml
   workspace = "your-workspace"
   team_id = "ABC"
   ```

4. **Create `.sandcastle/.env`** from `.env.example`: `CLAUDE_CODE_OAUTH_TOKEN`
   (or `ANTHROPIC_API_KEY`), `LINEAR_API_KEY`, and `LINEAR_TEAM_ID` matching the
   `team_id` above.

5. **Write `.sandcastle/CODING_STANDARDS.md`** for the project, or point
   `project.codingStandardsFile` at an existing document.

6. **Add to `package.json`:**

   ```json
   "scripts": {
     "sandcastle": "tsx .sandcastle/main.mts",
     "sandcastle:build-image": "sandcastle docker build-image"
   }
   ```

   Dev dependencies: `@ai-hero/sandcastle`, `tsx`, `zod`.

   Leave `--image-name` off — sandcastle derives `sandcastle:<repo-dir>` on both
   the build and the run side, so they agree by construction.

7. **Build the image:** `npm run sandcastle:build-image`.

8. **Check the host tooling:** `gh auth status` and `linear issue list` must both
   work — push and PR creation happen on the host, not in the sandbox.

## Smoke test

Run it against a root issue whose sub-issues are all closed. It should report
`0 eligible` and exit without creating a branch, a PR, or a container:

```
npm run sandcastle ABC-1
```
