# Close two degraded-jq fail-opens in guard-default-branch.sh

Start date: 2026-09-30 13:16:16 MDT

The default-branch guard has two degraded-jq paths that fail open silently. Without jq, the
raw-payload match misses a verb whose boundary is JSON syntax. That happens when the verb is the
last word of the command, before the closing quote, or starts a later line, after an escaped
newline. When jq is on `PATH` but cannot run, the parse fails and `gate()` is called, but
`gate()`'s own `jq -nc` fails as well, so the hook prints nothing. This branch closes both holes
and adds probes that fail without each fix.

## Changes

`pr-summary-2026-09-30.md` has the full narrative, the code examples and the plan alignment.
The reviews are `pr-review-2026-09-30.md` (pre-test) and `pr-review-2026-09-30-close.md` (close
gate). Every timestamp below is kept, and each entry is condensed to its decisions and their
evidence.

### 2026-09-30 13:55:26 MDT: Phase 1, both holes reproduced against `main` @ `a26f79c`

**Reproduction.** Nine commands were each run in `default` and `bypassPermissions` mode, on the
jq path, a no-jq `PATH` of links to `cat`, `git`, `grep` and `dirname`, and a broken-jq `PATH`
with a stub `jq` that exits 126:

- Commands: `git push`, `git commit`, `cd /x && git push`, `git add -A`⏎`git commit -m x`,
  `ls`⏎`git push origin main`, `git push`⏎`echo done`, `git push`⇥`echo done`, `git commit` + CR,
  and `git commit -m x`.
- The jq path asked or denied every one.
- The no-jq and broken-jq paths printed nothing for all of them, with one exception: the no-jq
  path gated `git commit -m x`.
- With a broken jq, even `ls -la` passed only because `gate()` failed silently.

**Item 1: widen the regex, don't decode.** Decoding needs `${s//…/…}`, which grows roughly with
the cube of the length under bash 3.2: 1.1s for 10KB, 8.3s for 20KB, 66s for 40KB. A 1MB run
was killed after 100s. `GIT_VERB_RAW` adds `\\([bfnrt]|u[0-9a-fA-F]{4})` before `git`, in
whitespace runs and after the verb, plus the unescaped closing `"` after the verb, and removes
nothing from `GIT_VERB`.

- **Differential test.** 160,000 checks: 2 encoders × 2 seeds × `C` and UTF-8 × 20,000
  commands.
  - Today's raw match missed 95–98% of the decoded matches.
  - `GIT_VERB_RAW` missed none, and over-matched 400–842 per run, the safe direction.
- **Cost.** At worst 0.32s against 0.07s, over six 1MB stress shapes.

**Item 2: the operator chose "ask".** After a failed parse, `jq -n true` decides: jq runs and
the payload is denied, or jq cannot run and the no-jq path takes over. `gate()` also falls back
to `printf` whenever `jq -nc` prints nothing.

### 2026-09-30 14:07:29 MDT: Phases 2–6, probes, both fixes, mutation proof, docs

**Probes.** 22 new cases took the suite from 91 to 113. `nj` now wraps `pj`, which takes the
hook's `PATH`.

- 10 no-jq cases for item 1. Eight must gate, including one that must deny under
  `bypassPermissions`. Two pin precision: `echo "git push"` and `printf 'git push\n'` must pass.
- A broken-jq harness with 8 cases.
- A harness whose stub `jq` fails only on `-nc`, with 3 cases.
- A trailing-comma payload that must still be denied when jq runs.

Against the unfixed hook, 98 passed and 15 failed, and the 15 are exactly the gating cases.
The other 7 pass either way. Two check the harness or guard against regression, and mutants
turn the other five red.

**Fixes.** The no-jq branch now uses `GIT_VERB_RAW`. On a parse failure, `jq -n true` routes to
deny or to the no-jq branch, which now opens with `if [[ "$HAVE_JQ" == 0 ]]`. `gate()` captures
`jq -nc` and falls back to `printf`, swapping a reason that `printf` cannot escape.

**Evidence.**

- **Suite.** 113 of 113, both on macOS with bash 3.2.57 and jq 1.8.2, and on `ubuntu:24.04`
  with bash 5.2.21 and jq 1.7. On Linux the differential test found no under-match in 80,000
  checks.
- **Real broken jq.** This machine's stale x86_64 jq exits 126 with `Bad CPU type`. On `main`
  the hook printed nothing. On the branch it asks, or denies under `bypassPermissions`, and
  `ls -la` passes.
- **Mutants.** All 12 were caught by their own cases: 7 on the regex, 3 on the parse-failure
  route and 2 on the fallback. Acceptance passed 42 of 42.

**Docs.**

- **Hook.** The decision table, the parse-failure comment, the no-jq `GIT_VERB_RAW` comment and
  the `gate()` comment.
- **README.** 113 cases. The mass-failure shapes were measured again: `main`'s 33/58 and 6/85
  were reproduced first, and the new shapes are 35/78 outside a configured repo and 8/105
  inside one. A broken jq and a missing jq now give the same shape.
- **Version.** `pr` goes from 0.2.10 to 0.2.11.

### 2026-09-30 14:34:22 MDT: Pre-test, draft PR #57, review APPROVE, two escalations filed

**Review: APPROVE.** The reviewer's own differential test found no under-match in 180,000
checks. It used `grep -E` line by line with the token check, three encoders and a wider
alphabet. The same test caught 53 under-matches in `main`'s regex. Two suggestions were applied:

- **Timing.** A 1MB body of repeated `git \t-a\tb\t` took 0.42s, and 0.40s here, so the comment
  now says about 0.4s at worst and names the shape.
- **`gate()` fails closed.** The check became `JSON_SAFE`, a safe shape, so a regex that fails to
  evaluate swaps rather than skips. The reason and the deny instruction (`stop`) are swapped
  separately, so a quoted reason keeps the token instruction. Both spellings of the class
  behave identically on bash 3.2 and on bash 5.2 with glibc.

A new probe, a token name holding a quote, took the suite to 114, and the swap mutant was split
in two, making 13. The jq path's stdout is byte-identical to `main`'s. The shapes are 35/79 and
8/106.

**Escalated.** Two pre-existing under-matches, reproduced identically on `main`, were each filed
immediately under the scope contract:

- **#58.** A default-branch push followed by `)`, `>` or a backtick passes on every path.
- **#59.** Without jq, the approval token is honoured across a `\n` inside an assignment's
  value.

### 2026-09-30 14:54:00 MDT: Close gate, review APPROVE, one probe added

**Review: APPROVE, no blocking or important issues.** Two suggestions were applied:

- **The recovery the separate swaps keep was unpinned.** The pre-`58aee16` joint swap passed as
  a mutant, so a new case now checks that a quoted reason under `bypassPermissions` still names
  `PR_ALLOW_MAIN=1`. That takes the suite to 115, and the joint-swap mutant, M14, is caught
  along with the other 13.
- **The summary's line totals would go stale** once the close commits its own artifacts, so
  they were replaced with the code and doc lines only.

**Evidence.** 115 of 115 on macOS and on `ubuntu:24.04`. The shapes are 35/80 and 8/107, and
the README is updated.
