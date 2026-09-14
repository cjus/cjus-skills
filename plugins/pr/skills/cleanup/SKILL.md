---
name: cleanup
description: Tear down a merged branch's workspace by ticket number. Verifies the close ran and the PR actually merged, confirms the issue closed, removes the worktree, deletes the branch, and pulls the merge. Destructive, so it only runs when the user invokes it explicitly.
disable-model-invocation: true
allowed-tools: Bash(node:*), Bash(git:*), Bash(gh:*), Bash(rmdir:*), Bash(ls:*), Bash(jq:*)
argument-hint: <ticket-number>
---

# /pr:cleanup

Clean up after a merged PR, by ticket number.

## When NOT to recommend this skill

This skill is `disable-model-invocation: true`, so it runs only when the **user** invokes it. That makes *suggesting* it the only way it can fire prematurely, so the bar for suggesting it is high.

**Never recommend `/pr:cleanup` unless BOTH hold, verified rather than assumed:**

1. `/pr:close` completed on the branch, evidenced by `COMMITMSG.md` in its plan folder, **and**
2. `gh pr view <branch> --json state` reports `MERGED`.

A finished close, a pushed branch, an approved review, or an open PR are **not** cleanup triggers. Cleanup is destructive. If the user asks about it before both conditions hold, say which one is unmet.

## Step ordering is mandatory

Each step depends on the one before it:

- Step 0 resolves the workspace, and step 1 reads artifacts out of it.
- Step 1 gates every destructive action.
- **Step 4 must run before step 6. Deleting a branch before checking PR status can permanently lose work.**

Steps 4b and 4c are the exception to "never skip": they are bookkeeping rather than destruction, so a not-found issue or a title mismatch there reports and moves on rather than halting.

## Step 0. Find the workspace

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/pr-lifecycle-state.mjs" --offline --text
git worktree list --porcelain
```

Look for a path containing the ticket segment **including its trailing hyphen**, so `/pr:cleanup 73` does not match a `73x-…` workspace. Step 1's pathspec anchors on the same substring; if the two disagree, step 0 resolves a workspace whose artifacts step 1 then fails to find, and the gate false-negatives.

- **No match** → where `worktrees.enabled` is false the branch has no worktree, so fall back to resolving the branch by name and skip steps 5 and 7. Otherwise report "no workspace found for ticket $1" and stop.
- **Multiple matches** → list them and ask.

**Echo the resolved path immediately**, with the full slug and never the bare number.

## Step 1. Verify the close ran

Cleanup assumes the close already produced the summary, the review, the condensed changelogs, the verified closing reference, and the handoff documents. Cleaning up a branch that was never closed deletes a workspace whose record is incomplete.

**The primary signal is `COMMITMSG.md`.** `/pr:close` writes it at step 5, reached only after the conflict check, the review verdict and the issue-link resolution have all passed, so its presence means the close cleared every gate that can halt it. The summary and review files are written *before* those gates and survive a halted close, so they are secondary evidence only.

```bash
git -C "$WORKTREE_PATH" ls-files --cached --others --exclude-standard -- \
  "*<changelogRoot>/*<ticket>-*/COMMITMSG.md" \
  "*<changelogRoot>/*<ticket>-*/pr-summary-*.md" \
  "*<changelogRoot>/*<ticket>-*/pr-review-*.md"
```

> `--cached --others` is deliberate: it counts **committed and uncommitted** artifacts alike. A close that halted at a gate leaves the whole folder untracked, and a cached-only check would call that "never closed". The leading `*` matches across `/`, and the one before the ticket segment covers a nested layout. A flat layout needs neither, and they cost nothing.

| Result | Meaning | Action |
|---|---|---|
| `COMMITMSG.md` present | The close completed | Report `close: verified` and **proceed without prompting** |
| Only summary or review present | The close started and halted at a gate | Report what was found and ask, defaulting to **no** |
| No artifacts at all | The close never ran | Ask, defaulting to **no** |

On explicit confirmation, continue and note `close: unverified (user-confirmed)` in the final report.

This gate is about the close **workflow**. Step 4's gate is about the **merge**. Both must pass, and neither substitutes for the other.

## Step 2. Check for uncommitted changes

```bash
git -C "$WORKTREE_PATH" status --porcelain
```

**If anything is there, report it and STOP.** Do not prompt, do not proceed.

Note that stashing is not a safe workaround: the stash stack is shared across every worktree of the repo, so a later `git stash pop` elsewhere can take what you pushed.

## Step 3. Confirm the target out loud

```bash
BRANCH=$(git -C "$WORKTREE_PATH" rev-parse --abbrev-ref HEAD)
```

**Print both before continuing.** This is the last point before anything destructive:

```
Cleaning up ticket <N>:
  Workspace: <path>
  Branch:    <branch>
