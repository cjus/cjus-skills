# PR review: Pass the PR to gh pr view --repo in resume and close

Close-gate re-run, 2026-09-25, against `main` (`75f1a0b`). The branch is one commit ahead
(`2215027`), zero behind, and pushed. PR #38 (draft, CI green), ticket #30.

**What this re-run covers.** The code commit has not changed since `pr-review-2026-09-24.md`
(APPROVE) or `pr-review-2026-09-25.md` (REQUEST_CHANGES, for a close artifact, not the code).
The delta since the last run:

- `pr-review-2026-09-24.md:84`, rewritten to fix the blocker
- `pr-summary-2026-09-25.md`, with the four wording nits applied
- `PLAN.md § Deferred`, `:143` changed to `:145`
- `pr-review-2026-09-25.md` itself, which close step 7 will also commit

As asked, I also re-checked the code diff and every close artifact from scratch.

Settled, and not raised again: the two `PLAN.md § Deferred` entries, the 09-24 review's two
optional wording suggestions (the "every" claim at `close/SKILL.md:72` and where the step 1b
note sits), and both earlier reviews' dropped items.

## Summary

Both fixes check out. The pre-test review now reports that the audit ran without reproducing
its pattern. The banned-term audit from CLAUDE.md finds nothing in any file the close will
commit, and nothing on `main` or `HEAD` either. The summary's four wording fixes are in, and I
checked every factual claim it makes against the diff, the git log and live runs against #38.
All of them hold. The code change still delivers the objective, with no regression.

## What is working well

