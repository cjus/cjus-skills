# makebook: give the PDF a navigable outline, so a Kindle Scribe shows an expandable table of contents

Start date: 2026-10-02 18:33:56 MDT

Ticket: #62 (status:todo -> status:in-progress)

## Overview

A PDF that carries an outline (bookmarks) gets a navigable table of contents on a Kindle
Scribe, with entries that expand and collapse. A book bound by `/bookcraft:makebook` has no
outline, so on the Scribe the only way to reach a chapter is to page through or use the
printed contents page.

The objective is to give every PDF `/makebook` binds an outline with this shape: the front
matter, each chapter and appendix, and the back matter at the top level, and each chapter's
sections nested beneath it. The change must not alter layout, and an empty or short outline
must fail the build or warn instead of shipping unnoticed. In full:

1. `render()` passes `outline=True, tagged=True` to `page.pdf()` for every edition and type
   size.
2. Chapter, appendix, front-matter and back-matter titles become `h1`, so the outline nests
   by chapter. Their styling stays the same.
3. The outline's depth and each chapter entry's label are decided and implemented.
4. The build fails or warns when the outline is empty or has fewer top-level entries than the
   book has chapters.
5. `makebook/SKILL.md` documents the outline and its dependency on `tagged=True`.

Acceptance:

- Rebinding a full-length book gives a PDF whose outline lists the front matter, each chapter
  and appendix, and the back matter at the top level, with each chapter's sections nested
  beneath it.
- `pdftotext -layout` of the book gives identical output before and after, so no page and no
  contents-page number moves.
- Sent to a Kindle Scribe through Send to Kindle, the book's table of contents expands and
  collapses by chapter.

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred`, never as new scope.

## About Ticket

**#62: makebook: give the PDF a navigable outline, so a Kindle Scribe shows an expandable table of contents**

Labels at start: `feature`, `status:todo`, `priority:high`.

The ticket body below is restated, not quoted. It cited a separate PDF generator in another
project and a specific bound book by path. Those details are given here in generic terms.

> **Why.** A PDF that carries an outline gets a navigable, expandable table of contents on a
> Kindle Scribe. This was confirmed on the device on 2026-10-02 with PDFs from a separate
> generator, sent through Send to Kindle. A book bound by `/bookcraft:makebook` has no
> outline: `PdfReader(<bound book>.pdf).outline` returns 0 entries.
>
> **How the reference PDFs get their outline.** Both the reference generator and the binder
> render through Playwright's `page.pdf()` on Chromium. The reference generator passes two
> flags that `makebook` does not:
>
> ```python
> page.pdf(..., outline=True, tagged=True)
> ```
>
> Chromium then builds the outline from the page's `h1` to `h6` elements and nests each
> entry by heading level. Measured with the bookcraft venv (Playwright 1.62.0, pypdf 6.19.0):
>
> | Probe | Result |
> |---|---|
> | `outline=True` without `tagged=True` | **No outline at all.** Both flags are required |
> | makebook's current markup, both flags on | Chapter titles and their sections come out as siblings, all nested under the cover's `h1` |
> | Chapter and back-matter titles promoted to `h1`, both flags on | Clean tree: cover, Contents, each chapter with its sections and subsections nested, then Index |
> | makebook's pypdf attachment step (`PdfWriter(clone_from=...)`) on a PDF with an outline | Outline preserved, 173 entries before and after |
>
> The outline comes out flat because of the heading levels. In bookcraft 1.9.0's
> `skills/makebook/scripts/build-book.py`, the chapter title is `h2.chapter-title` (`:2237`),
> and in-chapter sections are plain `h2` (styled by `.chapter h2:not(.chapter-title)`,
> `:308`), so both are at the same level. The back-matter and front-matter titles are
> `h2.section-title` as well (`:1658`, `:2258`, `:2284`, `:2310`, `:2333`). The cover title is
> the only `h1` (`:1566`).
>
> Chromium leaves a heading hidden with `clip-path` or `opacity: 0` out of the outline, but
> keeps one styled `color: transparent`. The reference generator relies on this for its
> hidden headings. Promoting the visible titles to `h1` suits this binder better, because it
> adds no hidden text for `locate()`'s pdftotext pass to read.

## Plan

Status as of 2026-10-02 19:09 MDT: phases 1 to 8 are done and uncommitted. Phase 9 is done
except for the device check, which only the operator can run.

- [x] Phase 1: Pass `outline=True, tagged=True` to `page.pdf()` in `render()`
      (`build-book.py:2599`), and confirm every edition and type size goes through it.
      *Done. `render()` is the only `page.pdf()` call, and every settling pass, the
      clean render and the fallback render go through it.*
- [x] Phase 2: Promote `h2.chapter-title` and `h2.section-title` to `h1` without changing
      their styling. Update the selectors at `:251`, `:299` and `:308`, plus anything else
      that keys on `h2` (`.chapter h2, .chapter h3` at `:486`). Visual output must not change.
      *Done. `.chapter h2:not(.chapter-title)` is kept as written because its 0,2,1
      specificity is what styles the reading edition's Notes heading (see Deferred).*
- [x] Phase 3: Confirm that no chapter body renders its own `h1`, which would appear as a
      stray top-level entry.
      *A body can render one: any `# ` line after the title. `build_outline` files it under
      its chapter as a section, and the bind fixture covers that case.*
