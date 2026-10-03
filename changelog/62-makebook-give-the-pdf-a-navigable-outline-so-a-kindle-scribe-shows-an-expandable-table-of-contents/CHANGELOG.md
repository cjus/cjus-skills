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

- **The operator amended the ticket to add a linked contents page.** The list of figures
  links too, and the index waits.
- **Prefixed `id`s on every page and figure** (`mb-ch-N`, `mb-fig-NNN`, `mb-glossary`).
  Each contents and list-of-figures row links to its target through an empty anchor laid
  over the row. Making the row an `<a>` would move the first part heading after a Figures
  row, through `.toc-group:first-of-type`. Wrapping the spans would break their flex sizing.
- **Checked:** the full binds still match `main`, and every row's link opens the page it
  prints, through `attach_scripts` too. `fixtures/bind/contents-links.py` holds the check,
  and two broken binders fail it. Its first version misread a caption ending in "week 3"
  as a row number.
- **The operator tested the bound book on the device** and reported that it looks great.
  The close review approved, with one important finding: an in-chapter `#` heading that
  matches the next chapter's title takes that chapter's outline entry.
- **The close halted at triage, on the operator's choices.** The misfile was fixed now,
  the index was linked on this branch, and issue #62's body was restated in generic terms.
- **Outline entries match on their page too.** `build_outline` takes the settled page map,
  so a body `h1` that repeats the next chapter's title is filed as a section. A new
  fixture check exercises both of the bind's refusals through the binder's own `render()`.
- **The index links each page number, laid on after rendering.** Wrapping the numbers in
  `<a>` worked, but it moved the page: per-item rounding made an entry 0.14px wider, and
  one number wrapped in a full book. The index HTML is now `main`'s. `link_pages` finds
  each number with `pdftotext -raw -bbox`, matched in order against the index's page
  references. Raw order is used because reading order interleaves the columns. The full
  binds match `main` exactly, and all 1612, 1096 and 1643 index links open the page printed
  under them. `fixtures/bind/contents-links.py` became `page-links.py` and checks the index
  by cropping to each link's rectangle.
