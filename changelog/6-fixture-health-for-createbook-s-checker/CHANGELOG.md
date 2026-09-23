# Fixture health for createbook's checker

Start date: 2026-09-21 15:45:57 MDT

Make the createbook fixture folders carry real signal: resolve the provenance folder's
unexplained exit 1, and give all four folders a runner plus CI so nothing depends on a
person remembering to run them.

## Changes

### 2026-09-22 — Phase 1, the baseline

Ran every fixture folder through both checkers and recorded the result. Under `check-book.sh`:
`fence` 0, `guide` 0, `guide-under-narration` **1**, `jq-unrunnable` 0, `ledger` **2**,
`overview` 0, `overview-nothing-carried` 0, `provenance` **1**. The three existing `run.sh`
fixtures all exit 0. `check-provenance.sh fixtures/provenance/` exits 1 with 6 failures and 1
REVIEW.

**The ticket conflated two scripts.** `fixtures/provenance/` is a deliberate negative fixture
for `check-provenance.sh` and already documented itself in `book.json`: *"Expected: 6 failures
and 1 review, exit 1. This sentence is the fixture's only assertion, since the repo has no CI
to hold it."* That measured exactly, all seven against chapter 2, none against chapter 1. The
exit 1 the ticket saw was `check-book.sh`'s, and it was collateral — both chapters carried one
part heading where a chapter's shape is two or three, so the folder failed a structural rule
neither chapter was written to exercise.

**Three findings the ticket did not have.** `guide-under-narration` is a second intentional
exit 1, documented in its `book.json` and absent from the ticket. `book.json`'s `description`
is already the convention for recording an expectation, used by five of seven folders. And
`check-provenance.sh` and `check-references.sh` are Python despite the `.sh` extension — running
one with `bash` gives pages of parse garbage and exit 2 rather than a clean error, so the runner
must dispatch through the shebang and the executable bit is load-bearing.

### 2026-09-23 — Phases 2 to 5

**Phase 2.** Both provenance chapters split into two parts. `check-book.sh` now exits 0 on the
folder; `check-provenance.sh` still exits 1 with the same 6 failures and 1 REVIEW. The folder's
`book.json` assertion extended to name both codes.

**Phase 3.** `plugins/bookcraft/scripts/test-fixtures.sh`, inside the plugin, per the convention
every other test script follows. Manifest-driven, and every expectation names a string the
output must carry rather than an exit code alone — the direct lesson of the folder it was
written for. A folder asserted by neither a manifest row nor a `run.sh` fails the run. 11
checks, under six seconds.

The no-jq configuration became a third half of `jq-unrunnable/run.sh` rather than the separate
CI job proposed at Phase 1. The manifest's codes are only valid with a working `jq` —
`fixtures/guide/` passes only because its profile declaration is read — so the runner refuses to
grade the manifest without one instead of reporting failures that are not defects.

**Phase 4.** `.github/workflows/fixtures.yml`, the repo's first. macOS blocking, Linux
alongside. Asserts `jq` *runs* rather than that it exists.

**Phase 5.** Four deliberate regressions, each caught and reverted: a silenced H3 rule in
`check-book.sh` (**the folder still exited 1, so only the required-substring assertion caught
it** — the whole argument for the design), a dropped case in the provenance fixture, a fixture
folder asserted by nothing, and a cleared executable bit. CI then reported the first on both
platforms, naming the missing message. The two commits carrying those probes were labelled
TEMPORARY and removed afterwards.

**Measured.** The first absent-jq implementation forked a `$(basename)` subshell per `PATH`
entry and took 32 seconds; one `ln -s` per directory, letting `ln` refuse to clobber so `PATH`
precedence survives, takes 1.5. This is also the repo's first recorded Linux run.

### 2026-09-23 — close review fixes

The review returned APPROVE with five important findings. Four were acted on: a manifest row
with an empty required-output field now fails instead of degrading to exit-code-only; the
manifest gained a `!` prefix for must-NOT-contain, used to assert that nothing is reported
against the provenance fixture's chapter 1; the provenance row now asserts the REVIEW line too;
and the workflow gained `permissions: contents: read`.

The fifth was a correction to this branch's own documentation. **"Linux cannot fail the branch"
was asserted in three documents and is too strong.** `continue-on-error` keeps the *workflow
run's* conclusion `success`, but the ubuntu job and its **check run** both report `failure`.
`gh pr checks` reads check runs, so a Linux-only failure surfaces as a red check and will halt
the pr plugin's own CI gate. Verified directly against the probe commit: check run
`fixtures (ubuntu-latest)` = `failure`, run conclusion = `success`. The workflow header and the
root README now say that rather than "cannot fail the branch".

One finding was not acted on: two citations flagged as cross-repo are `#26`, which `origin/main`
cites a dozen times as this repo's own pre-rebuild issue number. Left as found.
