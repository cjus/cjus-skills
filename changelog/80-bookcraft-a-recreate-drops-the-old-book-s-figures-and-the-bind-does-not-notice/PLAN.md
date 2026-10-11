# bookcraft: a recreate drops the old book's figures, and the bind does not notice

Start date: 2026-10-10 19:40:16 MDT

Ticket: #80 (status:todo -> status:in-progress)

Status, 2026-10-11 08:55 MDT: every plan item is done. PR #81 is open, CI passes all five jobs,
and both the pre-test and close-gate reviews approved. Every open question is resolved.

## Overview

`/createbook --recreate` writes every chapter fresh into a new folder, and its procedure never
mentions `diagrams/`. Every figure the old book placed, and the `diagrams/README.md` recording
why, is left behind in the old folder. `/makebook` binds the new book without a warning,
because `build-book.py` never reads that README. The loss shows only when a reader compares
the two editions.

The objective is to make a recreate account for the old book's figures, and to make the bind
notice a book whose figure decisions were never recorded, as #80 specifies. A recreate
inventories the old `diagrams/` and reports it at the gate, says how the old figures reach the
new book and that each must be re-checked against the new prose, and names the `/makebook`
figure pass as due before the new book is bound. `build-book.py` warns when a book has no
`diagrams/README.md`. The review on #80 adds the slide folder `book.json`'s `slide_figures`
names, which the recreate drops the same way.

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred`, never as new scope.

## About Ticket

The body of #80 as of the branch start. Its action items are tracked under `## Plan`, together
with the one added by the review comment on #80.

A `/createbook --recreate` silently drops every figure the old book carried, and nothing downstream notices. Measured on 1.11.0: a guide book whose old edition placed eight hand-drawn figures across eight chapters, each recorded in its `diagrams/README.md`, was recreated and bound with none of them. The bind ran clean, and the loss was found only by a reader comparing the two editions.

**Why nothing catches it:**

| Where | What it does with figures |
|---|---|
| `plugins/bookcraft/skills/createbook/SKILL.md` § Recreating a book (`:671`) | Never mentions figures or `diagrams/`. Its step table covers `assertions.json`, the ledger, the gate and `book.json`, so the old `diagrams/` folder is neither carried nor listed |
| `createbook/SKILL.md:821` | Says figures land in `diagrams/` only when `/makebook` runs and decides a figure earns its place. True for a new book, but a recreate is the case where earlier decisions already exist and are thrown away |
| `plugins/bookcraft/skills/makebook/SKILL.md` § Procedure (`:62`) and `:100` | Asks for the figure pass and for the decisions to be recorded in `diagrams/README.md`. This is prose the operator or agent must remember; running `build-book.py` directly skips it |
| `plugins/bookcraft/skills/makebook/scripts/build-book.py` | Never reads `diagrams/README.md`, so a book with no figure decisions binds without a warning |

The same book's slide images survived only because the consuming project has its own check that fails when one goes missing. Nothing in bookcraft provides that for figures.

**Precedent:** #46 fixed the same class for `assertions.json` ("so a recreate cannot drop them").

**Cost:** every recreate of a book with figures loses them, and the bound book looks complete. The old figures cannot simply be copied back afterwards either, since a recreate changes worked examples and renumbers every tag the old `diagrams/README.md` cites, so each one has to be re-checked against the new prose.

**Occasion:** the next recreate of any book that carries figures.

### Review on #80

The review comment verified every line reference above against `main`, and proposed:

- **The slide folder is dropped too.** Recreate step 4 starts `book.json` from the old one, so
  `"slide_figures": "diagrams/slides"` carries over but the folder it names does not. Slides
  are source material rather than figure decisions, so the recreate should copy them.
- **List the old figures rather than copy them.** The recreate already refuses the old chapters
  as input, and `/makebook` chooses figures against the finished chapters, so the old README
  goes to the figure pass as candidates. The operator keeps the old folder until that pass is
  done.
- **Scope the `build-book.py` warning** to books `/createbook` wrote (an `assertions.json` or a
  `book.json` in the folder), since `/makebook` binds any folder of markdown.
- **Decide the `check-book.sh` REVIEW line's input first.** Nothing in the new folder records
  which folder it replaced. If that input is not settled, the box moves to a follow-up issue.

## Plan

### Recreate (`createbook/SKILL.md` § Recreating a book)

