---
name: resume
description: Establish the actual current state of a branch after a break, from git, GitHub and the branch's own documents rather than from conversation memory, and lead with the open questions and blockers. Use when the user says "/pr:resume" or returns to work after time away.
allowed-tools: Bash(node:*), Bash(git:*), Bash(gh:*), Read, Glob
---

# /pr:resume

Get back up to speed on ground truth.

This is deliberately **not** a recap of the conversation. It examines git, GitHub and the branch's files to establish where things actually stand, which is frequently not where the last message said they were.

## Step 1. Identify the branch and its folders

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/pr-lifecycle-state.mjs" --text
```

Take the branch, repo and default branch from that.

**The distinction that matters:** per-branch files (`PLAN.md`, `CHANGELOG.md`, `pr-summary-*.md`, `pr-review-*.md`) live in `<changelogRoot>/<slug>/`. Repo-global documents, including the assertions file and the continuity folder, live at the repo root and are **shared across every branch**. They are never duplicated per branch, so do not look for them inside the branch folder. See `${CLAUDE_PLUGIN_ROOT}/reference/handoff-docs.md`.

## Step 2. Read the branch's documents

- `PLAN.md`, for the objective and its checkboxes.
- `CHANGELOG.md`, for curated decisions. It may be sparse.
- Any `pr-review-*.md`, for findings that were never addressed.
- The newest few continuity entries at the repo root, for recent repo-wide context:

```bash
ls "$CONTINUITY_ROOT"/[0-9]*.md | sort -r
```

## Step 3. Read the assertions file

At the **repo root**, at the configured path. Never inside the branch folder.

- **Configured as `null`** → report `assertions: disabled` and skip step 4.
- **Configured but absent** → flag it in the report and **continue**; skip step 4 this run. Recommend creating one, or offer to draft an initial set.
- **Present** → parse every entry: `ID`, `Constraint Type`, `Evidence`, `Status`, `Impact of Violation`, `Re-validate`.

## Step 4. Cross-check assertions against the plan's scope

For each entry, decide whether it is **in scope**: the plan touches a file or symbol named in `Evidence`, or the plan's work matches a `Re-validate` trigger.

For every in-scope assertion, flag a discrepancy when any of these hold:

- The plan proposes changing something a `Re-validate` trigger names. That is a re-validation flag rather than a discrepancy in itself.
- The plan's intended end state appears to **contradict** the constraint.
- `git log --oneline -- <evidence-path>` shows the `Evidence` symbol was renamed, moved or removed in merged work. The assertion is stale and should be re-anchored.
- The plan's described behavior already silently violates a still-valid assertion.

Report each with one of:

```
✅ A-NNN: in scope, still satisfied: <one line, citing the symbol>
⚠️ A-NNN: in scope, needs re-validation: <which trigger fires, and what to verify>
❌ A-NNN: in scope, the plan appears to violate it: <how, which symbol, recommended resolution>
```

None in scope? Say so explicitly.

## Step 5. Check git state

```bash
git status
git log "$DEFAULT_BRANCH"..HEAD --oneline
git diff "$DEFAULT_BRANCH"...HEAD --stat
git stash list
```

## Step 6. Check GitHub state

```bash
gh pr view "$BRANCH" --repo "$REPO" --json state,title,mergeable,reviewDecision,statusCheckRollup,comments
```

**Always pass the branch.** With `--repo`, `gh pr view` does not infer the PR from the checkout: it stops with "argument required when using the --repo flag". "No pull requests found for branch" means there is no PR yet. Report that; it is not an error.

Review comments needing a reply, CI status, merge conflicts.

## Step 7. Collect the open questions and blockers

Gather everything standing between this branch and its next action, in roughly this order of consequence:

- **`PLAN.md § Open Questions`.** **Check each against the commits and diff from step 5 before reporting it**: work done since the break may already have answered it. An answered question is reported as resolved, naming what resolved it, rather than re-asked.
- **The `⚠️` and `❌` assertion flags** from step 4.
- **CI failures, merge conflicts and unresolved review comments** from step 6, including unchecked TODO checkboxes in PR comments.
- **Unaddressed findings** in any `pr-review-*.md`.
- **`gaps`** from the state check.

**`PLAN.md § Deferred` is NOT a source.** Those entries are a triage inbox, triaged once at `/pr:close`, and most exit as DROP. Surfacing them here presents work that is about to be dropped as work that is outstanding.

Write **one line per surviving item**: the question or blocker, then who or what resolves it. **Say explicitly when only the operator can answer**, because that is the item they have to act on. Where the answer changes what gets built, say what each branch of the answer implies, in a clause.

Sort by consequence: what blocks the very next action, then a later step, then what is merely worth knowing.

## Step 8. Report

**The open questions and blockers lead the report**, above the branch and CI scaffolding. When step 7 found nothing, that collapses to a single clause and never becomes a section of its own.

Then: branch, PR status, CI status, commits ahead, uncommitted changes, progress against the plan, recent activity, the assertion audit, and the recommended next step.

**Ground truth is git plus GitHub plus `PLAN.md` plus the assertions file.** `CHANGELOG.md` is curated and supplementary, never authoritative.

## Step 9. State readiness

Conclude with exactly one of:

- **"Ready to continue working on this branch."** No `❌`, every `⚠️` has a plan, and nothing blocks the next action.
- **"Blocked on assertion violation: A-NNN. Resolve before continuing."**
- **"Blocked on N unanswered question(s), listed above."** Repeat the single most consequential question **verbatim** on this line, so the conclusion is actionable without scrolling back. **Do not pick an answer and build on it.**
- **"This branch looks merge-ready. Run `/pr:close`."** No open in-scope items, no `❌`, nothing outstanding in CI or review. Name the command rather than saying "ready to merge", and never invoke the close from here. Where the operator has granted standing permission to run `/pr:close`, it runs as its own step after this report (`${CLAUDE_PLUGIN_ROOT}/reference/lifecycle.md § How a skill uses this`).

## Lifecycle position

`/pr:resume` runs inside the work band, on returning after a break. Fold the state check in per `${CLAUDE_PLUGIN_ROOT}/reference/lifecycle.md § How a skill uses this`.
