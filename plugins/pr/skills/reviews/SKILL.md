---
name: reviews
description: Summarize what was recently completed, from the continuity entries, the assertions file and merged PRs, then cross-reference the open status:todo queue to recommend what to work on next. Use when the user says "/pr:reviews" or asks "what did we just do and what is next".
allowed-tools: Bash(node:*), Bash(gh:*), Bash(git:*), Bash(ls:*), Bash(sort:*), Bash(head:*), Bash(cat:*), Read
---

# /pr:reviews

A two-part answer: **what just happened**, reconstructed from the handoff documents and PR activity, and **what is next**, the best picks from the Todo queue, informed by the first half.

> Sibling of `/pr:next`, which cuts straight to a single pick. This skill first *characterizes recent work* and produces a "recently done, do next" briefing.
>
> **`/pr:next` owns the shared machinery**: the queue query, the label semantics, and the ticket and branch reconstruction. This skill references those rather than restating them, so a fix lands in one place.

## Step 1. Mine the handoff documents

The continuity folder and the assertions file live at the repo root and are the highest-trust in-tree record of recent work. **Both are optional.** If either is absent or disabled, say so and lean on step 2's merged PRs plus the plan folders of recently merged branches.

```bash
for f in $(ls "$CONTINUITY_ROOT"/[0-9]*.md 2>/dev/null | sort -r | head -5); do echo "--- $f"; cat "$f"; done

git log --since="21 days ago" --name-only --date=short \
  --pretty=format:'%h|%ad|%an|%s' -- "$ASSERTIONS_FILE" "$CONTINUITY_ROOT/"
```

Read the signal rather than listing it:

- **Continuity entries** are feature and behavior work worth handing off. Each carries `Covers` and `Source` fields tying it to a branch or PR.
- **Assertions edits** mean an **invariant** was established or changed. Higher stakes, worth calling out.
- **Ticket numbers come from branch names** in merged PRs' `headRefName`. That is the reliable ticket-to-PR link.

Keep this bounded: the newest few entries and one `git log`, not a full-history excavation.

## Step 2. Corroborate with PR activity and worktrees

Run in parallel with step 1:

```bash
gh pr list --repo "$REPO" --state merged --limit 20 --json number,title,headRefName,mergedAt,author
gh pr list --repo "$REPO" --state open --limit 30 --json number,title,headRefName,updatedAt,isDraft,reviewDecision,author
git worktree list
```

- **Merged PRs** confirm the recently-done picture. A document change with no matching merged PR may be work that never reached the default branch.
- **Open PRs and active worktrees** are in flight, so exclude their tickets from the recommendation.
- **Judge worktree activity by its diff, not the `prunable` flag.** See `/pr:next` step 1 for the mechanism: active means a non-empty `<default>...<branch>` diff, and an empty diff means stale or just created, which does not block its ticket.

## Step 3. Query the queue and reconstruct ticket identity

Follow **`/pr:next` steps 2 and 3 verbatim**. Do not restate the machinery here; if it changes, it changes there.

## Step 4. Rank and recommend

Exclude in-flight tickets. **Flag any stale status**: a merged PR whose issue is still open is marked *done*, not recommended.

Rank by:

1. **Priority band.** High outranks medium, always.
2. **`/pr:next`'s decision framework**, plus a recency theme.

**Use step 1 to inform the ranking, not merely to report it.** Prefer a ticket that continues the theme of recently landed work, which means warm context and likely faster, or one that closes a loop the recent work opened. **Name that connection explicitly when it drives the pick**, since otherwise the reader cannot tell an informed ranking from an arbitrary one.

## Output format

```
## Recently done

- **#{N}: {subject}** (PR #{n}){, invariant touched}
{3-7 bullets, newest first}

## In flight (excluded)

- **#{N}**: {open PR #{n} | active worktree}
{omit when nothing is in flight}

## Work on next

**Top pick: #{N}: {title}** ({high|medium}) · `{branch}` (derived)
**Start it:** /pr:start {branch}
{<=80 words: what it is, why now, tied to the framework and where relevant to the recent-work theme.}

### Runner-up candidates
- **#{N}: {title}** ({priority}) · `{branch}`
  {<=60 words.}
```

Rules:

- Every candidate shows its priority and derived branch, within the word caps.
- Too thin to rank? Read the comments, but only for the two or three leading candidates.
- **Zero `status:todo` issues?** Say so and stop. Do not widen the filter without asking.
- **This skill starts no work.**
- **Evidence discipline:** "recently done" comes from the handoff documents, the git log and merged PRs; "next" comes from the issue's title and body. Do not fabricate scope or history absent from those sources. Give each ticket's full URL on first mention.

## Lifecycle position

`/pr:reviews` runs outside any one branch's cycle and hands off to `/pr:start`. Fold the state check in per `${CLAUDE_PLUGIN_ROOT}/reference/lifecycle.md § How a skill uses this`.
