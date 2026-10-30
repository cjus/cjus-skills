# makebook: let a book set its own chapter labels, and wrap wide code

Start date: 2026-10-30

Ticket: #102 (status:todo -> status:in-progress)

## Overview

Two kinds of book bind badly. A book that numbers its own chapters, with sub-chapters such as
6.1 between the whole numbers and an unnumbered introduction, and that cross-references those
numbers in its text, binds with a sequential 1, 2, 3 that disagrees with the text from the first
sub-chapter on. A book that quotes source code wider than the measure loses the tail of every
long line, from the page and from the text layer.

The objective is three optional `book.json` keys, `labels`, `code_wrap` and `code_pt`, each
defaulting to today's behaviour exactly, documented, and covered by a fixture.

## Plan

- [x] `labels`: applied in the binder after the chapters load (`apply_labels`), never in the
      book model, since `check-references.sh` keys chapters by the model's `unit`. Printed in the
      contents, the opener, the PDF outline, the EPUB opener, figure numbers, the EPUB index's
      links, a glossary entry's `(ch. N)`, and the binder's messages. Appendices are not counted.
      An empty label prints no number; its figures fall back to the chapter's place.
- [x] The contents and Figures number columns widen to fit the longest label (the Figures page
      allows ".NN" more), and stay at 1.9em without labels.
- [x] `code_wrap` and `code_pt`, validated in `layout_options`, carried into `build_css`, and the
      long-line threshold measured at `code_pt`.
- [x] `fixtures/labels/` binds a book using all three keys and checks every place a label prints,
      the empty label, the figure prefix, the wrap at `code_pt`, the EPUB, and four refusals.
- [x] `makebook/SKILL.md`, the plugin README, and bookcraft 1.17.0.

## Status

Done. `test-fixtures.sh`: 21 passed, 0 failed, 0 skipped. With no `labels`, `code_wrap` or
`code_pt`, `build_css()` differs from `main`'s only by one rule, `.toc-num.fig-num`, whose 1.9em is
the width the column already inherited.

## Deferred

- A fenced `svg` figure's source lines count toward the long-line total, so a book with inline
  figures reports more long lines than it prints. Present before this branch.
- `sections` and a glossary's `(ch. N)` still name a chapter by its place among the chapters. A
  book with labels might rather write them by label; that would be a change to two grammars and
  to `check-book.sh`, so it is left for a ticket of its own if a book needs it.
