# Fix cleanup's close-check pathspec overmatching ticket numbers

Start date: 2026-09-23 16:07:22 MDT

Anchor the ticket number in `/pr:cleanup` step 1's artifact pathspec, so a close check for
ticket 6 can no longer be satisfied by the artifacts of ticket 16 or 26.

## Changes

### Phase 1 — both gaps reproduced, and the issue's fix misses prefixed folders (2026-09-23)

This repo already shows the step 1 bug. No `changelog/2-*` or `changelog/4-*` folder exists, yet the
current pathspec returned `12-…`, `14-…-phases-2-9` and `22-…` for ticket 2, and `14-…` and `34-…`
for ticket 4, each with a committed `COMMITMSG.md`. Both would report `close: verified` without
prompting. The `phases-2-9` hit is the number mid-slug, a shape the issue did not list.

**Finding: the issue's suggested anchored forms miss every prefixed folder.** With
`ticketPrefix: "abc"` the folder is `changelog/abc-6-…/` (`reference/config.md:61`), and neither
`*changelog/6-*` nor `*changelog/*/6-*` reaches it (case H below). In a prefixed repo the gate would
never find a close.

**Finding: step 0 has the same gap, and it defeats any step 1 fix.** With only `feature/16-…`
checked out, "a path containing `6-`" resolves ticket 16's workspace for `/pr:cleanup 6` (case D).
Step 1 can only verify the workspace it is handed, and step 3 prints the target without asking.

**Decision (operator): step 1 reads the exact slug, and step 0 matches the branch name.** This
departs from the issue's suggested mechanism, not from the objective: another ticket's artifacts
can no longer satisfy the check.

**Decision: step 0 anchors at a segment start, not with `reference/config.md:131`'s `^`.** The
incident reference records a real repo that nested an owner segment, and a `^` anchor would stop
finding its workspaces. `^([^/[:space:]]+/)*(<ticketPrefix>-)?<ticket>-` accepts `feature/6-…`,
`feature/<owner>/6-…` and `feature/abc-6-…`, and rejects `16-`, `66-`, `6x-` and `14-phases-6-9`.

### Phases 2-3 — the edits (2026-09-23)

In `plugins/pr/skills/cleanup/SKILL.md`:

- Step 0 lists branches with the worktree each is checked out in
  (`git for-each-ref --format='%(refname:short)%09%(worktreepath)' refs/heads`), filters them with
  the pattern above, and sets `WORKTREE_PATH`, `BRANCH` and `SLUG` from the row.
- Step 1's pathspec is `<changelogRoot>/<slug>/…`. The note under it now explains why it must not be a
  glob on the number, and says what a renamed branch does (finds nothing, asks, defaults to no).
- The incident reference amends the flat-layout entry and adds this bug.
- `allowed-tools` gains `Bash(grep:*)`, because the step 0 command pipes into it. Step 5 already
  piped into `grep` without it being listed.

**Additions beyond the phase list, both closing gaps the branch rule opened:**

- **The main checkout is excluded by name.** With worktrees off, `%(worktreepath)` reports the main
  checkout for a branch checked out there. The old path rule never matched it, because the main
  checkout's path carries no ticket segment. The branch rule would, and step 5 must never be handed
  the main checkout.
- **"No rows" now has an outcome of its own.** The by-name fallback resolves from the same rows, so
  an empty result means no branch rather than a missing workspace.

### Phase 4 — the reproduction, before and after (2026-09-23)

A scratch script built one fresh repo per case. Each repo had closed decoys `16-decoy`, `26-decoy`
and `14-phases-6-9` committed on the default branch, and plan-folder files left untracked, as a
close leaves them. The new-rule rows run the pattern and pathspecs lifted from the edited
`SKILL.md`, so they check the skill's text rather than a copy of it.

| Case | Old rules | New rules |
|---|---|---|
| A. `feature/6-flat`, close never ran | step 1 `verified` off the decoys | resolves `feature/6-flat`; step 1 `never-ran` |
| B. same, close completed | | `verified` |
| C. same, halted with only a summary | | `halted` |
| D. `/pr:cleanup 6`, only `feature/16-other` checked out | step 0 resolves 16; step 1 there `verified` | no rows |
| E. only `feature/14-phases-6-9` checked out | step 0 matches it | no rows |
| F. `feature/6x-thing` and `feature/66-thing` | step 0 matches `66-thing` | no rows |
| G. nested `feature/owner/6-nested`, closed | found | found; `verified` |
| H. `ticketPrefix: abc`, `feature/abc-6-prefixed`, closed | the issue's anchored forms find nothing | found; `verified` |
| I. `feature/ABC-6-upper`, closed | | found case-insensitively; `verified` |
| J. worktrees off, `feature/6-main` in the main checkout | | the row carries the main checkout's path, so it is not a workspace; a branch checked out nowhere has an empty path |
| K. ticket 5, worktree root `claude-25-worktrees` | step 0 matches `16-other` through the root's name, and the main checkout because the scratch root's own path holds `25-` | no rows |

New rules: 16 assertions passed, 0 failed. Against this repo, ticket 25 resolves this worktree and
nothing else, and tickets 2, 5 and 6 return no rows. `test-acceptance.sh plugins/pr` passed 39 of
39. It does not cover skills; it was run to confirm the version bump broke nothing.

### Phase 5 — version (2026-09-23)

`pr` bumped from 0.2.3 to 0.2.4 so installed copies pick up the new `cleanup` skill.
