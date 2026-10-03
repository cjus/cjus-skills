# makebook: give the PDF a navigable outline, so a Kindle Scribe shows an expandable table of contents

## Overview

A PDF bound by `/bookcraft:makebook` had no outline and no internal links. On a Kindle Scribe
the only way to reach a chapter was to page through the book or read the printed contents
and page to the number. This branch adds two things.

- **An outline.** The Scribe shows it as an expandable table of contents. Each chapter and
  appendix is a collapsed top-level entry that opens its chapter and expands to that
  chapter's sections. The cover, Contents, About This Book, Figures, Glossary and Index are
  top-level entries too. Chapters nest under their parts when `book.json` declares
  `sections`. A bind whose outline comes back short or empty fails.
- **A linked contents page and list of figures.** Each row is a link that opens the page it
  names.

Neither change moves anything on the page. Three full-length binds (the default edition at
14pt and 17pt, the reading edition at 14pt) give the same `pdftotext -layout` output as the
same books bound from `main`, on every line except the `Created:` stamp. The operator tested
the result on the device and reported that it looks great.

## Key changes

- **`plugins/bookcraft/skills/makebook/scripts/build-book.py`**
  - `render()` passes `outline=True, tagged=True` to `page.pdf()`. Chromium builds the
    outline from the structure tree, so `outline` alone writes none at all.
  - Every page title (`section-title`) and every chapter title is now an `h1` instead of an
    `h2`, so the outline nests by chapter. The stylesheet already set every property the UA
    styles differently for the two levels. `.chapter h2:not(.chapter-title)` stays as
    written, because its specificity is what styles the reading edition's Notes heading.
  - New `build_outline()` reshapes Chromium's outline after the last render. It sits beside
    `attach_scripts()`, the other step that rewrites the finished PDF.
  - Each page section and each `<figure>` has a prefixed `id` (`chapter_id`, `figure_id`).
    Each contents and list-of-figures row carries a link (`toc_link`, `.toc-link`).
  - `build_front_matter()` returns `(title, html)`, so the outline can tell that page's `h1`
    apart from one in its body.
  - The bind reports one line on the outline, and warns about any entry it couldn't
    retitle.
- **`fixtures/bind/run.sh`** compares the whole outline tree and every listing link on both
  of its guide binds. The second bind now also declares parts and appends a stray, wrapping
  `h1` to chapter 2.
- **`fixtures/bind/contents-links.py`** (new) holds the link check. For each listing, the
  page numbers its rows print must equal the pages their links open.
- **`fixtures/save-scripts/run.sh`** runs the same link check after `attach_scripts` has
  rewritten that book's link annotations.
- **`makebook/SKILL.md`** has two new sections, The outline and The linked contents, and a
  Navigation row in the PDF and EPUB table. The README has a paragraph on both.
- **`plugin.json`**: bookcraft 1.9.0 to 1.10.0.

## Code examples

`build-book.py`, `build_outline()`. Chromium's own outline entries are relinked rather than
rewritten, so each keeps its `/Dest` and the `/SE` that ties it to its heading in the
structure tree:

```python
for ch, ref, kids in found:
    for kid in kids:
        link(kid, [])          # a section keeps no children: depth stops here
        retitle(kid)
    link(ref, kids, -len(kids))  # negative /Count: collapsed
    ...
    if ch:
        retitle(ref, f'{"Appendix" if ch.get("appendix") else "Chapter"} '
                     f'{ch.get("label_num", ch["num"])}')
```

`build-book.py`, retitling. Chromium drops the space where a heading wraps, so an entry is
matched with its whitespace removed and then retitled from the heading's text in the page:

```python
def key(text: str) -> str:
    return "".join(text.split()).casefold()

for m in HEADING_RE.finditer(html_text):
    text = " ".join(html_mod.unescape(TAG_RE.sub("", m.group(2))).split())
    heading_text.setdefault(key(text), text)
```

`build-book.py`, the contents link. The row stays a `div` and its spans stay its flex items:

```css
.toc-row { ...; position: relative; }
.toc-link { position: absolute; inset: 0; }
```

```python
f'<span class="toc-page">{pg}</span>'
f'{toc_link(chapter_id(ch["num"]))}</div>'
```

## Plan alignment

All fifteen phases in `PLAN.md` are complete, including the two device checks the operator
ran.

The operator decided every open question:

