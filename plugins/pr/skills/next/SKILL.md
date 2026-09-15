---
name: next
description: Recommend which ticket to work on next by cross-referencing recent PR activity and local worktrees against the open status:todo queue, high priority then medium. Each candidate comes with its derived branch name. Use when the user says "/pr:next" or asks what to work on next.
allowed-tools: Bash(node:*), Bash(gh:*), Bash(git:*)
---

# /pr:next

Suggest the next ticket by cross-referencing **what is already moving** against the **Todo queue**.

> The queue this recommends *from* is `status:todo`. An issue already at `status:in-progress` has been started by `/pr:start` and is deliberately excluded.

## Step 1. Gather what is already moving

Run in parallel:

```bash
gh pr list --repo "$REPO" --state open --limit 30 --json number,title,headRefName,updatedAt,isDraft,reviewDecision,author
gh pr list --repo "$REPO" --state merged --limit 15 --json number,title,headRefName,mergedAt,author
git worktree list
```

Match an issue number against a branch name to connect the two.

**Worktrees catch what PR checks miss:** an issue can be started locally with no PR yet.

**Decide whether a worktree is active from the diff, not the `prunable` flag.** `prunable` only fires once the branch's directory or ref is gone, so a worktree whose branch merged cleanly keeps sitting there unflagged. Test emptiness instead:

| `git diff --name-only $DEFAULT_BRANCH...<branch>` | Meaning | Effect on its ticket |
|---|---|---|
| Empty | Stale or not started: already merged, or freshly created | **Does not exclude** the ticket |
| Non-empty | Active work in progress | **Exclude** the ticket |

Keep `prunable` only as a secondary hint that a worktree needs cleanup.

## Step 2. Query the Todo queue

```bash
gh issue list --repo "$REPO" --state open --label "status:todo" --limit 60 \
  --json number,title,body,labels,assignees,url,createdAt,updatedAt
```

Then keep only issues carrying `priority:high` or `priority:medium`.

- **A `status:todo` issue with no priority label is a queue defect, not a candidate.** Surface it as unprioritized and do not rank it. A missing label means the ticket was filed outside `/pr:ticket`, and guessing a priority launders that into a decision nobody made.
- `--json body` already returns the description, so a second fetch per candidate is usually unnecessary.
- Repeated `--label` flags are ANDed, so filter priority client-side from the returned array rather than with a second flag.

## Step 3. Reconstruct the ticket ID and branch name

Derive both from the number and title, by the rule in `${CLAUDE_PLUGIN_ROOT}/reference/config.md`. **Label the branch as derived**: it is what `/pr:start` would create, not a value read from GitHub.

## Step 4. Optionally enrich the leaders

If a title and body are too thin to rank, read the comment thread with `gh issue view <n> --comments`. **Only for the two or three leading candidates**, never the whole queue.

## Step 5. Rank

**Priority band first, then the framework.**

1. **Priority band.** `priority:high` always outranks `priority:medium`.
2. **The framework**, which breaks ties within a band:
   1. Unblock something queued behind it
   2. Reduce open loops: stale PRs, half-done work
   3. Forward momentum on a key project
   4. Prevent debt: security, reliability, quality
   5. Explore or learn, only after the above

Then apply step 1's findings:

- **Active worktree** → **exclude**, and note it in the flagged list so the reason is visible.
- **Open or merged PR** → **down-rank**, unless the PR is stalled and picking it up unblocks it. **A merged PR whose issue is still open is a stale status**: flag it as done rather than recommend it.

## Output format

Lead with the single recommendation, then the runners-up. **Each description is 100 words or fewer.**

```
## Next up: #{N}: {title}

**Why this matters:** {one line tied to the framework}
**Branch (derived):** {branch}
**Start it:** /pr:start {branch}

{<=100 words: what it is, current state, why now. Note any related PR from step 1.}

---

### Other candidates

- **#{N}: {title}** ({high|medium}) · `{branch}`
  {<=100 words.}
```

Rules:

- Every candidate shows its priority, its derived branch, and a description of 100 words or fewer.
- **Zero `status:todo` issues returned?** Say so and stop. Do not widen the filter without asking.
- **Do not start any work.** This skill only recommends.
- **Evidence discipline:** descriptions come from the issue's title and body and the PR list. Do not fabricate scope, status or history that is not in those sources. Give each ticket's full URL on first mention.

## Lifecycle position

`/pr:next` runs outside any one branch's cycle and hands off to `/pr:start`. Fold the state check in per `${CLAUDE_PLUGIN_ROOT}/reference/lifecycle.md § How a skill uses this`. On the default branch it reports no gaps and recommends this skill, which is confirmation rather than a finding.
