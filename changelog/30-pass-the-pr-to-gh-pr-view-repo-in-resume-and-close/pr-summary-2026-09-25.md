# Pass the PR to gh pr view --repo in resume and close

Date: 2026-09-25
Branch: `feature/30-pass-the-pr-to-gh-pr-view-repo-in-resume-and-close`
Issue: #30

## Overview

`/pr:resume` step 6 and `/pr:close` steps 1b and 4 ran `gh pr view --repo "$REPO" --json …` with
no PR number or branch. With `--repo`, `gh pr view` does not look at the checkout, so every one
of those calls exited 1 with "argument required when using the --repo flag". Every resume and
every close hit it, and the model had to improvise an argument to get past it.

Reproducing it turned up two more problems of the same kind:

- **`gh pr checks --repo` fails the same way.** `/pr:pre-test` wrapped its call in
  `2>/dev/null || echo "no PR / no runs yet"`, so it reported no CI runs on a branch whose CI had
  already passed. In `/pr:close` step 1d, that "no runs" answer means the CI gate cannot see a
  red run.
- **`gh pr edit --repo` does not fail with no argument.** It falls back to the checked-out
  branch. `/pr:close` step 4 nested the failing view inside that edit:

  ```bash
  gh pr edit --repo "$REPO" --body "$(gh pr view --repo "$REPO" --json body --jq .body)

  Closes #$N"
  ```

  Run as written, the inner view prints nothing, the edit succeeds, and the PR body is replaced
  with just `Closes #N`. Step 4's verify asks for a non-empty body that closes #N, and
  `Closes #N` alone is both, so it passes.

This PR passes `"$BRANCH"` to every `gh pr view`, `gh pr checks` and `gh pr edit` in resume, close
and pre-test that uses `--repo`. That matches the form `/pr:abort` and `/pr:cleanup` already use,
and the `gh pr list --head "$BRANCH"` and `gh pr create --head "$BRANCH"` calls in close's own
step 4. The link edit now reads the body first and edits only when that read succeeded, so a
failed read of any kind can no longer wipe the description.

The `gh pr checks` fix and the guarded link edit were first deferred. At the close's triage,
the operator pulled both into this PR (Phase 6). The next close run exposed two more gaps in
close step 4. Both were pulled in as Phase 7:

- **A re-run kept a stale body.** A body an earlier close wrote already carries the link, so it
  looked like a real description, and the PR would have merged describing the branch before
  Phase 6.
- **`closingIssuesReferences` lags a body edit.** A read taken straight after the append can
  return `false` for a body that does link the issue.

Close now marks every body it writes with `<!-- pr:close:summary -->`, and replaces a body
carrying that marker on every run. After a create or replace it appends the link without
consulting that lagging field, and the verify re-reads a `false` before stopping.

## Key changes

- **`plugins/pr/skills/resume/SKILL.md`**
  - **Step 1** now says to take the branch, repo and default branch from the lifecycle state
    check, as `/pr:close`'s Context section already does. Before this, resume used `$REPO` and
    `$DEFAULT_BRANCH` without ever saying where they came from.
  - **Step 6** passes `"$BRANCH"`. A new note explains why, and says that "no pull requests
    found for branch" means there is no PR yet, not an error.
- **`plugins/pr/skills/close/SKILL.md`**
  - **Step 1b** (`:69`) passes `"$BRANCH"`. A note under it covers the whole skill: every
    `gh pr view`, `gh pr checks` and `gh pr edit` call that takes `--repo` passes the branch,
    because view and checks refuse to infer the PR while edit silently falls back to the
    checkout.
  - **Step 1d** (`:145`) passes `"$BRANCH"` to `gh pr checks`. The "No PR or no runs" bullet
    names gh's two messages for those cases ("no pull requests found for branch", "no checks
    reported on the … branch"). Any other error is now a stop, not a clear gate.
  - **Step 4.**
    - A new table row covers a body starting with the `pr:close:summary` marker: an earlier run
      of this skill wrote it, so it is replaced with the current summary.
    - The create and the replace pipe the marker plus the summary through `--body-file -`,
      guarded by `[ -s "$SUMMARY" ]`. A pipe exits with `gh`'s status, so without the guard a
      missing summary would send a marker-only body.
    - The link edit (`:221`) reads the body into `BODY` and edits only when that read succeeded
      and returned text.
    - The pre-append check (`:238`) now applies only to a kept description. After a create or
      replace, the link is appended without it, and the summary must carry no literal closing
      keyword with an issue number.
    - The verify (`:257`) passes `"$BRANCH"` and re-reads a `false`, up to three reads in all,
      before stopping.
