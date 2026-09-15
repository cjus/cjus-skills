---
name: close
description: Close a branch so it can merge. Runs the summary, conflict, migration-drift and check gates, a review gate, links the GitHub issue with a verified closing reference, writes the handoff artifacts, triages deferred work, then commits and pushes. Required before any merge. Use when the user says "/pr:close" or says a branch is ready to merge.
allowed-tools: Bash(node:*), Bash(git:*), Bash(gh:*), Bash(date:*), Bash(jq:*), Bash(ls:*), Bash(basename:*), Write, Read, Edit, Agent, Skill
---

# /pr:close

The last step before a merge, and the only path to one.

## Every step is mandatory

**The steps below are a required sequence, not a menu.** Do not skip, reorder, merge or defer any of them, and do not decide a step is unnecessary because the branch looks simple. A step whose outcome is a no-op still runs and still gets reported as a no-op.

Steps get dropped silently. The failure is always the same shape: the step is never refused, it just never happens, and nothing surfaces the omission because the only visible artifact is the final message.

**The report block in § Workflow complete is the anti-skip mechanism.** Every step owes it one row, and a row is only fillable from the artifact that step actually produced: a path, a sha, a verdict string, a PR number, a label, or an explicit no-op with its reason. **A row you cannot fill from a real artifact is a step that did not run**, and the response is to go and run it, never to write a row that reads as finished.

**Emit each step's outcome as it completes**, not in advance and not as one batch at the end. A report assembled from recollection is the failure this section exists to prevent.

The sequence, one row each:

- **1** `/pr:summary`
- **1b** merge-conflict check against the default branch
- **1c** migration drift check
- **1d** configured checks, then the CI verdict
- **2** review gate
- **3** `/pr:condense`
- **4** PR exists, and the issue is linked by a **verified** closing reference
- **5** `/pr:commitmsg`
- **6** continuity entry and the assertion audit
- **6b** deferred-work triage
- **7** arm the sentinel, stage, commit, push
- **8** terminal `/pr:cp` until the tree is clean
- **8b** PR body verified non-empty and carrying a resolved closing reference

**If a gate halts the run** (1b conflicts, 1c unaccepted drift, 1d a failing check, step 2 requesting changes, step 4 finding no exact match or a closed or merged PR, or the default-branch stop), report the rows you reached, name the halt, and **stop**. Do not write rows for steps you never got to.

**Nothing here is a permission stop.** On a feature branch the run goes end to end through 7, 8 and 8b without asking. See `${CLAUDE_PLUGIN_ROOT}/reference/git-conventions.md`.

