# Re-validate books that were checked while jq was broken

Closes #7.

## Overview

A stale x86_64 `jq` binary shadowed a working one on the operator's machine. Every `jq` call in
`check-book.sh` is `2>/dev/null`, so each `book.json` declaration read as an empty string and every
book folder was graded in a weaker mode than it declared — silently, because nothing on the summary
line distinguished that from a book declaring nothing. The machine fix landed before this branch
opened. This branch answers the question the ticket actually asked: now that `jq` runs, does every
book in the repo satisfy what its `book.json` declares?

**It does. Six of eight folders exit 0, two exit 1, and no book disagrees with its own
declaration**, so there was nothing to correct. That is a result rather than an absence of one: the
bug degraded the *grading mode*, not the verdict, so the books were always sound while the
declaration-gated checks were not being enforced. The branch's deliverable is therefore the record —
a per-folder table of declaration and expected exit code, in the place a later runner will look —
plus two findings that bound the damage more tightly than the ticket assumed.

## Key changes

| File | Change |
|---|---|
| `plugins/bookcraft/README.md` | `§ Fixtures` gains a table of all eight book folders, what each declares, and what `check-book.sh` should exit; a paragraph naming exactly what a downgraded mode stops checking; `createbook/fixtures/ledger` named as deliberately not a book; `check-claims/fixtures/` added to the shipped-files tree |
| `changelog/7-.../PLAN.md` | Status refreshed through all four phases, three open questions resolved, two review findings recorded under `## Deferred` |
| `changelog/7-.../CHANGELOG.md` | The baseline result, the measured evidence behind it, and the two bounding findings |

No executable code changed. The diff is documentation.

## Code examples

The table, which is the branch's deliverable — `plugins/bookcraft/README.md § Fixtures`:

```markdown
| Folder | Declares | Exits | Why |
|---|---|---|---|
| `check-claims/fixtures/appendix` | guide profile, overview, provenance; tags and suggested reading off | 0 | |
| `createbook/fixtures/fence` | tags, provenance, suggested reading | 0 | |
| `createbook/fixtures/guide-under-narration` | all five, no profile | **1** | Five failures by design ... |
| `createbook/fixtures/provenance` | provenance only | **1** | Both chapters carry one part heading ... |
```

The warning that carries it, rewritten during review from "checking almost nothing" to something a
reader can test:

```markdown
A narration book graded in a weaker mode than it declares still exits 0, with the provenance
sweep, the suggested-reading requirement and the overview and glossary cross-checks all off, and
tags inferred rather than required. The filename, ordering, heading and prose sweeps run either
way, which is what makes that downgrade easy to miss. A guide book fails the opposite way,
loudly: the narration rules apply in place of its declared profile and reject every construct
the profile exists to allow.
```

The split between the silent case and the loud one came from the second review pass. The first
rewrite listed the profile substitution alongside the four silent degradations, which reads as a
claim that a downgraded guide book also slips through quietly. It does not —
`guide-under-narration` is exactly that case and exits 1 on five lines.

The evidence behind the sentence, reproduced by running `fixtures/fence` with `jq` removed from
`PATH` — the same `declared_*=""` state the broken binary produced. Five fields of the eleven the
mode line prints, quoted out of their printed order:

```
tagged: 2/2 (inferred)   provenance: off   suggested reading: off   prose: 570   structure: 298
```

## Plan alignment

All four phases completed as planned, and both remaining ticket action items are checked.

- **Phase 1, baseline** — `check-book.sh` run against all eight folders carrying a `book.json`.
  Six exit 0, two exit 1. Every folder is now graded in the mode it declares.
- **Phase 2, classify** — two failures, neither new and neither a declaration error.
  `guide-under-narration` fails on five lines by construction; `fixtures/provenance` fails on the
  part-heading count that is issue #18.
- **Phase 3, apply resolutions** — **nothing to apply.** No book and no declaration disagreed once
  `jq` could read them. #18's fix stays with #18, per the plan's own instruction.
- **Phase 4, record** — the table, in `plugins/bookcraft/README.md § Fixtures`.

**Deviations.** Two, both additive and neither touching the objective:

1. The plan scoped Phase 1 to "all eight book folders carrying a `book.json`". A ninth folder,
   `createbook/fixtures/ledger`, was checked as well to establish that it is deliberately not a book
   — no chapter files, so the checker exits 2. It is named in the README so the next reader does not
   repeat the question.
