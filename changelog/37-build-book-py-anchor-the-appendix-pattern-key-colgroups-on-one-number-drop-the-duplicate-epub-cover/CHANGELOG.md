# build-book.py: anchor the appendix pattern, key colgroups on one number, drop the duplicate EPUB cover

Start date: 2026-09-24 13:01:31 MDT

Fix three defects in makebook's `build-book.py`. The appendix filename pattern should be anchored
the way the checkers anchor it. The column-width repair should key the measurement and the
injection on one chapter number, so appendix tables get repaired and a chapter never receives an
appendix's widths. The EPUB should stop opening on two cover pages when the cover art was
rasterised from the cover page.

## Changes

### 2026-09-24: appendix pattern anchored, colgroups keyed on `num`

- **#35.** `APPENDIX_FILE_RE` is now `^[a-z]+(?:-[a-z]+)*-appendix-(\d+)-[a-z0-9-]+\.md$`,
  which is the checkers' anchor plus the binder's existing tail.
  - Bound with `main`, `sql-02-appendix-1-of-the-standard.md` printed as a second "Appendix 1".
    On the branch it prints as Chapter 2, and `sql-appendix-1-answer-key.md` stays Appendix 1.
  - The new pattern and the checkers' pattern agreed on seven sample names.
  - A name with no letters-only book slug in front, such as `09-appendix-1-x.md`, now binds as a
    chapter, as the checkers already read it.
- **#20, checked on `main` before changing anything.** The label collision alone cannot give a
  chapter an appendix's widths. `seen` counts per label, so appendix N's tables are keyed after
  chapter N's own tables. It does happen when chapter N's injection index runs ahead of its
  measurement. A raw `<table></table>` does that: the JS skips a table with no rows, and
  `TABLE_OPEN_RE` counts it. With one in chapter 3, chapter 3 took appendix 3's `[100, 331]`.
  The within-chapter shift that remains is logged under Deferred.
- **#20, the fix.** `section.chapter` now carries `data-ch="{num}"`, and the measurement keys on
  it. The printed label is only used to name the table in the warning ("Appendix 1 (6 columns)"
  rather than "ch N").
- **Rerun.** Both phase 2 fixtures plan `(6, 0)`, inject into appendix 3 only, and bind with no
  warning. The ticket's A/B reproduction binds clean under both names.
  `test-fixtures.sh --strict` passes 15 of 15.

### 2026-09-24: one EPUB cover, whole-book check, SKILL.md

- **#19.** `cover.xhtml` is built after the cover-art decision, and only when the art was not
  generated from it, so it leaves the manifest as well as the spine. Declared `cover_image` art
  keeps it behind. Both choices were the operator's.
  - Reading the spines: generated art opens on `nav`, declared art opens on `cover-page`, and
    `main` opened on `cover-page` after the generated art.
  - No nav or ncx link to the page in any case.
  - epubcheck reports 0 errors and 0 warnings on all three, and on `main`'s build.
- **Whole book.** `createbook/fixtures/guide` was bound with `main` and with the branch.
  - The PDF text differs only in the `Created:` stamp, and both are 13 pages.
  - The EPUB spine loses only `cover-page`, and the branch's EPUB passes epubcheck clean.
- **SKILL.md.** § Appendices says how the filename is read. The `cover_image` bullet, the EPUB
  cover row and the creation-stamp paragraph follow the new cover behavior.

### 2026-09-25: review follow-through

- The pre-test review's SKILL.md wording fixes are applied: the lowercase book slug, the cover
  row, and the "chapter or appendix" warnings row. The `APPENDIX_FILE_RE` comment says lowercase
  too.
- The close review found bookcraft's version unbumped. It is now `1.7.1`, a patch bump for bug
  fixes, as with #15.
- All cover results come from reading the package structure, not from viewing the book on a
  reading device.
