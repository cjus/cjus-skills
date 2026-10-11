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

- [ ] Decide who places the copied slides in the new chapters (see `## Open Questions`), and
  write the decision into `createbook/SKILL.md § Recreating a book`, plus the skill that does
  the placing.
- [ ] Make the gate or the report surface the slides the new chapters do not place, so a
  recreated book binding without them is visible rather than silent.

### Release

- [ ] Bump bookcraft's version in `plugin.json`, and run the fixture checks CI runs.

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
  - Accepted cost: the paragraph beside a slide was not drafted as its notes. `/updatebook` can
    rewrite that paragraph in place, and the paragraph keeps its tag.
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
