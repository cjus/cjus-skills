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
close leaves them. The new-rule rows ran the pattern and pathspecs copied verbatim from the edited
`SKILL.md`.

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

### Pre-test review — a prefix regression, fixed (2026-09-23)

The review (`pr-review-2026-09-23.md`) returned NEEDS_DISCUSSION on one in-scope finding. Both
the finding and the tag suggestion were confirmed in a scratch repo before anything changed.

**Fixed: step 0 found no workspace where `branchPrefix` does not end in `/`.** `/pr:ticket` builds a
branch by concatenation (`ticket/SKILL.md:67`) and the schema allows any string, so `feature-6-x` is
a valid branch. The path rule on `main` found it; the new pattern did not. The pattern now opens
with `(<branchPrefix>)?`, the group `reference/config.md:131` already carries. The alternative,
declaring that a prefix must end in `/`, would have narrowed a documented setting to cover a
regression this branch introduced.

**Fixed: `%(refname:short)` became `%(refname:lstrip=2)`.** A tag named like the branch makes `short`
print `heads/feature/6-…`, which yields the wrong slug, so step 1 read a closed ticket as never
closed.

**Also taken from the review:** the multiple-rows bullet now says which rows can be chosen when
worktrees are on, and the flat-layout incident says the loose glob "opened the next gap" rather than
"caused the next incident", since the observed overmatch still produced the right verdict.

**Not taken:** step 3's re-assignment of `BRANCH`. It is optional, and it matches step 0's value for a
linked worktree. The worktrees-off case where it does differ joins that Deferred item.

**Unverified assumption:** the incident repo that nested an owner segment is taken to have carried it
in the branch name too, as `/pr:start`'s folder rule requires. If it lived only in the folder, step 1
finds nothing there and asks, defaulting to no.

The repro script now reads the format, pattern and pathspecs out of `SKILL.md` each time it runs,
and gained two cases:

| Case | New rules |
|---|---|
| L. `branchPrefix: feature-`: `feature-6-dash` closed, beside `feature-16-x` and `feature-14-phases-6-9` | resolves `feature-6-dash` only; `verified` |
| M. a tag named `feature/6-tagged` beside the branch | resolves `feature/6-tagged`; `verified` |

New rules: 20 of 20 pass. CI on the first push passed on macOS and Ubuntu.
