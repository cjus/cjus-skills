# build-book.py: anchor the appendix pattern, key colgroups on one number, drop the duplicate EPUB cover

Start date: 2026-09-24 13:01:31 MDT

## Overview

Three defects in `plugins/bookcraft/skills/makebook/scripts/build-book.py`, fixed together
because they all land in that file and two of them meet in `load_chapters`:

1. `APPENDIX_FILE_RE` is unanchored. A chapter whose slug happens to contain `-appendix-N-`
   binds as Appendix N, while every checker reads it as a numbered chapter. It gets anchored the
   way the checkers anchor it.
2. The colgroup repair files its plan under the rendered label number and looks it up by the
   running file index. Appendix tables are never repaired, and a chapter can pick up an
   appendix's column widths. Both sides get keyed on the one true `num`.
3. When `book.json` declares no `cover_image`, the EPUB opens on the rasterised cover art and
   then shows a text cover page with the same content. The text page comes out of the spine in
   that case.

The branch is done when all three hold in a bound book: a chapter slug containing `-appendix-N-`
binds as a chapter, appendix tables are repaired with no chapter getting their widths, and a
generated-cover EPUB opens on exactly one cover.

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred`, never as new scope.

## About Ticket

Issue #37: build-book.py: anchor the appendix pattern, key colgroups on one number, drop the
duplicate EPUB cover (priority:high, bug)
https://github.com/cjus/cjus-skills/issues/37

> Consolidates #19, #20 and #35, which converge on
> `plugins/bookcraft/skills/makebook/scripts/build-book.py`.
>
> - [ ] makebook's EPUB opens with two cover pages when no cover_image is declared
> - [ ] makebook's colgroup repair never reaches an appendix, and can apply its widths to the
>   wrong chapter
> - [ ] Anchor makebook's appendix filename pattern like the checkers
>
> **Why these combine:** strict. All three land in `build-book.py`: #35 in `APPENDIX_FILE_RE`
> (`:706`, applied at `:876`), #20 in the colgroup key (injection by `num` at `:1962` against
> the plan keyed at `:1881` on the rendered `label_num` read at `:2195`), and #19 in the EPUB
> spine (`:3117`). #20 and #35 meet at `load_chapters` `:876-880`, where the appendix pattern
> sets `label_num`.
>
> #32 (binding a fixture book in CI) names this work as its occasion but stays separate, since
> its changes land in the CI workflow and the fixtures rather than in `build-book.py`.

Line numbers below were rechecked against `main` @ `75f1a0b` when this branch started, and all
hold.

### #35: the unanchored appendix pattern

- `:706` `APPENDIX_FILE_RE = re.compile(r"-appendix-(\d+)-[a-z0-9-]+\.md$")`, applied with
  `.search` at `:876`.
- The checkers anchor it as `^[a-z]+(?:-[a-z]+)*-appendix-(\d+)-`: `check-provenance.sh:1156`,
  `check-references.sh:86`, and `check-book.sh:334` (as an ERE, guide profile only).
- Symptom: `sql-02-appendix-1-of-the-standard.md` prints as "Appendix 1" in the contents and on
  its own page. Every checker reads it as chapter 2.

### #20: the colgroup repair keys one table two ways

- `load_chapters` sets `num` to the running position across all files and `label_num` to the
  appendix's own number (`:879-880`).
- `plan_columns` keys its plan by the chapter number the measurement reads off the rendered page
  (`:1881`, `ch = t["ch"]`). That comes from `.chapter-number` (`:2195`), which prints
  `label_num` for an appendix (`:1969`).
- `inject_colgroups` looks the plan up by `ch["num"]` (`:1962`).
- For the third appendix in an eighteen-chapter book, the plan is stored at `(3, i)` and looked
  up at `(21, i)`. Consequence 1: no appendix table is ever repaired. Consequence 2: chapter 3
  asks for `(3, i)` and gets appendix 3's plan. This is the cross-contamination the module
  comment at `:1841` warns about.
- The measured A/B reproduction: three files, the table in the third. As
  `repro-appendix-1-the-squeezed-table.md` it warns that 1 of 1 tables breaks a word with room
  to spare. As `repro-03-the-squeezed-table.md` there is no warning. The two leading files
  exist so the appendix's position differs from its label; with the appendix first, the keys
  coincide and the bug hides.
- Consequence 2 is read from the code, not demonstrated. The ticket says to confirm it before
  fixing.
- Suggested fix: `build_chapters` already emits a probe carrying the true `num` beside the
  chapter number (`:1970`, `CH{num:03d}`). Have the measurement read that, or add a `data-ch`
  attribute with `num` to `section.chapter`. Stop keying on the rendered label, which is a
  display string and stops being unique once a book has appendices.

### #19: the duplicate EPUB cover

- `:3053` builds `cover.xhtml` unconditionally.
- `:3093` tracks `generated_cover`. The PDF cover is rasterised to `cover.png` and registered
  with `book.set_cover(..., create_page=False)`, which declines ebooklib's own cover page.
- `:3117` puts the hand-built page first in the spine regardless:
  `book.spine = [cover, "nav"] + front + chapter_items + back`.
- Suggested fix: `book.spine = ([] if generated_cover else [cover]) + ["nav"] + front +
  chapter_items + back`. Neither `nav.xhtml` nor `toc.ncx` links `cover.xhtml`, so dropping it
  from the spine leaves no dangling reference.
- The PDF is unaffected.

## Plan

- [x] Phase 1 (#35): anchor `APPENDIX_FILE_RE` to match the checkers. A slug containing
  `-appendix-N-` should bind as a numbered chapter, and a real `<book-slug>-appendix-N-<slug>.md`
  should still bind as Appendix N.
- [x] Phase 2 (#20): build a fixture that isolates consequence 2, a chapter receiving an
  appendix's widths, and confirm it on `main` before changing anything.
- [x] Phase 3 (#20): key `plan_columns` and `inject_colgroups` on the same `num`, reading the true
  number from the page rather than the `.chapter-number` label.
- [x] Phase 4 (#20): rerun the A/B reproduction and the phase 2 fixture. Both builds should come
  back clean, and no chapter should carry an appendix's colgroup.
- [x] Phase 5 (#19): keep `cover.xhtml` out of the EPUB spine when the cover art was generated,
  following whatever the open question on a declared `cover_image` settles.
- [x] Phase 6: bind a fixture book with appendices and check the result. The contents and chapter
  pages should label chapters and appendices correctly. The EPUB spine should open on one cover
  with and without `cover_image`. The PDF should be unchanged apart from the repaired tables.
  Run the existing fixture runner.
- [x] Phase 7: update `makebook/SKILL.md` wherever it describes the behaviors that changed.

**Status (2026-09-25):** all seven phases are done. Draft PR #39 has CI green on macOS and Linux.
The pre-test and close reviews both returned APPROVE. bookcraft was bumped to `1.7.1` so
installed copies pick up the fix.

## Open Questions

- ~~**#19: a declared `cover_image`.**~~ Resolved by the operator: keep the asymmetry. The text
  cover page drops out only when the art was rasterised from it; declared art keeps it behind.
- ~~**#19: manifest.**~~ Resolved by the operator: leave the manifest too. `cover.xhtml` is not
  built at all when the art was generated.
- ~~**#20: which key.**~~ Resolved: `section.chapter` carries `data-ch="{num}"` and the
  measurement reads that. The `.chapter-number` text is kept only as the label the warning
  names a table by.
- **Fixtures.** Should the #20 A/B reproduction and the #35 look-alike slug become permanent
  fixtures under the fixture runner, or stay local to this branch? Binding a fixture in CI is
  #32's scope, so this branch should not grow that work. Carried into § Deferred as "No regression
  fixtures for #35 or #20". Settled at close: folded into #32.

## Deferred

- **A table with no rows desyncs a chapter's own colgroups.** The measurement skips a table
  whose `rows` is empty (`if (!rows.length) continue;`), while `inject_colgroups` counts it
  through `TABLE_OPEN_RE`. A raw `<table></table>` ahead of a squeezed table shifts every later
  table's plan in that chapter by one place. On `main` this was also what let chapter 3 pick up
  appendix 3's widths in the phase 2 fixture; keying on `num` closes the cross-chapter half, and
  the within-chapter shift remains. Pushing an entry for the empty table, with no columns, would
  keep the indices aligned. **Triage: TICKET, filed as #40.**
- **No regression fixtures for #35 or #20** (from the pre-test review). A revert of either fix
  binds silently. The reviewer suggests folding the look-alike slug and the appendix-table A/B
  into #32's checklist, since #32 is where a bind would run in CI. This is the same decision as
  the Fixtures open question above. **Triage: folded into #32 as a comment listing both fixtures.**
- **`check-book.sh:336` takes the last `-appendix-N-` in a name** (from the pre-test review). Its
  greedy `sed` differs from the binder and the other two checkers only for a doubled name like
  `x-appendix-1-appendix-2-y.md`. **Triage: DROP.**
- **The binder's appendix tail is stricter than `check-references.sh` and
  `check-provenance.sh`** (from the pre-test review). The binder requires `[a-z0-9-]+\.md`, the
  two checkers accept any tail, and `check-book.sh` requires the same tail as the binder.
  Unchanged from `main`. **Triage: DROP.**
