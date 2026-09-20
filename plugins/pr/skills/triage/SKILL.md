---
name: triage
description: Review every open GitHub issue against the state of the default branch, closing the ones the work has already retired, stamping the ones that still hold with a last-reviewed record, and consolidating issues that have converged on one piece of work. Reports only by default; writes with --apply. Use when the user says "/pr:triage" or asks to clean up or consolidate the issue queue.
allowed-tools: Bash(node:*), Bash(gh:*), Bash(git:*), Read, Write, Glob, Grep, AskUserQuestion
argument-hint: "[--apply]"
---

# /pr:triage

Keep the open issue queue honest. The queue is the only backlog this workflow has, so an issue another PR fixed incidentally, or three issues that are really one pass over the same material, cost `/pr:next` its usefulness.

This reads every open issue, checks its claim against the default branch, and produces one of three verdicts: **still valid**, **retired**, or **combine**.

**It writes nothing unless invoked with `--apply`.** A bare `/pr:triage` is a report.

> Sibling of `/pr:next` and `/pr:reviews`, and the difference is the **subject**. Those ask which issue to work on. This asks whether each issue is still an issue at all. Run it when the queue has grown faster than it has drained, or after several PRs have landed in one area.

| Invocation | Effect |
|---|---|
| `/pr:triage` | Dry run. Reads and prints, writes nothing. |
| `/pr:triage --apply` | Performs exactly the closures, stamps and consolidations the report described. Stops once to confirm the grouping. |

Any other argument is an error: say so and stop.

## Where the evidence comes from

**The evidence tree is the default branch in the main checkout, and that is a property of the tree, not of where this skill was invoked.** Resolve it rather than requiring a particular working directory:

```bash
COMMON=$(git rev-parse --git-common-dir)
case "$COMMON" in /*) ABS="$COMMON" ;; *) ABS="$(cd "$COMMON" && pwd)" ;; esac
MAIN_CHECKOUT=$(dirname "$ABS")
```

Every evidence read then runs against that path. **Do not read the current worktree's copy of a file as evidence about the default branch**: a worktree is mid-change by definition, and a file the branch just edited would be read as the shared state.

**Gate on that checkout, and refuse rather than triage against a moving tree:**

- Not on the default branch → **refuse**, saying which branch it is on.
- `git status --porcelain` non-empty → **refuse**, listing the dirty paths. An uncommitted edit there is somebody's in-flight work, and closing an issue against it would cite a state that exists on one machine.
- Behind the remote → **warn**, name the gap in commits, and continue. A stale-but-clean tree still answers most validity questions correctly; say which SHA the run used.

Resolving the checkout instead of gating on the working directory is deliberate. The thing worth protecting is the tree the evidence comes from, and a rule about the current directory protects that only by accident while making the skill impossible to dry-run from a worktree.

## Step 1. Read the whole open queue

```bash
gh issue list --repo "$REPO" --state open --limit 100 \
  --json number,title,body,labels,assignees,url,createdAt,updatedAt
```

**No label filter.** `status:in-progress` issues are in scope: a live branch does not guarantee the issue still describes real work, and an issue whose branch was quietly dropped is exactly the kind the queue never sheds on its own. `/pr:abort` is what clears the label when a branch is abandoned deliberately, so the issues this catches are the ones nobody ran it on.

**An issue carrying no `status:` label at all is a queue defect**; report it as such and still triage it. Such an issue is invisible to `/pr:next` while sitting in the open queue.

**Ask for `url` and print it.** A triage report discusses every open issue, and a bare number is not clickable in a terminal.

## Step 2. Find what is already in flight

**This step is a gate, and it runs before any verdict.** An issue somebody has already started is not a triage candidate: closing it discards a live plan, and folding it into a consolidation orphans a checkout that is mid-work.

Run in parallel with step 1:

```bash
gh pr list --repo "$REPO" --state open --limit 30 --json number,title,headRefName
git -C "$MAIN_CHECKOUT" worktree list
git -C "$MAIN_CHECKOUT" branch --format='%(refname:short)'
```

**Map each result back to an issue number by its branch.** A PR's `headRefName` carries the same name a worktree path does.

**The number is what protects; the slug is only a cross-check, and a failed cross-check never releases the protection.** Resolve the number, then compare the slug against that issue's slugified title. **On a mismatch, protect the issue anyway** and report the mismatch as a queue observation. A mismatch is what an edited issue title looks like from here, and titles get edited after `/pr:start` routinely; reading it as "this branch is not really about this issue" would hand back exactly the closure the gate exists to refuse.

