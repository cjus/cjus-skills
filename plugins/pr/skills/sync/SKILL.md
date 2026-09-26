---
name: sync
description: Assess what the default branch's new commits mean for every live worktree, then merge them into the current one. Stays silent when nothing intersects. Use when the user says "/pr:sync", after a PR merges, or when the default branch has moved and you need to know which branches are affected.
allowed-tools: Bash(node:*), Bash(git:*), Bash(ls:*), Bash(sort:*), Bash(comm:*), Bash(awk:*), Bash(grep:*), Bash(wc:*), Bash(printf:*), Bash(mktemp:*), Read
argument-hint: "[ticket-number]"
---

# /pr:sync

Assess the impact of the default branch's new commits on live worktrees, then merge them into the current one.

`git log HEAD..origin/<default>` is one command and already gives the count. **This skill earns its place only by saying whether the count matters**, by intersecting what the default branch changed against what each branch touched and against the assertions' `Evidence` paths, and by **staying quiet when they do not intersect.**

## Relationship to `/pr:resume`

Adjacent but distinct, and the difference is the **trigger**. `/pr:resume` fires when *you* return and answers "where did I leave off". `/pr:sync` fires when *the default branch* moves and answers "does that affect me".

Do not merge the two later on the strength of their overlapping git commands: a skill that only runs when you sit down cannot catch a merge that lands while you are already working, which is the case this exists for.

## Silence is the feature

`/pr:cleanup § Incident reference` records the close gate that cried wolf. It keyed on an unreliable signal, fired on correctly closed tickets, and because it prompted on every one, its practical effect was **training the operator to click through the guard**. *A guard that false-positives is worse than no guard.*

So the non-intersecting case is **one line and nothing else**. No table, no per-worktree breakdown, no list of commits, no "you may want to consider". Being behind is the normal state of a healthy worktree. Report it as a finding only when it changes what the operator should do.

## Arguments

- `$1` *(optional)*: ticket number, narrowing the **report** to that one worktree. Omitted, the skill sweeps every worktree.

## Scope of action

**The sweep is read-only across every worktree. The merge touches the current one only.**

A sibling worktree may have a live session mid-edit, and **the stash stack is shared across all of them**: `refs/stash` resolves into the common git directory from every worktree, so a stash pushed in one is popped by any other. Writing into another worktree from here is unrecoverable for whoever is working there. Report on siblings; act on yourself.

**Argument scope follows from this.** `$1` narrows the report; it never redirects the merge. When `$1` resolves to a worktree that is not the current one, **say so explicitly** rather than leaving the operator to infer which tree the merge would touch.

## Step 1. Fetch first, or the whole assessment is invalid

```bash
git fetch origin "$DEFAULT_BRANCH"
git rev-parse --short "origin/$DEFAULT_BRANCH"
```

**Mandatory, and never collapse it.** Every comparison below is against the remote ref; without the fetch they run against a local ref that may be days old and produce a confident all-clear.

## Step 2. Enumerate the worktrees

```bash
git worktree list --porcelain
```

- **With `$1`:** resolve the ticket to its branch by `${CLAUDE_PLUGIN_ROOT}/reference/config.md § Resolving a ticket number to its branch`, and keep only that branch's worktree:

  ```bash
  git for-each-ref --format='%(refname:lstrip=2)%09%(worktreepath)' refs/heads \
    | grep -iE '^(<branchPrefix>)?([^/[:space:]]+/)*(<ticketPrefix>-)?<ticket>-'
  ```

  Match the branch name, never the worktree path: `78-` is a substring of `…/feature/178-…`. Drop rows whose second field is empty, since a branch checked out nowhere has no working tree to assess; the main checkout counts, since it is where the branch lives when worktrees are off. One row left sets `$WT` and `$BRANCH`, and multiple rows list and ask. None left reports and stops: when rows matched but none is checked out, name those branches; when nothing matched, run the no-match check in that section.
- **Without `$1`:** keep all. Exclude the main checkout from the *action* half but keep it in the report, since a stale main checkout is worth knowing about.

## Step 3. Per worktree: is it behind, and on what?

```bash
BEHIND=$(git -C "$WT" rev-list --count "$BRANCH..origin/$DEFAULT_BRANCH")
MAIN_CHANGED=$(git -C "$WT" diff --name-only "$BRANCH...origin/$DEFAULT_BRANCH")
BRANCH_TOUCHED=$(git -C "$WT" diff --name-only "origin/$DEFAULT_BRANCH...$BRANCH")
```