- **`plugins/pr/skills/pre-test/SKILL.md`**
  - **Step 5** (`:73`) passes `"$BRANCH"` to `gh pr checks` and drops the
    `2>/dev/null || echo "no PR / no runs yet"` fallback, keeping gh's own message. A note names
    the no-PR and no-runs messages, and says any other error means CI could not be read.
- **`plugins/pr/.claude-plugin/plugin.json`**: `pr` goes from 0.2.4 to 0.2.5, so installed copies
  refresh.
- **`changelog/30-…/`**: `PLAN.md`, `CHANGELOG.md`, the pre-test and close reviews, and this
  summary.

## Code examples

`/pr:resume` step 6, `plugins/pr/skills/resume/SKILL.md`. Before:

```bash
gh pr view --repo "$REPO" --json state,title,mergeable,reviewDecision,statusCheckRollup,comments
```

After:

```bash
gh pr view "$BRANCH" --repo "$REPO" --json state,title,mergeable,reviewDecision,statusCheckRollup,comments
```

`/pr:close` step 4's replace and link edit, `plugins/pr/skills/close/SKILL.md`. After:

```bash
[ -s "$SUMMARY" ] && { printf '%s\n\n' '<!-- pr:close:summary -->'; cat "$SUMMARY"; } \
  | gh pr edit "$BRANCH" --repo "$REPO" --body-file -

BODY=$(gh pr view "$BRANCH" --repo "$REPO" --json body --jq .body) && [ -n "$BODY" ] \
  && gh pr edit "$BRANCH" --repo "$REPO" --body "$BODY

Closes #$N"
```

`/pr:pre-test` step 5, `plugins/pr/skills/pre-test/SKILL.md`. Before:

```bash
gh pr checks --repo "$REPO" --json name,bucket,link 2>/dev/null || echo "no PR / no runs yet"
```

After:

```bash
gh pr checks "$BRANCH" --repo "$REPO" --json name,bucket,link
```

## Plan alignment

Phases 1 to 5 were done as planned. Phases 6 and 7 were added by the operator at close triage.

- **Phase 1, reproduce.** Confirmed on gh 2.92.0. Two findings beyond the reproduction:
  `gh pr edit` falls back to the checkout instead of failing, which is the body-overwrite risk
  above, and `gh pr checks --repo` fails the same way as `gh pr view`.
- **Phases 2 and 3, the edits.** The operator chose the branch over the PR number. It is known
  before step 4 creates the PR, and it matches the sibling skills.
  - **One deviation:** the plan said to establish `BRANCH` "in the step itself" for resume.
    It is established in step 1 instead, where the state check that yields it already runs.
    That matches close's Context section and covers `$REPO` and `$DEFAULT_BRANCH` too.
- **Phase 4, verify.** Done against this branch's PR, #38. See Testing.
- **Phase 5, version bump.** Done. Phase 6 ships in the same unreleased 0.2.5.
- **Phase 6, scope change (operator, 2026-09-25).** The first close stopped at deferred-work
  triage because the operator chose to fix both deferred items here rather than ticket them.
  That extends the objective beyond the issue's five `gh pr view` calls: to the two
  `gh pr checks` calls (`close:145`, `pre-test:73`) and to the link edit's failed-read case.
