# Pass the PR to gh pr view --repo in resume and close

Start date: 2026-09-24 12:59:46 MDT

Give every argument-less `gh pr view --repo "$REPO"` call in `/pr:resume` and `/pr:close` the
branch it should read, so those steps run as written instead of failing with "argument required
when using the --repo flag".

## Changes

### Phase 1: `gh pr view` reproduced; `gh pr edit` behaves differently (2026-09-24)

- **Reproduced on gh 2.92.0.** Argument-less `gh pr view --repo` exits 1 with "argument required
  when using the --repo flag". With the branch passed, the call is accepted.
- **Finding:** argument-less `gh pr edit --repo` falls back to the checked-out branch, so
  `close/SKILL.md:210` run literally does not stop. Its inner view prints nothing to stdout, and
  the edit replaces the PR body with just `Closes #N`. The step 4 verify asks for a non-empty
  body that closes #N, and that body is both.
- **Finding:** argument-less `gh pr checks --repo` fails like `gh pr view`. Per the plan's own
  rule, `close:143` and `pre-test:73` go to `## Deferred`, not into this branch.

### Phases 2, 3 and 5: the edits (2026-09-24)

- **Decision (operator):** pass the branch, not the PR number.
- **`resume/SKILL.md`**: step 1 reads the branch, repo and default branch from the state check.
  Step 6 passes `"$BRANCH"` and treats "no pull requests found" as no PR.
- **`close/SKILL.md`**: `:69`, `:212` (both halves), `:224` and `:239` pass `"$BRANCH"`. A note
  in step 1b explains why every `gh pr view` and `gh pr edit` in the skill needs the branch.
- **`pr` 0.2.4 → 0.2.5**, so installed copies refresh.

### Phase 4: verified against draft PR #38 (2026-09-24)

- No argument-less `gh pr view --repo` or `gh pr edit --repo` is left in either skill.
- Every rewritten view returns #38's data. The outer `gh pr edit "$BRANCH"` found PR 38, and
  setting the body to itself left it byte-identical. The acceptance suite passes 39/0.

### Close (2026-09-25)

- **First close run halted at the review gate** (`pr-review-2026-09-25.md`, REQUEST_CHANGES).
  The untracked pre-test review quoted the banned-term audit pattern, and the pattern contains
  literal project names. The line was reworded to refer to `CLAUDE.md` instead, and the summary
  took the reviewer's four wording fixes. Nothing had reached git or GitHub.
- **Re-run approved** (`pr-review-2026-09-25-rerun.md`). Steps 1b, 1d, 4 and 8b pass `"$BRANCH"`
  by hand, because the installed 0.2.3 close skill still carries the calls this branch fixes.
- **Decision (operator), at deferred triage:** fix both deferred items in this PR. The close
  stopped there, before step 7, and nothing was committed.

### Phase 6: the two deferred items (2026-09-25)

- **`gh pr checks` passes `"$BRANCH"`** at `close:145` and `pre-test:73`. Pre-test drops the
  `2>/dev/null || echo` that turned the argument error into a false "no runs yet". Both skills
  name gh's "no pull requests found" and "no checks reported" messages. Close stops on any
  other error.
- **Close step 4's link edit** reads the body into a variable and edits only on a successful,
  non-empty read.
- **Verified:** a stand-in `gh` shows the edit is skipped when the read fails or is empty. Live
  runs cover #38, pre-CI PR #8 and a branch with no PR.
- **Not verified:** what `gh pr checks --json` exits with when a check is failing or pending.
  No PR in this repo has a failing check. Neither skill depends on it: close reads `bucket`,
  and pre-test no longer maps a non-zero exit to "no runs".
- **Third close run approved** (`pr-review-2026-09-25-phase6.md`). The summary was rewritten to
  cover Phase 6. The review found that step 4 would keep #38's pre-Phase-6 body, so this run
  replaces it by hand. That gap is parked under `## Deferred`.
- **Decision (operator), at the third close's triage:** fix the two new step 4 items in this PR
  too. The close stopped there, before step 7.

### Phase 7: close step 4 safe to re-run (2026-09-25)

- **Marker:** close writes `<!-- pr:close:summary -->` as a body's first line. A body carrying it
  is replaced with the current summary on every run.
- **Lag:** after a create or replace, the link is appended without the pre-append check. The
  verify re-reads a `false`, up to three reads in all.
- **Review finding, fixed (operator: fix, re-review, continue):** the create and replace pipes
  sent a marker-only body when the summary was missing, and the verify passed it. Both pipes
  are now guarded by `[ -s "$SUMMARY" ]`.
- **Fourth close run:** the re-review approved (`pr-review-2026-09-25-phase7-fix.md`), and the
  run continued from step 3.
- **Finding:** a clean test on #38 showed the lag only after the append (`false`, then `true`).
  The earlier stale-looking `true` after a replace came from an inline `Closes #30` in the
  summary, since removed. The skill now says to keep such literals out of the summary.
