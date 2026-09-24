# PR review: Fix cleanup's close-check pathspec overmatching ticket numbers

Reviewed 2026-09-24 against `main` (e0ffa9b, two commits ahead). PR #26, ticket
[#25 — Fix cleanup's close-check pathspec overmatching ticket numbers](https://github.com/cjus/cjus-skills/issues/25).
This is a **re-review for the close**. The prior review is `pr-review-2026-09-23.md`
(NEEDS_DISCUSSION at b27bc4b). This one covers the delta: commit e0ffa9b, which answers that
review, and the uncommitted `pr-summary-2026-09-24.md`. It does not re-audit the rest of the PR.

The three items in `PLAN.md § Deferred` are settled and not raised again: abort/sync matching,
the argument-less `gh pr view --repo`, and the worktrees-off path. The same goes for the prior
review's step 3 `BRANCH` suggestion, which `CHANGELOG.md` records as "Not taken".

## Summary

`/pr:cleanup` step 1 now reads the one plan folder named by the resolved branch's slug. Step 0
now resolves the workspace by matching branch names from `git for-each-ref` against a
segment-anchored pattern, where it used to match a substring of the worktree path. Commit
e0ffa9b adds an optional `(<branchPrefix>)?` group to that pattern, replaces
`%(refname:short)` with `%(refname:lstrip=2)`, limits which rows can be chosen when several
match, and fixes two overreaching sentences. The objective is delivered: another ticket's
artifacts can no longer satisfy the close check. The regression the prior review blocked on is
fixed.

## What is working well

- **The prefix fix reuses the rule the plugin already had.** The pattern now opens with
  `(<branchPrefix>)?`, the same group as `reference/config.md:131`. It no longer carries a local
  approximation of that rule, so cleanup parses a ticket branch the way `/pr:ticket` builds it.
  The CHANGELOG also explains why "declare that prefixes must end in `/`" was rejected: that
  would have narrowed a documented setting to cover a regression this branch introduced. That
  is the right reason.
- **The fix was confirmed in a scratch repo before anything changed**, and the repro now reads
  the pattern out of `SKILL.md` on each run. That removes the "tested a copy" gap the prior
  review raised about the wording.
- **The tag case is explained in one clause where it is used** (`SKILL.md:43`). A future
  editor tempted to "simplify" back to `short` will see why not.
- **The multiple-rows rule is tight without being wordy** (`SKILL.md:50`). A worktrees-on
  operator can no longer pick a row that leaves `WORKTREE_PATH` empty.

## Verification of the pre-test fixes

I checked each fix independently, rather than relying on the CHANGELOG. I used a scratch repo
with `git 2.54.0`, BSD grep, and the zsh `grep` function (ugrep). The pattern was read verbatim
from `SKILL.md:40`, then optional groups were dropped or filled with a literal replace:

| Configuration | Found for ticket 6 | Rejected |
|---|---|---|
| `branchPrefix: feature/`, no `ticketPrefix` | `feature/6-a`, `feature/owner/6-e` | `feature/16-b` (checked out in a worktree), `66-c`, `6x-d`, `14-phases-6-9`, `feature-6-h` |
| `feature/` + `ticketPrefix: abc` | adds `feature/abc-6-f`, `feature/ABC-6-g` | same |
| `branchPrefix: feature-` | adds `feature-6-h` (the regressed case, now found) | `feature-16-i`, `feature-14-phases-6-9` |
| `feature-` + `abc` | adds `feature-abc-6-j` | same |
| both empty | `feature/6-a`, `feature/owner/6-e` | all decoys |
| `branchPrefix: v1.x-`, escaped | `v1.x-6-dot` | `v1Yx-6-nodot` (the escape matters) |

- **`(<branchPrefix>)?`**: correct and complete. The prose at `:45` now lists `feature-6-…`,
  which the prior review asked for.
- **`lstrip=2`**: correct. With a tag `feature/6-a`, `short` prints `heads/feature/6-a` and
  `lstrip=2` prints `feature/6-a`, as `:43` states.
- **The main-checkout exclusion still holds**: `%(worktreepath)` reports the main checkout's
  path for a branch checked out there, is empty for a branch checked out nowhere, and gives the
  same resolved path as the first `git worktree list --porcelain` entry, even when invoked
  through the `/tmp` → `/private/tmp` symlink. That makes the comparison at `:47` sound.
- **Multiple rows**: correct. With worktrees on, a stale branch checked out nowhere can no longer
  be chosen.
- **The two wording fixes**: both landed. `SKILL.md:263` now reads "opened the next gap", and
  `CHANGELOG.md:61-62` reads "copied verbatim from the edited `SKILL.md`".

## Summary claims checked against the diff and the repo

| Claim in `pr-summary-2026-09-24.md` | Result |
|---|---|
| The old pathspec reports tickets 2 and 4 closed, and neither has a folder | Holds: 2 → `12-`, `14-…-phases-2-9`, `22-`; 4 → `14-`, `34-`; no `changelog/2-*` or `4-*` |
| Step 0 finds only ticket 25's branch; 2, 6 and 12 return no rows | Holds |
| The shipped `SKILL.md` diff is 23 added and 11 removed; `plugin.json` 1 and 1 | Holds (`git diff --numstat`) |
| 5 files, 458 insertions, 12 deletions | Holds for the committed diff (the summary itself will be the sixth file) |
| `%(worktreepath)` needs git 2.23 | Holds: the [2.23.0 `for-each-ref` docs](https://git-scm.com/docs/git-for-each-ref/2.23.0.html) list the atom |
| The step 0 snippet and the ticket-6 examples | Match `SKILL.md:39-45` exactly |
| Deviations and "Taken from the pre-test review" | Match e0ffa9b and `CHANGELOG.md:86-111` |

**Conventions.** Both commit subjects are lowercase imperative. The banned-term audit pattern
from the repo's `CLAUDE.md` returns nothing across the diff and the uncommitted summary. There
are no `org/repo#N` cross-references, and `marketplace.json` carries no version to drift.

## Issues found

### Critical

None.

### Important

None.

### Suggestions

🟢 **Two phrases in the summary say slightly more than happened**

📍 Location: `pr-summary-2026-09-24.md:96` and `:177`

- "Step 0 excludes the main checkout **by name**." The rule compares paths, specifically the
  row's `%(worktreepath)` against the first `worktree` entry (`SKILL.md:47`). "by path" is
  accurate. `CHANGELOG.md:50` uses the same phrase.
- Deferred item 3: "This was already on `main`, **and the review extended its reach**." Read
  quickly, this says the PR or its review made the defect worse. The prior review said the
  opposite: "not worsened by it". `PLAN.md` phrases it correctly as "The review found it
  reaches further". Use that wording here too.

**Learning note:** the summary is the permanent record that triage and later readers trust
without re-reading the diff. A verb that shifts who caused something is worth one more pass.

🟢 **The `:47` parenthetical still names only the worktrees-off case**

📍 Location: `plugins/pr/skills/cleanup/SKILL.md:47`

The prior review suggested an "or", and it did not land. The CHANGELOG does not record it as
declined either. The behaviour is already right: with worktrees on and the branch in the main
checkout, the bullet at `:49` treats the row as not a worktree of its own, and stops. Only the
sentence describing the rows is narrower than the rule. This is optional.

### ⏭️ Deferred to follow-up

No new items. `PLAN.md § Deferred` is unchanged, and close triage will handle it.

I considered these and dropped them, so they need no entry:

- With `-i`, a branch whose prefix differs only in case (`Feature-6-x`) matches, but
  case-sensitive "minus `branchPrefix`" leaves the prefix in `SLUG`. Step 1 then finds nothing
  and asks, which is the safe direction, and `/pr:ticket` never builds such a branch.
- Consider worktrees on, one live row, and one stale row checked out nowhere. Step 0 lists
  both and asks, even though only one can be chosen. That is one extra prompt in a rare case,
  and it fails safe.

## Questions

None. The prior review's question about the `branchPrefix` shape was answered in code. The
question about the incident repo's owner segment is recorded as an unverified assumption in
both `CHANGELOG.md` and the summary, and in either case the failure mode is the safe one.

## Verdict

VERDICT: APPROVE

The one regression the pre-test review blocked on is fixed and verified. Nothing new is in
scope. The two 🟢 wording nits in the summary and at `SKILL.md:47` are optional before the
close commits.
