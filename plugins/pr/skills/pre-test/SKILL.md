---
name: pre-test
description: Review the branch and decide whether it is ready for hands-on testing. Refreshes PLAN.md status, opens a draft PR so CI starts running, runs the configured checks, and runs a code review. Use when the user says "/pr:pre-test", asks whether the branch is ready to test, or wants a review pass before closing.
allowed-tools: Bash(node:*), Bash(git:*), Bash(gh:*), Bash(printf:*), Read, Write, Edit, Glob, Grep, Agent
---

# /pr:pre-test

Answer one question: **is this branch ready for the operator to test by hand?**

Readiness means the objective is delivered and nothing regressed. It does **not** mean the review found zero issues. See `${CLAUDE_PLUGIN_ROOT}/reference/scope-contract.md`.

## Step 1. Branch context

```bash
node "${CLAUDE_PLUGIN_ROOT}/scripts/pr-lifecycle-state.mjs" --text
```

That yields the branch, the slug, the repo, the plan folder's state, and the PR and CI state in one call.

## Step 2. Refresh PLAN.md

Check whether `<changelogRoot>/<slug>/PLAN.md` still describes the branch, and update it where status has moved.

> **Update status, never scope.** Newly discovered work goes under `## Deferred`, not into the plan's checklist. The objective was fixed at `/pr:start` and only the operator changes it.

## Step 3. Open a draft PR, before the local checks

Do this **first**, not last. CI then runs in parallel with the checks below instead of starting once they finish.

**Where CI triggers on pull requests, a branch gets no CI signal at all until a PR exists.** A close that reports green while CI has never run is reporting the absence of a signal as a pass. That has happened: a branch closed green, and its first CI run, which only started when the PR was opened afterward, failed.

This step is idempotent. Resolve the current state first:

```bash
gh pr list --head "$BRANCH" --repo "$REPO" --state all --json number,state,isDraft --jq '.[0]'
```

| State | Action |
|---|---|
| An open PR exists, draft or not | No-op. Report its number. **Never open a second one.** |
| A closed or merged PR exists | No-op, and say so. Reopening is the operator's decision, not this step's. |
| No PR | Push anything unpushed, then open a draft |

```bash
git push -u origin HEAD
gh pr create --draft --repo "$REPO" --base "$DEFAULT_BRANCH" --head "$BRANCH" \
  --title "<PLAN.md's H1, or the branch slug>" \
  --body "$(printf '<!-- pr:pre-test:draft-placeholder -->\n\nDraft opened by /pr:pre-test so CI runs while the branch is still in development. /pr:close replaces this body with the PR summary and adds the closing reference.')"
```

**Keep the `pr:pre-test:draft-placeholder` marker as the body's first line.** `/pr:close` keys on it to know the body is a stub to replace wholesale rather than a real description to preserve. Dropping the marker makes the placeholder text survive into the merged PR. The lifecycle script anchors its check to `startsWith`, so the marker must lead the body, not merely appear in it.

**`gh pr create` fails when the branch has no commits ahead of the default branch.** That is the expected state on a branch whose work is still uncommitted. It is not a failure of this step: report it and continue to the checks.

**Do not gate on the CI run here.** It has only just started.

## Step 4. Run the checks

Run whichever of `checks.lint`, `checks.typecheck`, `checks.test` and `checks.build` are configured. **A `null` check is absent, not failing:** skip it silently and never report it as a gap.

Where a build command is configured, **run it last and do not skip it.** It is usually the slowest and the most load-bearing, and in a repo with a pre-commit build hook a failure here is a commit failure later.

Then run a code review over the diff with the `Agent` tool, using `${CLAUDE_PLUGIN_ROOT}/agents/code-reviewer.md`.

Beyond the automated suites, "testing" means manual verification of the objective, so judge whether the branch is in a state where that is possible.

> Deferred and suggestion-level findings do not hold up testing. Only an in-scope blocking finding does, or a lesser one that is a **regression against the objective**.

## Step 5. Report CI if it has finished, then name the next command

```bash
gh pr checks --repo "$REPO" --json name,bucket,link 2>/dev/null || echo "no PR / no runs yet"
```

**Read `bucket`, not `state`.** It is the documented categorization of a raw state into `pass`, `fail`, `pending`, `skipping` or `cancel`, so it survives a renamed raw state.

Report it as one line. A run still in progress is `pending`, which is information rather than a blocker, and **do not wait on it here**.

**A red CI does not override the readiness verdict**, because this skill answers whether the branch is ready for hands-on testing, and a failing check rarely changes that answer. Report it plainly and let the operator decide. `/pr:close` is what halts on red CI, so a failure surfaced here is something to fix before the close, not a reason to withhold the branch from testing.

- **Ready** ends with exactly this, and nothing softer: *"Ready for testing. Once you have verified it, run `/pr:close`. It is required before this branch can merge."*
- **Not ready** names the blocking finding and the one next step, and does **not** mention `/pr:close`.

Never describe a branch as merge-ready without naming that command, and never run the close yourself.

## Lifecycle position

`/pr:pre-test` closes the work band and hands off to `/pr:close`. Fold the state check into the report per `${CLAUDE_PLUGIN_ROOT}/reference/lifecycle.md § How a skill uses this`.
