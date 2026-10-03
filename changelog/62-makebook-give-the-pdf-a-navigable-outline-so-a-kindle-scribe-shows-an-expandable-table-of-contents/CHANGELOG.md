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

- **The ticket gained linked listings.** The operator amended it to add a linked contents
  page. Each contents and list-of-figures row now links through an empty anchor laid over
  the row, aimed at prefixed `id`s (`mb-ch-N`, `mb-fig-NNN`). Making the row an `<a>`, or
  wrapping its spans in one, would have moved the page.
- **The operator tested the outline and the contents links on the device**, and reported
  that it looks great.
- **The first close halted at triage, on the operator's choices:**
  - The review's misfile was fixed. Outline entries now match on their settled page as well
    as their text, and a fixture check exercises both of the bind's refusals.
  - The index was linked on this branch. That is done after rendering (`link_pages`, with
    `pdftotext -raw -bbox`), because inline anchors rounded an entry 0.14px wider and wrapped
    a number.
  - Issue #62's body was restated in generic terms.
- **Checked:** the full binds match `main` exactly, and every Contents, Figures and Index
  link opens the page printed under it, including 1612, 1096 and 1643 index links.
  `fixtures/bind/page-links.py` holds the check, and broken binders fail it.
- **The second close review approved.** It found that a bare number in a term which equals
  the entry's next page number takes that link. The docs now say so, and the case is under
  Deferred.
- **The second close halted at triage, and the index-term finding was fixed.**
  `link_pages` takes an entry's numbers as the run that follows its term's last word, so a
  number inside a term is never linked. The bind fails, naming the entry, when a run isn't
  found. A new check covers "Top 2 lists  2, 3", and the per-number matcher fails it.
- **The third close stopped at its review (NEEDS_DISCUSSION).** Anchoring on a term's last
  word failed a bind when a curated term wrapped at its hyphen, a regression from `main`.
  `link_pages` now anchors on the whole term, stripped to letters and digits. A 17pt check
  with a wrapping hyphenated term, which also covers the refusal path, fails the last-word
  matcher.
- **The fourth close stopped at its review (NEEDS_DISCUSSION).** The 17pt check's term
  didn't wrap on the Linux runner, so CI failed 17/1/0 there while the binder itself was
  fine. The check now slides the hyphen across the line end over eight entries and requires
  a wrap and all 16 links. It also gained a refusal for a term that doesn't match.