The three-dot form is deliberate in both directions: it diffs from the **merge base**, so each side shows only its own changes.

## Step 4. The direct hit, and its two shapes

Intersect `MAIN_CHANGED` against `BRANCH_TOUCHED`. Where they overlap, ask git whether it is actually a conflict:

```bash
git merge-tree --write-tree "$BRANCH" "origin/$DEFAULT_BRANCH" >/dev/null 2>&1; echo $?
```

Exit **0** merges clean, **1** is a real conflict, **anything else could not be determined** and must be reported as such, never as clean. Only exit 1 may be called a conflict.

The direct hit has two shapes, and **the second is the dangerous one**:

- **Conflict (exit 1).** Git will stop and ask. Loud, self-announcing, low cost.
- **Clean merge over a shared document (exit 0).** The real hazard, because nothing announces it. A branch behind on a repo-global document whose copy is later carried forward wholesale **silently reverts** the newer text. A conflict would have *prevented* it.

Say which shape it is. They need opposite reactions.

## Step 5. Intersect against the assertions file, the indirect hit

A branch can be broken by a commit it shares no files with, because the invariant it depends on moved. For each path in `MAIN_CHANGED`, find which assertion names it:

```bash
awk -v p="$CHANGED_PATH" '
  p == "" { exit 1 }
  /^## A-/ { id = $2; sub(/:$/, "", id) }
  id != "" && index($0, p) { print id }
' "$ASSERTIONS_FILE" | sort -u
```

**The empty-path guard is load-bearing, not defensive padding.** `index($0, "")` returns 1 for every line, so an unset path prints **every** assertion ID in the file, which reads as "your change touches all of them" rather than as the bug it is. That is the loudest possible false positive in a skill whose whole discipline is silence.

Note the scope this actually has: it matches the path anywhere in the entry, not only inside `Evidence`, so a path named in a narrative or a `Re-validate` trigger also hits. That is deliberate, since triggers are exactly what to match on, but it means the result is a **candidate list to read**, not a verdict.

Report an assertion when the default branch changed a path inside its `Evidence` **and** this branch's plan or diff touches the same area. An assertion whose entry merely moved is not a finding for a branch that never reads it.

**Read the worktree's `PLAN.md` where one exists.** A branch's *intended* surface is often wider than its current diff, and a branch with no commits yet has an empty `BRANCH_TOUCHED` while being fully exposed.

**Also flag a premise, not just a file.** If the default branch amended an assertion this branch's `PLAN.md` cites as justification, the plan may now rest on a superseded claim even though no file collides. **That is the sharpest thing this skill can find, and it is invisible to every other check.**

## Step 6. Migration versions claimed elsewhere

Skip entirely when `migrations.dir` is `null`.

Migration filenames begin with a hand-chosen version, and **nothing warns when two worktrees pick the same one.** The failure is silent and it reaches production: whichever is pushed first claims the version, and a later push from the other branch finds that version already applied and **skips its real migration while reporting success**.

The sweep is already walking every worktree, which makes it the cheapest place to catch this.

```bash
MAIN_MIGRATIONS=$(mktemp)
git ls-tree -r --name-only "origin/$DEFAULT_BRANCH" -- "$MIGRATIONS_DIR/" | sort > "$MAIN_MIGRATIONS"

# committed migrations this branch has that the default branch does not
git -C "$WT" ls-files -- "$MIGRATIONS_DIR/" | sort | comm -23 - "$MAIN_MIGRATIONS"

# and the half `git log --all` structurally cannot see
git -C "$WT" status --porcelain -- "$MIGRATIONS_DIR/"
```

Collect the **versions** from every worktree's result. A version appearing in two worktrees, or in one worktree and on the default branch under a different filename, is the collision. Report it naming both owners.

**Both halves are required.** A `git log --all` miss means "uncommitted **so far**", not "never": a sibling worktree can commit mid-session and flip the answer. The `status --porcelain` half closes that window, and it is only reachable because the sweep visits each working tree.

Report a hit as: *this version is claimed by two branches; one must be renumbered before either is pushed.* **Do not renumber, apply, or repair anything from here**, since a rename touches a branch this skill may only read.

## Step 7. Resolve, current worktree only

Only after the report, only for the worktree the skill runs in, and **only after asking. Never merge as a side effect of assessing.**

**Refuse outright, with no prompt, when any of these hold:**

