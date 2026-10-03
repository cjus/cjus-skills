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

### Amended 2026-10-03: a linked contents page

The operator updated ticket #62 to add this scope and asked for it to be added to this
plan. That is an operator decision, so it is recorded here as an amendment and the
objective above is left as written.

6. Each chapter, appendix, front-matter page and back-matter page gets an `id`, and each
   contents row links to it. The link is styled so that nothing on the page changes.
7. Whether the list of figures and the index's page numbers link too is decided, and
   implemented if the answer is yes.
8. `makebook/SKILL.md` documents the linked contents alongside the outline.

Added acceptance:

- Every entry on the contents page links to the page it names.
- On a Kindle Scribe, tapping a contents-page entry jumps to it.
- The `pdftotext -layout` check above still holds with the links in place.

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

**Added to the ticket on 2026-10-03**, also restated rather than quoted, for the same reason:

> **A linked contents page.** The reference generator's cover lists every section with its
> page number, and each number is a link that jumps to its page on the Scribe. No
> `page.pdf()` flag is involved: Chromium turns every in-document `<a href="#id">` into a PDF
> link annotation whose named destination is the page holding that `id`. The generator gives
> each page an `id` and writes each contents entry as `<a href="#pN">N</a>`; its cover's 49
> links all resolve to the right page. A bare `page.pdf()` with neither `outline` nor
> `tagged` produced working links in a test, so this half does not depend on the outline
> flags.
>
> makebook's contents page has the rows but nothing to link to. `build_toc()` writes each
> entry as a `div.toc-row` of spans with no anchor, and each chapter is
> `<section class="chapter" data-ch="N">` with no `id`. A bound book has no link
> annotations on its first six pages and no named destinations.
>
> The pypdf attachment step keeps the links: a `PdfWriter(clone_from=...)` copy of a
> reference PDF still had all 49, each resolving to its page. That copy also printed
> "Object count 12784 exceeds defined trailer size 12776", though it kept every outline entry
> and link. A 20-page tagged test did not reproduce the warning, and its cause is unknown.
>
> New work: give the pages `id`s and wrap each contents row (title and page number) in
> `<a href="#…">`, styled to inherit its colour with no underline; decide whether the list of
> figures and the index's page numbers link too; document the linked contents in
> `makebook/SKILL.md`; expect the pypdf warning.

## Plan

Status as of 2026-10-03: phases 1 to 8 are committed and pushed (`9fb320f`). Phases 10 to 15,
from the 2026-10-03 amendment, are done and uncommitted. Phase 9 and its re-run are done
except for the device checks, which only the operator can run.

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

Added 2026-10-03, from the amendment:

- [x] Phase 10: Give each chapter, appendix, front-matter page and back-matter page an `id`.
      Prefix the ids (`mb-ch-3`, `mb-contents`, `mb-glossary` and so on), because a chapter's
      raw HTML can carry ids of its own and a duplicate would send a link to the wrong page.
      *Done: `mb-contents`, `mb-about`, `mb-figures`, `mb-ch-N` (`chapter_id`),
      `mb-glossary`, `mb-index`, and `mb-fig-NNN` on each `<figure>` (`figure_id`).*
- [x] Phase 11: Link every contents row (Figures, each chapter and appendix, Glossary,
      Index) to its page, styled so the page doesn't change. **Two ways of doing this move
      the layout:**
      - *Turning the row into an `<a>`.* `.toc-group:first-of-type` (`:270`) counts element
        type. In a book with figures, the Figures row is the first `div`, so that rule matches
        no part heading today. Make the row an `<a>` and the first part heading becomes the
        first `div`, so its top margin drops from 0.14in to 0.05in. A part heading moving that
        little might not show up in `pdftotext -layout`, so that check alone could miss it.
      - *Wrapping the title and number spans in `<a>`.* The anchor becomes the flex item, so
        `.toc-title` and `.toc-page` lose their flex sizing.
      Proposed instead: keep the `div`, make it `position: relative`, and lay an empty
      `<a href="#…">` over it at `inset: 0`. The spans are untouched, and the whole row,
      title, leader dots and number together, becomes the tap target. That is a superset of
      the ticket's "title and page number". Confirm that Chromium writes a link annotation
      for an anchor with no text before relying on it.
      *Done as proposed (`toc_link`, `.toc-link`). A probe confirmed it first: Chromium
      writes the empty anchor as a `/Link` over the full row, with a named `/Dest` in the
      root `/Dests`. Part headings aren't linked, since a part has no page of its own.*