- **Phase 7, scope change (operator, 2026-09-25).** The third close run stopped at triage for
  the same reason: make close step 4 safe to re-run, with the body marker and the lag handling
  above.

## Testing

**By hand (gh 2.92.0):**

- Before #38 existed, each rewritten `gh pr view "$BRANCH" --repo …` got past argument parsing
  and returned "no pull requests found for branch".
- Once #38 existed, each returned its data. The pre-append check and the verify reported
  `false` for #30, as expected before `/pr:close` adds the closing reference.
- The same view form against merged PR #33's head branch also returned data (`[10356,true]`),
  so the branch lookup finds merged PRs too.
- An earlier, unguarded form of the outer `gh pr edit "$BRANCH" --repo …` was run with the body
  set to itself. It found PR 38 and left the body byte-identical (same shasum before and after).
- The guarded link edit, run with a stand-in `gh`: a failed read (stderr, exit 1) and an empty
  read both skip the edit, and the chain exits 1. A good read calls the edit with the body plus
  the closing line.
- `gh pr checks "$BRANCH" --repo …` returns #38's buckets
  (`fixtures (macos-latest)=pass  fixtures (ubuntu-latest)=pass`). It prints "no checks reported
  on the '…' branch" for PR #8, from before CI, and "no pull requests found for branch" for a
  branch with no PR. Both exit 1.
- No `gh pr` subcommand other than `list` or `create` is called with `--repo` and no argument
  anywhere under `plugins/`.
- The Phase 7 sequence, live on #38. The body was replaced with the marker plus the summary,
  then the guarded append added the link. Before the append, three reads returned `false`.
  After it, the first read returned `false` and the second `true`, which is the lag the re-read
  rule covers. The body starts with the marker and ends with the link.
- The summary guard, run with a stand-in `gh` under bash and zsh. A present summary is piped
  with the marker first. An empty or missing one never reaches `gh`, and the chain exits 1.
- An earlier `true` read straight after a replace was traced to an inline-code closing keyword
  in the summary, not to lag. That literal was removed, and the skill now forbids such literals
  in the summary.

**Not verified:** what `gh pr checks --json` exits with when a check is failing or pending. No PR
in this repo has a failing check. Neither skill depends on it: close reads `bucket`, and pre-test
no longer maps a non-zero exit to "no runs". Nor how long the `closingIssuesReferences` lag can
last: every lag seen here cleared by the next read.

**Automated:** `plugins/pr/scripts/test-acceptance.sh` passes 39/0 against the source tree. It
covers the plugin's scripts and hooks, not skill text, so it only shows that nothing else
broke. CI `fixtures` passes on macOS and Ubuntu.

**Edge cases considered:** no PR yet (resume reports none, close 1b falls back to the local
merge check, and close 1d and pre-test report no PR); a PR with no CI runs; a merged or closed
PR on the head branch (the branch lookup finds it); and a failed or empty body read in the link
edit.

## Impact assessment

- 4 plugin files changed, +41 −13 against the branch point. Plus the branch's changelog folder.
- No dependency changes. `gh` was already required.
- **Not a breaking change.** The skills already assumed `$BRANCH` was set: close's step 4 used it
  in `gh pr list` and `gh pr create`, and pre-test's step 3 in `gh pr list` and `gh pr create`.
  Installed copies at 0.2.3 or 0.2.4 keep the old calls until they refresh to 0.2.5.
- **Behavior changes:**
  - Pre-test step 5 shows gh's own message for `gh pr checks` errors, instead of a blanket
    "no PR / no runs yet".
  - Close now overwrites a PR body that starts with the `pr:close:summary` marker on every run,
    so hand edits to a close-written body are replaced. To keep hand edits, delete the marker
    line.
  - Bodies written by close before this change have no marker, so they are still kept as
    descriptions.

## Deferred work

None left. The four items this branch deferred were all pulled in and are done:
- as Phase 6: the `gh pr checks` calls, and the link edit's failed-read case
- as Phase 7: the stale body on re-run, and the `closingIssuesReferences` lag
