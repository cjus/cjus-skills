---
name: cleanup
description: Tear down a merged branch's workspace by ticket number. Verifies the close ran and the PR actually merged, confirms the issue closed, removes the worktree, deletes the branch, and pulls the merge. Destructive, so it only runs when the user invokes it explicitly.
disable-model-invocation: true
allowed-tools: Bash(node:*), Bash(git:*), Bash(gh:*), Bash(grep:*), Bash(rmdir:*), Bash(ls:*), Bash(jq:*)
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

- Step 0 resolves the workspace and its branch, and step 1 reads that branch's artifacts out of it, or out of the branch itself when there is no workspace.
- Step 1 gates every destructive action.
- **Step 4 must run before step 6. Deleting a branch before checking PR status can permanently lose work.**

Steps 4b and 4c are the exception to "never skip": they are bookkeeping rather than destruction, so a not-found issue or a title mismatch there reports and moves on rather than halting.

## Step 0. Find the workspace

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/pr-lifecycle-state.mjs" --offline --text
git worktree list --porcelain
git for-each-ref --format='%(refname:lstrip=2)%09%(worktreepath)' refs/heads \
  | grep -iE '^(<branchPrefix>)?([^/[:space:]]+/)*(<ticketPrefix>-)?<ticket>-'
```

The last command resolves the ticket to its branch by `${CLAUDE_PLUGIN_ROOT}/reference/config.md § Resolving a ticket number to its branch`, which carries the escaping rule and the examples. **Match the branch name, never the worktree path**: `6-` is a substring of `…/feature/16-…`.

Set `MAIN_CHECKOUT` to the first `worktree` entry. Each row is a branch and the worktree it is checked out in, and that second field decides whether the row is usable. Neither an empty field nor the main checkout is a workspace, so step 5 must never be handed the main checkout.

| Second field | `worktrees.enabled` true | `worktrees.enabled` false |
|---|---|---|
| A worktree of its own | Usable: the workspace | Usable: a worktree made by hand is still one |
| Empty, checked out nowhere | Not usable | Usable, with no workspace. Steps 5 and 7 skip themselves, and steps 1 and 2 read the branch rather than a checkout |
| The main checkout | Not usable | Not usable |

- **No rows** → there is no branch. Run the no-match check in that section, report what it finds, and stop.
- **Rows, none usable** → where `worktrees.enabled` is true, report "no workspace found for ticket $1" and stop. Where it is false, the branch is checked out in the main checkout: stop, and tell the operator to switch the main checkout to the default branch and run cleanup again. Step 6 cannot delete a checked-out branch, and step 8 would pull this branch rather than the default. Do not switch it for them: a switch carries uncommitted changes with it.
- **Multiple rows** → list them and ask. Only a usable row can be chosen.

Set `WORKTREE_PATH` from the row, empty when it has no workspace, `BRANCH` from the row, and `SLUG` to the branch minus `branchPrefix`. **Echo them immediately**, with the full slug and never the bare number. **`BRANCH` is fixed from here on.** No later step re-derives it from a checkout, because with `WORKTREE_PATH` empty `git -C ""` runs in the session's own checkout, whose branch need not be this one.

Step 1 reads the plan folder this slug names, so it can only verify the workspace this step hands it: a wrong match here passes step 1 on another ticket's record.

## Step 1. Verify the close ran

Cleanup assumes the close already produced the summary, the review, the condensed changelogs, the verified closing reference, and the handoff documents. Cleaning up a branch that was never closed deletes a workspace whose record is incomplete.

**The primary signal is `COMMITMSG.md`.** `/pr:close` writes it at step 5, reached only after the conflict check, the review verdict and the issue-link resolution have all passed, so its presence means the close cleared every gate that can halt it. The summary and review files are written *before* those gates and survive a halted close, so they are secondary evidence only.

```bash
git -C "$WORKTREE_PATH" ls-files --cached --others --exclude-standard -- \
  "<changelogRoot>/<slug>/COMMITMSG.md" \
  "<changelogRoot>/<slug>/pr-summary-*.md" \
  "<changelogRoot>/<slug>/pr-review-*.md"
