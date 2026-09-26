# Resolve ticket numbers to workspaces by branch name across pr skills

Start date: 2026-09-25 17:10:35 MDT

Ticket: #29 (status:todo -> status:in-progress)

## Overview

#25 made `/pr:cleanup` resolve a ticket number to its workspace by an anchored match on the branch
name. Two pr skills still resolve by a worktree-path substring, which is unanchored on the left,
and `/pr:cleanup` itself acts on the session's checkout when worktrees are off.

This branch moves `/pr:abort` and `/pr:sync` to the same branch-name rule, and makes
`/pr:cleanup` with `worktrees.enabled: false` read and act on the branch it resolved rather than on
whatever checkout the session happens to be in.

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred`, never as new scope.

## About Ticket

**#29: Resolve ticket numbers to workspaces by branch name across pr skills**

#25 changed `/pr:cleanup` step 0 to match the **branch name**:

```bash
git for-each-ref --format='%(refname:lstrip=2)%09%(worktreepath)' refs/heads \
  | grep -iE '^(<branchPrefix>)?([^/[:space:]]+/)*(<ticketPrefix>-)?<ticket>-'
```

The old rule was "a path containing the ticket segment including its trailing hyphen", and that
substring is unanchored on the left. Two gaps remain, and both were already on `main` before #25.

- [ ] **`abort` and `sync` still match a path substring.** They are at
  `plugins/pr/skills/abort/SKILL.md:54` and `plugins/pr/skills/sync/SKILL.md:53`.
  - `/pr:sync 2` with only `feature/12-…` checked out reports on ticket 12's worktree.
  - `/pr:abort 2` resolves ticket 12 and stops only at its issue-title/slug check
    (`abort/SKILL.md:101`).
  - Occasion: any repo past ticket 10.
- [ ] **`/pr:cleanup` with `worktrees.enabled: false` acts on the session's checkout.** Step 0
  resolves a branch but sets no `$WORKTREE_PATH`, and `git -C ""` leaves the working directory
  unchanged.
  - Step 1 checks whatever checkout the session is in.
  - Step 3 re-derives `BRANCH` the same way, so steps 6 and 8 can act on the session's branch
    instead of the resolved one.
  - Occasion: the first cleanup in a repo with worktrees off.

Triage on 2026-09-24 (against `main` @ `75f1a0b`) found both gaps still present. They were
re-checked on `main` @ `d28c06b` at the start of this branch: `abort/SKILL.md:54` and
`sync/SKILL.md:53` still match on the path, and `cleanup/SKILL.md:96` still derives `BRANCH` from
`git -C "$WORKTREE_PATH"`.

## Plan

- [x] Phase 1: `/pr:abort` step 0 rule 1 resolves an explicit ticket number by the anchored
      branch-name match, not a path substring. Its issue-title/slug check stays as the second
      defence.
- [x] Phase 2: `/pr:sync` with `$1` resolves by the same branch-name match. The no-argument path
      is unchanged.
- [x] Phase 3: `/pr:cleanup` with `worktrees.enabled: false` gives steps 1 to 3 an explicit target
      for the resolved branch, so they never fall through to the session's checkout, and steps 6
      and 8 act only on the `BRANCH` step 0 resolved.
- [x] Phase 4: Bump the pr plugin's version so installed copies refresh, and run
      `plugins/pr/scripts/test-acceptance.sh`.

## Open Questions

- State the branch-name rule once, in `reference/config.md` beside "Recovering the issue number
  from a branch name", and have cleanup, abort and sync point to it? Or carry the pattern in each
  skill, as cleanup does today?
  **Decided 2026-09-26: state it once.** `config.md` gets a section on resolving a ticket number
  to its branch, holding the pattern, the escaping note, the examples and the no-match hint. Each
  skill keeps the two-line `for-each-ref | grep` command, since that is what runs, and points to
  the section for the rest. The reverse regex stays as it is (see `## Deferred`).
- With worktrees off, the resolved branch is checked out either in the main checkout or nowhere.
  When it is checked out nowhere, there is no working tree for step 1's `--others` or step 2's
  `status --porcelain` to read. Read the committed tree (`git ls-tree -r "$BRANCH"`) and treat
  "no uncommitted work" as holding by construction, or require the branch to be checked out in the
  main checkout and stop otherwise?
  **Decided 2026-09-26: read the committed tree, and require the branch to be checked out
  nowhere.** The second option cannot work, because git refuses to delete a checked-out branch
  (`cannot delete branch … used by worktree`), so step 6 would always fail, and step 8 would pull
  the feature branch. A branch checked out in the main checkout stops at step 0 with an
  instruction to switch to the default branch. Step 1 lists the branch's folder with `ls-tree`
  plus the main checkout's untracked files, since a halted close's untracked folder stays in the
  checkout across a switch. `ls-tree` ignores glob pathspecs, so it lists the folder and filters
  by name. Step 2 holds by construction.
- This branch's PR is opened by the installed plugin (0.2.5), which predates the `[#N]` title
  prefix. Title it `[#29] …` by hand, as #42 and #44 did?
  **Resolved 2026-09-26: no.** The installed plugin updated to 0.2.8 (commit `d28c06b`), whose
  `/pr:pre-test` prefixes the title and whose `/pr:close` corrects it on every run. Run
  `/pr:pre-test` from a session started after the update.
- Keep the branch-name rule strict for repos with no `pr-config.json`, or loosen it? Some repos
  never ran `/pr:init`, and their branches carry a tracker team key before the number
  (`<user>/abc-836-…`). The old path substring found them, because the path contains `836-`.
  Under the defaults `ticketPrefix` is empty, and the anchored rule does not, because `836` must
  open a segment. With `ticketPrefix: "abc"` it does. Loosening the rule to accept any leading
  `<letters>-` when `ticketPrefix` is empty would keep them working, but a hand-made
  `feature/fix-6-…` would then match ticket 6.
  **Decided 2026-09-26: keep it strict.** Those repos need a one-time `/pr:init` that sets
  `ticketPrefix`. So that the miss is never silent, a skill that finds no match looks for a branch
  with a word before the number (`(^|/)[[:alpha:]]+-<ticket>-`) and, on a hit, names it and says
  `ticketPrefix` resolves it. That keys on the actual cause rather than on the config being
  absent, so it also covers a configured repo whose prefix is unset or different.

## Deferred

- `/pr:cleanup` step 5 checks registration with `grep -q "$WORKTREE_PATH"` over
  `git worktree list --porcelain`, an unanchored substring that also reads `.` as any character.
  A sibling worktree whose path extends this one (`…/29-x` beside `…/29-x-y`) reads as still
  registered, and the step stops with its ERROR. That fails in the safe direction, and it is outside
  this ticket's objective, which is resolving the ticket number.
- The reverse regex, branch name to ticket number (`config.md`, and `ticketRe` in
  `pr-lifecycle-state.mjs`), does not accept a nested segment, while the forward rule does. So
  `feature/<owner>/6-…` resolves from `/pr:cleanup 6`, yet the state script reports it as carrying
  no ticket. Aligning them changes the state script's behaviour.