## Context

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/pr-lifecycle-state.mjs" --text
```

Take the branch, slug, repo, default branch, ticket number and plan folder from that. Read `.claude/pr-config.json` for `checks`, `docs`, `migrations` and `closeGate`.

## Step 0. Clear a stale close sentinel

```bash
"${CLAUDE_PLUGIN_ROOT}/hooks/verify-close-landed.sh" --disarm
```

A previous close abandoned after step 7 could have left one armed. Starting fresh guarantees the step-7 arming is this run's. No-op in the normal case. Skip when `closeGate.enabled` is false.

## Step 1. `/pr:summary`

Invoke the skill. It writes `<changelogRoot>/<slug>/pr-summary-<date>.md`.

## Step 1b. Merge-conflict check, before the expensive work

A branch that no longer merges cleanly must surface **now**, not after summary, review and condense have run.

Prefer GitHub's own verdict where a PR exists:

```bash
git fetch origin "$DEFAULT_BRANCH"
gh pr view --repo "$REPO" --json mergeable,mergeStateStatus,baseRefName,headRefName
```

- `mergeable: "CONFLICTING"`, or `mergeStateStatus: "DIRTY"` → **stop.** The branch must be rebased or merged before the close continues.
- `mergeable: "UNKNOWN"` → GitHub is still computing. Fall back to the local check.

Local fallback, and **gate on the exit code**:

```bash
git fetch origin
git merge-tree --write-tree --name-only HEAD "origin/$DEFAULT_BRANCH"
```

Keep stderr separate. No `2>&1`, no `|&`: folding stderr into stdout makes the two empty-stdout failure rows below look like real output.

**Read the exit code. It is the verdict. Never read stdout to decide.**

| Case | Exit | stdout |
|---|---|---|
| Clean merge | 0 | the written tree OID, non-empty |
| Conflicts | 1 | an OID, then conflicted paths, then `CONFLICT (content):` lines |
| Bad or unreadable ref | 1 | **empty** |
| Unrelated histories | 128 | **empty**, with the error on stderr |

- **exit 0** proceeds.
- **exit 1** stops.
- **any other exit** stops, surfaced as "conflict status unknown, could not verify". It did **not** report clean.

> **stdout is not a clean/dirty signal, so never test it for emptiness.** A clean merge prints a non-empty OID and a failed check prints nothing, so "empty means clean" is exactly backwards: it passes a broken check and second-guesses a good one. Use stdout only to report *which* paths conflict, after exit 1 has already established that there are conflicts.

> **Do not grep the three-argument form for `^<<<<<<<`.** That form embeds conflict markers **indented inside diff hunks**, so a line-anchored grep silently matches nothing and reports clean on a genuinely conflicting branch. That has happened: the gate passed, GitHub then flagged the PR conflicting, and the conflict had been there for an hour. Prefer `--write-tree`, which needs no grep at all.

Resolving a conflict is a prerequisite, not part of this skill.

## Step 1c. Migration drift

Skip and report `n/a` when `migrations.dir` is `null`.

Where migrations are applied by hand, a merge is exactly the moment an unapplied or version-colliding migration stops being "not yet shipped" and becomes "live and broken". The check is read-only and cheap, so it sits with the other pre-flight gates.

```bash
git fetch origin "$DEFAULT_BRANCH"
git diff --name-only --diff-filter=A "origin/$DEFAULT_BRANCH"...HEAD -- "$MIGRATIONS_DIR/"

