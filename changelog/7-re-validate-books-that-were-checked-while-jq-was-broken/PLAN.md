# Re-validate books that were checked while jq was broken

Start date: 2026-09-21 15:45:10 MDT

## Overview

A stale x86_64 `jq` binary shadowed a working one on the operator's machine. Every `jq` call
in `check-book.sh` is `2>/dev/null`, so each `book.json` declaration read as an empty string
and every book folder was checked in the weakest mode available while its `book.json` plainly
declared otherwise. Nothing on the summary line distinguished that from a book declaring
nothing, so the failure was silent and indistinguishable from a pass.

The objective of this branch is to establish, for every book folder in the repo, whether it
actually satisfies what its `book.json` declares now that `jq` runs — and to resolve each
disagreement by correcting either the book or the declaration.

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred`, never as new scope.

## About Ticket

Issue #7 — Re-validate books that were checked while jq was broken (priority:high)
https://github.com/cjus/cjus-skills/issues/7

The ticket was filed as blocked on a machine fix rather than on repo work. `/usr/local/bin/jq`
was an x86_64 binary from March 2022 failing with `Bad CPU type in executable` on arm64, and it
shadowed a working `jq`. The condition was confirmed pre-existing on an earlier branch by running
the checker against `fixtures/fence`, which declares `tags`, `provenance` and `suggested_reading`
all `true` and reported all three as off. That same earlier branch made `check-book.sh` exit 2
when `jq` is present but will not run, so the problem is loud from here on. This ticket covers
the books already checked under the broken binary.

> The issue body cites a ticket number from another project's numbering for that earlier branch.
> The fact is recorded generically above; the stale reference is deliberately not carried into
> this repo.

**Symptom if skipped:** a book signed off as satisfying `provenance` or `suggested_reading` may
satisfy neither, because those declarations were never enforced on this machine.

### Action items from the ticket

- [x] Remove or replace the stale binary. **Already done before this branch opened** — verified
      at start: the binary is renamed to `/usr/local/bin/jq.x86_64-stale-2022.disabled`, and
      `jq --version` now resolves `jq-1.8.2` from `/opt/homebrew/bin/jq`. This was the ticket's
      stated blocker, which is why the remaining work is now actionable.
- [x] Re-run `check-book.sh` against every existing book folder. Done 2026-09-22: all eight
      folders carrying a `book.json`, plus `fixtures/ledger`, which turns out not to be a book.
- [x] For any book that now fails, decide whether the declaration or the book is wrong. Two fail.
      Neither is a declaration error: `guide-under-narration` fails by design, and
      `fixtures/provenance` fails on the part-heading count already tracked by #18.

## Plan

- [x] Phase 1: Establish the true baseline. Run `check-book.sh` against all eight book folders
      carrying a `book.json` and record each exit code and summary line verbatim. This is the
      first run any of them has had under a working `jq`. **Six exit 0, two exit 1.** Every
      folder is now graded in the mode its `book.json` declares; under the broken binary every
      one of them was graded in the weakest mode.
- [x] Phase 2: Classify every failure. Two failures, neither new and neither a declaration
      error. `guide-under-narration` exits 1 because it is built to: it is `guide/`'s chapters
      with the profile line removed, so the narration rules reject every guide-only construct.
      `fixtures/provenance` exits 1 on the part-heading count, which is issue #18.
- [x] Phase 3: Apply the resolutions — correct the book, or correct its `book.json`. **Nothing
      to apply.** No book and no declaration disagreed once `jq` could read them. #18's fix
      stays with #18 per the note in Open Questions.
- [x] Phase 4: Record the resolved per-folder expected exit codes, so a later runner has an
      accurate table to assert against. Written into `plugins/bookcraft/README.md § Fixtures`
      as a table of folder, declaration and expected exit code.

## Book folders in scope

Eight folders carry a `book.json`:

| Folder | Declares |
|---|---|
| `check-claims/fixtures/appendix` | overview, provenance |
| `createbook/fixtures/fence` | tags, provenance, suggested_reading |
| `createbook/fixtures/guide` | tags, provenance, suggested_reading, overview, glossary |
| `createbook/fixtures/guide-under-narration` | tags, provenance, suggested_reading, overview, glossary |
| `createbook/fixtures/jq-unrunnable` | tags, provenance, suggested_reading, overview, glossary |
| `createbook/fixtures/overview` | tags, provenance, suggested_reading, overview, glossary |
| `createbook/fixtures/overview-nothing-carried` | tags, provenance, suggested_reading, overview, glossary |
| `createbook/fixtures/provenance` | provenance |

## Open Questions

- **Open, and only the operator can answer.** Does "every existing book folder" mean only the
  in-repo fixtures above, or are there books outside this repo that were also checked under the
  broken binary? Only the in-repo folders are verifiable from here; anything outside is out of
  scope for this branch unless pointed at. Everything in this repo is now re-validated, so an
  answer of "in-repo only" closes the ticket as it stands.
- ~~Two folders are expected to fail for reasons already known and separately ticketed.~~
  **Resolved 2026-09-22.** Both are pre-existing. #18 is open and its title names exactly the
  failure observed, `body has 1 part headings; a chapter's shape is two or three parts`, so its
  fix stays with #18. `guide-under-narration` fails on five lines, which is what
  `plugins/bookcraft/README.md § Fixtures` already documented. One correction to the phrasing
  here: its `book.json` declares no exit code, it declares all five features `true`. What makes
  it fail is the absent `"profile": "guide"` line, not a declaration of failure.