**Both lists, unioned.** A branch predating the current naming convention lives in the main checkout with no worktree of its own, and a worktree-only sweep would call its ticket unstarted.

Any issue matched by an open PR, a worktree, or a branch is **protected**: read and stamped like any other, never closed and never folded into a group, whatever step 4 finds. Report it under **Not triaged**, naming which of the three matched it.

> **The diff rule here is deliberately stricter than `/pr:next`'s, and the difference is the cost of being wrong.** `/pr:next` treats an empty diff as stale-or-not-started and lets the ticket be recommended, which costs nothing if it guesses wrong: the operator simply finds the branch waiting. Closing that same issue strands the worktree, leaves a label pointing at a closed ticket, and deletes the only written record of what the work was for. **Existence protects, and nothing below refines that.** Never use an empty diff as permission to close.

**Describing a protected issue takes two tests, not one.** A commit range cannot see a worktree that has not committed yet:

| Diff | Status | Report it as |
|---|---|---|
| Non-empty | either | `active work` |
| Empty | non-empty | `uncommitted work in the worktree` |
| Empty | empty | `started, no commits yet` |

The commit-only test is the one that misleads: a worktree whose edits are all uncommitted reads as idle, and an operator who believes "started, no commits yet" may go clean up a checkout somebody is working in. The protection never depends on either test, so the cost is a wrong sentence rather than a wrong decision.

## Step 3. Read each issue's existing stamp

The stamp is a comment this skill owns, found by a sentinel rather than by position:

```bash
gh api --paginate repos/"$REPO"/issues/<N>/comments \
  --jq '.[] | select(.body | contains("<!-- pr-triage:stamp v1 -->")) | {id, updated_at, body}'
```

**`--paginate` is load-bearing, not decoration.** The comments endpoint returns 30 per page **oldest first**, so the stamp, being the most recent comment, sits on the **last** page. Without it the lookup reads the thirty *oldest* comments, which on a busy issue is exactly where the stamp is not: the issue reads as never triaged and collects a **second** stamp, the duplicate the sentinel design exists to prevent.

Zero matches means never triaged; report it as **new to triage**. Two or more means a previous run was interrupted between writing and cleaning up: use the newest and report the duplicates rather than silently picking one.

> **`gh issue comment --edit-last` is the wrong tool here, and this is a refusal rather than an oversight.** Its documented behaviour is to edit the last comment *of the current user*, and the current user is the operator, the same identity that leaves ordinary comments on these issues. A triage run following any operator comment would overwrite it. **Find the stamp by sentinel and edit it by id, always.**

## Step 4. Decide a verdict per issue

Check the issue's claim against the tree: does the file, route, component, migration or defect it names still exist, and does it still read the way the issue says? **Read the actual file or run the actual command.** Recognizing the shape of a claim is not checking it.

**An issue is retired only on one of three findings, each naming its evidence:**

| Finding | Meaning | Evidence the report must carry |
|---|---|---|
| **Done** | The work is already on the default branch | The commit, the merged PR, or the `file:line` showing it landed |
| **Gone** | The subject no longer exists | The path that is absent, plus the commit that removed it |
| **Superseded** | A later issue covers the same work | That issue's number and URL, and one sentence on why it subsumes this one |

**Age never retires anything.** An issue open for a year against material nobody has touched is still valid; it is just unscheduled. There is no staleness rule here and none should be added.

Everything else is **still valid**, which is the default. **When the evidence is ambiguous, the verdict is still valid**: a wrongly closed issue vanishes from the only backlog there is, while a wrongly kept one costs one line in the next report.

**A migration-shaped issue is checked against the database, not only against the tree**, wherever migrations are applied by hand: a file sitting in the migrations directory proves it was authored, never that it ran. Say which of the two you checked.

### A still-valid issue can have a stale body

**Whether the work remains and whether the issue still describes it accurately are two questions, and the second is not answered by the first.** An issue keeps `still valid` when its work is outstanding, and carries **`body stale`** alongside it when checking that work showed the issue's own text no longer matches: a renamed flag, a default that moved, a file it tabulates that is gone.

Name each moved premise with its evidence, the same way a retirement names its finding. The cost of leaving it unsaid is specific: **a still-valid issue is one somebody will pick up, and they will plan the work from the body rather than from this report.**

**`body stale` never becomes a fourth verdict and never licenses a closure.** When `--apply` runs, the flag's detail goes into the stamp, which is the only place a future reader meets it.