# For each added file, has its version been claimed anywhere else?
for f in <added files>; do
  v=$(basename "$f" | sed -E "s/$VERSION_PATTERN.*/\1/")
  ls ../*/"$MIGRATIONS_DIR"/"$v"_* 2>/dev/null
  git log --all --oneline -- "$MIGRATIONS_DIR/${v}_*"
done
```

- **No added migrations** → `n/a`, proceed.
- **Added, no collision** → report each by filename as a **post-merge action**, reminding the operator that nothing applies them automatically. Proceed.
- **A version claimed by another branch or worktree** → **stop.** Two files sharing a version is silent and it reaches production: the second push finds the version already applied and **skips the real migration while the ledger claims it shipped**. Report both owners and stop until one is renumbered.

**A `git log --all` miss is weak evidence, not a clear.** It means "not committed yet", and a sibling worktree can commit mid-session and flip the answer. The `ls ../*/` half is what closes that window, so run both and re-run rather than trusting an earlier answer. See `${CLAUDE_PLUGIN_ROOT}/reference/evidence-discipline.md § Treating an absence as proof`, which exists because this exact dismissal once let a colliding migration through.

## Step 1d. Run the checks, then read CI

Run the configured `checks`, skipping any that are `null`, in this order:

```bash
$LINT && $TYPECHECK && $TEST
```

**Where a pre-commit hook already runs the build**, do not also run `checks.build` here: step 7's commit will run it regardless, and running it now costs a second full build to learn the same thing. Where no such hook exists, run the build too.

- **All pass** → report each by name and proceed.
- **Any fails** → **stop**, naming which and its output. A close is not the place to decide a lint error is acceptable, particularly where CI runs lint first and one error there stops every later step from running at all, taking the whole gate dark.

**Then read CI, because local commands cannot see jobs that only run on the remote:**

```bash
gh pr checks --repo "$REPO" --json name,bucket --jq '[.[] | "\(.name)=\(.bucket)"] | join("  ")'
```

- **Any `fail`** → **stop**, naming the job. A red CI is not a close-time judgment call.
- **`pending`** → report and proceed. Waiting would make every close as slow as the slowest job, and step 8b runs after the push anyway.
- **No PR or no runs** → report plainly. That is expected on a branch whose PR this close is about to create, and it means no CI verdict exists for this work.
- **A failure you believe is a flake is still a stop.** Prove it by re-running the job and watching it pass on unchanged code, then re-run the close. Talking past a red gate inside the close is how a gate stops being read.

## Step 2. Review gate

```bash
date '+%Y-%m-%d'
```

Spawn a review with the `Agent` tool using `${CLAUDE_PLUGIN_ROOT}/agents/code-reviewer.md`. **Pass the review file path in the prompt** and have the agent write the full review there, returning only a short summary:

> "Review all changes on this branch. Write the full review to `<changelogRoot>/<slug>/pr-review-<date>.md` using the Write tool. Return only the `VERDICT:` line, a one-sentence summary, and a bullet list of blocking and important issue titles, 300 words at most."

Parse the `VERDICT:` line from the returned response. **Do not re-read the review file** unless gating requires deeper inspection. The full review can be large, and having the agent write it to disk keeps this context small while preserving it for later.

| Verdict | Action |
|---|---|
| `REQUEST_CHANGES` | **Stop.** Surface the issue list and point at the review file. |
| `NEEDS_DISCUSSION` | Surface the list, point at the file, and ask for explicit confirmation before continuing. |
| `APPROVE` | Proceed automatically. |
| No `VERDICT:` line found | Treat as `NEEDS_DISCUSSION`. |

## Step 3. `/pr:condense`

Invoke the skill.

## Step 4. Link the issue, resolving by exact number, then verify

The PR body's closing reference is what closes the issue, and it fires on **merge**, not here. This step makes sure that link exists and points at the right issue.

> **Resolve by number, never by searching titles.** A fuzzy search over title and body readily returns a *different* issue that merely mentions this one. Linking the wrong number closes somebody else's ticket on merge, silently, and unlike a missed link it is not obvious afterward. See § Incident reference.

```bash
gh issue view "$N" --repo "$REPO" --json number,title,state,labels,url
```

- **Slugify the title and confirm it matches the branch slug.** On mismatch, **stop**: do not link, do not relabel. Report the branch, the issue number and its actual title.
- **`CLOSED`** → surface and ask before proceeding. Usually a mistyped number or duplicate work.
- **No such issue** → **stop**, same treatment. A missed link is recoverable by hand; a wrong one closes the wrong ticket.

Then resolve the PR state:

```bash
gh pr list --head "$BRANCH" --repo "$REPO" --state all --json number,state,isDraft,body --jq '.[0]'
```

**Use `--state all`, never the default open-only view.** GitHub refuses only a second *open* PR for the same head and base, so a closed one does not block a create. An open-only query reports "no PR" for a branch whose PR was closed, the create then succeeds, and the review history splits across two PRs. The two stop cases below are only reachable if the query can see those states.

| State | Action |
|---|---|
| **No PR** | Create from the step-1 summary, then append the link as its own line |
| **Open, real description** | Keep it and append the link, unless GitHub already resolves one |
| **Open, empty or placeholder body** | **Replace** the whole body with the summary, then add the link |
| **Draft** | Handle the body as above, then `gh pr ready` |
| **Closed but unmerged** | **Stop.** Let the operator reopen or explain. |
| **Merged** | **Stop.** Nothing left to do. |

```bash
gh pr create --repo "$REPO" --base "$DEFAULT_BRANCH" --head "$BRANCH" \
  --title "<resolved issue title>" \
  --body-file "<changelogRoot>/<slug>/pr-summary-<date>.md"

gh pr edit --repo "$REPO" --body "$(gh pr view --repo "$REPO" --json body --jq .body)

Closes #$N"
```

The title comes from the issue resolved just above, so it cannot drift from the branch. `--body-file` deliberately bypasses any pull-request template: the summary already covers what a template prompts for, and more.

**Do not assume the summary supplies the link.** It is a document, not a PR body, and any closing keyword inside it is likely to sit in a code fence, which GitHub ignores. Creating from it and going straight to verification is how this path fails.

Before appending to an existing description, ask the **same** question the assertion below asks:

```bash
gh pr view --repo "$REPO" --json closingIssuesReferences \
  --jq "[.closingIssuesReferences[].number] | index($N) != null"
