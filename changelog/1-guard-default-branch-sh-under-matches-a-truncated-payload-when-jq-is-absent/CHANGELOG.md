# guard-default-branch.sh under-matches a truncated payload when jq is absent

Start date: 2026-09-30 10:51:36 MDT

When `jq` is absent, the default-branch guard falls back to matching the raw payload. That
fallback promises to over-match and never under-match. A payload cut off inside its `command`
value breaks the promise: no git verb survives the cut, so the hook exits 0 and a commit or push
on the default branch runs unguarded. This branch makes the no-jq path recognise a truncated
payload and deny it, as the jq path already does, and adds a test probe that fails without the fix.

## Changes

`pr-summary-2026-09-30.md` has the full narrative: the code examples, the plan-alignment table
and the mutation table. The review findings are in `pr-review-2026-09-30.md` and
`pr-review-2026-09-30-close.md`. All three timestamps below are kept, and each entry is
condensed to its decisions and their evidence.

### 2026-09-30 10:55:58 MDT — Phase 1: reproduced against `main` @ `3dea6ba`

The hook was run directly against opted-in throwaway repos. Its `PATH` was a folder of links to
only `cat`, `git`, `grep` and `dirname`. Dropping a directory from `PATH` does not hide jq,
because macOS also ships `/usr/bin/jq`.

With jq absent:

- A whole `git commit` got `ask`.
- The same payload cut before the verb exited 0 with no output.
- **Empty stdin** also exited 0 with no output. The ticket did not name this case.

The jq path denied both of the failing payloads. The no-jq branch gates any commit without
looking up the branch, so a probe needs only an opted-in repo. `gate()` exits 0 without the
opt-in.

### 2026-09-30 11:14:19 MDT — Phases 2–5: probes, the completeness check, mutation proof, docs

**Probes.** 18 cases were added in three no-jq sections: 73 → 91. They are the first cases to
cover this path. The first checks that jq is hidden, because otherwise the jq path's own deny
lets every case pass vacuously. `CLAUDE_PROJECT_DIR` is set per case, because this path ignores
the payload's `cwd`. Against the unfixed hook the run was 85/6, and the 6 failures were exactly
the truncation cases.

**The check.** A payload counts as whole only if both of these hold:

- a `command` key has a string value that closes on an unescaped `"`
- the payload ends in `}`

The check runs before the approval token and the mode recovery, and gates with `MODE` empty,
so a cut payload is `deny` in every mode. That settles all four open questions in the plan.

**Evidence.**

- **Prefix sweep.** Every prefix of four sample payloads was tried under `C` and UTF-8. No cut
  inside the command got through, and no whole payload was rejected.
- **Cost.** 0.08s for a 1MB command.
- **Mutants.** Seven mutants were each caught by their own case, with 85 to 90 of 91 passing.
  Two probes were reshaped until the any-quote mutant and the heuristic-close mutant failed.
- **Acceptance.** 42 of 42.

**Found in passing.** Under a UTF-8 locale, an invalid UTF-8 byte used to make every `=~` in
this path match nothing, which let a commit through. The check now denies it. This case is
parked under Deferred.

**Docs.**

- The hook's comment block and decision table describe the check.
- The README count is now 91.
- The README's mass-failure shapes were measured again. The old 31/42 was reproduced from
  `main` first, and the new shapes are 33/58 and 6/85.
- `pr` goes from 0.2.9 to 0.2.10.

### 2026-09-30 — Pre-test: draft PR #53, review APPROVE, escalation filed as #54

**Reviews.** The first review was APPROVE. It swept every byte prefix of 11 payloads on macOS
and on Ubuntu (bash 5.2, glibc) and found nothing that got through. Its four findings were all
applied:

- The README claimed whole-payload parity with jq, which is not true. It now says a whole
  payload gets "the decision it always did".
- The mass-failure paragraph's explanation of why each shape occurs was fixed.
- The blind-spot comment now names a class of cuts and states what the check guarantees.
- The comment now says the closing-quote half relies on `command` being the only key of that
  name in the payload.

The close-gate review was also APPROVE. It corrected the blind-spot wording again: GIT_VERB
reads the whole raw payload, so the guarantee is that the command is read whole, not that the
input is identical.

**Escalated.** The review found two pre-existing fail-opens, and I reproduced both on `main`
and on the branch:

- With no jq, a whole payload whose command ends in its verb, or has the verb at the start of
  a later line, passes.
- With a jq that cannot run, the hook passes everything.

Under the scope contract's rule for pre-existing security defects, both were filed as one issue:
#54.