```

**This is the only defence against the one failure this skill's gates cannot see.** Steps 1 and 4 verify that *the resolved ticket* was properly closed and merged. Neither says anything about whether it is the ticket the operator meant. A mistyped number that happens to match another closed and merged workspace passes every gate legitimately and deletes the wrong one.

Print the **full slug**, never the bare number: the descriptive half is what an operator actually recognizes. Print it even on a unique match, since a single hit proves the argument was well-formed, not that it was intended.

## Step 4. Check PR status, before any destructive action

```bash
PR_STATE=$(gh pr view "$BRANCH" --repo "$REPO" --json state --jq '.state' 2>/dev/null || echo "NO_PR")
```

**Display it immediately.** On `MERGED`, also confirm the content actually reached the default branch rather than trusting the PR state alone, since a merge commit exists whether or not the files you expect are in it:

```bash
git fetch origin "$DEFAULT_BRANCH"
git log --oneline "origin/$DEFAULT_BRANCH" -1
```

### Step 4b. Confirm the issue closed, and close it by hand if the merge did not

**Skip entirely unless step 4 reported `MERGED`.**

```bash
ISSUE=$(gh issue view "$1" --repo "$REPO" --json number,title,state,url,labels 2>/dev/null)
```

- **No such issue** → report and continue. Bookkeeping, not a blocker.
- **Found** → **verify before touching it.** Slugify the title and confirm it matches the branch slug, the same check `/pr:close` performs before writing the closing reference. **On mismatch, close nothing**, report it, and continue.
- **`CLOSED`** → the merge closed it as expected. Report and continue.
- **`OPEN`** → the link was missing or malformed. Close it by hand, referencing the merge so the trail is visible:

```bash
gh issue close "$1" --repo "$REPO" \
  --comment "Closed by /pr:cleanup: the PR for \`$BRANCH\` merged, but its closing reference did not close this automatically."
```

Re-fetch and confirm `CLOSED` before reporting success. A failure here is reported and never blocks the rest of cleanup.

### Step 4c. Drop `status:in-progress`

**Run only when 4b ended with the issue confirmed `CLOSED`.** Skip on not-found, on a title mismatch, and when a hand-close failed. Each of those means the ticket was never established as this branch's, and relabelling the wrong issue is the same class of error as closing one.

```bash
# --remove-label errors on a label the issue does not carry, so check first.
if echo "$ISSUE" | jq -e '.labels | any(.name == "status:in-progress")' >/dev/null; then
  gh issue edit "$1" --repo "$REPO" --remove-label "status:in-progress"
fi
```

**Nothing goes in its place.** There is no `status:done`, and a closed issue is a done ticket. `/pr:close` runs pre-merge, which is why stripping the label there would leave an open ticket carrying no status through review; cleanup is the only correct place for it.

## Step 5. Remove the worktree, with verification

`git worktree remove` commonly fails with `Directory not empty` when the workspace holds dependency or build caches. Sometimes the first attempt unregisters git's metadata but leaves the directory on disk, and the retry then reports `is not a working tree`, which is misleading.

Use this exact sequence and **do not stop after the first attempt**:

```bash
git worktree remove "$WORKTREE_PATH" 2>&1 || true

if git worktree list --porcelain | grep -q "$WORKTREE_PATH"; then
  git worktree remove --force "$WORKTREE_PATH" 2>&1 || true
fi

if git worktree list --porcelain | grep -q "$WORKTREE_PATH"; then
  echo "ERROR: worktree still registered; investigate before proceeding"
  exit 1
fi

if [ -d "$WORKTREE_PATH" ]; then
  echo "WARNING: git metadata removed but the directory is still on disk."
  echo "Run manually (rm is NOT in this skill's allowed-tools):"
  echo "  chmod -R u+w \"$WORKTREE_PATH\" && rm -rf \"$WORKTREE_PATH\""
  DISK_DIR_LEFTOVER=true
