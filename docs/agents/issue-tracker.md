# Issue tracker: Linear

Issues, specs and PRDs for this repo live in Linear.

- **Workspace**: `vincentbattez`
- **Team**: `Vincentbattez` (key `VIN` — issue identifiers look like `VIN-42`)
- **Project**: `DynamicNotch` — https://linear.app/vincentbattez/project/dynamicnotch-c8ef0959498c

All issues for this repo go in that project. Never create an issue outside it.

## Access

Linear is reached through the `linear` plugin's MCP tools (`mcp__plugin_linear_linear__*`).
Load their schemas with `ToolSearch` before calling them — batch every tool you expect to need
into a single `select:` query.

The `linear-create` skill is `disable-model-invocation: true` — only the user can trigger it.
Don't route through it; use the MCP tools directly.

## When a skill says "publish to the issue tracker"

Call `save_issue` with:

- `team`: `Vincentbattez`
- `project`: `DynamicNotch`
- `title`: concise and descriptive
- `description`: Markdown — Contexte, Objectif, Critères d'acceptation, Informations complémentaires
- `labels`: the triage role plus any type label (`Bug`, `Feature`, `Improvement`, `DX`, …) —
  see `triage-labels.md`
- `parentId`: set it when the issue is a slice of a parent spec (`/to-tickets`)

Check for a duplicate first with `list_issues` (`project: DynamicNotch`, `query: <keywords>`).

Report the created identifier and URL back to the user.

## When a skill says "fetch the relevant ticket"

The user passes an identifier (`VIN-42`) or a Linear URL. Resolve it with `get_issue`, and
`list_comments` when the conversation history matters. To list open work, use `list_issues`
with `project: DynamicNotch`.

## PRs as a request surface

**Off.** GitHub pull requests on the repo are not part of the triage queue. Only Linear issues are.

## Historical issues

Issues written before the switch to Linear were markdown files under `.scratch/`. That directory
is gitignored and untracked, so it may or may not exist in a given clone — treat anything found
there as **read-only local history**, never as the tracker, and don't rely on it being present.
New work goes to Linear.

## Mirror new work to Things 3

New work created for this repo is also mirrored as a task in the user's Things 3 to-do list,
using the `things3` skill (`things` CLI). Do it in the same run, right after the issue is
created.

The point is that nothing gets forgotten: everything the user has to do surfaces in Things 3.
Only the parent surfaces there — never the details.

**Mirror the root of a work item, never its children.** A feature broken into 10
implementation tickets stays a single Things task, the one named after the feature.

- A spec, feature, or parent issue is published (`/to-spec`) → create the task.
- A standalone issue with no parent — feature, bug, chore, whatever it is → create the task.
- Children — `/to-tickets` slices, sub-issues, any ticket under a spec → create nothing. The
  parent already has its task.

Fields:

- **Project**: `🏝️ Dynamic Notch` — pass the emoji, it is part of the title.
- **Title**: `[VIN-42] <feature in French>` — short and direct (~35 characters total). The
  Things title column is narrow: no trailing punctuation.
- **Notes**: `VIN-42 — <one-line French summary>` on the first line, the Linear issue URL on
  the second.
- **Tags**: none by default — the user applies effort/priority tags themselves.

```bash
things add "[VIN-42] Système de notifications" --list "🏝️ Dynamic Notch" \
  --notes "VIN-42 — Notifications in-app et système, avec réglages par projet
https://linear.app/vincentbattez/issue/VIN-42"
```

Check for an existing task first to avoid duplicates. `--project` requires a `--query`;
`title:/./` is the catch-all:

```bash
things search --query=title:/./ --project="🏝️ Dynamic Notch" --select="uuid,title,notes" --json
```

The first result is the project row itself (its title, empty notes), not a duplicate.