```

> `--cached --others` is deliberate: it counts **committed and uncommitted** artifacts alike. A close that halted at a gate leaves the whole folder untracked, and a cached-only check would call that "never closed".
>
> **The folder is the exact slug step 0 resolved, never a glob on the ticket number.** `/pr:start` names the folder `<changelogRoot>/<slug>/` and the state script reads it by the same rule, so a nested (`<owner>/6-…`) or prefixed (`abc-6-…`) folder needs nothing extra: the nesting and the prefix are part of the slug. A glob loose enough to reach those reaches other tickets' folders too (`*6-*` matches `16-…`, `26-…` and `14-phases-6-9`), and every closed ticket's `COMMITMSG.md` is committed on the default branch, so after a few dozen tickets every worktree holds a decoy for most single-digit numbers. A branch renamed after `/pr:start` no longer names its folder; the gate then finds nothing and asks, defaulting to no, which is the safe direction.

**With no workspace, read the branch rather than a checkout.** The branch is checked out nowhere, so the main checkout holds some other branch, and its files say nothing about whether this one's close ran:

```bash
{ git -C "$MAIN_CHECKOUT" ls-tree -r --name-only "$BRANCH" -- "<changelogRoot>/<slug>/"
  git -C "$MAIN_CHECKOUT" ls-files --others --exclude-standard -- "<changelogRoot>/<slug>/" 2>/dev/null
} | grep -E '/(COMMITMSG|pr-summary-[^/]*|pr-review-[^/]*)\.md$'
```

The first half is what the close committed to the branch. The second is what a halted close left untracked, which is in the main checkout because untracked files stay in a checkout when the operator switches branches. Its stderr is dropped because the usual case, a merge not yet pulled, has no such folder in the main checkout, and `ls-files` warns that it cannot open it. **No output, with `grep` exiting 1, is the "No artifacts at all" row below**, not a failed command. **`ls-tree` takes no globs**: a `pr-summary-*.md` pathspec lists nothing and exits 0, so list the folder and filter by name.

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

**Skip when `WORKTREE_PATH` is empty:** this holds by construction, since no working tree holds the branch, so nothing on it is uncommitted. Do not run the command in the main checkout instead. It describes that checkout's own state, so it would stop on unrelated work there, and on the untracked plan folder a halted close leaves behind, which step 1 has already weighed.

Note that stashing is not a safe workaround: the stash stack is shared across every worktree of the repo, so a later `git stash pop` elsewhere can take what you pushed.

## Step 3. Confirm the target out loud

**Print the workspace and the branch step 0 resolved before continuing.** This is the last point before anything destructive:

```
Cleaning up ticket <N>:
  Workspace: <path> | none (worktrees off)
  Branch:    <branch>
```

**Do not re-derive the branch from a checkout here.** With no workspace, `git -C "" rev-parse` answers for the session's own checkout, and steps 4 and 6 would then check and delete whatever branch the session happens to be on.

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

**Skip when `WORKTREE_PATH` is empty.** `grep -q ""` matches every line, so the registration check below would report a worktree that does not exist as still registered.

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

Skip when `WORKTREE_PATH` is empty, since `dirname ""` is `.`.

```bash
rmdir "$(dirname "$WORKTREE_PATH")" 2>/dev/null || true
```

A no-op while other worktrees remain under the same prefix segment, which is the normal case.

## Step 8. Pull the merge

Only when step 4 reported `MERGED`, and only when the main checkout is on the default branch:

```bash
git -C "$MAIN_CHECKOUT" branch --show-current
git -C "$MAIN_CHECKOUT" pull --ff-only    # only when the line above printed $DEFAULT_BRANCH
```

On any other branch, `pull` would advance that branch rather than bring in the merge, so report `not pulled (main checkout is on <branch>)` instead. With worktrees off that is a real case: the main checkout may hold the next ticket's branch.

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

**An artifact pathspec that assumed a flat layout.** In a repo that nested an owner segment under the changelog root, the gate found zero artifacts on a correctly closed ticket and false-negatived. The loose glob that fixed it opened the next gap; step 1 now reads the exact slug, which carries any nesting with it.

**A glob that matched other tickets' closes.** The `*` the flat-layout fix put before the ticket number matched leading digits and mid-slug text as well as an owner segment, so `/pr:cleanup 6` matched the artifacts of tickets 16 and 26 alongside its own. Had ticket 6's folder lacked `COMMITMSG.md`, the gate would have reported the close verified off another ticket's record and proceeded without prompting, in front of a destructive step. Step 0's path substring had the same gap: with only `feature/16-…` checked out, it would resolve ticket 16's workspace for ticket 6. Step 0 now anchors on a segment of the branch name and step 1 on the exact slug.

**`git worktree remove` failing on a dependency directory.** Git's metadata was cleared and the skill reported success while hundreds of megabytes remained on disk. Step 5 now verifies both the registration and the directory, retries with `--force`, and surfaces the leftover. `rm` is intentionally not in allowed-tools: deletion must be user-initiated.

**A ticket closed by the wrong number.** The close workflow's issue-linking step once resolved a ticket by fuzzy title search and wrote a closing reference on a *different* issue that merely mentioned the target, closing it on merge with no prompt and no trace. Step 4b reuses the fix for the same reason: the number is trusted because the operator typed it, but the fetched issue is still title-matched before anything closes it, because a stale or copy-pasted number is exactly as cheap a mistake as a fuzzy search was.

## Lifecycle position

`/pr:cleanup` runs after the merge and ends the cycle. Fold the state check into the report per `${CLAUDE_PLUGIN_ROOT}/reference/lifecycle.md § How a skill uses this`.

The state check is read-only and safe to run before this skill's destructive gates. A `not-cleaned-up` gap is this skill's own trigger, so seeing it is confirmation rather than a finding.
