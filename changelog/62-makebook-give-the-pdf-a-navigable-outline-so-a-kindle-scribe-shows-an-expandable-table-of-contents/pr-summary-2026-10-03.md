# makebook: give the PDF a navigable outline, so a Kindle Scribe shows an expandable table of contents

## Overview

A PDF bound by `/bookcraft:makebook` had no outline and no internal links. On a Kindle Scribe
the only way to reach a chapter was to page through the book or to read the printed contents
and page to the number. This branch adds two things:

- **An outline.** The Scribe shows it as an expandable table of contents. Each chapter and
  appendix is a collapsed top-level entry that opens its chapter and expands to that
  chapter's sections. The cover, Contents, About This Book, Figures, Glossary and Index are
  top-level entries too. Chapters nest under their parts when `book.json` declares
  `sections`. A bind whose outline comes back short or empty fails.
- **Links on every listing.** Each row on the contents page and in the list of figures, and
  each page number in the index, links to the page it names.

Neither feature moves anything on the page. Four full-length binds give the same
`pdftotext -layout` output as the same books bound from `main`, on every line except the
`Created:` stamp. They cover each edition at 14pt and 17pt, and one of them has a curated
`terms.txt`.

The operator tested the outline and the contents links on the device, and reported that it
"looks great". The index links came later, at the close's triage, and haven't been tried on
the device.

## Key changes

### `plugins/bookcraft/skills/makebook/scripts/build-book.py`

- **The render flags.** `render()` passes `outline=True, tagged=True` to `page.pdf()`.
  Chromium builds the outline from the structure tree, so `outline` alone writes none.
- **Titles become `h1`.** Every page title (`section-title`) and every chapter title is now
  an `h1`, not an `h2`, so the outline nests by chapter. The stylesheet already sets every
  property the UA styles differently between the two levels. `.chapter h2:not(.chapter-title)`
  stays as written, because its specificity is what styles the reading edition's Notes
  heading.
- **`build_outline()`, new.** It reshapes Chromium's outline after the last render:
  - Depth stops at a chapter's sections.
  - Titles are retaken from the page's own heading text, because Chromium drops the space
    wherever a heading wraps.
  - Chapter entries get their `Chapter N:` and `Appendix N:` labels.
  - Chapters nest under their parts, and stray body `h1`s are filed under their chapter.
  - Every expected entry has to match on its text and on the page the binder settled for
    it. Otherwise the bind fails.
- **The listing links.**
  - Each page section and each `<figure>` gets a prefixed `id` (`chapter_id`, `figure_id`).
  - Each contents and list-of-figures row carries an empty anchor laid over the row
    (`toc_link`, `.toc-link`).
  - **`link_pages()`, new**, adds the index's links after rendering. It finds each number
    with `pdftotext -raw -bbox`, taking an entry's numbers as the run its whole term comes
    just before, compared on letters and digits only, and lays a `/Link` over each one. The index's HTML is unchanged from
    `main`.
- **`build_front_matter()`** returns `(title, html)`, so the outline can tell that page's
  `h1` apart from one in its body.
- **Reporting.** The bind prints one line on the outline. It warns about any outline entry
  it couldn't retitle, and says that each index page reference is a link.

### Tests

- **`fixtures/bind/run.sh`**:
  - Compares the whole outline tree on both of its guide binds.
  - Checks every link on the Contents, Figures and Index pages, and holds the index's link
    count to the bind's own count of page references.
  - Tests `build_outline`'s two refusals through the binder's own `render()`.
  - Its second bind also declares parts, appends a wrapping stray `h1` to chapter 2, and ends
    chapter 1 with an `h1` that repeats chapter 2's title.
- **`fixtures/bind/page-links.py`, new.** Each Contents and Figures row's printed number must
  equal the page its link opens. Each index link must open the number printed under its own
  rectangle.
- **`fixtures/save-scripts/run.sh`** runs the same check on its Contents links after
  `attach_scripts` has rewritten that book's annotations.

### Docs and version

