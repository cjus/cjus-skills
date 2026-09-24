# build-book.py: anchor the appendix pattern, key colgroups on one number, drop the duplicate EPUB cover

Start date: 2026-09-24 13:01:31 MDT

Fix three defects in makebook's `build-book.py`. The appendix filename pattern should be anchored
the way the checkers anchor it. The column-width repair should key the measurement and the
injection on one chapter number, so appendix tables get repaired and a chapter never receives an
appendix's widths. The EPUB should stop opening on two cover pages when the cover art was
rasterised from the cover page.

## Changes

### 2026-09-24: appendix pattern anchored, colgroups keyed on `num`

- **#35.** `APPENDIX_FILE_RE` is now `^[a-z]+(?:-[a-z]+)*-appendix-(\d+)-[a-z0-9-]+\.md$`, the
  checkers' anchor plus the binder's existing tail. Bound with `main`,
  `sql-02-appendix-1-of-the-standard.md` printed as a second "Appendix 1". On the branch it
  prints as Chapter 2, and `sql-appendix-1-answer-key.md` stays Appendix 1. A folder whose
  appendix has no letters-only book slug in front, such as `09-appendix-1-x.md`, now binds it as a
  chapter, which is what the checkers already did.
- **#20, consequence 2 checked on `main` before changing anything.** It does not follow from the
  label collision alone. `plan_columns` runs one `seen` counter per label, so appendix N's first
  table is keyed `(N, k)`, where k is chapter N's own table count, and chapter N never asks
  that far. It does happen once chapter N's injection index runs ahead of its measurement. A raw
  `<table></table>` does that, because the measurement skips a table with no rows and
  `TABLE_OPEN_RE` counts it. With one in chapter 3, chapter 3's `A | B` table took appendix 3's
  `[100, 331]`. The empty-table shift inside a chapter is logged under Deferred.
- **#20, the fix.** `section.chapter` carries `data-ch="{num}"`, and the measurement keys on it
  instead of the digits in `.chapter-number`. The label is still read, and the table warning now
  names a table by it ("Appendix 1 (6 columns)", "Chapter 3 (...)") rather than as "ch N".
- **Rerun.** Both phase 2 fixtures plan `(6, 0)`, inject into appendix 3 only, and bind with no
  warning. The ticket's A/B reproduction warns on `main` as the appendix and binds clean on the
  branch under both names. `test-fixtures.sh --strict` passes 15 of 15.

### 2026-09-24: one EPUB cover, whole-book check, SKILL.md

- **#19.** `cover.xhtml` is built after the cover-art decision, and only when the art was not
  generated from it. `page()` adds to the manifest, so this keeps the page out of the manifest as
  well as the spine, which is the operator's answer to the manifest question. Declared
  `cover_image` art keeps the text page behind it, also per the operator. Measured: with generated
  art the spine now opens on `nav` and the package has no `cover.xhtml`; with declared art the
  spine still opens on `cover-page`; `main` opened on `cover-page` after the generated art. Neither
  `nav.xhtml` nor `toc.ncx` links the page in any of the three. epubcheck reports 0 errors and 0
  warnings on all three, and on `main`'s build.
- **Whole book.** `createbook/fixtures/guide`, which has an appendix, was bound with `main` and
  with the branch. The PDF text differs only in the `Created:` stamp, both are 13 pages, and the
  EPUB spine differs only in losing `cover-page`. `test-fixtures.sh --strict` passes 15 of 15.
- **SKILL.md.** § Appendices says how the filename is read now, with the look-alike slug and the
  no-book-slug case as examples. The `cover_image` bullet and the EPUB cover row say the text
  cover page gives way to generated art and stays behind declared art. The creation-stamp
  paragraph says "the EPUB's cover" rather than "cover page", since generated art carries the
  stamp without one.
