# build-book.py: anchor the appendix pattern, key colgroups on one number, drop the duplicate EPUB cover

## Overview

makebook's binder had three defects in `build-book.py`, and this PR fixes all three.

- **Appendix filenames.** The appendix pattern was unanchored, so a chapter whose slug happened
  to contain `-appendix-N-` bound as Appendix N, while every checker read it as a chapter. It is
  now anchored the way the checkers anchor it.
- **Table column widths.** The colgroup repair filed its plan under the printed chapter label
  ("Appendix 3" reads as 3) but looked it up by the binder's sequential number. Appendix tables
  were never repaired, and the table warning named the wrong chapter. The measurement and the
  injection are now keyed on the same number.
- **The EPUB cover.** A book with no `cover_image` opened on the cover art rasterised from the
  cover page, followed by that same page as text. The text page is no longer built when the art
  is generated from it.

The PDF is unchanged, apart from appendix tables that now get the repair every other table
already got.

## Key changes

- `plugins/bookcraft/skills/makebook/scripts/build-book.py`
  - `APPENDIX_FILE_RE` is anchored to a lowercase, letters-only book slug, matching
    `check-book.sh`, `check-provenance.sh` and `check-references.sh`.
  - `build_chapters` writes `data-ch="{num}"` on each `section.chapter`.
  - The table measurement (`TABLE_FIT_JS`) keys each table on `data-ch`, and carries the printed
    label along for the warning.
  - The table-width warning names a table by its label, "Appendix 1 (6 columns)", instead of by
    "ch N".
  - `build_epub` builds `cover.xhtml` after the cover-art decision, and only when the art was
    not generated from it. The page therefore leaves both the spine and the manifest in that
    case.
- `plugins/bookcraft/.claude-plugin/plugin.json`: bookcraft goes from `1.7.0` to `1.7.1`, so installed
  copies pick up the fixes. It's a patch bump because these are bug fixes, as with #15.
- `plugins/bookcraft/skills/makebook/SKILL.md`
  - § Appendices says how the filename is read, with the look-alike and no-book-slug cases as
    examples.
  - The `cover_image` bullet and the EPUB cover row say when the text cover page appears.
  - The creation-stamp paragraph and the warnings table follow the new behavior.

## Code examples

The pattern, `build-book.py`:

```python
# before
APPENDIX_FILE_RE = re.compile(r"-appendix-(\d+)-[a-z0-9-]+\.md$")
# after
APPENDIX_FILE_RE = re.compile(r"^[a-z]+(?:-[a-z]+)*-appendix-(\d+)-[a-z0-9-]+\.md$")
```

The measurement key, `build-book.py` (`TABLE_FIT_JS`). The section is written with
`data-ch="{ch["num"]}"` one line after `inject_colgroups(body, ch["num"], ...)`, so the key and
the lookup come from the same value:

```js
// before: the digits of the printed label
const m = numEl && numEl.textContent.match(/(\\d+)/);
const ch = m ? parseInt(m[1], 10) : null;
// after: the binder's own sequential number
const ch = sec && sec.dataset.ch ? parseInt(sec.dataset.ch, 10) : null;
const label = numEl ? numEl.textContent.trim() : null;
```

The EPUB spine, `build-book.py` (`build_epub`):

```python
cover = (None if generated_cover else
         page("cover-page", "cover.xhtml", title,
              epub_cover_body(title, cfg, chapters, src, stamp)))
...
book.spine = (([cover] if cover else []) + ["nav"] + front
              + chapter_items + back)
```

## Plan alignment

All seven phases were completed as planned.

- **Phase 1.** The pattern is anchored.
- **Phase 2.** The ticket's "a chapter receives an appendix's widths" was checked on `main`
  before anything changed. The label collision alone does not cause it. `plan_columns` keeps one
  running counter per label, so appendix N's first table is keyed after chapter N's own tables,
  and chapter N never asks for that index. It does happen when chapter N's injection index runs
  ahead of its measurement. A raw `<table></table>` does that: the measurement skips a table with
  no rows, and `TABLE_OPEN_RE` counts it. With one in chapter 3, `main` gave chapter 3's table
  appendix 3's widths `[100, 331]`.
- **Phases 3 and 4.** Keying both sides on `num` closes that cross-chapter case and repairs
  appendix tables.
- **Phase 5.** It follows the operator's two answers:
  - declared `cover_image` art keeps the text cover page behind it
  - when the art is generated, the page leaves the manifest as well as the spine
