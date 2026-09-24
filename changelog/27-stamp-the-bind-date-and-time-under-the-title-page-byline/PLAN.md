# Stamp the bind date and time under the title page byline

Start date: 2026-09-24 06:14:10 MDT

## Overview

A bound book carries nothing that says when it was bound, so two PDFs or two EPUBs made from the
same folder cannot be told apart. This branch adds the date and time of binding to the title
page, directly under the author name, in both the PDF and the EPUB `/makebook` produces. The
stamp is the book's version marker.

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred`, never as new scope.

## About Ticket

Issue #27: Stamp the bind date and time under the title page byline (priority:high)
https://github.com/cjus/cjus-skills/issues/27

> Add the date and time a book was bound to the title page, directly under the author name. The
> stamp serves as the version marker for a bound book, so two bindings of the same folder can be
> told apart.
>
> - Applies to both outputs `/makebook` produces: the PDF and the EPUB.
> - Placement: under the author name on the title page (the `byline` from `book.json`, rendered
>   on the cover by `build_cover` in `plugins/bookcraft/skills/makebook/scripts/build-book.py`).
> - The value is the time of binding, meaning when `/makebook` ran.

### Where the title page is rendered

All three are in `plugins/bookcraft/skills/makebook/scripts/build-book.py`:

- **PDF cover:** `build_cover`, which places `.byline` after the title and subtitle and before
  the `.head-rule`.
- **EPUB cover page:** `cover.xhtml`, built from `epub_cover_body`.
- **EPUB cover art:** when `book.json` declares no `cover_image`, `render_cover_png` rasterises
  the PDF cover, so a stamp on the PDF cover shows up in that image too. A declared
  `cover_image` is used as-is.

## Plan

- [x] Phase 1: capture the bind time once per run, so the PDF and EPUB from one binding carry
  the same stamp. `bind_stamp()` is read once in `main` before the settling loop and passed
  as a required `stamp` argument through `assemble`, `build_epub` and `render_cover_png`.
- [x] Phase 2: render the stamp under the byline on the PDF cover (`build_cover`) and style it.
  `.cover .stamp` shares the byline's 10pt sans. The byline's gap before the rule moved to
  the stamp.
- [x] Phase 3: render the same stamp under the byline on the EPUB cover page (`epub_cover_body`).
  `.byline` and `.stamp` both set `text-indent: 0`. Main indented the byline 1.2em whenever a
  subtitle preceded it, which would have left the stamp and byline misaligned.
- [x] Phase 4: document the stamp in `makebook/SKILL.md`.
- [x] Phase 5: bind a fixture book and confirm the stamp shows on the PDF cover, the EPUB cover
  page and the generated EPUB cover art, and that the cover still fits on one page. The
  `guide` fixture was bound at 11.8, 14 and 17pt, plus a copy with no byline. In each, the PDF
  and the EPUB carried the same stamp, page 2 was Contents, and there was no cover warning.
  The stamp costs a fixed 21pt (about 0.29in) of cover height at every size, because none of
  it scales. A cover within 21pt of spilling on main now spills, and the existing
  `ZQCOVERENDQZ` warning reports it.

## Open Questions

None open. The operator answered all six on 2026-09-24:

- **Format and time zone:** local time with the zone abbreviation, such as MST. Written as
  `2026-09-24 06:14:10 MDT`, the same shape as this plan's start date. Seconds are kept so a
  rebind inside the same minute still reads differently.
- **Label:** `Created: `, so the line reads `Created: 2026-09-24 06:14:10 MDT`.
- **No `byline`:** the stamp still prints on the title page, in the place under the author name.
  Every binding carries the version marker, whether or not `book.json` names an author.
- **Size:** the same type as the author name. On the PDF cover that is the byline's 10pt system
  sans. In the EPUB it is the byline's unstyled body size. Whether the extra line still fits a
  long-description cover on one page is Phase 5's to measure.
- **Declared `cover_image`:** left as it is. The stamp is not drawn onto supplied art, and the
  text cover page carries it.
- **Reproducibility override:** none. No `SOURCE_DATE_EPOCH` or equivalent.

## Deferred