## Step 5. Decide what combines

Consolidation is the least reversible thing here, so the bar is written down rather than judged per run. Three clauses govern it, and **clause 2 is the spine**: every group clears it, and its strength decides how the other two apply. Read the three, then read the strength, and do not treat 1 and 3 as settled before you have.

1. **One occasion** *(implied on the strict path below)*. A single event would cause all of them to be picked up.
2. **One changeset.** Doing any one puts you inside the files the others name, so scheduling them separately means opening the same material twice.
3. **One priority band** *(replaced on the strict path below)*. Every member carries the same `priority:` label. Combining across bands silently promotes the low member or demotes the high one, and neither is a decision this skill gets to make. **An issue carrying no priority label fails this clause and never joins a group**: it is a queue defect, and the fix is for the operator to label it.

**Clause 2 holds at two strengths.** Every group clears clause 2 either way; the strength changes only how clauses 1 and 3 apply and how many members are worth grouping. **Name the strength as part of forming the group rather than after it**, and say which one applied, because a group whose strength you cannot state is not a group.

### Strict clause 2: the members' changes land in the same file or the same migration

Doing one member means editing the same file, or the same migration, that another member needs. **"The same migration" means one migration file**, not two that must be applied together. **The shared file or migration is common to every member, not merely to some pair of them**: a third issue that overlaps one member but not the rest makes the group **not strict**, and whether it is a loose group is then loose clause 2's question to answer.

On this path the work is a single unit, so the only real question is when that unit gets scheduled:

- **Clause 3 is replaced.** The group takes the **highest** member's band — high, then medium, then low — and **the report names each promoted member explicitly**, so the promotion is visible rather than silent. Where every member already carries the same band, this is the same band and no promotion happened; say nothing about promotion in that case.
- **Clause 1 is implied and not separately required.** If doing one member puts you inside the file another names, then the occasion for one is the occasion for the other by construction.
- **Two members suffice.** A same-file pair saves an entire lifecycle: a branch, a worktree, a plan folder, a review gate, the close artifacts and a continuity entry. That is the largest saving this skill has to offer, so the two-member caution below does not apply here.

**An issue carrying no priority label still never joins a group, including a strict one.** It was never ranked, so there is nothing to promote it *from*: the group's band would be one member's evidence applied to another member nobody has judged. That is the same laundering `/pr:next` refuses, and it is a queue defect either way. The fix is the same: the operator labels it.

### Loose clause 2: clause 2 holds, but across more than one file

Doing any one member still puts you inside files the others name, yet no single file or migration is common to them. **Clauses 1 and 3 both apply exactly as written above, unchanged.** Nothing on this path is looser than the bar has always been.

**On this path,** a group of two is worth forming only when the clauses are strong; below three members the consolidation often costs more attention than it saves. Say so rather than suppressing the proposal.

### Both strengths

**Do-not-combine is the default, and the burden of proof sits on combining.** Two issues that merely share a subject area do not combine, at either strength. **If you cannot write the strength and its clauses out for a proposed group, it is not a group.**

**An issue in flight never joins a group**, for the same reason it is never closed.

## Step 6. The report

Order by issue number ascending, one fixed-shape block per issue, so two runs diff cleanly against each other.

```
## Triage run <date> against <default> @ <sha>

### Retire (N)

- **#NN: {title}** ({priority}) · {url}
  was: {prior verdict from the stamp, or "never triaged"}
  **Finding:** done | gone | superseded
  **Evidence:** {commit, file:line, or issue number}

### Combine (N groups)

- **Group: {one-line name for the shared work}** ({priority band}) · {strict | loose}
  Members: #NN, #NN, #NN
  **One changeset:** {the material all of them sit in; on strict, the file or the migration by name}
  **One occasion:** {the event that picks all of them up}
  **Promotes:** #NN {priority:medium} → {priority:high}
  New issue title: {the title the combined issue would carry}

### Still valid (N)

- **#NN: {title}** ({priority}) · {url} · unchanged since {date} | changed: {was X, now Y} | new to triage
  {one clause of evidence, only when the verdict changed or the issue is new}

### Queue defects (N)

- **#NN** · {url} · {no priority label | no status label | two triage stamps}

### Not triaged (N)

- **#NN: {title}** · {url} · protected by {open PR #NNN | worktree at <path> | branch <name>}, {active work | uncommitted work | started, no commits yet}; stamped, never closed
```

