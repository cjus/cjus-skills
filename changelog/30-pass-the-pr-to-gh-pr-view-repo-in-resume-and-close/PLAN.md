# Pass the PR to gh pr view --repo in resume and close

Start date: 2026-09-24 12:59:46 MDT

## Overview

Give every argument-less `gh pr view --repo "$REPO"` call in `/pr:resume` and `/pr:close` the
branch it should read, so `/pr:resume` step 6 and `/pr:close` steps 1b and 4 run as written
instead of failing with "argument required when using the --repo flag" and leaving the model to
improvise an argument.

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred`, never as new scope.

## About Ticket

Issue #30: Pass the PR to gh pr view --repo in resume and close

`gh pr view --repo "$REPO" --json …` fails when it gets no PR number or branch:
"argument required when using the --repo flag".

- [x] Pass the PR number or branch at every argument-less call:
  - `plugins/pr/skills/resume/SKILL.md:73`
  - `plugins/pr/skills/close/SKILL.md:69`
  - `plugins/pr/skills/close/SKILL.md:210`
  - `plugins/pr/skills/close/SKILL.md:222`
  - `plugins/pr/skills/close/SKILL.md:237`

**Symptom:** `/pr:resume` step 6 and `/pr:close` steps 1b, 4 and 8b fail as written, and the
model has to improvise an argument. Both were hit during #25's resume and close.

**Occasion:** every `/pr:resume` and `/pr:close`.

Triaged 2026-09-24 against `main` @ `75f1a0b`: still valid, all five calls unchanged.

## Plan

- [x] Phase 1: Reproduce. Confirm `gh pr view --repo cjus/cjus-skills --json state` fails with
  the quoted error, and that the same call with a branch argument is accepted. Check whether
  `gh pr edit --repo` fails the same way, since `close/SKILL.md:210` nests the failing view
  inside an argument-less `gh pr edit --repo "$REPO"`.
  - Done 2026-09-24 on gh 2.92.0. Argument-less `gh pr view --repo` fails with the quoted error.
    With the branch passed, the call gets past argument parsing ("no pull requests found for
    branch", since no PR exists yet).
  - **Argument-less `gh pr edit --repo` does not fail the same way.** It falls back to the
    checked-out branch. On `:210` that makes the bug a data-loss risk, not just a failed step.
    The inner view fails with empty stdout, the outer edit succeeds, and the PR body is replaced
    with just `\n\nCloses #N`. The `:237` verify only checks for a non-empty body, which that
    passes. Phase 3 still passes `"$BRANCH"` to the outer edit so it no longer depends on the
    working directory.
  - Argument-less `gh pr checks --repo` fails the same way as `gh pr view`. See `## Deferred`.
- [x] Phase 2: `/pr:resume` step 6 (`resume/SKILL.md:73`) passes `"$BRANCH"`. The skill never
  names `BRANCH`, so establish where it comes from (the branch checked out, or the lifecycle
  state's `branch`) in the step itself.
  - Done. Step 1 now says to read the branch, repo and default branch from the lifecycle state
    check, as `/pr:close`'s Context section does. Step 6 passes `"$BRANCH"`, explains why, and
    treats "no pull requests found for branch" as no PR, not an error.
- [x] Phase 3: `/pr:close` steps 1b and 4 (`close/SKILL.md:69`, `:210`, `:222`, `:237`) pass
  `"$BRANCH"`, the same variable the step's own `gh pr list --head "$BRANCH"` (`:191`) and
  `gh pr create --head "$BRANCH"` (`:206`) already use. On `:210` that covers both the outer
  `gh pr edit` and the inner `gh pr view`. This matches the `gh pr view "$BRANCH" --repo "$REPO"`
  form `/pr:abort` and `/pr:cleanup` already use.
  - Done. All four calls, now at `:69`, `:212`, `:224` and `:239`, pass `"$BRANCH"`, including both
    halves of `:212`. A note under `:69` covers the whole skill: why the branch is required,
    and that `gh pr edit` falls back to the checkout instead of failing.
- [ ] Phase 4: Verify. Run each rewritten command, as written, against this branch's own PR once
  one exists, and confirm no argument-less `gh pr view --repo` or `gh pr edit --repo` remains in
  either skill.
  - Partly done 2026-09-24. No argument-less `gh pr view --repo` or `gh pr edit --repo` is left
    in either skill. Each rewritten `gh pr view` was run as written: all five get past
    argument parsing and return "no pull requests found for branch", since this branch has no
    PR yet. The same form run against merged PR #33's head branch returns its data
    (`[10356,true]` from the `:239` jq). **Still open:** a run against this branch's own PR.
    The outer `gh pr edit` was not run, because it writes.
- [x] Phase 5: Bump the `pr` plugin version so installed copies refresh, as the last fix to
  this plugin did.
  - Done. `plugins/pr/.claude-plugin/plugin.json` is now `0.2.5`. `scripts/test-acceptance.sh`
    passes 39/0 against the source tree.

## Deferred

Discovered on this branch and out of scope for it. Not work this branch performs.

- **Argument-less `gh pr checks --repo`** at `close/SKILL.md:143` and `pre-test/SKILL.md:73`
  fails with "argument required when using the `--repo` flag" (Phase 1). `close` step 1d's
  "No PR or no runs → report plainly" makes the failure read as no CI verdict rather than a
  gate. `pre-test`'s `2>/dev/null || echo "no PR / no runs yet"` hides it completely, so pre-test
  reports "no runs yet" even when a PR with finished CI exists. The fix is the same
  `"$BRANCH"` argument.
- **`close/SKILL.md:212` still overwrites the body if the inner read fails for any other
  reason.** Passing the branch removes the failure this ticket is about, but a network or auth
  error in the inner `gh pr view` still produces an empty `$(…)`, and the outer edit still
  succeeds. Reading the body into a variable and stopping when that read fails would close the
  gap.

## Open Questions

- ~~**`gh pr checks --repo` has the same shape.**~~ Resolved by Phase 1: it fails the same way,
  so both calls moved to `## Deferred` as the plan specified.
- ~~**Branch or PR number?**~~ Resolved 2026-09-24 (operator): the branch. It is known before
  step 4 creates the PR, and it matches the sibling skills.
