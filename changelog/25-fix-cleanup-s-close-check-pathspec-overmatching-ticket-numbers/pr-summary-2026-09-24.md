# Fix cleanup's close-check pathspec overmatching ticket numbers

Date: 2026-09-24
Branch: `feature/25-fix-cleanup-s-close-check-pathspec-overmatching-ticket-numbers`
Issue: #25

## Overview

`/pr:cleanup` step 1 decided whether a branch's close ran by globbing for its artifacts with
`*<changelogRoot>/*<ticket>-*/COMMITMSG.md`. The `*` before the ticket number was unanchored on the
left, so `/pr:cleanup 6` matched the folders of tickets 16 and 26 too, and so did any slug with
`-6-` inside it (`14-…-phases-6-9`). Every closed ticket's `COMMITMSG.md` is committed on the
default branch, so every worktree carries decoys. A ticket whose close never ran could therefore
read as `close: verified`, and the gate would proceed without prompting, in front of a destructive
step. In this repo the old pathspec reports tickets 2 and 4 closed, and neither has a plan folder.

Step 0, which picks the workspace step 1 inspects, had the same gap. It matched "a path containing
`<ticket>-`", so with only `feature/16-…` checked out it would resolve ticket 16's workspace for
`/pr:cleanup 6`. A step 1 fix alone cannot help there, since step 1 only verifies the workspace
it is handed.

This PR fixes both. Step 0 matches the **branch name**, with the ticket anchored at the start of a
segment. Step 1 checks the **exact folder** named by that branch's slug, with no glob near the
ticket number.

## Key changes

- **`plugins/pr/skills/cleanup/SKILL.md`**
  - **Step 0.** Lists branches with the worktree each is checked out in, and filters them with an
    anchored pattern that accepts flat, nested, prefixed and non-`/`-terminated branch prefixes.
    It never treats the main checkout as a workspace, gives "no rows" and "multiple rows" their own
    outcomes, and sets `WORKTREE_PATH`, `BRANCH` and `SLUG`.
  - **Step 1.** The pathspec is `<changelogRoot>/<slug>/…`. The note under it now explains why the
    folder must not be globbed from the number, and what a renamed branch does.
  - **Incident reference.** The flat-layout entry is amended, and this bug has its own entry.
  - **`allowed-tools`** gains `Bash(grep:*)`, because the step 0 command pipes into it.
- **`plugins/pr/.claude-plugin/plugin.json`**: `pr` goes from 0.2.3 to 0.2.4, so installed copies
  refresh.
- **`changelog/25-…/`**: `PLAN.md`, `CHANGELOG.md` (decisions and the repro table), and the
  pre-test review.

## Code examples

Step 1, `plugins/pr/skills/cleanup/SKILL.md`. Before:

```bash
git -C "$WORKTREE_PATH" ls-files --cached --others --exclude-standard -- \
  "*<changelogRoot>/*<ticket>-*/COMMITMSG.md" \
  "*<changelogRoot>/*<ticket>-*/pr-summary-*.md" \
  "*<changelogRoot>/*<ticket>-*/pr-review-*.md"
```

After:

```bash
git -C "$WORKTREE_PATH" ls-files --cached --others --exclude-standard -- \
  "<changelogRoot>/<slug>/COMMITMSG.md" \
  "<changelogRoot>/<slug>/pr-summary-*.md" \
  "<changelogRoot>/<slug>/pr-review-*.md"
```

Step 0 in the same file. It replaces the prose rule "look for a path containing the ticket segment
including its trailing hyphen":

```bash
git for-each-ref --format='%(refname:lstrip=2)%09%(worktreepath)' refs/heads \
  | grep -iE '^(<branchPrefix>)?([^/[:space:]]+/)*(<ticketPrefix>-)?<ticket>-'
```

For ticket 6 this matches `feature/6-…`, `feature/<owner>/6-…`, `feature-6-…` (when
`branchPrefix: feature-`) and `feature/abc-6-…` (when `ticketPrefix: abc`). It rejects
`feature/16-…`, `feature/66-…`, `feature/6x-…` and `feature/14-phases-6-9`.

## Plan alignment

All five phases are complete.

1. **Reproduced** both gaps in scratch repos, one fresh repo per case, with closed decoys
   committed on the default branch.
2. **Step 0** matches the branch name.
3. **Step 1** checks the exact slug. The note and the incident reference are rewritten.
4. **Re-ran** every case against the new rules and recorded the results in `CHANGELOG.md`.
5. **Bumped** `pr` to 0.2.4.

Deviations, each stated in `CHANGELOG.md`:

- **Not the issue's suggested fix.** The issue proposed two anchored globs,
  `*<changelogRoot>/<ticket>-*` and `*<changelogRoot>/*/<ticket>-*`. Neither reaches a folder in a
  repo that sets `ticketPrefix` (`changelog/abc-6-…/`), so the gate would never find a close there.
  The operator chose the exact-slug approach instead. The objective is met either way: another
  ticket's artifacts can no longer satisfy the check.
