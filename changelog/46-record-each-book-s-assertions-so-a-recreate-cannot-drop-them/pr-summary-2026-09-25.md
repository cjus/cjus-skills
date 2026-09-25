# Record each book's assertions so a recreate cannot drop them

Ticket 46 · branch `feature/46-record-each-book-s-assertions-so-a-recreate-cannot-drop-them` · 2026-09-25

## Overview

A book written by `/createbook` rests on its sources and on everything it was told or settled
along the way. The sources are in `book.json`, and any later run can open them again. The rest
used to have no home. It lived in chapter prose, in outline revision notes keyed by paragraph
tag, and in commit history. A recreate from the outline and the sources therefore dropped it: a
premise that changed, a ruling with no source, an answer key that was derived and then
corrected.

This branch gives every book an `assertions.json` beside its `book.json`:

- **One writer.** A new helper, `createbook/scripts/assertions.sh`, is the file's only writer,
  and its `check` is the only definition of the format.
- **Marks cite entries.** Provenance marks cite entries as `assertion <id>`.
  `check-provenance.sh` fails a mark citing an entry that no longer holds. It also sweeps the
  book for prose still built on a superseded premise, and reports every `expected` entry that no
  mark cites.
- **The skills write and carry the file.** `/createbook` writes it from step 1 onward.
  `/updatebook` writes to it and carries it through every edit. `/check-claims` gives each claim
  agent the entries it needs. All three stop and backfill a book that has none.
- **A recreate carries every entry.** It is `/createbook --recreate <old> <new>`, into a new
  folder, and it carries every entry that holds, so nothing the old book stood behind is lost.

The branch was validated on the reference guide in its own repository. That backfill produced
40 entries and carried three of the ticket's four cases. The fourth, an unadopted
recommendation, was left out by the operator's ruling, as the procedure intends. It also
measured the premise sweep's precision and recall, and it prompted four procedure fixes.

## Key changes

**New**
- `plugins/bookcraft/skills/createbook/scripts/assertions.sh`: Python 3, standard library
  only, runs on 3.9 and later. It has nine commands, `init`, `brief`, `add`, `supersede`,
  `retire`, `correct`, `expect`, `list` and `check`. Every write validates the whole file before
  and after, so the helper cannot leave behind a file `check` rejects. `load` and `problems_in`
  are importable by path.
- `plugins/bookcraft/skills/createbook/fixtures/assertions/`: a one-chapter book with a figure
  and a backfilled `assertions.json`, ten malformed files, and a `run.sh` that makes 32
  assertions.

**Changed**
- `createbook/scripts/check-provenance.sh`:
  - Handles the reserved `assertion <id>` component, and fails a citation that is missing,
    superseded or retired.
  - Reads the file in three states: ok, invalid (a failure), and missing (a note).
  - Builds the cited set from every chapter, even under `--chapters`.
  - Sweeps superseded premises as REVIEW, including in books whose marks are not read.
  - Reports uncited `expected` entries, and follows supersession chains to their end.
  - Its worklist carries each unit's `entries` and the book's `settled` entries.
- `createbook/SKILL.md`:
  - `§ The assertions file` is the format for a reader.
  - Steps 1 to 7 write and carry the file.
  - `§ Recreating a book` and `§ Backfilling the assertions file` are new, the backfill being
    an eight-step triage.
  - `unsourced` is now "for a method, never for a fact".
- `createbook/reference/chapter-prose.md`: adds the `assertion <id>` mark grammar.
- `createbook/NOTES.md`: separates what is measured from what is asserted, including the
  reference guide's backfill.
- `updatebook/SKILL.md`:
  - Step 0 stops on a missing file.
  - A classification row writes entries before the prose changes.
  - A `legacy` entry turns `expected` once every paragraph resting on it cites it.
  - The file is carried and checked.
  - The rewrite and recreate sections read the file instead of `git log -p`.
  - The recreate names `/createbook --recreate` and stops.
- `check-claims/SKILL.md` and `reference/judgement.md`: stop on a missing file. A sentence
  resting on a cited entry is not a finding against the source, and `settled` entries are read
  before any finding is raised.
- `makebook/SKILL.md`: states that it neither reads nor requires the file.
- `scripts/test-fixtures.sh`, `.github/workflows/fixtures.yml` and the README: checks that the
  helper is executable, asserts the missing-file note on the provenance fixture, describes the
  new fixture and the book-folder layout, and gains a `--recreate` argument row.
- bookcraft moves from 1.7.1 to 1.8.0.

**Outside the ticket, by operator direction**
- The pr plugin's `reference/lifecycle.md` and the `ticket`, `resume` and `pre-test` skills
  now let a standing grant from the operator cover `/pr:close`. Under a grant it runs as its own
  step, never from inside another skill, and never extends to a merge. pr moves to 0.2.7.

## Code examples

The helper refuses to write a file its own `check` would reject, so a missing flag is reported
as the key it would have written. From
`plugins/bookcraft/skills/createbook/scripts/assertions.sh`:

```python
def _commit(path, doc, said):
    probs = problems_in(doc)
    if probs:
        raise Refused("refused, because the file would then fail check. Each "
                      "key is set by the flag of the same name, with a hyphen "
                      "for the underscore:", probs)
    _write(path, doc)
    print(said)
```

`next_id` and the no-gap rule stop an ID from ever coming to mean a different claim. From the
same file:

