# Resolve ticket numbers to workspaces by branch name across pr skills

## Overview

`/pr:abort` and `/pr:sync` took a ticket number and found its worktree by looking for `<N>-`
anywhere in the worktree path. That substring is not anchored on the left. With only
`feature/12-…` checked out, `/pr:sync 2` reported on ticket 12's worktree, and `/pr:abort 2`
resolved ticket 12, stopped only by its issue-title check. Repos past ticket 10 hit this often: a
repo at ticket 105 has several numbers that name a real worktree they do not belong to.

Separately, `/pr:cleanup` with `worktrees.enabled: false` resolved a branch but left
`WORKTREE_PATH` empty. `git -C ""` runs in the session's own checkout, so step 1 checked whatever
checkout the session was in, and step 3 re-derived `BRANCH` from it. Steps 4 and 6 could then check
and delete the session's branch instead of the resolved one.

This PR moves abort and sync to the anchored branch-name rule `/pr:cleanup` has used since the
ticket-25 work, and states that rule once, in `reference/config.md`. It also makes cleanup with
worktrees off act on the branch it resolved: it reads the branch's committed tree, requires the
branch to be checked out nowhere, and never re-derives the branch from a checkout.

## Key changes

- **`plugins/pr/reference/config.md`:** new section, `## Resolving a ticket number to its branch`.
  - The `for-each-ref | grep -iE` command, the escaping rule, and the examples that match and
    that do not.
  - What a row's worktree field means: a worktree of its own, empty (checked out nowhere), or the
    main checkout. Each skill says which of these it can act on.
  - How the rule differs from the branch-to-number regex above it: it accepts segments before the
    ticket, such as an owner.
  - A no-match check. It looks for a word in front of the number (`<user>/abc-836-…`) and tells
    the operator that setting `ticketPrefix` through `/pr:init` resolves it, without acting on the
    branch.
- **`plugins/pr/skills/abort/SKILL.md`:**
  - Rule 1 resolves by branch name, and sets `MAIN_CHECKOUT`.
  - A branch checked out in the main checkout stops at step 0. Before, the abort would have closed
    the PR and the issue and then failed at step 8, since git will not delete a checked-out branch.
  - The "worktree already gone" fallback checks the remote with the same pattern. One remote row
    resolves, and several list and stop. When nothing is found, it runs the no-match check before
    offering an issue-only close.
  - `Bash(grep:*)` joins `allowed-tools`, which the new command needs.
- **`plugins/pr/skills/sync/SKILL.md`:** step 2 with `$1` resolves by branch name. It drops rows
  checked out nowhere, since they have no working tree to assess, and keeps the main checkout, which
  is where the branch lives when worktrees are off.
- **`plugins/pr/skills/cleanup/SKILL.md`:**
  - Step 0 keeps the command and points to `config.md` for the rest. A table sorts row kinds by
    `worktrees.enabled`.
  - With worktrees off, a branch checked out in the main checkout stops with an instruction to
    switch to the default branch. `BRANCH` is fixed at step 0.
  - With no workspace, step 1 reads `ls-tree` of the branch plus the main checkout's untracked
    files, and step 2 is skipped.
  - Step 3 prints what step 0 resolved instead of re-deriving it.
  - Steps 5 and 7 skip on an empty `WORKTREE_PATH`. Step 5's `grep -q ""` would otherwise match
    every line and report a phantom worktree.
  - Step 8 pulls only when the main checkout is on the default branch.
- **`plugins/pr/.claude-plugin/plugin.json`:** 0.2.8 → 0.2.9, so installed copies refresh.

## Code examples

**The rule, `plugins/pr/reference/config.md` § Resolving a ticket number to its branch:**

```bash
git for-each-ref --format='%(refname:lstrip=2)%09%(worktreepath)' refs/heads \
  | grep -iE '^(<branchPrefix>)?([^/[:space:]]+/)*(<ticketPrefix>-)?<ticket>-'
```

The ticket must open a segment of the branch name, or follow `branchPrefix` directly, and end at
its hyphen. Ticket `6` finds `feature/6-…` and `feature/<owner>/6-…`, and not `feature/16-…`,
`feature/6x-…` or `feature/14-phases-6-9`.

**Abort's rule 1, `plugins/pr/skills/abort/SKILL.md` step 0.** Before:

```markdown
1. **An explicit ticket number was passed.** Find its worktree in `git worktree list --porcelain`,
   matching the ticket segment **including its trailing hyphen**, so `12` does not match `125-`.
```

After, it runs the command above. It sets `MAIN_CHECKOUT` from the first `worktree` entry, and
reads the matched row's second field:

```markdown
- **A worktree of its own** → that is the worktree path.
- **Empty** → the worktree is gone; see below.
- **The main checkout** → **stop.** ... step 8 cannot delete a checked-out branch, so the abort
  would close the PR and the issue and then fail on the branch.
```

**Cleanup step 1 with no workspace, `plugins/pr/skills/cleanup/SKILL.md`:**

```bash
{ git -C "$MAIN_CHECKOUT" ls-tree -r --name-only "$BRANCH" -- "<changelogRoot>/<slug>/"
  git -C "$MAIN_CHECKOUT" ls-files --others --exclude-standard -- "<changelogRoot>/<slug>/" 2>/dev/null
} | grep -E '/(COMMITMSG|pr-summary-[^/]*|pr-review-[^/]*)\.md$'
```

`ls-tree` ignores glob pathspecs and exits 0, so the folder is listed and filtered by name. The
`ls-files` half finds what a halted close left untracked, since untracked files stay in a checkout
across a branch switch. Step 3 used to run `BRANCH=$(git -C "$WORKTREE_PATH" rev-parse
--abbrev-ref HEAD)`, and now prints the branch step 0 resolved.