**The Combine block names the strength that applied**, so a reader can tell why a group formed rather than reconstructing it from the members. Two of its lines are conditional. **One occasion** is omitted on strict, where clause 1 is implied. **Promotes** appears only on strict, one line per member whose band the group raised, giving the member's own prior band and the band it now carries; omit the line entirely when every member already agreed, since nothing was promoted.

Omit any empty section. **A still-valid issue whose verdict did not change is one line**, with no repeated evidence: the whole point of the stamp is that the reasoning was recorded last time. The exception is `body stale`, which repeats its moved premises every run until the body is corrected, because the reader it protects is the one who picks the issue up without reading any report at all.

Give each issue's URL once, then use the bare number for later mentions.

Close with what `--apply` would do, as a count.

## Step 7. `--apply`

Perform exactly what the report described, in this order, reporting each write as it happens.

**`--apply` always produces the report first, in the same run.** Steps 1 through 6 are not optional preliminaries a prior session's output can stand in for. Nothing on disk holds a previous run's report, so "the preceding dry run" always means the one immediately above.

### 7-0. Re-read the queue, and refuse a stale plan before writing anything

```bash
gh issue list --repo "$REPO" --state open --limit 100 --json number --jq '[.[].number] | sort'
```

Compare against the numbers the report covered, and re-check the checkout gate. Any difference, an issue closed, a new one filed, the checkout moved, means the report describes a queue that no longer exists. **Say what changed and stop.** Re-run the dry run; do not apply the parts that still match, because the combining decisions in particular were made against the whole queue rather than issue by issue.

**This check runs first and gates every write below it.** A divergence found after 7a has already cost a comment on every still-valid issue.

### 7a. Stamp every still-valid issue

```bash
# first triage of this issue
gh issue comment <N> --repo "$REPO" --body-file "$STAMP_FILE"

# re-triage: edit the comment found by sentinel in step 3
gh api -X PATCH repos/"$REPO"/issues/comments/<comment_id> -F body=@"$STAMP_FILE"
```

**Build the body with the Write tool and pass it by file in both branches.** `-F key=@<path>` reads the value from the file; an inline `$(cat …)` would put the whole stamp on the command line, where a backtick or a `$` in the evidence is the shell's to interpret before `gh` sees it.

The acceptance criterion for the edit branch is that step 3's sentinel query still returns **exactly one** comment afterward.

```markdown
<!-- pr-triage:stamp v1 -->
**Triaged** <date> against `<default>` @ `<sha>`
**Verdict:** still valid
**Evidence:** <one clause naming what is still outstanding>
```

A `body stale` issue carries its moved premises here too, under a **What has moved since this was filed** heading. The stamp is the only place that reaches somebody who opens the issue without reading a report, which is the whole reason the flag exists.

### 7b. Close the retired issues

```bash
gh issue close <N> --repo "$REPO" --reason completed \
  --comment "Retired by /pr:triage on <date>. {Finding}: {evidence}."
```

Use `--reason completed` for **done**, and `--reason "not planned"` for **gone** and **superseded**. GitHub renders the two with different icons, which is what keeps a retirement from reading as a delivery. A superseded issue also names the superseding issue.

**Closing never touches labels**, so remove `status:in-progress` from a closed issue the way `/pr:cleanup` does, checking first because `--remove-label` errors on an absent label. **Leave `status:todo` alone**: it is the resting state and nothing reads it on a closed issue.

### 7c. Consolidate, after one confirmation

**Ask once with `AskUserQuestion` before any write.** This closes N issues to open one, and the grouping is the part most likely to be a judgment the operator would make differently. A declined group leaves its members untouched and is reported as declined.

**Where a strict group promotes a member, the confirmation says so, naming the member and both bands.** That is a second decision riding inside the same approval: the operator is agreeing both that the group is real and that the lower member should now be scheduled at the higher band. Burying it in the group's description asks them to approve one thing and get two.

Approved groups then: create the combined issue with `--label status:todo`, `@me`, **the band step 5 assigned the group** (the members' shared band on the loose path, the highest member's band on the strict one), and their shared type label where they all carry one; comment on each member naming the new issue; close each member with `--reason "not planned"`.

**Report a created combined issue by its derived branch name and nothing else**, since that is the standing rule for a newly created ticket. The members being closed are existing tickets, so they keep their URLs.

**The combined issue quotes its members rather than only linking them.** A closed member's text is still on GitHub, so nothing is literally lost, but `/pr:next` reads only open issues' bodies, so work described solely inside a closed member becomes invisible to the queue that schedules it.