- **Phases 6 and 7.** A whole-book comparison, and the SKILL.md update.

One key choice was settled during the work. `section.chapter` gets a `data-ch` attribute rather
than the measurement reading the existing `CH###` probe. The attribute says what it is, and it
doesn't depend on the probe's text format.

The fixtures question stays open. It is triaged at close under Deferred work below.

## Testing

Every bind below was run with `main`'s binder and with this branch's, from scratch fixtures.

- **Appendix pattern.** The fixture held `sql-01-intro.md`, `sql-02-appendix-1-of-the-standard.md`
  and `sql-appendix-1-answer-key.md`.
  - `main` labelled them Chapter 1, Appendix 1, Appendix 1.
  - The branch labels them Chapter 1, Chapter 2, Appendix 1.
  - The new pattern also agrees with the checkers' pattern on seven sample names.
- **Colgroup keying.** The fixture was three chapters and three appendices, with a squeezed
  table in appendix 3.
  - `main` planned it at `(3, 1)`, injected nothing, and warned.
  - The branch plans `(6, 0)`, injects into appendix 3 only, and binds with no warning.
  - A variant that adds an empty raw table to chapter 3 contaminated chapter 3 on `main`. On the
    branch it is clean.
- **The ticket's A/B reproduction.** Three files, with the table in the third. Named as an
  appendix, it warns on `main`. On the branch it binds clean under both the appendix name and
  the chapter name. A table too wide to repair is now reported as "Appendix 1 (6 columns)".
- **EPUB cover.** Read from the package's spine and manifest, and not viewed on a reading
  device.
  - `main` opened on the generated art, then `cover-page`.
  - With generated art, the branch opens on `nav`, and the package holds no `cover.xhtml`.
  - With a declared `cover_image`, the branch keeps `cover-page` first.
  - Neither `nav.xhtml` nor `toc.ncx` links the page in any case.
  - epubcheck reports 0 errors and 0 warnings on all of these.
- **Whole book.** `createbook/fixtures/guide`, which has an appendix, was bound with both
  binders.
  - The PDF text differs only in the `Created:` stamp line, and both PDFs are 13 pages.
  - The EPUB spine differs only in losing `cover-page`, and the EPUB passes epubcheck clean.
- **Automated.** `test-fixtures.sh --strict` passes 15 of 15, and CI's `fixtures` job passes on
  macOS and Linux.
- **By hand.** Bind a book that has an appendix, a chapter whose slug holds `-appendix-1-`, and a
  table that breaks a word with room to spare.
  - The look-alike should print as a chapter.
  - The appendix table should come out with no warning.
  - With no `cover_image`, the EPUB should open on a single cover.
  - With a `cover_image`, it should open on the art, then the text page.

## Impact assessment

- Three plugin files changed: `build-book.py`, `SKILL.md` and bookcraft's `plugin.json`. There
  are no new dependencies.
- **Behavior change.** A file whose name has no lowercase letters-only book slug in front of
  `-appendix-N-` now binds as a chapter. Examples are `09-appendix-1-x.md`, `Guide-appendix-1-x.md`
  and `web3-appendix-1-x.md`. This is how `/createbook`'s checkers already read those names, and
  books written by `/createbook` are unaffected.
- **Behavior change.** A generated-cover EPUB no longer contains `cover.xhtml`, so it has one
  fewer page.
- **Output change.** The table-width warning prints "Chapter N" or "Appendix N" in place of
  "ch N". Nothing in the repo parses that text.

## Deferred work

These items are logged under `PLAN.md § Deferred`:

- **A table with no rows shifts one chapter's colgroups.** The measurement skips an empty table
  while `TABLE_OPEN_RE` counts it, so later tables in the same chapter take the wrong plan.
  Keying on `num` closes the cross-chapter half of this, but not the within-chapter half.
- **No regression fixtures for the appendix pattern or the appendix-table repair.** A revert of
  either fix would bind silently. The review suggests adding them to #32, which is where a bind
  would run in CI.
- **`check-book.sh:336`'s greedy `sed`** takes the last `-appendix-N-` in a name, while the binder
  and the other checkers take the first. This matters only for a doubled name.
- **The binder's appendix tail is stricter than `check-references.sh` and
  `check-provenance.sh`.** This is unchanged from `main`, and matches `check-book.sh`.

Assertions: disabled (`docs.assertionsFile` is `null`).
