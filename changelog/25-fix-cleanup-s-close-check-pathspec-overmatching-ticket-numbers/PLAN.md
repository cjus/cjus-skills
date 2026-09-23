# Fix cleanup's close-check pathspec overmatching ticket numbers

Start date: 2026-09-23 16:07:22 MDT

## Overview

Anchor the ticket number in `/pr:cleanup` step 1's artifact pathspec, so a close check for
ticket 6 can no longer be satisfied by the artifacts of ticket 16 or 26.

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred`, never as new scope.

## About Ticket

Issue #25: Fix cleanup's close-check pathspec overmatching ticket numbers

`/pr:cleanup` step 1 decides whether the close ran by globbing for the branch's close artifacts
(`plugins/pr/skills/cleanup/SKILL.md:56`):

```
"*<changelogRoot>/*<ticket>-*/COMMITMSG.md"
```

The `*` before `<ticket>` matches leading digits as well as a nested owner segment, so the
ticket number is unanchored on the left.

- Observed: `/pr:cleanup 6` matched `changelog/6-…`, and also `changelog/16-…` and
  `changelog/26-…`.
- Failure direction: if ticket 6's folder had no `COMMITMSG.md` but `16-…` or `26-…` did, the
  gate would report `close: verified` and proceed without prompting. This gate stands in front
  of a destructive step, and that is the unsafe way for it to be wrong.
- The same applies to the `pr-summary-*.md` and `pr-review-*.md` patterns on the adjacent lines.
- Suggested fix: split each pattern into two anchored forms, `*<changelogRoot>/<ticket>-*` for
  the flat layout and `*<changelogRoot>/*/<ticket>-*` for the nested layout.

## Plan

Approach, settled 2026-09-23 (operator): step 1 reads the one folder named by the resolved
branch's slug instead of globbing on the ticket number, and step 0 matches the branch name
instead of a substring of the worktree path. The issue's suggested anchored forms were rejected
because they miss every folder in a repo that sets `ticketPrefix` (`changelog/abc-6-…/`).

- [x] Phase 1: Reproduce in a scratch repo, one fresh repo per case, with the closed decoys
  `16-…`, `26-…` and `14-phases-6-9` committed on the default branch:
  - a flat `6-` folder with no `COMMITMSG.md`: the current pathspec reports it closed;
  - only `feature/16-…` checked out: the current step 0 resolves it for ticket 6;
  - a mid-slug `feature/14-phases-6-9` worktree: the current step 0 matches it for ticket 6;
  - a nested `owner/6-…` slug and a prefixed `abc-6-…` slug: the issue's anchored forms miss
    the prefixed one.
- [x] Phase 2: Step 0 (`SKILL.md:34-46`) matches each branch name, listed with the worktree it is
  checked out in, against `^([^/[:space:]]+/)*(<ticketPrefix>-)?<ticket>-`, case-insensitively,
  never treating the main checkout as a workspace, and sets
  `BRANCH` and `SLUG` from the match. The by-name fallback uses the same pattern. Rewrite the
  cross-reference sentence at `:41`.
- [x] Phase 3: Step 1's pathspec (`:56-58`) becomes `<changelogRoot>/<slug>/…`, with no wildcard
  near the ticket. Rewrite the note at `:61` and the flat-layout incident at `:253`, and add
  this bug to the incident reference.
- [x] Phase 4: Re-run every Phase 1 case against the new rules: decoys ignored; flat, nested and
  prefixed folders found; ticket 6 with only `16-…` checked out reports no workspace. Record the
  cases and results in `CHANGELOG.md`.
- [x] Phase 5: Bump the `pr` plugin from 0.2.3 to 0.2.4 so installed copies refresh.

## Open Questions

None open.

- Resolved 2026-09-23 (operator): step 0 is in scope. Step 1 can only verify the workspace
  step 0 hands it, and step 3 prints the target without asking, so a loose step 0 defeats any
  step 1 fix. The anchor is segment-start rather than the `^`-anchored ticket regex at
  `reference/config.md:131`, because the incident at `cleanup/SKILL.md:253` records a real repo
  that nested an owner segment, and a `^` anchor would stop finding its workspaces.
- Resolved 2026-09-23 (operator): no permanent case in `test-acceptance.sh`. The suite excludes
  skills by design, CI does not run it, and an exact-path check leaves no glob logic to regress.
  The repro is recorded in `CHANGELOG.md` instead.

## Deferred

- `plugins/pr/skills/abort/SKILL.md:54` and `plugins/pr/skills/sync/SKILL.md:53` use the same
  "contains the ticket segment including its trailing hyphen" rule to resolve a worktree, with
  the same left-side gap. Lower stakes than cleanup's: abort halts on an issue-title/slug
  mismatch (`abort/SKILL.md:101`) and makes the operator type the slug, and sync deletes nothing.
- `gh pr view --repo "$REPO" --json …` with no branch argument fails ("argument required when
  using the --repo flag"): `resume/SKILL.md:73`, and the same form at `close/SKILL.md:69, 210,
  222, 237`. This branch's own `/pr:close` will hit it.
- With worktrees disabled, cleanup's step 0 resolves a branch but no `$WORKTREE_PATH`, and
  `git -C ""` leaves the working directory unchanged, so step 1 reads whatever checkout the
  session is in rather than the branch.
