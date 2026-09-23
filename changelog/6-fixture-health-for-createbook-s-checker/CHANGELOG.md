# Fixture health for createbook's checker

Start date: 2026-09-21 15:45:57 MDT

Make the createbook fixture folders carry real signal: resolve the provenance folder's
unexplained exit 1, and give all four folders a runner plus CI so nothing depends on a
person remembering to run them.

## Changes

### Phase 1: the baseline, 2026-09-22

Run on macOS, bash 3.2.57, jq 1.8.2 working. Every fixture folder, both checkers.

`check-book.sh <folder>`:

| folder | exit | what the code means |
|---|---|---|
| `fence` | 0 | sound |
| `guide` | 0 | sound under the guide profile |
| `guide-under-narration` | 1 | **intentional negative**, documented in its `book.json` |
| `jq-unrunnable` | 0 | sound, graded in the strongest mode |
| `ledger` | 2 | **not a book folder** — `error: no chapter markdown files` |
| `overview` | 0 | sound |
| `overview-nothing-carried` | 0 | sound |
| `provenance` | 1 | **undocumented**, and unrelated to provenance |

The three existing `run.sh` fixtures (`jq-unrunnable`, `ledger`, check-claims' `appendix`)
all exit 0.

`check-provenance.sh fixtures/provenance/` exits 1 with 6 failures and 1 REVIEW.

### The provenance folder: the ticket conflated two scripts

The ticket asks whether `provenance-fixture-01-everything-resolves.md` fails because of a
checker defect or because the fixture is a deliberate negative case. It is neither, because
two different scripts are involved and only one of them is the fixture's subject.

`fixtures/provenance/` is a deliberate negative fixture **for `check-provenance.sh`**, and it
already says so. Its `book.json` description reads: "Chapter 1 holds only passing marks, so a
run that reports anything against it is a regression. Chapter 2 holds one of each failing
shape... Expected: 6 failures and 1 review, exit 1. This sentence is the fixture's only
assertion, since the repo has no CI to hold it." Measured: exactly 6 failures and 1 REVIEW,
all seven against chapter 2, nothing against chapter 1, exit 1. The fixture holds, its name
is accurate, and the file that promises everything resolves does resolve everything.

The exit 1 the ticket observed is `check-book.sh`'s, and it is collateral. Both chapters fail
one shape rule — `body has 1 part headings; a chapter's shape is two or three parts` — which
neither chapter was written to exercise. Nothing about provenance is being reported. So the
folder's `check-book.sh` exit code carries no signal, exactly as the ticket suspected, but the
cause is a structural rule the fixture was never built to satisfy rather than a provenance
defect or an undocumented intent.

Phase 2 therefore resolves as: give the two chapters a valid part structure so `check-book.sh`
exits 0, while `check-provenance.sh` keeps exiting 1. No rename, and no checker fix. That
makes a `check-book.sh` regression inside the folder visible, which is what the ticket wants
from it.

### Three findings the ticket did not have

**`guide-under-narration` is a second intentional non-zero.** Its `book.json`: "The same
three files as `guide/`, with the `profile` line removed so the narration rules apply. Every
guide-only construct in them is expected to fail here. This is the half that proves the
profile is doing the work." Expected exit 1, and the ticket lists neither the folder nor the
code.

**`book.json`'s `description` is already the convention for recording an expectation**, used
by five of the seven folders that have one, and `provenance/` states outright that prose is
the only thing holding its assertion "since the repo has no CI to hold it". The runner's job
is to make those prose assertions executable rather than to invent a new place for them.

**Two of the three scripts in `createbook/scripts/` are Python named `.sh`.**
`check-provenance.sh` and `check-references.sh` both open `#!/usr/bin/env python3`; only
`check-book.sh` is bash. Invoking one with `bash` produces pages of parse garbage and exit 2
rather than a clean error. The runner must dispatch through the shebang, which also means the
executable bit is load-bearing — the same packaging defect class `pr`'s acceptance suite
already caught once.

### Phases 2 to 5, 2026-09-23

**Phase 2 — `fixtures/provenance/`.** Both chapters split into two parts
(`provenance-fixture-01` into quotations and locators, `-02` into sources/headings and
locators/quotations). `check-book.sh` now exits 0 on the folder; `check-provenance.sh` still
exits 1 with the same 6 failures and 1 REVIEW, all seven against chapter 2 and none against
chapter 1. The folder's `book.json` assertion was extended to name both codes and to point at
the runner that now holds them.

**Phase 3 — the runner.** `plugins/bookcraft/scripts/test-fixtures.sh`, inside the plugin,
following the convention every other test script in the repo already follows. It takes an
optional plugin path so it can grade an installed copy, and invokes both checkers through
their shebangs so a lost executable bit fails loudly.

It is manifest-driven, and **every expectation names a string the output must carry** rather
than an exit code alone. That is the direct lesson of the folder it was written for: an
exit-code-only suite would have passed `provenance/` indefinitely. A fixture folder covered by
neither a manifest row nor a `run.sh` fails the run, which is what stops the drift that let
the ticket undercount the folders by half. 11 checks, under six seconds.

**The no-jq configuration became a third half of `jq-unrunnable/run.sh`** rather than the
separate CI job proposed at Phase 1. Same coverage, no extra job, and it runs on developer
machines too. The manifest's expected codes are only valid with a working `jq` —
`fixtures/guide/` passes only because its profile declaration is read — so the runner refuses
to grade the manifest without one instead of reporting failures that are not defects.

**Phase 4 — CI.** `.github/workflows/fixtures.yml`, the repo's first. Push, pull request and
manual dispatch; macOS blocking, Linux alongside and non-blocking, since the repo records
macOS as its only tested platform. It asserts `jq` *runs* rather than that it exists, for the
reason the jq-unrunnable fixture exists.

**Phase 5 — verification.** Four deliberately introduced regressions, each caught, each
reverted:

| regression | caught by |
|---|---|
| H3 rule silenced in `check-book.sh` | the required substring — the folder still exited 1 |
| one failing case dropped from the provenance fixture | `6 failure(s)` missing; exit 1 still right |
| a new fixture folder asserted by nothing | the completeness check |
| executable bit cleared on `check-provenance.sh` | the shebang-dispatch precondition |

The first is the one that matters: exit code unchanged, defect still caught.

**The CI half, measured on PR #23.** Three runs, on two platforms:

| pushed state | macOS job | Linux job | run conclusion |
|---|---|---|---|
| the branch as it stands | success | success | success |
| H3 rule silenced in `check-book.sh` | failure | failure | failure |
| a Linux-only failing step | success | failure | **success** |

The second run is the one that closes Phase 5. Both platforms printed the exact diagnosis —
`exit 1 is right and the output is not` / `missing from the output: body carries an H3 or
deeper` — so CI names the silenced rule rather than reporting a bare non-zero exit.

The third settles the claim that Linux does not gate the branch, which was asserted in three
places before it was checked. `continue-on-error` behaves as intended: the ubuntu job's own
conclusion is `failure` and the workflow run's is `success`, so a Linux-only failure shows as
a red job without blocking the merge.

All eleven checks ran on both platforms with nothing skipped, under `jq` 1.8.2 on macOS and
1.7 on Linux. The absent-`jq` symlink farm works on Linux too, which was the specific risk
the one-`ln`-per-directory rewrite had to clear: `jq` sits in `/usr/bin` there beside `awk`
and `sed`, so pruning directories would have removed the tools the checker needs.

**This is the repository's first recorded Linux run.** The README had said Linux should work
with two edits and that no run had been recorded; there is one now, and it passed.

The two commits that carried those probes were labelled TEMPORARY, existed only to measure
CI, and were dropped from the branch afterwards.

**Measured.** The first absent-jq implementation forked a `$(basename)` subshell per entry on
`PATH` and took 32 seconds. One `ln -s` per directory, letting `ln` refuse to clobber so
`PATH` precedence survives, takes 1.5.

### Files

| file | change |
|---|---|
| `plugins/bookcraft/scripts/test-fixtures.sh` | new, executable |
| `.github/workflows/fixtures.yml` | new, the repo's first workflow |
| `.../fixtures/provenance/provenance-fixture-0{1,2}-*.md` | split into two parts each |
| `.../fixtures/provenance/book.json` | assertion extended to both checkers |
| `.../fixtures/jq-unrunnable/run.sh` | third half: absent jq |
| `plugins/bookcraft/skills/createbook/NOTES.md` | what was measured and what is asserted |
| `plugins/bookcraft/README.md` | § Fixtures rewritten; ships tree |
| `README.md` | § The fixture suite, and CI |

Neither checker was modified. `scripts/check-citations.py` passes: 125 resolve.
