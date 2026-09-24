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
  the edit replaces the PR body with just `Closes #N`. The step 4 verify checks only for a
  non-empty body, which that passes.
- **Finding:** argument-less `gh pr checks --repo` fails like `gh pr view`. Per the plan's own
  rule, `close:143` and `pre-test:73` go to `## Deferred`, not into this branch.

### Phases 2, 3 and 5: the edits (2026-09-24)

- **Decision (operator):** pass the branch, not the PR number.
- **`resume/SKILL.md`**: step 1 reads the branch, repo and default branch from the state check.
  Step 6 passes `"$BRANCH"` and treats "no pull requests found" as no PR.
- **`close/SKILL.md`**: `:69`, `:212` (both halves), `:224` and `:239` pass `"$BRANCH"`. A note
  in step 1b explains why every `gh pr view` and `gh pr edit` in the skill needs the branch.
- **`pr` 0.2.4 → 0.2.5**, so installed copies refresh.

### Phase 4: verified up to the missing PR (2026-09-24)

- No argument-less `gh pr view --repo` or `gh pr edit --repo` is left in either skill.
- All five rewritten views get past argument parsing. The same form returns data for merged
  PR #33. The acceptance suite passes 39/0.
- **Still open:** re-running them against this branch's own PR.
