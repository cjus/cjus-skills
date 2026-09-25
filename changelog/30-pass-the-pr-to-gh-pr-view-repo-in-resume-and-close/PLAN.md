# Pass the PR to gh pr view --repo in resume and close

Start date: 2026-09-24 12:59:46 MDT

## Overview

Give every argument-less `gh pr view --repo "$REPO"` call in `/pr:resume` and `/pr:close` the
branch it should read, so `/pr:resume` step 6 and `/pr:close` steps 1b and 4 run as written
instead of failing with "argument required when using the --repo flag" and leaving the model to
improvise an argument.

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred`, never as new scope.

**Scope changes (operator, 2026-09-25).** At `/pr:close`'s deferred-work triage, the operator
twice chose to fix deferred items in this PR rather than ticket them.
- **Phase 6** extends the objective to the argument-less `gh pr checks --repo` calls and to the
  link edit's failed-read case.
- **Phase 7** makes close step 4 safe to re-run: it refreshes a PR body an earlier close wrote,
  and it tolerates `closingIssuesReferences` lagging an edit.

**Status (2026-09-25):** all seven phases done. The first and third close runs stopped at
triage, for Phase 6 and Phase 7. The fourth run's review gate found a regression in Phase 7,
the unguarded summary pipe. It was fixed and re-reviewed, and that run is committing the branch.

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
    with just `\n\nCloses #N`. The `:237` verify asks for a non-empty body that closes #N,
    and that body is both. Phase 3 still passes `"$BRANCH"` to the outer edit so it no longer depends on the
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
- [x] Phase 4: Verify. Run each rewritten command, as written, against this branch's own PR once
  one exists, and confirm no argument-less `gh pr view --repo` or `gh pr edit --repo` remains in
  either skill.
  - Done 2026-09-24. No argument-less `gh pr view --repo` or `gh pr edit --repo` is left in
    either skill. Before the PR existed, all five rewritten views got past argument parsing
    ("no pull requests found for branch"). Against draft PR #38, every one returns the PR's
    data. `:224` and `:239` report `false` for #30, as expected until `/pr:close` adds the
    closing reference. The outer `gh pr edit "$BRANCH"` was run with the body set to itself.
    It found PR 38 and left the body byte-identical.
- [x] Phase 5: Bump the `pr` plugin version so installed copies refresh, as the last fix to
  this plugin did.
  - Done. `plugins/pr/.claude-plugin/plugin.json` is now `0.2.5`. `scripts/test-acceptance.sh`
    passes 39/0 against the source tree.
- [x] Phase 6 (added by the operator at close triage): fix the two items that were deferred.
  - `close/SKILL.md:145` (step 1d) and `pre-test/SKILL.md:73` (step 5) pass `"$BRANCH"` to
    `gh pr checks`. Pre-test no longer uses `2>/dev/null || echo "no PR / no runs yet"`: it
    keeps gh's own message and names the two messages that mean no PR and no runs. Close's
    "No PR or no runs" bullet names the same two messages, and any other error now stops
    the gate instead of reporting it clear. The step 1b note now covers `gh pr checks` too,
    and is limited to calls that take `--repo`.
  - `close/SKILL.md:212` (step 4) reads the body into `BODY` and edits only when the read
    succeeded and returned text. A note says to stop otherwise.
  - Verified: with a stand-in `gh`, a failed read and an empty read both skip the edit, and a
    good read appends `Closes #30`. Live, `gh pr checks "$BRANCH"` returns #38's buckets,
    and reports "no checks reported on the … branch" for pre-CI PR #8 and "no pull
    requests found for branch" for a branch with no PR. No `gh pr` subcommand other than
    `list` or `create` is called with `--repo` and no argument anywhere under `plugins/`. `pr`
    stays at 0.2.5, which has not shipped yet.

- [x] Phase 7 (added by the operator at the third close's triage): make close step 4 safe to
  re-run.
  - Every body close writes now starts with `<!-- pr:close:summary -->`, piped in with
    `--body-file -`. A new table row replaces a body carrying that marker with the current
    summary, so a re-run after new commits no longer keeps the stale one. A note explains the
    marker, anchored at the start like pre-test's placeholder.
  - After a create or a replace in the same run, the link is appended without the pre-append
    check, which now applies only to a kept description. The summary must carry no literal
    closing keyword with an issue number, even in inline code.
  - The verify re-reads a `false`, up to three reads in all, before stopping.
  - Both pipes are guarded by `[ -s "$SUMMARY" ]` (found by the Phase 7 review). A pipe exits
    with `gh`'s status, so a missing summary would otherwise send a marker-only body that the
    link and the verify pass. Tested with a stand-in `gh` under bash and zsh.
  - Verified live on #38: marker replace, then guarded append. Before the append, three reads
    returned `false`; after it, the first read returned `false` and the second `true`. The body
    starts with the marker and ends with the link.

## Deferred

Discovered on this branch and out of scope for it. Not work this branch performs.

Every item below was pulled into this branch by the operator: the `gh pr checks` and link-edit
items as Phase 6, and the stale-body and lag items as Phase 7, both on 2026-09-25. All are done.
They are kept here as the record of how they surfaced.

- **Close step 4 keeps a stale PR body on a re-run** (found by the Phase 6 review). A body an
  earlier run of the same close wrote already links the issue, so step 4 treats it as a real
  description and leaves it, even when the summary has changed since. This close replaced it
  by hand. Not pulled into Phase 6.
- **`closingIssuesReferences` lags a body edit** (seen in the third close run). Right after the
  link was appended, the verify read `false`, and the next read, with no edit in between, read
  `true`. A literal close check can therefore stop on a PR that is fine. An earlier `true` read
  just after a replace was traced to an inline-code `Closes #30` in the summary, not to lag.
- **Argument-less `gh pr checks --repo`** at `close/SKILL.md:145` and `pre-test/SKILL.md:73`
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

**Triage outcome (fourth close run, 2026-09-25).**
- **Pulled in:** all four items above.
- **Ticketed as [#42](https://github.com/cjus/cjus-skills/issues/42):** from the Phase 7
  reviews, step 4's verify accepts closing references other than #N, and the rule against
  closing keywords in the summary lives in close rather than `/pr:summary`.
- **Dropped:**
  - step 6's audit statement landing in the summary after step 4 has written the body
    (assertions are disabled here);
  - the summary guard printing nothing when it fails.

## Open Questions

- ~~**`gh pr checks --repo` has the same shape.**~~ Resolved by Phase 1: it fails the same way,
  so both calls moved to `## Deferred` as the plan specified.
- ~~**Branch or PR number?**~~ Resolved 2026-09-24 (operator): the branch. It is known before
  step 4 creates the PR, and it matches the sibling skills.
