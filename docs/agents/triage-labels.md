# Triage Labels

The skills speak in terms of five canonical triage roles. This file maps those roles to the actual label strings used in this repo's issue tracker.

| Label in mattpocock/skills | Label in our tracker | Meaning                                  |
| -------------------------- | -------------------- | ---------------------------------------- |
| `needs-triage`             | `needs-triage`       | Maintainer needs to evaluate this issue  |
| `needs-info`               | `needs-info`         | Waiting on reporter for more information |
| `ready-for-agent`          | `ready-for-agent`    | Fully specified, ready for an AFK agent  |
| `ready-for-human`          | `ready-for-human`    | Requires human implementation            |
| `wontfix`                  | `wontfix`            | Will not be actioned                     |

When a skill mentions a role (e.g. "apply the AFK-ready triage label"), use the corresponding label string from this table.

These are **Linear issue labels**, not workflow states — all five already exist in the
`Vincentbattez` workspace. Apply them with `save_issue` (`labels: [...]`); never create a
near-duplicate. Workflow states (Backlog, In Progress, Done…) stay orthogonal: a triage label
says whether the issue is *ready*, the state says whether it's *started*.

Edit the right-hand column to match whatever vocabulary you actually use.