- **`makebook/SKILL.md`** has two new sections, The outline and The linked contents, and a
  Navigation row in the PDF and EPUB table. The README has a paragraph on both.
- **`plugin.json`**: bookcraft goes from 1.9.0 to 1.10.0.

## Code examples

`build-book.py`, `build_outline()`. An entry counts only if its text matches and it opens
the page the binder settled for it:

```python
for ref in tops:
    want = expected[len(found)] if len(found) < len(expected) else None
    # A page either side doesn't know leaves the text to decide alone.
    page = opens(ref)
    if (want and key(title_of(ref)) == key(want[0])
            and (want[2] is None or page is None or page == want[2])):
        found.append((want[1], ref, children(ref)))
    elif found:
        found[-1][2].append(ref)
```

`build-book.py`, `link_pages()`. An entry's numbers are the run of printed words, read in
content-stream order, that its whole term comes just before. The term is compared on its
letters and digits only, so a digit inside it is never taken for a page number, and a line
break after a hyphen doesn't matter:

```python
for display, pgs in entries:
    run = [f"{p}," for p in pgs[:-1]] + [str(pgs[-1])]
    term = bare(display)
    for k in range(max(at, 1), len(words) - len(run) + 1):
        if [w[6] for w in words[k:k + len(run)]] != run:
            continue
        tail, j = "", k
        while j > at and len(tail) < len(term):
            j -= 1
            tail = bare(words[j][6]) + tail
        if tail.endswith(term):
            break
    else:
        raise RuntimeError(f"the page numbers of {display!r} (...) were not found after its term")
```

`build-book.py`, a contents row's link. The row stays a `div`, and its spans stay its flex
items:

```css
.toc-row { ...; position: relative; }
.toc-link { position: absolute; inset: 0; }
```

## Plan alignment

All twenty phases in `PLAN.md` are complete. These are the operator's decisions:

- **Depth:** sections only.
- **Labels:** `Chapter N: Title` and `Appendix N: Title`.
- **A short outline:** fails the bind.
- **The EPUB:** unchanged, since its nav already nests by `sections`.
- **Parts:** the PDF outline nests chapters under them.
- **Linking the list of figures:** yes.
- **The index:** first deferred, then built on this branch at the close's triage.

On 2026-10-03 the operator also amended the ticket to add the linked contents. `PLAN.md`
records that as a dated amendment and leaves the original objective as written.

**The first close halted at triage, on the operator's choices.** The review's important
finding was fixed then, the index was linked on this branch, and the ticket's GitHub body
was restated in generic terms. **The second close halted at triage too:** its review's
important finding, a number inside an index term taking a link, was fixed then. **The third
close stopped at its review**, which found that the fix anchored on a term's last word and
so failed a bind when that word wrapped at a hyphen. The operator chose the reviewer's
whole-term anchor. **The fourth stopped at its review too:** the new check's single term
didn't wrap on Linux fonts, so it became a font-independent sweep.

### Deviations and discoveries

- **Chromium joins words across a wrap** in the outline entries it writes. Every entry is
  retitled from the page's own heading text.
- **The outline is relinked, not rebuilt.** A first version rebuilt it with pypdf, which
  wrote `/GoTo` actions, dropped `/SE` and left Chromium's entries orphaned.
- **Matching on text alone misfiled one case.** A chapter body's `h1` that shares the next
  chapter's title took that chapter's entry, and the bind passed. The close review found it
  and reproduced it, and the page check stops it.
- **The contents link is an empty anchor over the row**, because both ways of wrapping the
  row in an `<a>` move the page.
- **The index links are laid on after rendering.** Wrapping each number in an `<a>` worked
  but moved the page: per-item rounding made an entry 0.14px wider, and one number wrapped
  in a full-length book. `pdftotext`'s reading order interleaves the two columns, so the
  numbers are read in raw, content-stream order.

## Testing

### Automated

- **The fixture suite:** `plugins/bookcraft/scripts/test-fixtures.sh` passes 18, fails 0,
  skips 0.