- ~~Confirm the working `jq` does not invalidate `fixtures/jq-unrunnable`.~~ **Resolved
  2026-09-22: it does the opposite.** `run.sh` finds a working `jq` itself rather than trusting
  `PATH`, and synthesizes the broken one for its second half. A working system `jq` is what
  makes its first half meaningful. It now passes all nine of its assertions.

## What the baseline found

`check-provenance.sh` and `check-references.sh` call `jq` nowhere, so the silent-downgrade bug
was confined to `check-book.sh` and to what a `book.json` declares. That bounds the damage: no
provenance or reference result recorded on this machine was affected.

**One correction to the ticket narrative above, left in place rather than edited.** The About
Ticket section records that `fixtures/fence` "reported all three as off" under the stale binary.
Reproducing the degraded state — `fixtures/fence` with `jq` removed from `PATH`, which is the
same `declared_*=""` the broken binary produced — gives a mode line reading, in part,
`tagged: 2/2 (inferred)`, `provenance: off`, `suggested reading: off`, `prose: 570` and
`structure: 298`.
Two of the three were off; tags fell back to inference, which still catches a book whose second
chapter dropped its tags. The structural and prose sweeps ran throughout. The ticket's conclusion
is unaffected and its sentence is left as the operator wrote it, but the sharper version is: the
declaration-gated checks lapsed, not every check.

## Deferred

Raised by the code review on 2026-09-23. Both are follow-up work, not this branch's scope.

**Triaged at close, 2026-09-23: both consolidated onto issue #6, "Fixture health for createbook's
checker", which already tracks the missing fixture runner. No new issue was filed.** The same
comment corrects #6's now-stale "Expected exit codes today" line, which named four folders against
the nine this branch re-validated.

- **Nothing executable asserts the new table** (`plugins/bookcraft/README.md § Fixtures`). The
  repo has no CI, and every other fixture carries its own `run.sh`, so this table is the one
  record with no runner behind it and will drift the next time a fixture is edited. Occasion:
  next fixture added, or next change to `check-book.sh`'s grading. Theme: fixture assertion
  harness.
- **`check-claims/fixtures/appendix/book.json` now under-counts its own assertion sites.** It
  says "This is the fixture's only assertion beyond `run.sh`; update both in the same edit",
  and the README table is now a third site. An editor following that instruction updates two of
  three. Occasion: same edit as the item above. Theme: fixture assertion harness.
