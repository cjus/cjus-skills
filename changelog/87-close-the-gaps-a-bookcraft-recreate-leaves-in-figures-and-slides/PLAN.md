# Close the gaps a bookcraft recreate leaves in figures and slides

Start date: 2026-10-11 10:31:26 MDT

Ticket: #87 (status:todo -> status:in-progress)

## Overview

The branch for #80 made `/createbook --recreate` account for the old book's figures and copy
its slide folder. It left two gaps, triaged at its close into #87.

- **Figure candidates.** The recreate's gate counts every image the old chapters reference,
  but `/makebook`'s figure pass reads only the old `diagrams/README.md` as its candidates. A
  figure the old chapters placed and the README never recorded can still leave the book by
  drift.
- **Slides.** The recreate copies the folder `book.json`'s `slide_figures` names, but
  `/createbook`'s drafting never places a slide. Nothing in the new chapters references the
  copied slides, and the new book binds without them.

The objective is to close both gaps, as #87 specifies. The figure pass takes its candidates
from every figure the old chapters placed, not only from the old README. And a recreate's
procedure says who places the copied slides in the new chapters, so a recreated book carrying
slides binds with them.

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred`, never as new scope.

## About Ticket

The body of #87 as of the branch start. It has no comments. Its action items are tracked under
`## Plan`.

Two items left by the branch for #80, which made a `/createbook --recreate` account for the old
book's figures and copy its slide folder.

- **Take the figure pass's candidates from every figure the old chapters placed, not only from
  the old `diagrams/README.md`.**
  - `createbook/SKILL.md § Recreating a book` counts the images the old chapters reference at
    its gate.
  - `makebook/SKILL.md § Deciding where a figure helps` reads only the old README as
    candidates.
  - So a figure the old chapters used but the README never recorded can leave the book by
    drift.
  - Occasion: the next recreate of a book whose README is incomplete.
- **Decide who places the copied slides in a recreated book's new chapters.**
  - The recreate now copies the folder `book.json`'s `slide_figures` names.
  - `/createbook`'s drafting never places slides, so nothing references them and the new book
    binds without them.
  - Occasion: the next recreate of a book that carries slides.

## Recent Context

The decisions this branch builds on are recorded in
`changelog/80-bookcraft-a-recreate-drops-the-old-book-s-figures-and-the-bind-does-not-notice/PLAN.md`
under `## Open Questions` and `## Deferred`: a recreate carries no figure, the figure pass
redraws each old one or passes it over with a reason, and slides are copied because they are
source material.

## Plan

### Figure candidates

- [x] `makebook/SKILL.md § Deciding where a figure helps`: take the candidates from the union of
  the old README's placed figures and every figure the old chapters reference (images outside
  the slide folder, plus inline `<svg>`), the set `createbook`'s gate counts. Say how a figure
  found only in the chapters is named in the new README, and keep the placed-plus-passed-over
  sum answering to that count.
- [x] `createbook/SKILL.md § Recreating a book`: align step 9, the "Hand that pass the old
  README as its candidates" paragraph and the folder note near the end of the skill with the
  new candidate rule, so both skills name one candidate set. The gate's figure count became the
  same union too, and names each figure only one record holds.

### Slides

- [x] Decide who places the copied slides in the new chapters (see `## Open Questions`), and
  write the decision into `createbook/SKILL.md § Recreating a book`, plus the skill that does
  the placing. `updatebook/SKILL.md` gained § Placing slides and a row in step 2's table.
- [x] Make the gate or the report surface the slides the new chapters do not place, so a
  recreated book binding without them is visible rather than silent. Step 9's report lists
  them, and the bind is unchanged.

### Release

- [x] Bump bookcraft's version in `plugin.json`, and run the fixture checks CI runs. 1.12.1 to
  1.13.0. At close the suite passes 18 of 18, 227 citations resolve, and CI passes all five
  jobs on PR #93.

