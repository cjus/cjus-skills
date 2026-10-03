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

Status as of 2026-10-03: every phase is done. Phases 1 to 8 are in `9fb320f`, phases 10 to
15 in `d485edf`, phases 16 to 18 in `17283a1`, Phase 19 in `f7ba3da`, and Phase 20 is uncommitted. On 2026-10-03 the operator tested
the bound book with the outline and the contents links and reported that it "looks great",
which closes the device checks in Phase 9 and its re-run. The index links in Phase 17 came
after that test, so they haven't been tried on the device.

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
- [x] Phase 9: Verify the acceptance bar on a full-length book: outline shape, identical
      `pdftotext -layout` before and after, and the Kindle Scribe check.
      *Outline shape and `pdftotext -layout` are done: three binds (default edition at 14pt
      and 17pt, reading edition at 14pt) match the binds from `main` on every line except
      the `Created:` stamp. The operator ran the device check on 2026-10-03.*

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
- [x] Re-run Phase 9's acceptance with the links in place: identical `pdftotext -layout`, and
      on the Scribe, a tapped contents entry jumps to its page.
      *`pdftotext -layout` is done: all three full binds still match `main` on every line
      except the `Created:` stamp. Every Contents and Figures row in them opens its page.
      Binds take 1 s longer than without the links (29 s, 20 s, 28 s) and about 17 KB bigger.
      The operator ran the device check on 2026-10-03.*

Added 2026-10-03, from the operator's answers at `/pr:close`'s triage. That close halted at
step 6b, and PR #63 stays open for its re-run:

- [x] Phase 16: Match each outline entry on the page it opens as well as its text. This is
      the close review's important finding: a body `h1` that shares the next chapter's
      title took that chapter's entry and the bind passed.
      *Done. `build_outline` takes the settled page map, and an entry counts only when its
      `/Dest` opens the page the binder found it on. A page either side doesn't know leaves
      the text to decide. The second bind in `fixtures/bind/run.sh` reproduces the case in
      chapter 1. A new check runs `build_outline` through the binder's own `render()` on two
      tiny pages and asserts both refusals, which closes the review's "no automated test"
      gap. A broken binder without the page check fails the tree.*
- [x] Phase 17: Link every page number in the index. The operator chose to do this on this
      branch rather than ticket it.
      *Done after rendering, in `link_pages`. A first version wrapped each number in an
      `<a>` to a marker URI. It worked, but it moved the page: splitting a number list into
      inline items rounds each one separately, so an entry of seven numbers measured 0.14px
      wider, and one entry's last number wrapped in the 14pt default edition. So the index
      HTML is now byte-identical to `main`. `link_pages` reads `pdftotext -raw -bbox` (raw,
      because reading order interleaves the two columns), matches words in order against
      the index's page references, and lays a `/Link` over each one. The bind fails if any
      reference isn't found. Results: 1612, 1096 and 1643 links in the three full binds,
      every one opening the page printed under it; `pdftotext -layout` identical to `main`.
      Two broken binders fail the fixture (no links, and links a page early). The cost is
      about 290 KB per book.*
- [x] Phase 18: Rewrite issue #62's body in generic terms, at the operator's request. It
      named another repository, a course code and a file path in that repository.
      *Done, and audited clean. GitHub keeps the old revision under the issue's "edited"
      menu until the operator deletes it.*
- [x] Phase 19: Never link a number inside an index term. This is the second close review's
      important finding, which the operator chose to fix at that close's triage. Matching
      one number at a time, a bare number in a term that equals the entry's next page
      number took that link.
      *Done. `link_pages` now takes an entry's numbers as the run that follows the last word
      of its term, read exactly as printed (`2,` then `3`). The bind fails, naming the
      entry, if any run isn't found. A new check in `bind/run.sh` renders "Top 2 lists
      2, 3" and "Week 4  4" through the binder's own `render()`. It asserts that every
      printed number has a link and neither term digit does, and the previous matcher fails
      it. The three full binds found every entry's run, still match `main` exactly, and
      every index link opens the page printed under it.*
- [x] Phase 20: Anchor an index entry's numbers on its whole term. The third close review
      (`pr-review-2026-10-03-3.md`, NEEDS_DISCUSSION) found that Phase 19's last-word anchor
      failed the bind whenever a curated term's last word wrapped at its hyphen, which is a
      regression from `main`. The operator chose the reviewer's fix.
      *Done as the reviewer proposed and tested it. The stripped, NFKC-normalized,
      casefolded text just before the run must end with the whole stripped term. A new
      `bind/run.sh` check renders "large language model pre-training" at 17pt through the
      real stylesheet and `build_index()`. It asserts the wrap, then the 4 links, then the
      refusal of numbers that never printed, which is the raise path's first test. Phase
      19's matcher fails it. The error message no longer doubles its commas. Four full
      binds were re-checked: each edition at 14pt and 17pt, including the curated reading
      edition at 17pt, which the reviewer noted had never been tried. All four match
      `main` exactly under `pdftotext -layout`, and every link opens its page (1612, 1096,
      1643 and 1068 index links).*

## Open Questions

- ~~Should the list of figures and the index's page numbers link too?~~ Answered by the
  operator on 2026-10-03: **figures yes, index skipped for now.** At the close's triage
  the same day, the operator chose to link the index on this branch after all (Phase 17).

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

From the close review (`pr-review-2026-10-03.md`, verdict APPROVE). The important finding,
the missing failure-path test and the index links were resolved in Phases 16 and 17. The
rest is parked for triage:

- With tagging on, `attach_scripts` replaces link annotations and orphans their structure
  references: 7 of the 10 `/OBJR`s in the save-scripts book. Keeping the annotation's
  object number would avoid it. Similarly, `link_pages` adds its index links without a
  `/StructParent`, so they aren't in the structure tree.
- The reading edition's endnotes heading (`h2`) appears as a "Notes" section under every
  chapter. `SKILL.md` doesn't mention it, and no test covers that edition's outline.
- From the second close review (`pr-review-2026-10-03-2.md`, APPROVE): `FOOTER_BAND_PT`
  restates `render()`'s 0.95in margin. The review's important finding, a number inside an
  index term taking a link, was fixed in Phase 19.
- `fixtures/bind/page-links.py` checks only the first page of the contents and of the list
  of figures. It reads the index to the end.
- A letter-labelled title such as "Appendix A: …" on Appendix 1 gets a second label.

- `.chapter .endnotes-title` (0,2,0) has always lost to `.chapter h2:not(.chapter-title)`
  (0,2,1). The reading edition's Notes heading therefore prints at the section-heading size,
  weight and margins, not the uppercase sans size its own rule asks for. Fixing it moves the
  layout, so it is out of scope here.
- Chromium drops the space where a heading wraps when it writes the heading's text into the
  outline. `build_outline` retitles every entry from the page's HTML to work around it. The
  same joined text may be in the structure tree's `/SE` elements, which a screen reader reads.
  This was not checked.