- The current branch is the default branch. There is nothing to sync, and the guard hook gates writes there anyway.
- `git status --porcelain --untracked-files=no` is non-empty. Modified tracked files would be clobbered or would block the merge. **Untracked files are fine and must not trigger this refusal**: a fresh branch's own plan folder is untracked by design, and refusing on it would make the skill unusable exactly when it is most useful.
- A merge, rebase or cherry-pick is already in progress.
- HEAD is detached. There is no branch for the merge to advance, and fast-forwarding one would strand the commit.

**Never reach for `git stash` to clear a dirty tree.** The stack lives in the common git directory, so a later pop elsewhere takes what you pushed. Report the dirty files and stop.

**Merge, never rebase:**

```bash
git merge --ff-only "origin/$DEFAULT_BRANCH"    # preferred
git merge "origin/$DEFAULT_BRANCH"              # only with the operator's agreement
```

**Rebase is not an option, and this is not a style preference.** `/pr:start` pushes every branch at creation, so a rebase always means force-pushing over published history. And it buys nothing where the repo squash-merges, because the branch's shape never reaches the default branch.

**On conflict:** stop with the merge in progress. List the conflicted paths and hand it back. **Do not resolve and do not abort**, since the operator may want the state. Say plainly that the tree is mid-merge, because nothing else in the report implies it.

**Do not push.** The merge is local; publishing is `/pr:cp`'s decision.

**Echo the target before merging**, full branch slug and path, never a bare ticket number. Every gate here can confirm the *resolved* branch is safe to touch, and none can confirm it is the *intended* one.

## Output

### Nothing intersects, the common case

One line. Nothing else.

```
<default> is <N> commits ahead (<sha>); nothing it changed touches this branch.
```

If the sweep found other worktrees behind but non-intersecting, add **at most** one more line: `<N> other worktrees are behind, none affected.` Do not name them.

### Something intersects

```
<default> moved to <sha>, <N> commits. Affected:

  <branch-slug>  (behind <N>)
    <what the operator must know, one line per finding>

Unaffected: <count> other worktrees.
```

Findings are ranked by what changes the next action: a superseded premise or a version collision first, a file collision second, **a bare commit count never**. A worktree that is merely behind is a number in the unaffected line, not a row.

### After merging

```
Synced <branch-slug>: <old-sha> -> <new-sha> (fast-forward | merge commit)
  Conflicts: none | <paths>
  Not pushed. Run /pr:cp when ready.
```

## Notes

- Read-only against every worktree but the current one. No exceptions.
- Never applies a migration. It reports what the files imply and leaves every remedy to the operator.
- Writes no `PLAN.md`, no `CHANGELOG.md`, nothing under the continuity root.
- **Deliberately model-invocable, unlike `/pr:cleanup`.** That skill is gated because its action is destructive and irreversible. This one's action is a merge into the current branch, reversible with `git reset --hard ORIG_HEAD`, and its assessment half is read-only and worth firing the moment the default branch moves. Gating it behind a manual invocation would put the check back where it started, dependent on somebody remembering. The safety sits on step 7's refusals, not on the skill being unreachable.

## Incident reference

**A worktree behind fails for a reason that has nothing to do with its own work.** A checkout ran its own older fixtures against schema a sibling had already applied, and reported a failure that did not reproduce from a current checkout. Steps 3 and 6 answer this in one command instead of a diagnosis pass.

**A branch behind on a shared document silently reverts it.** A worktree was behind on a repo-global document; carrying its copy forward wholesale would have reverted a paragraph that had already merged. Nothing flagged it. Step 4's clean-merge case is that hazard.

**A superseded premise is invisible to every file-based check.** A branch was four commits behind, and one of those commits had superseded a claim its own `PLAN.md` cited as justification. No file collided. Step 5's last paragraph is that case.

**A collision is not a conflict.** A branch six commits behind collided on a shared document and `merge-tree` still exited 0. Reporting that as a probable conflict would have been wrong on the very first branch examined, which is the cry-wolf mode reproduced by the skill's own draft. The `merge-tree` oracle is the correction.

**The report goes stale while you read it.** One worktree was four commits behind when a sweep began and current when re-checked minutes later, because another session had synced it. Re-run rather than acting on a sweep you did not just take.

## Lifecycle position

`/pr:sync` runs inside the work band, whenever the default branch moves. Fold the state check in per `${CLAUDE_PLUGIN_ROOT}/reference/lifecycle.md § How a skill uses this`.