- [x] Recreate: inventory `<old-folder>/diagrams/` (every figure a chapter references, plus `diagrams/README.md`) and report it at the gate, with the count.
- [x] Recreate: decide whether to copy the old figures and README into `<new-folder>/diagrams/` under a "to re-check against the new prose" heading, or to list them only. Either way, say that each figure's facts and its anchoring paragraph must be re-checked, because the tags and examples it cites have changed.
- [x] Recreate: copy the folder `book.json`'s `slide_figures` names into the new folder, and report the count at the gate. (Added by the review on #80.)
- [x] Recreate: end the procedure by naming the `/makebook` figure pass as due before the new book is bound, citing `makebook/SKILL.md` § Deciding where a figure helps.
- [x] Update `createbook/SKILL.md:821` so it covers the recreate case.

### Bind (`makebook/scripts/build-book.py`)

- [x] `build-book.py`: warn when the folder has no `diagrams/README.md`, saying the figure decisions were never recorded. A book that rightly has no figures still writes that file, listing the chapters passed over, so the warning has a legitimate silencer.

### Check (`createbook/scripts/check-book.sh`)

- [x] Consider a `check-book.sh` REVIEW line after a recreate naming any figure the old README placed that the new folder neither carries nor passes over. **Considered and not built** (see `## Open Questions`). It is replaced by the bind warning, together with `/makebook`'s report, where the candidates placed again and passed over must add up to the candidate count.

### Release

- [x] Bump bookcraft's version in `plugin.json`, and run the fixture checks CI runs.

## Open Questions

- ~~Copy the old figures into the new folder, or list them only?~~ **Resolved 2026-10-10 by the
  operator: list them, then redraw.** A recreate carries no figure and no `diagrams/README.md`.
  Every figure is redrawn against the new prose by `/makebook`'s figure pass, which takes the
  old README as its candidates: each figure the old book placed is drawn again or recorded as
  passed over with the reason, so a figure leaves the book by decision rather than by drift.
  A copied README would also silence the new bind warning before the figure pass had run.
  Slides are the exception, because they are source material rather than figures drawn from
  the prose, so they are copied.
- ~~What tells `check-book.sh` which folder a book replaced: a flag naming the old folder, or a
  field the recreate writes into `book.json`?~~ **Resolved 2026-10-10 by the operator: neither,
  and the line is not built.**
  - `check-book.sh` runs at `/createbook`'s step 7, before `/makebook`'s figure pass, so it
    would name every old figure on every recreate.
  - Both inputs reach outside the book folder, which `check-book.sh` never reads
    (`createbook/SKILL.md § 7`). The operator deletes the old folder once satisfied, so a
    `book.json` field would outlive its target. A flag works only when someone remembers it,
    which is the failure #80 is about.
  - The measured failure, a figure pass that never ran, is caught by the bind warning. The
    unmeasured one, a pass that forgets a candidate, shows in `/makebook`'s report as a sum
    that does not add up.
  - The review on #80 said `check-book.sh` already reads `diagrams/README.md`. It does not.
    `check-provenance.sh` does.

  A later check, if a recreate ever shows a candidate dropped without a reason, would have the
  recreate write the old figure names into the new folder (the `assertions.json` precedent).
  `check-provenance.sh` would check them only once a new README exists.
- ~~Does the CI fixture book carry a `diagrams/README.md`?~~ **Resolved 2026-10-10 from the
  code: it did not, and now does.** CI binds four books. Three of them
  (`makebook/fixtures/bind/appendix-slug`, `bind/appendix-table`, `save-scripts/book`) carry no
  `book.json` or `assertions.json`, so the scoped warning stays silent on them. The fourth,
  `createbook/fixtures/guide`, which `bind/run.sh` binds twice, has a `book.json` and a figure.
  It now carries `diagrams/README.md`. An earlier reading of this answer named only the first
  three books and was wrong about the guide.

## Deferred

From the pre-test review (`pr-review-2026-10-11.md`), for triage at `/pr:close`:

- (DROP) A `slide_figures` value of plain `diagrams` would make recreate step 4's copy carry the
  old figures and README. The value is undocumented, so the risk is speculative.
- (DROP) The fixtures paragraph in `plugins/bookcraft/README.md` does not list the three new
  `bind/run.sh` assertions. It already lagged behind the fixtures before this branch.

**Triaged at `/pr:close`, 2026-10-11.** Eight items: six dropped, and two ticketed together as
#87 with the operator's approval.

- **Dropped:** the two items above, three of the pre-test review's optional suggestions, and the
  evidence-gated candidate check NOTES records.
- **Ticketed as #87:** the review's candidate-count suggestion (the figure pass reads only the
  old README), and who places the copied slides in a recreated book's new chapters.