```markdown
Consolidates #NN, #NN, #NN, which converge on {the shared work}.

- [ ] {member 1 title}
- [ ] {member 2 title}

**Why these combine:** {strict | loose}. {the one-changeset clause in one sentence, plus the one-occasion clause on loose, where it is not implied}

**Band:** {priority:high} — {the band every member already carried | raised, one clause per promoted member: from #NN's {priority:medium}, because its changes land in {the file or migration} that #NN also needs}

<details><summary>#NN: {title} (original body)</summary>

{verbatim body}

</details>
```

**The combined issue takes the band step 5 assigned, and this is a deliberate divergence from `/pr:ticket`.** That skill files high because it is turning a freeform description into a ticket nobody has ranked. Here the members were already ranked, so their own bands are the evidence. On the loose path clause 3 required them to agree, and that agreed band is the answer. On the strict path they may disagree, and the **highest** is the answer, because members whose changes land in one file or one migration are a single unit of work: the lower member cannot be scheduled separately whatever label it carries, so the only honest question is when that unit gets picked up.

**Forcing high on the loose path** would be a re-prioritization this skill chose rather than one the material forced, and that is the line it must not cross. It would not be cosmetic either: `/pr:next` filters on the label and ranks band above everything else, so a consolidation would silently promote its members past every other issue in their band. A note in the body does not reach `/pr:next`, which reads labels.

**The strict path promotes deliberately rather than silently, and that is the whole of the difference.** The promotion is forced by the material rather than chosen by this skill, step 6's Combine block names every promoted member with its prior band, the combined issue's body repeats it, and the band lands on a newly created issue rather than by editing any member's label.

**A group whose members are all `priority:low` enters at `priority:low`, and that means it stays outside `/pr:next`'s queue**, exactly as its members already were. That is the correct outcome rather than a hole. Say in the report that the group will sit outside the queue, so raising the band stays an explicit decision somebody makes rather than a side effect of tidying.

**On the loose path, consolidation changes how work is grouped, never whether it is scheduled.** The strict path is the deliberate exception. Where a `priority:low` member's changes land in the same file or the same migration as a `priority:high` member's, the group enters at high and the low member is scheduled alongside it. Nothing else would be true to the material, since the two cannot be delivered separately. **This is the one case where consolidation does change whether work is scheduled**, it is confined to members sharing one file or one migration, and the report names the promoted member so it is never discovered after the fact.

## What this skill never does

- **Never closes or consolidates an issue that has an open PR, a worktree, or a branch.** Existence of the checkout is enough; an empty diff does not release the protection.
- **Never closes on age**, or on any rule other than the three findings.
- **Never changes a `priority:` label.** This still holds under strict consolidation, and not on a technicality. The group's band lands on a **newly created** issue; every member keeps the label it was filed with, right up to being closed as consolidated. What the strict path changed is that a group's band may now exceed some member's own, which is a scheduling decision the report states per promoted member rather than a relabelling this skill performs on an existing issue. **If you find yourself wanting to edit an existing issue's label, the answer is still no.**
- **Never edits an issue's title or body.** The stamp is a comment; the issue as filed stays as filed.
- **Never deletes a branch or a worktree.** That is `/pr:abort`'s and `/pr:cleanup`'s job, under explicit invocation.
- **Never widens `--apply` past the report.**

## Common mistakes

- **Reading the current worktree's files as evidence about the default branch.**
- **Treating a grep miss as proof an issue is retired.** An absence claim bounds only the places you looked, and this has cost a production incident elsewhere: a correct review finding was dismissed because two checks came back clean, and a colliding migration reached production. Name what you did not check before an absence becomes load-bearing.
- **Reading an applied migration out of the tree.** A file says it was written, not that it ran.
- **Citing an issue by bare number on first mention.**
- **Combining because two issues sound related.** The strength and its clauses, written out, or it is not a group.
- **Reading a shared directory as the same file.** Strict clause 2 is one file or one migration. Members scattered across a small directory are a loose group and still owe clause 3, however tightly the directory reads as a unit.

## Lifecycle position

`/pr:triage` runs outside any one branch's cycle, on the queue rather than on a PR. It changes no branch state. Fold the state check in per `${CLAUDE_PLUGIN_ROOT}/reference/lifecycle.md § How a skill uses this`.

The check reads whichever checkout it runs from, which is not necessarily the main one. When invoked from a worktree, **say which branch the check described**, so its gaps are not read as a claim about the queue.