```python
gone = [i for i in range(1, nid) if i not in by_id]
if gone:
    bad(f"no entry carries ID {', '.join(map(str, gone))}. An entry is "
        f"retired, never deleted, so a mark citing its ID keeps "
        f"resolving to the claim it meant")
```

A report names the end of a supersession chain, never the next link. From
`plugins/bookcraft/skills/createbook/scripts/check-provenance.sh`:

```python
def current(reg, e):
    while e["status"] == "superseded":
        e = reg[e["superseded_by"]]
    return e
```

## Plan alignment

All seven phases are complete, and every ticket checkbox is ticked.

- **As planned:**
  - Phase 1: the format and the helper.
  - Phase 2: marks cite entries.
  - Phase 3: `/createbook`, including the recreate.
  - Phase 4: `/updatebook` and `/check-claims`.
  - Phase 5: the backfill procedure.
  - Phase 6: fixtures and release.
  - Phase 7: validation on the reference guide.
- **Where the implementation went past the ticket's text**, each tightening the design and each
  recorded with its reason in `CHANGELOG.md`:
  - `next_id` and the no-gap rule
  - `expect` and `brief`, commands the ticket's own rules needed
  - `was` beside a corrected answer
  - a backfill's `null` argument and `unrecorded` origins
  - the sweep covering every markdown file in the book folder
  - the sweep and the uncited report running over the whole book under `--chapters`
  - chapter agents never writing the file
- **Decisions the operator settled:**
  - A recreate is a `/createbook` flag, into a new folder.
  - A backfill confirms by triage: solid candidates grouped by kind for striking, doubtful ones
    asked one by one.
- **The pre-test review** approved the branch with four Important findings, all fixed:
  - a backfill's `supersede` now passes `--citation legacy`
  - books whose marks are not read are still swept
  - chains are followed to their end
  - the worklist keys are tested
- **Phase 7 changed the procedure in four places:**
  - propose `search` phrases from a sweep of the bare value word
  - look for a saved `/createbook` argument before writing `null`
  - check an exclusion by searching for what it keeps out
  - leave out a live-system read that a later re-openable export now carries
- **Outside the objective:** the pr plugin change, recorded as such in `PLAN.md`.

## Testing

**Automated**
- `plugins/bookcraft/scripts/test-fixtures.sh --strict`: 17 passed, 0 failed, 0 skipped. The
  new `createbook/fixtures/assertions/run.sh` makes 32 assertions:
  - the committed file is rebuilt byte-identical from the helper's own commands
  - ten malformed files each fail by name
  - refused writes leave the file untouched
  - a newer format exits 2
  - the checker passes the folder with exactly three REVIEW lines
  - mutated copies fail as they should: superseded, retired or unreadable citations, a missing
    file, a reserved source name, a premise changed twice
  - a book with no marks and a figure spelling a space as an entity still pass, with the sweep's
    REVIEW lines
  - the worklist carries entries
  - a write keeps the file's mode
  - `init --how createbook` refuses an existing book
  - `check-book.sh` accepts the marks
- A copy of the scripts with the sweep, the `legacy` filter, the chain walk, the markless sweep,
  entity decoding and mode preservation each undone failed the fixture. So each assertion
  catches what it names.
- `plugins/pr/scripts/test-acceptance.sh`: 42 passed.
- CI passes on macOS and Ubuntu.
- The fixture passes with Python 3.9 first on `PATH`.

**By hand**
- Build a scratch book with the helper: `init`, `add` a premise, `supersede` it, `add` a
  settled entry with `--answer`, `correct` one answer, then `list` and `check`.
- Run `check-provenance.sh` on it with a mark citing the superseded entry, and see the failure.
  Put the old premise's phrase in a chapter and a figure, and see both REVIEW lines.
- Run `/createbook --recreate` from a backfilled folder into a new one. After `expect --all`,
  the uncited report names exactly the entries the new chapters did not carry.

**Edge cases considered:**
- repeated JSON keys, `true` or `1.0` as the format, a deleted newest entry
- a one-sided or backwards supersession
- `citation` on a book entry, `legacy` in a file `/createbook` started
- a component that only starts like a citation
- a source named with the reserved word
- `--chapters` scoping
- SVG markup splitting a phrase
- XML entities in figures
- a newer format
- a file left owner-only by the atomic write

## Impact assessment

- **Size:** 39 files, 4,902 lines added and 68 removed. About half of that is the helper, the
  fixture and its malformed files, and the branch's plan folder.
- **Dependencies:** none added. The helper is standard-library Python.
- **Compatibility:** no break for books that already exist. A book without `assertions.json`
  still passes every checker, which reports `assertions NOT CHECKED` instead of passing
  silently. Every existing fixture book stays in that state on purpose.
- **Behaviour that changes for an operator:** the first `/createbook`, `/updatebook` or
  `/check-claims` run on an existing book now stops for a one-time backfill that the operator
  confirms, even for a one-word fix.
- **Versions:** bookcraft 1.8.0 and pr 0.2.7, so installed copies refresh after merge.

## Deferred work

- **A review file for a backfill too large to confirm in chat.** Candidates would be written to
  a subfolder of the book for the operator to edit and a helper `import` to validate. It is not
  built, because the reference guide's 41 candidates fitted the triage.
- **No helper command amends a written entry's `search` phrases.** On the reference guide the
  first phrases missed a third of the passages, and the fix rewrote the uncommitted file. Backfill
  step 3 now proposes phrases from a bare-value sweep, which should make this rare.

**Assertions audit:** disabled. This repo configures no assertions file.
