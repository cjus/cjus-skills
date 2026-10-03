# makebook: give the PDF a navigable outline, so a Kindle Scribe shows an expandable table of contents

Start date: 2026-10-02 18:33:56 MDT

A `/makebook` PDF had no outline and no internal links, so a Kindle Scribe showed it without
a navigable table of contents. This branch renders the PDF with Chromium's outline and
tagging turned on. Page and chapter titles are promoted to `h1`, so the outline nests by
chapter without any change to layout. The bind fails when the outline comes back short.
Every row on the contents page and the list of figures now links to its page.

## Changes

### 2026-10-02

- **The outline's shape, as the operator decided it.** Chapters and appendices are
  collapsed top-level entries, labelled `Chapter N: Title`, that expand to their sections
  and no further. The cover, Contents, About This Book, Figures, Glossary and Index are
  top-level too. Chapters nest under parts when `book.json` declares `sections`. A short
  outline fails the bind, and the EPUB is unchanged.
- **Titles moved from `h2` to `h1` with no layout change.** Both title rules already set
  every property the UA styles differently. `.chapter h2:not(.chapter-title)` is kept for its
  specificity, which styles the reading edition's Notes heading. Three full binds match
  `main` under `pdftotext -layout`, except for the `Created:` stamp.
- **`build_outline` relinks Chromium's own entries.** That keeps `/Dest` and `/SE` and
  writes no `/Count` on leaves. A first attempt rebuilt the outline with pypdf instead, and
  it wrote `/GoTo` actions, dropped `/SE`, and left orphaned objects.
- **Chromium drops the space where a heading wraps.** That broke the first full bind.
  Entries are now matched with their whitespace removed and retitled from the page's
  heading text, and the bind warns about any entry it can't retitle.
- **A body `h1` is filed under its chapter** as one of its sections.
- **Cost:** about +50% file size and 1 to 2 s per bind. The fixtures compare the whole
  outline tree, including parts and a stray wrapping `h1`. Three broken binders fail them.
  bookcraft goes from 1.9.0 to 1.10.0.

### 2026-10-03

- **The ticket gained linked listings.** Each contents and list-of-figures row links through
  an empty anchor laid over the row, aimed at prefixed `id`s (`mb-ch-N`, `mb-fig-NNN`).
  Making the row an `<a>`, or wrapping its spans in one, would have moved the page.
- **The operator tested the outline and the contents links on the device** and reported
  that it looks great.
- **Four close rounds, each stopped by a finding and fixed at the operator's choice:**
  - **Outline entries match on their settled page as well as their text.** A body `h1`
    repeating the next chapter's title had taken that chapter's entry.
  - **The index links every page number, laid on after rendering.** `link_pages` uses
    `pdftotext -raw -bbox`, because inline anchors rounded an entry 0.14px wider and
    wrapped a number. Issue #62's body was also restated in generic terms.
  - **An entry's numbers are anchored on its whole term, stripped to letters and digits.**
    Matched one number at a time, a term's digit could take a link. Anchored on the last
    word, a term that wrapped at its hyphen failed the bind.
  - **The 17pt wrap check slides the hyphen across eight entries**, so it wraps on any
    font. A single term had not wrapped on the Linux runner.
- **Checked:** four full binds, each edition at 14pt and 17pt, match `main` exactly. Every
  Contents, Figures and Index link opens the page printed under it. The fixture suite passes
  18/0/0, and CI passes on both legs at `ef3347d`. Each fix has a check that its
  predecessor fails. The fifth close review approved.
