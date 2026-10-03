# makebook: give the PDF a navigable outline, so a Kindle Scribe shows an expandable table of contents

Start date: 2026-10-02 18:33:56 MDT

A `/makebook` PDF has no outline, so a Kindle Scribe shows it without a navigable table of
contents. This branch renders the PDF with Chromium's outline and tagging turned on, and it
promotes chapter and section titles to `h1` so the outline nests by chapter without any change
to layout. The build also fails or warns when the outline comes back empty or short.

## Changes

### 2026-10-02

- **The operator settled the shape.** Each chapter and appendix is a collapsed top-level
  entry that opens its chapter and expands to that chapter's sections, and no deeper. It
  reads `Chapter N: Title` or `Appendix N: Title`. The cover, contents, About This Book,
  figures, glossary and index are top-level entries. Chapters nest under their parts when
  `book.json` declares `sections`. A short outline fails the bind. The EPUB is unchanged.
- **Titles are `h1`, and nothing moves.** The five `section-title` headings and
  `chapter-title` went from `h2` to `h1`. Both rules already set every property the UA styles
  differently between the two levels. `.chapter h2:not(.chapter-title)` stays as written: its
  0,2,1 specificity is what styles the reading edition's Notes heading. Three binds
  (default edition at 14pt and 17pt, reading edition at 14pt) give the same
  `pdftotext -layout` as `main` on every line except the `Created:` stamp.
- **`build_outline` relinks Chromium's own entries instead of writing new ones.** That
  keeps each entry's `/Dest` and the `/SE` that ties it to its heading in the structure tree.
  It also leaves no `/Count` on a leaf, which is the form a Scribe was seen to open, and leaves
  nothing unreferenced except the dropped subsections. A first version rebuilt the outline
  with pypdf's `add_outline_item`. That wrote `/GoTo` actions, `/Count 0` on leaves and no
  `/SE`, and left every one of Chromium's entries in the file unreferenced.
- **Chromium joins the words either side of a wrap.** A heading set across two lines reaches
  the outline as "The DataModel". That broke the first full-book bind, because the matching
  compared text. Entries are now matched with their whitespace removed, and every kept entry
  is retitled from its heading's text in the page HTML. A title that can't be matched keeps
  Chromium's text, and the bind warns about it.
- **A body `h1` is filed under its chapter.** Any `# ` line after a chapter's title renders
  as an `h1`, which Chromium makes a top-level entry. It goes under the chapter as one of its
  sections.
- **Cost of `tagged=True`:** about +50% file size (3.34 MB to 5.01 MB on a 338-page book)
  and 1 to 2 s per bind.
- **`fixtures/bind/run.sh` compares the whole outline tree on both of its guide binds.** The
  second bind now also declares parts and appends a stray, wrapping `h1` to chapter 2.
  Checked against three broken binders (no retitle, no depth pruning, no `tagged`): each
  fails its assertion. bookcraft 1.9.0 to 1.10.0.
