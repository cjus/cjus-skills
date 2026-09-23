# Fixture health for createbook's checker

Start date: 2026-09-21 15:45:57 MDT

## Overview

The createbook fixture folders are the only verification `check-book.sh` has, and two gaps
make them weaker than they look. `fixtures/provenance/` exits 1 on a clean `main` without
that being documented as intentional, so its exit code carries no signal and a real
regression inside it would be invisible. And nothing runs the four folders but a person
remembering to — the repo has no `.github/workflows` at all.

This branch closes both: the provenance folder's exit code becomes explained and asserted,
and a runner plus CI executes all four folders against their expected exit codes.

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred`, never as new scope.

## About Ticket

**Issue:** [#6 — Fixture health for createbook's checker](https://github.com/cjus/cjus-skills/issues/6)
**Labels:** priority:high, status:in-progress

The createbook fixtures are the only verification `check-book.sh` has, and two gaps make
them weaker than they look. Surfaced during #26, where both were deferred.

- **`fixtures/provenance/` exits 1 on a clean `main`.** Its chapter named
  `provenance-fixture-01-everything-resolves.md` is among what fails, which is the one name
  in the folder that promises it should not. Until that is either fixed or documented as an
  intentional negative fixture, the folder's exit code carries no signal and a real
  regression inside it is invisible.

  *Occasion:* next change to `check-provenance.sh` or the provenance rules.

- **No runner and no CI for the fixture folders.** There are four now (`fence`, `overview`,
  `overview-nothing-carried`, `provenance`) and nothing runs them but a person remembering
  to. The repo has no `.github/workflows` at all.

  *Occasion:* next change to `check-book.sh`.

  *Why it earns a ticket:* #26 alone produced three defects that only hand-running caught —
  a crash on any book where no chapter carries a term in (`carried_records[@]: unbound
  variable`, no summary line at all), a silently undercounted carried-in line that passed a
  four-term line whose first two wrapped, and a section-recognition rule that failed a
  declared book on any machine without `jq`. A runner that executes the four folders and
  asserts their expected exit codes would have caught the first and third immediately.

Expected exit codes today: `fence`=0, `overview`=0, `overview-nothing-carried`=0,
`provenance`=1.

> **Corrected by Phase 1, 2026-09-22.** That list is the ticket's and it is incomplete.
> `createbook/fixtures/` holds eight folders, not four: the four above plus `guide`,
> `guide-under-narration`, `jq-unrunnable` and `ledger`. Seven of them predate the ticket;
> `ledger` arrived in #17. Measured codes under `check-book.sh`: `fence`=0, `guide`=0,
> `guide-under-narration`=1 (intentional), `jq-unrunnable`=0, `ledger`=2 (not a book folder),
> `overview`=0, `overview-nothing-carried`=0, `provenance`=1 (collateral, to become 0).
> `check-claims/fixtures/appendix/` is a ninth folder with its own `run.sh`.

Related theme, not a duplicate: #5 covers `guard-default-branch.sh` under-matching when
`jq` is absent — same class of jq-robustness problem, different script.

## Plan

- [x] Phase 1: Establish the baseline. **Done 2026-09-22.** Recorded in CHANGELOG.md
      § Phase 1: the baseline. The ticket's expected codes were wrong in three ways: there
      are eight fixture folders under createbook rather than four, `guide-under-narration`
      is a second intentional exit 1, and `ledger` exits 2 because it is not a book folder
      at all.
- [x] Phase 2: Resolve `fixtures/provenance/`. **Done 2026-09-23.** As settled by Phase 1: the
      folder is a deliberate negative fixture for `check-provenance.sh` and already
      documents its own expected result (6 failures, 1 review, exit 1), which measured
      exactly. Its `check-book.sh` exit 1 is separate and collateral — both chapters fail
      the part-headings shape rule, which neither was written to exercise. Give the two
      chapters a valid part structure so `check-book.sh` exits 0 while `check-provenance.sh`
      keeps exiting 1. No rename, no checker fix.
- [x] Phase 3: Write the runner. **Done 2026-09-23.** `plugins/bookcraft/scripts/test-fixtures.sh`.
      It asserts more than the exit code: every expectation also names a string the output must
      carry, because Phase 1 showed an exit code alone passes for the wrong reason. A folder
      covered by neither a manifest row nor a `run.sh` fails the run. 11 checks, under six
      seconds. An absent-jq third half was added to `jq-unrunnable/run.sh`, which is where that
      configuration belongs and which replaced the separate no-jq CI job proposed earlier.
- [x] Phase 4: Wire up CI. **Done 2026-09-23.** `.github/workflows/fixtures.yml`, on push,
      pull request and manual dispatch. macOS blocking, Linux alongside and non-blocking. It
      asserts `jq` runs rather than that it exists, and checks the executable bits the shebang
      dispatch depends on.
- [x] Phase 5: Verify. **Done 2026-09-23, both halves measured on PR #23.** Four
      deliberately introduced regressions, each caught and each reverted: a silenced H3 rule in
      `check-book.sh` (the folder still exited 1, so only the required-substring assertion
      caught it), a dropped case in the provenance fixture (6 failures became 5), a new fixture
      folder asserted by nothing, and a cleared executable bit. CI then reported the first of
      those on both platforms, naming the missing message rather than a bare non-zero exit. A
      third run confirmed a Linux-only failure leaves the run conclusion `success`, so the
      non-blocking claim holds.

## Action Items

- [x] `fixtures/provenance/` exits 1 on a clean `main` — resolved 2026-09-23. It is an
      intentional negative fixture for `check-provenance.sh` and now says so in its `book.json`;
      its unrelated `check-book.sh` failure was a part-heading shape defect and is fixed.
- [x] Add a runner and CI for the fixture folders — done 2026-09-23, covering all nine rather
      than the four the ticket named.

## Open Questions

- ~~Is `provenance-fixture-01-everything-resolves.md`'s failure a checker defect or an
  intentional negative case?~~ **Answered by Phase 1, 2026-09-22.** Neither, because two
  scripts are involved. Under `check-provenance.sh` — the script the fixture was built for —
  chapter 1 reports nothing and the folder exits 1 with exactly the 6 failures and 1 review
  its `book.json` asserts. The exit 1 the ticket saw is `check-book.sh`'s, from a
  part-headings shape rule unrelated to provenance. The folder's expected code is 1 for
  `check-provenance.sh` and should become 0 for `check-book.sh`.

- ~~**Where does the runner live?**~~ **Settled 2026-09-23:** `plugins/bookcraft/scripts/test-fixtures.sh`,
  inside the plugin, not repo-root `scripts/`. Every test script in the repo already lives
  beside its subject inside a plugin; repo-root `scripts/` holds only `check-citations.py`,
  which is repo-wide by nature and wired into `.githooks/pre-commit`. Installation copies only
  `plugins/<name>`, so a root-level runner could never grade an installed copy — which is what
  `plugins/pr/scripts/test-acceptance.sh` exists to do.

- ~~**Does CI need `jq`?**~~ **Settled 2026-09-23:** yes, asserted rather than assumed. The
  proposed second no-jq job became a third half inside `jq-unrunnable/run.sh` instead, which
  covers the same configuration, runs on developer machines too, and needs no CI job.
  Originally: Withholding it buys nothing: `jq-unrunnable/run.sh` synthesizes its own
  broken jq, so that half runs regardless, while its working-jq half prints `skip` and still
  exits 0. Seven of eight folders carry a `book.json`, and without jq every declaration in them
  reads as absent and the folder is graded in the weakest mode while still exiting 0 — a green
  run proving nothing the declared mode covers. The no-jq fallback is separately a documented
  supported configuration that nothing currently tests.

- **Which runner OS?** Not in the ticket, raised by Phase 4. The README records macOS as the
  only tested platform and Linux as unverified. Recommendation: `macos-latest` blocking, plus a
  non-blocking `ubuntu-latest` job, so the first recorded Linux run does not gate this branch.
  **Settled 2026-09-23, as recommended.**

## Deferred

Found during the close review, 2026-09-23. Triaged at `/pr:close`: the first two were
ticketed as **#24**, the last two dropped.

- **`command -v -a jq` is not valid bash**, so the working-jq probe in
  `fixtures/jq-unrunnable/run.sh` never actually consults `PATH` and falls through to its three
  hardcoded candidates. Pre-existing, in half one, not in the half this branch added. It still
  finds a working jq on both CI platforms and on this machine, so nothing is failing because of
  it. *Theme: jq probe robustness.*
- **`check-references.sh` has no fixture coverage at all.** It is the third checker in
  `createbook/scripts/`, and no fixture folder and no manifest row exercises it. The runner
  cannot report a gap it was never pointed at. *Theme: checker coverage.*
- **A pre-existing bare cross-repo ticket citation on `main`.** Out of scope here and untouched
  by this branch. *Theme: cross-repo citation scrub.*
- **`#26` and its neighbours dangle.** The repo was rebuilt from a scrubbed tree and GitHub's
  numbering restarted, so the ticket numbers quoted throughout `changelog/**` — including this
  plan's own About Ticket section — no longer resolve. Consistent with every other folder under
  `changelog/`, so it is left as found. *Theme: cross-repo citation scrub.*
