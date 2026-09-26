# Resolve ticket numbers to workspaces by branch name across pr skills

Start date: 2026-09-25 17:10:35 MDT

`/pr:abort` and `/pr:sync` still resolve a ticket number by an unanchored worktree-path substring,
and `/pr:cleanup` with worktrees off acts on the session's checkout. This branch moves all three to
the anchored branch-name rule #25 introduced, and makes cleanup act on the branch it resolved.

## Changes

### 2026-09-26: branch-name resolution in abort and sync, cleanup with worktrees off

- **Operator decisions:**
  - Matching stays strict. A repo whose branches put a tracker key before the number needs
    `ticketPrefix` set through `/pr:init`. A skill that finds no match looks for a word before
    the number and names that branch, so the miss is never silent.
  - The rule is stated once, in `config.md § Resolving a ticket number to its branch`, and each
    skill keeps only the two-line command.
  - With worktrees off, cleanup requires the branch to be checked out nowhere and reads its
    committed tree.
  - The installed plugin (0.2.8) titles this PR, so no hand-titling.
- **What landed:**
  - `config.md` has the new section: the pattern, escaping, examples, what a row's worktree
    field means, and the no-match check.
  - `/pr:abort` rule 1 resolves by branch name. A branch checked out in the main checkout stops at
    step 0, before anything closes. The remote check uses the same pattern, and `grep` joins
    `allowed-tools`. Abort keeps branches with no worktree as targets, since its "worktree already
    gone" path exists for them.
  - `/pr:sync $1` resolves by branch name and keeps only a row with a working tree, the main
    checkout included.
  - `/pr:cleanup` step 0 has a table of row kinds by `worktrees.enabled`. With no workspace, step
    1 reads `ls-tree` plus the main checkout's untracked files, step 2 holds by construction,
    step 3 no longer re-derives `BRANCH`, steps 5 and 7 skip, and step 8 pulls only when the main
    checkout is on the default branch.
  - Version `0.2.9`. Acceptance: 42 passed, 0 failed.
- **Checked in a scratch repo:** git refuses to delete a checked-out branch, `ls-tree` ignores a
  glob pathspec and exits 0, untracked files stay across a switch, and the pattern's documented
  matches and non-matches hold.

### 2026-09-26: review suggestions (`pr-review-2026-09-26.md`, APPROVE)

- **Operator decision:** apply all four suggestions. The three deferred items stay for `/pr:close`
  to triage.
- **What changed:**
  - Abort rule 1 says how to set `MAIN_CHECKOUT`, since its main-checkout stop compares against it.
  - Abort's remote fallback carries rule 1's cardinality: one remote row resolves, and several list
    and stop.
  - Cleanup step 1's `ls-files` half drops stderr. When the changelog root exists but the branch's
    folder does not, `ls-files` warns that it cannot open the folder, and that is the usual
    merged-but-not-pulled case. No output with `grep` exiting 1 is named as the "No artifacts at
    all" row.
  - Cleanup step 2 opens with "Skip when `WORKTREE_PATH` is empty", matching steps 5 and 7.