- [x] Phase 4: Decide the outline's depth. Chromium emits every heading level, so in-chapter
      `h3` and `h4` become entries too. pypdf, already a dependency, can prune below a chosen
      level after rendering.
      *Sections only: each top-level entry keeps its direct children and drops theirs.*
- [x] Phase 5: Decide each chapter entry's label. The entry uses the heading's text, so a
      chapter appears as its title without "Chapter N" or "Appendix N".
      *`Chapter 3: Title` and `Appendix 1: Title`. A title that already starts with its
      label keeps it once.*
- [x] Phase 6: Measure the change in file size and build time on a full book, since
      `tagged=True` adds a structure tree. The tree also makes the PDF more accessible to
      screen readers.
      *Measured on a 21-chapter book of 338 pages at 14pt: 3.34 MB to 5.01 MB (+50%) and
      26 s to 28 s. The reading edition went from 3.20 MB to 4.84 MB and 17 s to 19 s; at
      17pt, 3.41 MB to 5.11 MB and 26 s to 27 s.*
- [x] Phase 7: Fail or warn the build when the outline comes back empty or has fewer
      top-level entries than the book has chapters.
      *Fails. Every page and chapter must be found among Chromium's top-level entries, in
      order, or the bind exits 1 naming the first one missing.*
- [x] Phase 8: Document the outline in `makebook/SKILL.md`, including the `tagged=True`
      dependency.
- [ ] Phase 9: Verify the acceptance bar on a full-length book: outline shape, identical
      `pdftotext -layout` before and after, and the Kindle Scribe check.
      *Outline shape and `pdftotext -layout` are done: three binds (default edition at 14pt
      and 17pt, reading edition at 14pt) match the binds from `main` on every line except
      the `Created:` stamp. **The Kindle Scribe check is the operator's to run.***

## Open Questions

All four were answered by the operator on 2026-10-02.

- ~~How deep should the outline go?~~ Chapters expand to their sections (`h2`) and stop
  there.
- ~~Bare title or "Chapter N"?~~ `Chapter N: Title` and `Appendix N: Title`, matching the
  chapter's opening page.
- ~~Fail or warn on a short outline?~~ Fail the build.
- ~~Does the EPUB need anything?~~ No. Its nav document already nests by `sections`
  (`epub_toc`). The operator also chose that **the PDF outline nests chapters under their
  parts** when `book.json` declares `sections`, matching the contents page and the EPUB
  nav.

## Deferred

- `.chapter .endnotes-title` (0,2,0) has always lost to `.chapter h2:not(.chapter-title)`
  (0,2,1). The reading edition's Notes heading therefore prints at the section-heading size,
  weight and margins, not the uppercase sans size its own rule asks for. Fixing it moves the
  layout, so it is out of scope here.
- Chromium drops the space where a heading wraps when it writes the heading's text into the
  outline. `build_outline` retitles every entry from the page's HTML to work around it. The
  same joined text may be in the structure tree's `/SE` elements, which a screen reader reads.
  This was not checked.