- **`bind/run.sh` checks:**
  - **The whole outline tree on both guide binds.** This covers collapsed and expanded
    state, the dropped `###` headings, part nesting, both stray `h1`s (one wrapping, one
    repeating the next chapter's title) and the retitled wrap.
  - **Every listing link,** with the index's link count held to the bind's own count.
  - **Both refusals**, with their messages.
  - **No number inside an index term gets a link**, checked on "Top 2 lists  2, 3" and
    "Week 4  4" through the binder's own `render()`.
  - **A curated term that wraps at its hyphen still links at 17pt**, using the real
    stylesheet and `build_index()`. It runs as a sweep of eight entries, each one word
    longer, so that one of them wraps on any font: a single term that wrapped on macOS
    didn't on the Linux runner. The check asserts a wrap first. It also checks that
    numbers which never printed, or which printed against a different term, fail the bind.
- **`save-scripts/run.sh`** checks the Contents links after the attachments.
- **Twelve deliberately broken binders were run against the fixtures, and each failed them:**
  - no retitle
  - no depth pruning
  - no `tagged=True` (the bind refuses)
  - no contents links
  - contents rows aimed at the next chapter
  - no page check
  - the index linked through inline anchors that never get rewritten
  - inline-anchor index links a page early
  - no `link_pages`
  - `link_pages` links a page early
  - `link_pages` matching each number on its own, as before the second review's fix
  - `link_pages` anchoring on a term's last word, as before the third review's fix

### By hand

- The four full-length binds above, compared with `main` under `pdftotext -layout`.
- Every link in them was checked: 1612, 1096, 1643 and 1068 index links, plus every
  Contents and Figures row. The 1068 are curated terms at 17pt.
- The operator's device test.

To check by hand: bind any book and open the PDF in Preview. ⌥⌘3 shows the outline in the
sidebar. Chapters start collapsed and expand to their sections. Clicking a contents row or
an index number jumps to its page.

### Edge cases considered

- A heading that wraps.
- A title that already starts with its label.
- A body `h1`, including one that repeats the next chapter's title.
- Parts, and an appendix outside them.
- Figures above the parts on the contents page.
- An index of two columns spanning pages, and an empty index.
- Digits inside an index term, including one that equals the entry's own page number.
- A curated index term that wraps at its hyphen, at 17pt.
- The running footer's page number on index pages.
- No outline at all, and a short outline.
- Links surviving every pypdf rewrite.

## Impact assessment

- **Size of the change:** at `ef3347d`, before the close's own artifacts, 14 files changed,
  2299 insertions and 44 deletions, 867 of them
  outside `changelog/`. `build-book.py` gains 376 lines net (407 added, 31 removed). Most of the rest is
  fixtures and documentation.
- **Dependencies:** none new. The `page.pdf()` flags need Playwright 1.42 or later, and
  `requirements.txt` already asks for 1.44. `pdftotext` was already required.
- **Cost:** file size grows by about 59% (3.34 MB to 5.32 MB on a 338-page book). About 50%
  comes from the structure tree, which also makes the PDF readable by screen readers, and
  about 290 KB from 1612 index links. Binds take 3 to 4 s longer.
- **Breaking for an operator:** a bind whose outline comes back short, or whose index page
  numbers can't all be found, now fails where it used to succeed. Inside the script,
  `build_front_matter()` returns a tuple; its one caller is updated.
- **Assertions:** disabled for this repo (`docs.assertionsFile` is `null`).

## Deferred work

These are recorded under `## Deferred` in `PLAN.md`:

- **Tagging consistency.** With tagging on, `attach_scripts` replaces link annotations and
  orphans their structure references. `link_pages` adds its links without a
  `/StructParent`, so a screen reader's structure tree doesn't include them.
- **The reading edition's endnotes heading** appears as a "Notes" section under every
  chapter. That's undocumented and untested.
- **`page-links.py` reads only the first page** of the contents and of the list of figures.
- **A letter-labelled appendix title**, such as "Appendix A: …", gets a second label.
- **The reading edition's Notes heading has always printed in the section-heading style.**
  Fixing that would move the layout.
- **The structure tree's own text wasn't checked** for words joined at a wrap.