```

`false` appends the link. `true` leaves the body alone, since re-adding duplicates it on every run.

**An empty body or one carrying the `pr:pre-test:draft-placeholder` marker is a stub, not a description.** Appending to either leaves a merged PR whose body explains nothing. Replace it wholesale.

**`gh pr create` fails when the branch has no commits ahead of the default branch.** That happens when the whole branch is still uncommitted here, since step 7 is what commits the closing artifacts. Do not halt: record the resolved number, state that creation is deferred, carry the requirement into step 8b, and **do not report this step green.**

### Verify on every path, and halt on failure

This assertion is the point of the step, and it runs whether the PR was just created or already existed:

```bash
gh pr view --repo "$REPO" --json body,closingIssuesReferences \
  --jq "[(.body | length), ([.closingIssuesReferences[].number] | index($N) != null)]"
```

Require a non-zero length **and** `true`. Either failing is a **stop**, reported as "PR body is empty" or "the PR does not close #N", never as a warning appended to an otherwise successful report.

> **Assert on `closingIssuesReferences`, never on a string match.** That field is GitHub's own resolution of the closing keywords, so it is true exactly when the merge will close the issue. A string match returns true for the keyword inside a code fence, inside a blockquote, or inside a sentence that negates it, and GitHub acts on none of those. A PR has merged with a body that satisfied a string check while closing nothing, and the run that produced it reported success.

Report the resolved issue title and number so the operator can see which ticket the merge will close.

**Leave `status:in-progress` on the issue.** This step runs pre-merge, so stripping it would leave an open ticket carrying no status through review, and none at all if the PR never merges. `/pr:cleanup` drops it once the merge is confirmed.

## Step 5. `/pr:commitmsg`

Invoke the skill. It writes `COMMITMSG.md` into the plan folder.

## Step 6. Continuity entry and the assertion audit

Skip either half whose config key is `null`, reporting it as disabled rather than missing.

**First, re-check assertion IDs against the remote default branch, not against your branch point.** IDs are allocated by reading the file when work *started*, and **nothing enforces uniqueness**. A ticket that merged since then may have claimed the same next ID, and the collision is silent: it surfaces as a merge conflict at PR time, or not at all when the files do not textually overlap.

```bash
git fetch origin
git show "origin/$DEFAULT_BRANCH:$ASSERTIONS_FILE" | grep -oE '^## A-[0-9]+' | sort -V | tail -1
```

If the remote already uses your ID, **renumber yours**, since theirs is merged and yours is not, and update **every** reference: the entry header, code comments, and this branch's artifacts. Grep the worktree for the old ID and check each hit for **ownership** before rewriting, because a reference may legitimately point at the remote's entry with that number. Two branches claiming one ID has happened twice in a single day.

**Continuity entries need no such check.** One file per entry, named by date and slug, with no sequential ID to collide and no shared file to conflict in. Do not introduce a scan for one.

- **Continuity:** invoke `/pr:continuity-add`. If it reports nothing to write, proceed without it.
- **Assertions:** audit per `${CLAUDE_PLUGIN_ROOT}/reference/assertion-audit.md`. Add or update any invariant this branch established or changed. If every relevant invariant is already documented, **say so explicitly and do not fabricate an entry to have an edit.** If the repo has no assertions file yet, that is a valid state: say so and move on.

**The audit statement goes in the PR summary and this task message only.** Never append a per-ticket audit record to the assertions file, which holds atemporal invariants; the narrative is temporal and is already captured by the summary and by git.

Both live **outside** the plan folder, so step 7 must stage them explicitly.

## Step 6b. Deferred-work triage

Every item this branch deferred, descoped or punted gets triaged into one of the three bins in `${CLAUDE_PLUGIN_ROOT}/reference/scope-contract.md`. **Most are DROP.**

Scan `PLAN.md` (Deferred, Descoped, Deviations, open forward-looking checkboxes), the summary's deferred section, the review's deferred block, and this session's decisions.

**Triage before filing anything.** TICKET requires **both** a one-sentence user-visible symptom or concrete future cost **and** a named occasion that would cause it to be picked up. Missing either is a DROP. Arguable is a DROP.

- **Unconditional TICKET:** a *pre-existing* security, data-loss or correctness defect is filed immediately as its own issue regardless of both clauses. An escalation, never a deferral.
- **FIX NOW means this close is premature.** An item that re-opens the objective or regresses the default branch is surfaced, and the close stops. Do not triage it into a ticket to get the close through.

Search GitHub **only for the survivors**, not the whole inbox:

```bash
gh issue list --repo "$REPO" --search "<keywords>" --state all
```

**Group the survivors, defaulting to ONE follow-up issue** titled for the branch's surface area, with the items as a body checklist. Split only where you can name the reason: a different kind of work, materially different urgency, or more than roughly eight to ten checklist items. Aim for one, accept two or three, justify more.

Then **ask**, presenting drops collapsed to one line and survivors grouped:

```
Deferred work triage:
  DROPPED (7): a lint suppression, 3 style nits, 2 speculative perf items,
               coverage for a pre-existing loader
  1. "Follow-ups from the decision-log work"
     - [ ] Add a test for the decision-log server action
           symptom: silent regressions ship unnoticed
           occasion: next time that schema changes