- **The line 84 fix has the right shape.** It says the audit ran ("The case-insensitive
  banned-term audit from `CLAUDE.md` found nothing"), points to where the pattern lives, and
  reproduces none of it. A reader can trust the result without the artifact carrying the list.
- **The previous close review explains the leak without repeating it.** It refers to the two
  offending alternatives only by position ("the fourth and seventh"). Since the pattern is
  never published (`.gitignore` keeps `CLAUDE.md` local), those positions point to nothing.
  The audit finds zero hits in that file.
- **The summary fixes are exact, not approximate.** Line 25 now says what
  `close/SKILL.md:243` actually requires ("a non-empty body that closes #N, and `Closes #N`
  alone is both"). Lines 97-98 label the `false` result as expected rather than describing an
  event that has not happened. Line 77 reads "beyond the reproduction". Line 124 and
  `PLAN.md:84` both cite `:145`, which is the `gh pr checks` line on this branch.
- **The code fix still copies an existing pattern.** It uses the `gh pr view "$BRANCH" --repo
  "$REPO"` form from `abort/SKILL.md:109` and `cleanup/SKILL.md:114`, and the same `$BRANCH`
  that close step 4 already passes to `gh pr list --head` and `gh pr create --head`.

## Verification

Run 2026-09-25 on gh 2.92.0.

| Check | Result |
|---|---|
| Banned-term audit from CLAUDE.md, case-insensitive, with the pattern read verbatim from that file | Positive control: 8 hits in `CLAUDE.md` itself, so the pattern is live. **Zero hits** in each of `PLAN.md`, `CHANGELOG.md`, `pr-review-2026-09-24.md`, `pr-review-2026-09-25.md` and `pr-summary-2026-09-25.md`. Also zero in `git grep main`, `git grep HEAD`, the `main...HEAD` diff, the working-tree diff, the commit message, and #38's title and body. This file was audited after writing, also zero. |
| Attribution sweep (plan folder, commit message and author) | Clean. The commit is authored as the repo owner, and the subject is a lowercase imperative. |
| `org/repo`-shaped and cross-repo URL sweep | One match: `github.com/org/repo` at `pr-review-2026-09-24.md:85`. It is a generic placeholder naming what that review searched for, not a reference. Every `#N` (#25, #28, #30, #33, #38) resolves to this repo. |
| Closing keyword followed by a number | None in the summary. The review files quote "resolved #38" and "Closes #30" as text in the file. That is inert, since GitHub acts only on the PR body and commit messages. |
| `git diff main...HEAD --numstat -- plugins/` | 1/1, 6/4, 5/1: +12 −6 across 3 files, as the summary says |
| `grep -nE 'gh pr (view\|edit) --repo'` over both skills | No output, as the summary says |
| Resume `:75`, as written | Exit 0, `["OPEN","MERGEABLE",2,0]` |
| Close `:69`, as written | `["MERGEABLE","CLEAN","main"]` |
| Close `:224` and `:239`, as written, `N=30` | `false` and `[202,false]`. Expected, since there is no closing reference yet. |
| Argument-less `gh pr view --repo cjus/cjus-skills --json state` | Exit 1, "argument required when using the --repo flag" |
| `pre-test/SKILL.md:73`, as written | Prints "no PR / no runs yet". The same call with the branch passed returns both `fixtures` jobs as `pass`, which confirms the deferred symptom. |
| `plugins/pr/scripts/test-acceptance.sh "$PWD/plugins/pr"` | passed 39, failed 0 |
| `jq -e .version plugins/pr/.claude-plugin/plugin.json` | `"0.2.5"` |
| `git diff --check` (committed and working tree), trailing whitespace, final newline | Clean |

**Summary accuracy, claim by claim.** The summary says:

- The old calls exited 1. Reproduced.
- The old nested edit falls back to the checkout. This matches the 09-24 review's reading of
  gh's source.
- Every `--repo` view and edit in both skills now passes the branch. True: `close:393` has no
  `--repo`.
- Before this PR, resume used `$REPO` and `$DEFAULT_BRANCH` without naming their source. True:
  on `main`, `resume/SKILL.md` uses `$DEFAULT_BRANCH` at lines 65-66 and `$REPO` at line 73,
  and step 1 never says where either comes from.
- The branch form matches abort and cleanup. True.
- The deviation it records (`BRANCH` is established in step 1, not in step 6) is how the diff
  does it.
- It cites step 4's lines as `:212`, `:224` and `:239`. Those are the lines on this branch.
- Pre-test's `gh pr checks` call is in its step 5. True.
- The plugin moves from 0.2.4 to 0.2.5. True.

## Issues found

### Critical

None. The earlier blocker is fixed: see the first bullet of What is working well and the audit
row in Verification.

### Important

None.

### Suggestions

None.

### Deferred to follow-up

None new. `PLAN.md § Deferred` still holds this branch's two real follow-ups, and close step 6b
triages them from there.

**Considered and dropped** (not carried forward):

- **The 09-24 review cites gh's own source files as evidence** (`pkg/cmd/pr/.../*.go` at
  v2.92.0). The CLAUDE.md rule is aimed at the owner's other projects. gh is the public tool
  these skills call, so citing its source documents a dependency. It does not leak private
  work.
- **`CHANGELOG.md:17-20` and `PLAN.md:48` keep the two slips the summary fixed.** Those are
  "`close:143`" and "only checks for a non-empty body". Both are dated Phase 1 entries that use
  `main`'s line numbers throughout (they cite `:210` in the same place). Their conclusion still
  holds, and `/pr:condense` may rewrite `CHANGELOG.md` anyway.
- **Summary line 48, "the pre-test and close reviews"**, does not list this re-run file
  separately. The plural covers it.

## Questions

- **The installed copy of `/pr:close` is still 0.2.3.** The plugin cache holds only that
  version, and its `close/SKILL.md:210` still has the argument-less nested
  `gh pr edit --repo … "$(gh pr view --repo …)"`. #38 carries the 202-char placeholder, so
  step 4 will first replace it with the summary and then run the link edit. Run as 0.2.3
  words it, the inner view fails and the edit falls back to the checkout. That replaces the
  summary with `\n\nCloses #30`, and the verify still passes at `[12,true]`. This is the bug
  this PR fixes, reached through the old copy. At step 4 and again at 8b, pass `"$BRANCH"` by
  hand (the 0.2.5 form), or refresh the plugin first. Then confirm step 8b reports a length in
  the thousands (the summary is about 6,470 characters), not 12. The previous run raised this
  too. It is repeated here because nothing has changed it.

## Verdict

VERDICT: APPROVE

The pre-test review file no longer quotes the pattern. The audit is clean across everything
the close commits. The summary is accurate, and the code delivers #30's objective with no
regression. Proceed with the close, passing `"$BRANCH"` by hand at steps 4 and 8b while the
installed plugin is 0.2.3.