- [x] Phase 12: Link the list of figures and the index, if the open question below says to.
      Figures are cheap. Each is a `<figure>` (`:1998`), and adding an `id` to it covers raster
      figures too: today only SVG figures carry `id="figNNN"`, on the `<svg>` itself
      (`:1978`). The index is a different job. Its numbers are physical pages read back
      through `pdftotext`, and nothing in a flowing document marks the top of a page, so there
      is no element for `href="#…"` to target. A link would have to be made after rendering,
      for example a pypdf link annotation over each number, placed using
      `pdftotext -bbox`, that points at its page.
      *Figures done: each list-of-figures row links to its `<figure>`. The index is deferred,
      on the operator's answer.*
- [x] Phase 13: Confirm the links survive both pypdf rewrites, `build_outline` and
      `attach_scripts`. Also confirm that `attach_scripts` leaves them alone: it rewrites only
      a `/Link` whose URI starts with `ATTACH_URI` (`:2856`), and an internal link carries a
      destination, not a URI.
      *Confirmed. Every row's link still opens its page after `build_outline` alone, and in
      the save-scripts book after `attach_scripts` too, with its seven attachments in place.*
- [x] Phase 14: Extend `fixtures/bind/run.sh` to assert that every contents row's link
      resolves to the page its number prints. Cover a book with figures and parts, because
      that is where `.toc-group:first-of-type` comes into play. Document the linked contents
      in `makebook/SKILL.md` and the README.
      *Done. `fixtures/bind/contents-links.py` compares each listing's printed numbers with
      the pages its links open. `bind/run.sh` runs it on both guide binds, the second with
      figures above the parts, and `save-scripts/run.sh` runs it after the attachments. Two
      broken binders fail it: one with no links, one with each row aimed at the next
      chapter. Chromium drops a link whose id doesn't exist, so a wrong id shows up as a
      missing link. `SKILL.md` has a new section, The linked contents.*
- [x] Phase 15: Watch for pypdf's "Object count … exceeds defined trailer size" warning.
      None of the binds on this branch printed it: three full-length books, the guide
      fixture, a copy of it with parts and a stray `h1`, and the save-scripts book. Every
      bind now goes through a `clone_from` copy in `build_outline`, so the warning would have
      shown. If it appears, find its cause before shipping; don't silence it.
      *Not seen in any bind with the links in place either.*
- [ ] Re-run Phase 9's acceptance with the links in place: identical `pdftotext -layout`, and
      on the Scribe, a tapped contents entry jumps to its page.
      *`pdftotext -layout` is done: all three full binds still match `main` on every line
      except the `Created:` stamp. Every Contents and Figures row in them opens its page.
      Binds take 1 s longer than without the links (29 s, 20 s, 28 s) and about 17 KB bigger.
      **The Scribe tap is the operator's to check.***

## Open Questions

- ~~Should the list of figures and the index's page numbers link too?~~ Answered by the
  operator on 2026-10-03: **figures yes, index skipped for now.** Phase 12 links the list of
  figures only, and the index link is under Deferred.

The four earlier questions were answered by the operator on 2026-10-02:

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

- Linking the index's page numbers, which the operator skipped for now on 2026-10-03. No
  element marks the top of a page, so it would need a step after rendering: a pypdf link
  annotation over each number, placed using `pdftotext -bbox`, pointing at its page.

- `.chapter .endnotes-title` (0,2,0) has always lost to `.chapter h2:not(.chapter-title)`
  (0,2,1). The reading edition's Notes heading therefore prints at the section-heading size,
  weight and margins, not the uppercase sans size its own rule asks for. Fixing it moves the
  layout, so it is out of scope here.
- Chromium drops the space where a heading wraps when it writes the heading's text into the
  outline. `build_outline` retitles every entry from the page's HTML to work around it. The
  same joined text may be in the structure tree's `/SE` elements, which a screen reader reads.
  This was not checked.