```

Create issues through `/pr:ticket` only for the groups the operator approves. **A close where everything dropped is a normal outcome**, said in one line, not a failure to find work. Do not pad the proposal to look thorough.

## Workflow complete

Emit the report, then **continue straight into step 7. Do not stop to ask for commit permission.**

```
pr:close report
  1  /pr:summary ............... wrote <changelogRoot>/<slug>/pr-summary-<date>.md
  1b conflict check ........... clean vs origin/<default> (mergeable: MERGEABLE)
  1c migration drift .......... n/a (not configured) | N added, no collision | STOPPED: <version> also owned by <branch>
  1d checks ................... lint ok, typecheck ok, test ok; CI <buckets> | STOPPED: <which> failed
  2  review gate .............. VERDICT: APPROVE, pr-review-<date>.md
  3  /pr:condense ............. condensed PLAN.md + CHANGELOG.md
  4  PR + issue link .......... PR #<n> created | already open | draft marked ready; closes #<n> "<title>" verified
  5  /pr:commitmsg ............ wrote COMMITMSG.md
  6  continuity + assertions .. <date>-<slug>.md added; A-<nnn> added | no invariant change (stated)
  6b deferred triage ......... N items: N dropped, N ticketed (#<n>) | none found
  7  commit + push ........... <sha> pushed to origin/<branch>
  8  terminal /pr:cp ......... tree clean | <sha> housekeeping commit
  8b PR body verified ........ PR #<n> body <len> chars, closing ref to #<n> present
```

Use `skipped, <reason>` for anything not done. **Never report a step you did not perform.** Rows 7, 8 and 8b are filled after those steps run, so print them in the final message rather than this one.

**Branch check, then proceed.** Run `git branch --show-current`.

- **Any branch other than the default** → go to step 7 **automatically**. Do not ask, do not say "ready to commit when you give permission", do not wait.
- **On the default branch** → **stop.** Report the close as complete-but-uncommitted and ask the operator. The guard hook gates the commit regardless, and **never** add the approval token on your own initiative.

Do **not** call `/pr:close` again, which loops. Do **not** recommend cleanup here: the PR has not merged yet.

## Step 7. Arm the sentinel, then commit and push

```bash
"${CLAUDE_PLUGIN_ROOT}/hooks/verify-close-landed.sh" --arm
```

From here to the end there is no legitimate stop, so this is where an unlanded artifact becomes a defect rather than a normal pause. Skip when `closeGate.enabled` is false.

```bash
git add <changelogRoot>/<slug>/          # PLAN, CHANGELOG, pr-summary, pr-review, COMMITMSG
git add <continuityRoot>/ <assertionsFile>   # skip a path that does not exist
git add -A                                # feature code and anything uncommitted during development
git status
```

`git add -A` is safe here **only because a close runs on a branch dedicated to one ticket**, so every uncommitted change belongs to this work. Confirm nothing that belongs is unstaged, and nothing that does not belong is staged.

```bash
git commit -F <changelogRoot>/<slug>/COMMITMSG.md
git push
```

## Step 8. Terminal `/pr:cp` until the tree is clean

The close itself writes files that can land **after** the step-7 commit, most often a changelog touched by session logging, but also any condense or continuity write that races the commit. Leaving them uncommitted makes the PR look done while the branch is dirty.

- Invoke `/pr:cp` with a housekeeping message so the commit is self-describing.
- **Logging can fire more than once**, so re-check `git status --porcelain` after it returns and invoke it again while the tree is non-empty.
- End only when `git status --porcelain` reports clean.

## Step 8b. Backstop: assert the PR exists and closes the issue

Step 4 owns this; here its one deferral is settled. The branch is pushed now, so the "no commits ahead" case that blocks creation at step 4 cannot still apply.

- **Creation was deferred** → create the PR now exactly as step 4 describes, **including the edit that appends the closing reference.** The create alone does not add it.
- **Then, unconditionally**, re-run step 4's verification against the final pushed state. A zero length or a `false` is a **stop**, reported as a failed close.

The duplication with step 4 is deliberate. Step 4 runs before the closing artifacts are committed, so its verdict describes a PR that step 7 then changes. This check describes what actually merges.

## The close sentinel

Step 8 has said "end only when the tree is clean" for a long time, and a close still once finished, reported success, and left four artifacts uncommitted: the continuity entry, the summary, the review and the commit message, none of which reached the merged PR. Only a later destructive-action gate caught it. The sentinel makes that prose harness-enforced.

**How it works.** The hook runs on every `Stop` and exits silently unless the sentinel file exists, so ordinary turns are untouched. When armed it requires a clean tree including untracked files, a pushed tip, and the tracked artifacts `closeGate.requiredArtifacts` names. If anything is missing it blocks, naming the offending paths, and the turn continues instead of ending. When everything checks out it deletes the sentinel itself.

**Why step 7 and not step 0.** Every halt gate fires before step 7, so arming late means a halted close cannot strand the sentinel. It also leaves the one remaining legitimate pause, the default-branch stop, unblocked.

**It blocks at most once per turn**, so it can never wedge a session. The block path leaves the sentinel armed on purpose, so a stale one costs an extra turn on every later turn in that worktree until it is cleared. Step 0 clears a leftover one at the next close, and every block message names `--disarm`.

**To abandon a close deliberately**, run the hook with `--disarm`. Do that only when genuinely walking away: it is the one thing standing between a half-finished close and a PR that looks done.

## After the PR is merged

> **Reference material, not a next step to recommend at close time.** Finishing this skill does not make cleanup actionable: the PR still has to be reviewed and merged. Do not surface cleanup until `gh pr view --json state` actually reports `MERGED`.

From the main checkout, on the default branch: remove the worktree, delete the branch, **confirm the issue actually closed**, and apply anything step 1c flagged, since nothing does that automatically. `/pr:cleanup` performs all of it. **The plan folder stays in the repo** as history.

## Incident reference

**A ticket left open after merge, twice in one day.** An earlier version of this workflow resolved the ticket by fuzzy search over title and body and used the top hit, which was a different ticket that merely mentioned the target. The actual ticket did not appear in the top five at all.

The fix is what step 4 now does: resolve by exact number, verify the fetched record before writing, stop rather than touch a non-matching one, and confirm the write afterward. The tempting shortcut of searching titles for words from the branch slug reintroduces exactly this failure, and here it is worse, because a wrong closing reference closes an unrelated ticket the moment the PR merges, with no prompt and no obvious trace.

## Lifecycle position

`/pr:close` is the last step before a merge and the only path to one. Fold the state check into the report per `${CLAUDE_PLUGIN_ROOT}/reference/lifecycle.md § How a skill uses this`.

`next` reads `/pr:cleanup` once the branch is merged. **Do not surface that at close time.**