## Open Questions

- ~~Who places the copied slides: `/createbook`'s chapter agents while drafting (each handed the
  old chapter's slide references as an input), `/makebook`'s figure pass (alongside the figure
  candidates), or the operator after the recreate?~~ **Resolved 2026-10-11 by the operator: the
  operator, through `/updatebook`, after the recreate.**
  - Drafting places no slide, and step 5 is unchanged.
  - The recreate's report lists every copied slide as not yet placed and names `/updatebook`
    as the way to place them.
  - A slide line takes no tag and advances no count, so placing slides moves no tag other files
    cite, before or after the figure pass.
  - Accepted cost: no paragraph was drafted to explain a slide. `/updatebook` puts each slide
    before the paragraph that already explains it. Where none does, it rewrites the paragraph
    after the slide in place, keeping its tag, or adds a lettered one (pre-test review, 2026-10-12).
- ~~Should a slide go where the old chapter placed it, or wherever the new chapter's lesson calls
  for it?~~ **Resolved 2026-10-11 by the operator: where the new lesson needs it.** A recreate
  changes chapter boundaries, so the old placement may name a chapter that no longer exists.
  The old placement is not a constraint, whoever does the placing.
- ~~Does the figure pass need a recorded candidate list in the new folder (the `assertions.json`
  precedent, raised in #80's open questions), or is reading the old folder's chapters at pass
  time enough while the operator keeps the old folder?~~ **Resolved 2026-10-11 by the operator:
  no recorded list.** The pass reads the old folder's README and chapters at pass time. The
  operator already keeps the old folder until the pass is done, and #80 made a recorded list
  wait on evidence that a candidate was dropped without a reason.
- ~~Should the bind warn when the `slide_figures` folder holds images no chapter references, as
  it now warns about a missing `diagrams/README.md`?~~ **Resolved 2026-10-11 by the operator:
  no.** `build-book.py` does not change. A recreate's report is the only place that shows
  which copied slides are not placed yet (plan item 4).
- ~~Raised by the pre-test review, finding 2: should paragraphs added for slides in a placing run
  be exempt from `/updatebook`'s several-at-once rewrite rule, or should such a chapter be
  rewritten with its slides handed to the chapter agent?~~ **Resolved 2026-10-12 by the
  operator: exempt.** A rewrite drafts from a prompt that places no slide, so it would drop the
  slides the run had just placed.

## Deferred

From the pre-test review (`pr-review-2026-10-12.md`), for triage at `/pr:close`:

- An `/updatebook` chapter rewrite drops the chapter's figures and slides. § Rewriting one
  chapter replaces the file whole from `/createbook`'s step 5 prompt, which carries neither, and
  nothing warns. This was already true on `main`. Occasion: the next chapter rewrite of a book
  that carries figures or slides.

From the close review (`pr-review-2026-10-12-close.md`), for triage at `/pr:close`:

- The option-A exemption covers only the several-at-once rewrite trigger. A chapter that already
  carries several lettered tags is still due a rewrite (`updatebook/SKILL.md § Adding prose`,
  § When to stop editing in place), and that rewrite drops its slides. The exemption sits in
  § Placing slides, which a later run does not read. A two-clause edit would extend it, and the
  operator's reason covers that trigger too. Fixing the item above would make this one moot.
- Which provenance mark a paragraph explaining a slide carries. The slide folder is not a
  declared source, so marking the slide path fails `check-provenance.sh`, and marking the
  explanation `fill` moves the chapter header's Fills-in row. The checks catch either case.

**Triaged at `/pr:close`, 2026-10-12.** Nine items. Seven were dropped, and two were ticketed
together as #94 with the operator's approval.

- **Dropped:** the provenance-mark question above, and the six items the two reviews had
  already dropped.
- **Ticketed as #94:** the chapter rewrite that drops figures and slides, and the exemption that
  does not reach the lettered-tags trigger. They share a root cause.