- **Depth:** sections only.
- **Labels:** `Chapter N: Title` and `Appendix N: Title`.
- **Short outline:** fail the bind.
- **EPUB:** unchanged, since its nav document already nests by `sections`.
- **Parts:** the PDF outline nests chapters under them.
- **Figures and index:** the list of figures links, and the index waits.

On 2026-10-03 the operator updated the ticket to add the linked contents. That was recorded
in `PLAN.md` as a dated amendment, and the original objective was left as written.

Deviations and discoveries along the way:

- **Chromium joins words across a wrap.** A heading set across two lines reached the outline
  as one word at the break. The first full-book bind failed on it, and the same joined text
  would have shown on the Scribe. Every entry is now retitled from the page's own heading
  text.
- **The outline is relinked, not rebuilt.** The first version rebuilt it with pypdf's
  `add_outline_item`. That wrote `/GoTo` actions and `/Count 0` on leaves, dropped `/SE`,
  and left all of Chromium's entries in the file unreferenced. Relinking keeps the form a
  Scribe was seen to open.
- **A chapter body can render an `h1`.** Any `# ` line after the title does. Phase 3 found
  this, so `build_outline` files such a heading under its chapter, and a fixture covers the
  case.
- **The link is an empty anchor over the row.** The ticket proposed wrapping the row in an
  `<a>`, but both ways of doing that move the page. A row that is itself an `<a>` hands
  `.toc-group:first-of-type`, which counts element type, to the first part heading after a
  Figures row. An `<a>` around the spans takes their flex sizing. A probe confirmed first
  that Chromium writes an empty anchor as a full-row link.

## Testing

Automated:

- **The whole fixture suite passes** (`plugins/bookcraft/scripts/test-fixtures.sh`, 18
  passed, 0 failed, 0 skipped).
- **`bind/run.sh` compares the whole outline tree** of both guide binds against an expected
  tree. Collapsed and expanded state, the dropped `###` headings, the part nesting, the
  folded stray `h1` and its retitled wrap are all part of the comparison.
- **Every Contents and Figures row is checked against the page it prints.** `bind/run.sh`
  checks both binds, and `save-scripts/run.sh` checks its book after the attachments.
- **Five deliberately broken binders were run against the fixtures, and each failed them:**
  - no retitle
  - no depth pruning
  - no `tagged=True`, which the bind itself refuses
  - no links
  - each contents row aimed at the next chapter

By hand:

- **Layout:** the three full-length binds above compared with `main` under
  `pdftotext -layout`.
- **Outline:** each book's outline dumped and read, and every listing link resolved.
- **Device:** the operator sent the 338-page book with both features to the Kindle Scribe.

To check by hand, bind any book and open the PDF in Preview, where ⌥⌘3 shows the outline in
the sidebar. Chapters start collapsed and expand to their sections, and clicking a contents
row jumps to its page.

Edge cases considered:

- a heading that wraps
- a title that already starts with its label (the guide fixture's appendix)
- an `h1` in a chapter's body
- parts, and an appendix outside them
- figures listed above the parts on the contents page
- no outline at all
- a short outline
- links surviving both pypdf rewrites

## Impact assessment

- 9 files changed, 858 insertions, 39 deletions. About 300 of the added lines are in
  `build-book.py`, and most of the rest is fixtures and documentation.
- No new dependency. The `page.pdf()` flags need Playwright 1.42 or later, and
  `requirements.txt` already asks for 1.44.
- **Cost:** about 50% more file size, from the structure tree (3.34 MB to 5.03 MB on a
  338-page book), and 2 to 3 s more per bind. The structure tree also makes the PDF
  readable by screen readers.
- **Breaking for an operator:** a bind whose outline comes back short now fails where it
  used to succeed. Inside the script, `build_front_matter()` returns a tuple; its one caller
  is updated.
- Assertions: disabled for this repo (`docs.assertionsFile` is `null`).

## Deferred work

These are recorded under `## Deferred` in `PLAN.md`.

- **Linking the index's page numbers.** The operator skipped this for now. Nothing in a
  flowing document marks the top of a page, so it would need a step after rendering that
  lays a link annotation over each number.
- **The reading edition's Notes heading.** It has always printed in the section-heading
  style. Its own rule loses on specificity, and correcting that would move the layout.
- **The structure tree's own text was not checked.** It may carry the same joined words at
  a wrap that the outline did before retitling.