fi
```

**Track `DISK_DIR_LEFTOVER` and surface it in the report. Never report an unqualified "removed" when only the git registration was cleared.**

Run this from the main checkout. A worktree cannot remove itself, and the shell's working directory is invalidated if it sits inside the target.

## Step 6. Delete the branch, based on step 4

**`MERGED`:**

```bash
git branch -D "$BRANCH"
git push origin --delete "$BRANCH"      # may already be gone under branch auto-delete
```

> **`-D`, not `-d`, is deliberate.** Under a squash merge the commit on the default branch is not an ancestor of the branch tip, so `-d` either refuses or warns "not yet merged", and that warning is indistinguishable from the one a genuinely unmerged branch produces. That is exactly why step 4 is the gate and `-d` is not trusted to be one.

**`OPEN`:** warn that the PR is still open, and ask before deleting. Declined means "branch kept".

**`CLOSED` or `NO_PR`:** **stop and warn.**

```
WARNING: no merged PR found for this branch.
  Branch:    <branch>
  PR status: <state>

If this branch has code or changelog changes, deleting it will PERMANENTLY LOSE
that work: it exists nowhere else.

  1. Create a PR first (recommended if work exists)
  2. Cherry-pick the changes first
  3. Delete anyway (work will be lost)
```

Require explicit confirmation naming an option number. **The default is not to delete.**

## Step 7. Clean the empty parent directory

```bash
rmdir "$(dirname "$WORKTREE_PATH")" 2>/dev/null || true
```

A no-op while other worktrees remain under the same prefix segment, which is the normal case.

## Step 8. Pull the merge

Only when step 4 reported `MERGED`:

```bash
git -C "$MAIN_CHECKOUT" pull --ff-only
```

**The merged plan folder arrives with this pull and stays.** It is the project's only record of the work.

## Step 9. Report

```
Cleanup complete:
  close:       verified (COMMITMSG.md) | unverified (user-confirmed)
  Workspace:   removed (metadata + disk) | partial: metadata only, directory left on disk
  Branch:      deleted (local + remote) | kept
  PR status:   <state>
  Issue #<N>:  already closed | closed manually (was OPEN) | not found | title mismatch, not closed | n/a
  Label:       status:in-progress removed | none to remove | skipped
  Default:     pulled to <sha> | not pulled (<reason>)
  Plan folder: retained at <changelogRoot>/<slug>/
```

If the directory was left on disk, say so plainly and give the exact command. **Never report an unqualified "removed".**

## What this skill deliberately does NOT do

**It never deletes the branch's plan folder.** Merged folders stay in the repo as history and are the only durable record of the work. A version of this workflow once ended by migrating that folder into an external knowledge base and deleting it; those steps are intentionally absent and must not be re-added. It also means step 6's danger case is about losing code and changelog work that never reached the default branch.

## Incident reference

Every gate here was added after a real failure. They are retained because they explain **why** each exists, and the same failure modes apply to any repo using worktrees.

**A branch deleted without checking PR status.** The changelog files were recoverable only through a reflog cherry-pick. That is why step 4 is mandatory before any destructive action and cannot be reordered.

**A close gate that cried wolf.** An earlier version keyed the "was this closed?" check on a terminal tab label that nothing reliably wrote, so it prompted on correctly closed tickets. Because it prompted on a *destructive* action, its practical effect was training the operator to click through the guard. It was replaced with artifact detection, which is written at a point the close can only reach after every halting gate has passed. **A guard that false-positives is worse than no guard.**

**An artifact pathspec that assumed a flat layout.** In a repo that nested an owner segment under the changelog root, the gate found zero artifacts on a correctly closed ticket and false-negatived. Hence the loose glob.

**`git worktree remove` failing on a dependency directory.** Git's metadata was cleared and the skill reported success while hundreds of megabytes remained on disk. Step 5 now verifies both the registration and the directory, retries with `--force`, and surfaces the leftover. `rm` is intentionally not in allowed-tools: deletion must be user-initiated.

**A ticket closed by the wrong number.** The close workflow's issue-linking step once resolved a ticket by fuzzy title search and wrote a closing reference on a *different* issue that merely mentioned the target, closing it on merge with no prompt and no trace. Step 4b reuses the fix for the same reason: the number is trusted because the operator typed it, but the fetched issue is still title-matched before anything closes it, because a stale or copy-pasted number is exactly as cheap a mistake as a fuzzy search was.

## Lifecycle position

`/pr:cleanup` runs after the merge and ends the cycle. Fold the state check into the report per `${CLAUDE_PLUGIN_ROOT}/reference/lifecycle.md § How a skill uses this`.

The state check is read-only and safe to run before this skill's destructive gates. A `not-cleaned-up` gap is this skill's own trigger, so seeing it is confirmation rather than a finding.