- **Step 0 was brought into scope.** This was an open question in `PLAN.md`, and the operator
  answered yes. The anchor is at a segment start rather than the `^` in `reference/config.md:131`,
  because the incident reference records a real repo that nested an owner segment.
- **Added while implementing, to close gaps the branch rule opened:**
  - Step 0 excludes the main checkout by path. With worktrees off, a branch checked out there would
    otherwise match, and step 5 must never be handed the main checkout.
  - "No rows" now means no branch.
- **Taken from the pre-test review:**
  - The optional `(<branchPrefix>)?` group. Without it, step 0 could not find `feature-6-…`, which
    `main` could: a regression this branch had introduced.
  - `%(refname:lstrip=2)` instead of `%(refname:short)`. With `short`, a tag named like the branch
    prints `heads/…` and yields the wrong slug.
  - A rule on which rows can be picked when step 0 finds several.
- **No permanent test.** The operator answered this open question with no: `test-acceptance.sh`
  deliberately does not cover skills, and CI does not run it.

## Testing

**Automated, run on this branch:**

- **Scratch repro, 20 of 20 assertions passed.** It reads the `for-each-ref` format, the grep
  pattern and the three pathspecs out of `SKILL.md` each time it runs, so it tests the skill text as
  merged. The cases:
  - flat, closed / halted / never ran, beside closed `16-`, `26-` and `14-phases-6-9` decoys
  - only `feature/16-…` checked out
  - a mid-slug `14-phases-6-9` worktree
  - `6x-` and `66-` neighbours
  - a nested owner segment
  - `ticketPrefix: abc`, in lower and upper case
  - worktrees off, with the branch checked out in the main checkout
  - a worktree root whose own name holds digits
  - `branchPrefix: feature-`
  - a tag named like the branch

  The old rules reproduced every failure: `verified` off decoys, ticket 16's workspace resolved for
  6, and matches on `14-phases-6-9` and `66-`.
- **`plugins/pr/scripts/test-acceptance.sh`: 39 of 39.** It does not cover skills; it was run to
  confirm the version bump broke nothing.
- **CI (`fixtures`)** passed on macOS and Ubuntu.

**Against this repo:**

- Step 0 finds ticket 25's branch and worktree and nothing else.
- Tickets 2, 6 and 12 return no rows.
- The old step 1 pathspec returns `12-…`, `14-…-phases-2-9` and `22-…` for ticket 2.

**By hand.** Load this branch's copy in a session of its own with `claude --plugin-dir plugins/pr`,
then run `/pr:cleanup 2`. It should report "no workspace found for ticket 2" and stop at step 0,
before anything destructive. Under 0.2.3 it matched three other tickets' closes. Whether
`--plugin-dir` coexists cleanly with an installed 0.2.3 was not tried.

**Edge cases considered:**

- A branch renamed after `/pr:start` no longer names its folder. Step 1 finds nothing and asks,
  defaulting to no.
- A branch with no ticket at a segment start (`feature/fix-6-thing`) is no longer found. It never
  parsed as a ticket branch under `reference/config.md:131` either.
- Unverified assumption: the incident repo that nested an owner segment is taken to have carried it
  in the branch name, as `/pr:start`'s folder rule requires. If the segment lived only in the
  folder, step 1 finds nothing there and asks.

## Impact assessment

- **Size.** 5 files, 458 insertions, 12 deletions. Only two files ship: `cleanup/SKILL.md`
  (23 lines added, 11 removed) and `plugin.json` (1 and 1). The rest is the plan folder.
- **Dependencies.** None added. Step 0 needs `%(worktreepath)` in `git for-each-ref`, which arrived
  in git 2.23 (2019).
- **Breaking changes.** None to configuration. The behaviour changes are all in the safe direction:
  cleanup now stops, or asks, in cases where it used to resolve the wrong workspace or report
  another ticket's close.

## Deferred work

Parked under `PLAN.md § Deferred`. Triaged at close.

- **`abort` and `sync` have the same left-open match.** `abort/SKILL.md:54` and `sync/SKILL.md:53`
  resolve a worktree by "contains the ticket segment including its trailing hyphen". Abort's case
  is guarded: it halts when the issue title doesn't match the branch slug (`abort/SKILL.md:101`),
  and it makes the operator type the slug. Sync deletes nothing.
- **An argument-less `gh pr view --repo "$REPO" --json …` fails** with "argument required when using
  the --repo flag". This is in `resume/SKILL.md:73`, and the same form appears in
  `close/SKILL.md:69, 210, 222, 237`.
- **Cleanup with worktrees off.** Step 0 resolves a branch but no `$WORKTREE_PATH`, and `git -C ""`
  leaves the working directory unchanged. So step 1 reads whatever checkout the session is in, and
  step 3 re-derives `BRANCH` the same way, which lets steps 6 and 8 act on the session's branch.
  This was already on `main`; the review found it reaches further than step 1.