2. The plan's `## About Ticket` records that `fixtures/fence` "reported all three as off" under the
   stale binary. Reproducing the degraded state shows two of three off and the third fallen back to
   inference. The operator's sentence is **left as written**, with the correction recorded beside it
   rather than edited into their record of an earlier branch.

**The one open question is resolved.** Whether "every existing book folder" extended beyond this
repo was the single thing only the operator could answer, since books written outside it are not
verifiable from here. Answered 2026-09-23: no outside books need checking. Scope is the in-repo
folders, every one of which is re-validated, so nothing is left outstanding on #7.

## Testing

No automated tests were added — see the first deferred item, which is precisely that gap.

Verify by hand from the repo root:

```bash
# The table, row by row. Every one of these should match the README.
CHK=plugins/bookcraft/skills/createbook/scripts/check-book.sh
for f in check-claims/fixtures/appendix createbook/fixtures/fence createbook/fixtures/guide \
         createbook/fixtures/guide-under-narration createbook/fixtures/jq-unrunnable \
         createbook/fixtures/overview createbook/fixtures/overview-nothing-carried \
         createbook/fixtures/provenance createbook/fixtures/ledger; do
  bash "$CHK" "plugins/bookcraft/skills/$f" >/dev/null 2>&1
  echo "$f = $?"
done
# expect: 0 0 0 1 0 0 0 1 2

# The regression runners, all three green
bash plugins/bookcraft/skills/check-claims/fixtures/appendix/run.sh
bash plugins/bookcraft/skills/createbook/fixtures/jq-unrunnable/run.sh
bash plugins/bookcraft/skills/createbook/fixtures/ledger/run.sh

# The pre-commit hook's checker
python3 scripts/check-citations.py
```

**Edge cases considered.** The degraded path was reproduced directly rather than inferred, by
building a `PATH` that shadows every system directory except `jq` and re-running `fixtures/fence`.
That is what established that tags fall back to *inferred* rather than off, and that the structural
and prose sweeps keep running — the distinction between absent-`jq` (which prints a note) and
broken-`jq` (which printed nothing, and is the actual bug).

**Verification results at close:** all nine exit codes match, all three runners exit 0, and
`check-citations.py` reports 125 citations resolving.

## Impact assessment

- **Files changed:** 3 — one shipped document, two branch artifacts.
- **Lines:** +224 / −1 across those three files at the time of writing, plus the branch artifacts
  this close adds: this summary, `pr-review-2026-09-23.md` and `COMMITMSG.md`.
- **Dependencies:** none added or changed.
- **Breaking changes:** none. No executable code was modified, so no skill, script or fixture
  behaves differently than it did before this branch.
- **CI:** this repo has **no CI** — there is no `.github/workflows/` on this branch or on `main`.
  Verification is the pre-commit citation hook and the per-fixture `run.sh` scripts, run by hand.

## Two findings beyond the objective

**The blast radius is narrower than the ticket assumed.** `check-provenance.sh` and
`check-references.sh` call `jq` nowhere — they read `book.json` through Python's `json`. The silent
downgrade could only ever reach `check-book.sh` and the declarations in a `book.json`, so no
provenance or reference result recorded on this machine was affected. The ticket was written as
though every checker were suspect.

**The jq guard is fully exercisable for the first time.** `fixtures/jq-unrunnable/run.sh` passes all
nine assertions. Its first half needs a working `jq` to mean anything, and on this machine it had
never had one. It does not trust `PATH` — it hunts for a working `jq` itself and synthesizes the
broken one for its second half — so the machine fix neither invalidates it nor is required by it.

## Deferred work

Both raised by the close-time code review, both follow-up rather than this branch's scope, and both
on the same theme of a fixture assertion harness.

- **Nothing executable asserts the new table.** The repo has no CI, and every other fixture carries
  its own `run.sh`, so this table is the one record in the repo with no runner behind it. It will
  drift the next time a fixture is edited. The occasion that would pick it up: the next fixture
  added, or the next change to `check-book.sh`'s grading.
- **`check-claims/fixtures/appendix/book.json` now under-counts its own assertion sites.** It
  instructs an editor that "this is the fixture's only assertion beyond `run.sh`; update both in the
  same edit", and the README table is now a third site. An editor following that instruction updates
  two of three. Same occasion as above.

## Assertion audit

**Disabled for this repo.** `docs.assertionsFile` is `null` in `.claude/pr-config.json`, so there is
no assertions file to audit against and none was created. Likewise `docs.continuityRoot` is `null`,
so no continuity entry was written.