## Plan alignment

All four phases are done as planned. The four Open Questions were decided on 2026-09-26 and are
recorded in `PLAN.md`:

- **Stay strict.** A repo whose branches put a tracker key before the number needs `ticketPrefix`.
  The old path substring found those branches, and the anchored rule does not unless the prefix is
  set.
- **The rule lives in one place.** `config.md` holds it, and each skill keeps the two-line command.
- **Worktrees off reads the committed tree**, and requires the branch to be checked out nowhere.
  The alternative, requiring the branch to be checked out in the main checkout, cannot work, because
  git refuses to delete a checked-out branch.
- **No hand-titled PR.** The installed plugin reached 0.2.8, which prefixes the title.

Deviations, each within the phases' stated scope:

- **The no-match hint keys on the cause**, a word in front of the number, rather than on the config
  file being absent. So it also covers a configured repo whose `ticketPrefix` is unset or different.
- **Abort stops on a branch checked out in the main checkout.** The new rule returns that row
  explicitly, and the old path rule never did. Proceeding would close the PR and the issue before
  failing at step 8.
- **Cleanup step 8 checks the main checkout's branch before pulling.** With worktrees off, the main
  checkout may hold the next ticket's branch, and `pull` would advance that instead.
- **Abort keeps branches with no worktree as targets.** An earlier note in the session said abort
  and sync would both drop them. That was wrong for abort, whose "worktree already gone" path exists
  for exactly that row, so only sync drops them.
- **The pre-test review's four suggestions were applied** (`pr-review-2026-09-26.md`, APPROVE):
  abort defines `MAIN_CHECKOUT`, abort's remote fallback handles several rows, cleanup step 1's
  `ls-files` drops stderr and names the no-output case, and cleanup step 2 says "skip".

## Testing

**Automated:**

- `plugins/pr/scripts/test-acceptance.sh plugins/pr`: 42 passed, 0 failed. No tests were added. The
  change is skill prose, and the suite covers the lifecycle state script, which this PR does not
  touch.
- The citation check passes, with 190 resolving, including the four new
  `§ Resolving a ticket number to its branch` references.
- CI `fixtures` passes on macOS and Ubuntu. It covers bookcraft.

**Checked by hand in throwaway repos:**

- The rule's documented matches and non-matches, including `branchPrefix: "feature-"` and
  `ticketPrefix: "abc"`, and `<user>/abc-836-…` missing without the prefix and matching with it.
- `%(worktreepath)` is empty for a branch checked out nowhere, and equals the first `worktree`
  entry for a branch checked out in the main checkout.
- `git branch -D` refuses a checked-out branch with `cannot delete branch … used by worktree`.
- `git ls-tree` with a glob pathspec lists nothing and exits 0.
- Untracked files survive `git switch`.
- `ls-files --others` on a missing folder warns on stderr when the changelog root exists.
- Cleanup step 1's pipeline returns the committed and the untracked artifacts, and returns nothing
  with `grep` exiting 1 when there are none.
- Step 8's branch check passes on the default branch, and skips on a feature branch or a detached
  HEAD.

**To verify by hand:**

1. In a repo with only `feature/12-…` checked out, `/pr:sync 2` reports no match. Before this PR it
   reported ticket 12's worktree.
2. In a repo with `worktrees.enabled: false`, merge a branch, switch the main checkout to the
   default branch, and run `/pr:cleanup <N>`. Step 1 reads the branch's tree, step 2 is skipped,
   step 3 shows `Workspace: none (worktrees off)`, and step 8 pulls.
3. With the branch still checked out in the main checkout, `/pr:cleanup <N>` and `/pr:abort <N>`
   both stop at step 0 and say to switch to the default branch.
4. In a repo whose branches read `<user>/abc-<N>-…` and whose `ticketPrefix` is unset,
   `/pr:sync <N>` finds no match and names the branch, saying to set `ticketPrefix`.

## Impact assessment

- **Files:** 8 changed, +421/−23 in all. The plugin accounts for 5 files, +90/−23; the rest is this
  branch's plan folder.
- **Dependencies:** none added or changed.
- **Behaviour change:** in a repo whose branches put a word such as a tracker key in front of the
  number, and whose `ticketPrefix` is not set to it, `/pr:abort <N>` and `/pr:sync <N>` no longer
  find the branch. The old path substring did. The no-match hint names the branch and the fix, a
  one-time `/pr:init` that sets `ticketPrefix`. Branches `/pr:start` created are unaffected: every
  one on the machine this was developed on resolves under the new rule.
- **With worktrees on**, cleanup resolves and gates as before. Two changes still reach it: a
  ticket with no matching branch runs the no-match check, and step 8 pulls only when the main
  checkout is on the default branch. Sync without an argument is unchanged.

## Deferred work

- Cleanup step 5 checks registration with `grep -q "$WORKTREE_PATH"`, an unanchored substring that
  also reads `.` as any character. A sibling worktree whose path extends this one reads as still
  registered, and the step stops with its error. That fails in the safe direction.
- The branch-to-number regex in `config.md`, and `ticketRe` in `pr-lifecycle-state.mjs`, do not
  accept a nested segment, while the new rule does. So `feature/<owner>/6-…` resolves from
  `/pr:cleanup 6`, while the state script reports it as carrying no ticket.
- From the pre-test review, all marked as predating this PR:
  - Abort's rule 2, read loosely with worktrees off, could skip rule 1's new main-checkout stop.
  - Cleanup's final report has no `Workspace:` value for the no-workspace path.
  - A worktree directory deleted with `rm` keeps its stale path in the row, rather than showing the
    empty field abort's prose describes.
