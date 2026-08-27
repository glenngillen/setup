# Protected data directories — NEVER delete during disk cleanup

These look like disposable caches or redundant untracked dirs. They are not. Deleting
them is unrecoverable data loss (they are deliberately gitignored, so git has no copy):

- `.synapse/` inside ANY project repo — the synapse issue tracker's data store:
  `issues/*.md` (the issue content itself) plus `catalog.db`. "Stealth" projects
  gitignore this on purpose so synapse artifacts never show up in the repo;
  untracked ≠ redundant. On 2026-08-11 a disk-cleanup pass deleted
  `.synapse/issues/` in two infracost repos and two issues were lost for good.
- `.worktrees/` inside project repos — live agent session worktrees, often holding
  uncommitted/unpushed work.
- `~/.synapse/` — agent orchestration state: `synapse.db`, `sessions/`, `workspaces/`.
- `~/Library/Caches/Tenzai` — stateful despite the path (embedded-browser auth).

Orphaned worktrees and their build artifacts ARE reclaimed — by the synapse daemon's
own disk-maintenance routines, which check live sessions/leases, probe for in-use
files, and respect grace periods before deleting. That is the sanctioned path; this
note bans *manual* deletion, which has none of those checks. Manual cleanup should
target build outputs (`target/`, `node_modules/`, genuine caches), never the paths
above. If disk pressure work seems to require touching any of them, stop and ask first.
