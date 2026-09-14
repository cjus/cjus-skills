---
name: makebook
description: Bind a folder of markdown files into an ebook-style PDF and a matching EPUB, with a cover, a contents page, one chapter per file in filename sort order, hand-authored SVG figures placed where a concept needs one, and a back-of-book index. Takes a quoted book title and a folder; the PDF is set in 14pt unless another paragraph size from 11.8 to 17 is asked for. Use when asked to turn a set of notes, lessons, or narrations into a single readable book, PDF, large-print PDF, compact PDF, or Kindle-ready ebook.
license: Inherits repository license unless otherwise specified
---

# Make Book

Turn a folder of markdown files into one bound book, in two formats: a PDF that reads like a printed book, and an EPUB that reads like an ebook.

## When to Use

- A set of related markdown files should become a single document someone reads front to back
- A course's lessons, a series of notes, or a set of narrations needs a cover, a contents page, and an index
- You need page references that are actually correct, rather than a contents page nobody checked
- Someone wants to read it on a Kindle or another e-reader

Reach for `/make-pdf` instead when the job is one markdown file rendered faithfully. This skill is for many files bound together.

## Invocation

```
/makebook "Book Title" path/to/folder
```

Two arguments: the title in quotes, and the folder holding the markdown files. Run it as:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/bookcraft-python \
  ${CLAUDE_PLUGIN_ROOT}/skills/makebook/scripts/build-book.py \
  "Book Title" path/to/folder
```

Both files land in that folder, named from the title: `<title-slug>.pdf` and `<title-slug>.epub`. `--out path/to/book.pdf` puts them elsewhere; the EPUB follows the PDF, taking the same path with an `.epub` suffix.

The PDF is set at **14pt**. Add `--type-size 17` for large print or `--type-size 11.8` for the compact edition, or any size between. See **Type size**.

**Every run writes both formats. There is no flag to pick one**, because a book that is worth binding is worth having in both, and a flag is one more thing to remember at the moment you least want to.

## Setup (one-time)

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/install.sh
```

That builds the venv, installs the packages `requirements.txt` names, and fetches Chromium for Playwright. Re-running it is safe.

**Python 3.12 or newer is required**, and the script refuses anything older rather than letting you find out later. `build-book.py` uses nested same-quote f-strings (PEP 701), so an older interpreter fails while *parsing* the file, long before it could report a missing package. macOS ships 3.9 at `/usr/bin/python3`; `brew install python@3.12` or later covers it.

The venv lands at `~/.cache/bookcraft/venv` (or under `$XDG_CACHE_HOME`), **outside** the plugin. Claude Code installs every plugin version into its own directory, so a venv kept inside one would be thrown away on each update and rebuilt from nothing. One venv at a stable path serves every version instead. `bookcraft-python` is the wrapper that finds it, which is why the commands here name it rather than an interpreter.

Chromium comes from Playwright's cache at `~/Library/Caches/ms-playwright/`, so an already-populated cache skips that download.

`pdftotext` (poppler) must be on PATH; the script reads the rendered PDF back to resolve page numbers. `brew install poppler` covers it.

To check the EPUB rather than trust it, install the reference validator: `brew install epubcheck`. It is not needed to build one, only to verify it, and it is the fastest way to catch a package that a device would reject.

```bash
epubcheck path/to/book.epub
```

## Procedure

Running the script is the last step, not the first. A makebook run is:

1. **Read every chapter in full.** Not the titles, not the first paragraph. The figure decisions in step 3 are made against the argument each chapter actually makes, and a title cannot tell you that.
2. **Set up the folder:** a `book.json` if the book wants a subtitle, cover text, or section groupings; a `terms.txt` if the index should be curated (see **The index**).
3. **Decide where a figure would help, and where it would not.** This is the step that makes the result a book rather than a concatenation, and it is a judgment about the material. See **Deciding where a figure helps** below. Write the decisions down.
4. **Author the figures** you decided on, against `references/diagram-style.md`, and place each one in its chapter.
5. **Build**, read the report, and **look at the pages that carry figures** in the finished PDF. A figure that renders wrong fails silently.
6. **Run `epubcheck` on the EPUB** if it is installed. A package a device would reject is not visible from the report.
7. Report: page count, figure count and where they went, the index source, anything the legibility check flagged, and the EPUB's validation result.

## Deciding where a figure helps

**The goal is not a figure per chapter.** It is a figure wherever a reader would otherwise have to hold a shape in their head, and nowhere else. Most chapters do not need one. A book with six well-placed figures reads better than one with eighteen dutiful ones, because each figure then means "stop and look at this".

Go through the chapters one at a time. For each, write a single line naming the idea that is hardest to carry in prose, and answer whether a picture would carry it better. The honest answer is usually no.

**A figure earns its place when the idea has a shape prose cannot hold:**

| The idea is... | Example |
|---|---|
| Structural | A schema, a tree, a layout on disk, a set of tables and the lines between them |
| A comparison with two sides | Before and after, with and without, the naive way beside the correct way |
| A timeline | Events whose order is the whole point, such as a leak that depends on what was known when |
| A quantity that grows with scale | A measured cost the reader needs to see curve, not read as three numbers |
| Something the prose already asks the reader to picture | "Imagine two connections open on the same file" is a figure the text is drawing in words |

**A figure does not earn its place when:**

- The idea is a definition, a distinction, or a line of argument. Prose carries those better, and a box around a sentence adds nothing.
- The figure would restate a table or list already in the text.
- The flow is linear with no branching. A sentence with three arrows in it is not a diagram.
- It would decorate a chapter opening. Figures go after the paragraph that states what they show, never before it and never at the head of a chapter.
- The chapter is the odd one out and a figure would only be there to keep the count even.

**Every fact drawn in a figure is checked the way a fact in prose is.** A figure that shows a command's output shows real output. A figure that plots a cost plots measured numbers, and the caption says where they came from. A diagram is the part of the page a reader trusts most and reads fastest, which makes a wrong one the most expensive error in the book.

**Record the decisions** in `<folder>/diagrams/README.md`: each figure with its chapter and the one sentence saying why, and the chapters considered and passed over with the one sentence saying why not. That file is how the next person knows the selection was deliberate.

**Placing a figure:** save it as `<folder>/diagrams/<slug>.svg` and put `![](diagrams/<slug>.svg)` on its own line after the anchoring paragraph. Leave the alt text empty so the caption comes from the SVG's `<title>`, which keeps one source of truth. Inline SVG in the markdown is also supported, but a referenced file keeps the prose readable and lets one figure serve more than one document.

## What the PDF builds

| Page | Content |
|---|---|
| 1 | Cover: title, optional subtitle and byline, a description, an optional footnote. It has to fit on one page, and the build warns when it does not |
| 2 | Contents, every chapter with its page, optionally grouped under section headings |
| 3 | About this book, when the folder holds `about-this-book.md`. What the book is for, what it was built from, what it fills in, what it does not cover |
| 3 | Figures, listing every figure with its page. Appears only when the book has figures |
| Then | The chapters, each opening on a fresh page |
| Then | Glossary, one column, each term with the chapter that defines it. Appears only when the folder holds a `glossary.md` |
| Last | Index, two columns, terms with the pages they appear on |

**`about-this-book.md` is front matter, never a chapter**, and both this tool and `check-book.sh` skip it by name whether or not `exclude` mentions it. `book.json`'s `front_matter_file` renames it, and both tools read that same key so neither can disagree about which file is a chapter. It carries no paragraph tags and gets no contents entry: a reader reaches it by turning the page from the listing, and the page it would list is the next one.

**Provenance marks are stripped before anything renders.** A line reading `<!-- src: ... -->` records where a unit of a chapter came from, for `check-book.sh` and `/updatebook`. Two reasons it is removed rather than left to be an invisible comment: markdown-it passes an HTML comment straight into the output, so it would ship inside the PDF's and the EPUB's markup, and `strip_markdown` does not remove comments, so every source name inside one would reach the term harvest and put "syllabus" and "outline" in the index.

Chapters come from `sorted(folder.glob("*.md"))`, so name files with a numeric prefix (`01-`, `02-`) when the reading order is not alphabetical. Each chapter's title is its first H1; a file with no H1 falls back to a prettified filename. Markdown inside a chapter renders normally: headings, lists, tables, code blocks, blockquotes, task lists, and images at relative paths.

## Page numbers are verified, not assumed

This is the PDF's problem alone; the EPUB has no page numbers to verify.

The script renders the book, reads the physical page of every chapter and index term back out with `pdftotext`, re-renders with what it found, and repeats until the numbers read out of the PDF are the numbers printed into it. It reports how many passes that took, normally 2 or 3.

**Do not "simplify" this into a single substitution pass.** Chromium's fragmentation can move a line when the document's total page count changes, and filling in an empty index changes it. A two-pass build was measured shipping an index entry pointing at a page that did not contain the term.

## The EPUB

The same book, rendered for a reader that reflows. The two formats are for two
different readings, which is why both are built every time:

| | PDF | EPUB |
|---|---|---|
| Layout | Fixed. The page you see is the page everyone sees | Reflows to the reader's font size and screen |
| Annotation | Full pen markup on a Kindle Scribe | Highlights and sticky notes, no freehand |
| Page numbers | Real, verified, and printed in the contents and index | None. The format has no fixed pages |
| Best for | Reading with a pen, printing, handing to a room | Reading on a device, at whatever size your eyes want |

Send it to a Kindle by emailing it to your Send to Kindle address, or through
the Send to Kindle app. Amazon converts EPUB to its own format on delivery and
the text stays reflowable. MOBI is no longer accepted, so there is no reason to
build one.

**What the EPUB contains**

| Part | Content |
|---|---|
| Cover | Title, subtitle, byline, description, footnote, as one page. The cover **art** comes from `book.json`'s `cover_image`, or, when that is absent, from rasterising the PDF's own cover page |
| Nav | The contents, as the EPUB navigation document, plus a readable contents page. `sections` become nested entries |
| Figures | Every figure, linking to where it sits in its chapter. Only when the book has figures |
| Chapters | One XHTML file each, in the same sort order as the PDF |
| Index | Terms with the **chapters** that discuss them, each a link |

**Page numbers are dropped, not approximated.** Nothing in the EPUB counts
pages, because a reflowable book has none: the reader picks the font size, and
that decides where a page would break. A number printed into the file would be
a number about some other reader's screen. This is also why there is no
fixed-point render loop on this path. That loop exists to settle Chromium's
pagination, and nothing here paginates, so one pass is exact by construction.

**The index counts chapters, and each number is a link.** The alternative was to
anchor every occurrence of every term, which would mean rewriting the chapter
markup at each regex match. Those patterns are built for prose and would also
fire inside tag attributes, inline `<svg>` markup, and code spans, producing
malformed XHTML that no e-reader would open. Chapter links need no such
rewriting: each term is matched against the chapter's own source text, which is
cleaner than the PDF's text layer because there is no hyphenation, no column
break, and no footer to strip out. A term is capped at eight chapters, narrowed
the same way the PDF narrows to its dense pages.

The `terms.txt` curation carries over unchanged, and it is what makes the index
worth keeping at all: a Kindle can already search the full text, so the value of
an index is the editorial judgment about which terms matter. `--no-index` omits
it from both formats.

**Figures are packaged, not linked.** Every referenced `diagrams/*.svg` is
copied into the book as `images/<name>` with media type `image/svg+xml`, byte
for byte, so a `viewBox` survives intact. Inline SVG stays inline, and its
`<style>` is scoped per figure exactly as in the PDF: one XHTML file per chapter
still holds every figure in that chapter, so two diagrams defining `.label`
would collide without it. A referenced image that does not exist becomes a
visible `[missing image: path]` note and a build warning, because a `src`
pointing outside the package makes the whole book invalid rather than one figure
broken.

**The identifier is derived, never generated.** It is a UUID5 of the title and
the folder name, so rebuilding produces the same identifier and a re-send
replaces the book on the device instead of sitting beside the old copy.

**A note on XHTML.** An EPUB is XML, so every tag closes and `&nbsp;` is not a
thing. The build converts what markdown-it emits and validates the result before
packaging; a source file carrying raw HTML that does not close its tags stops
the build with the file named. This is also why the builder writes the chapter
files itself rather than letting the EPUB library serialize them: that library
round-trips content through an HTML parser, which lowercases attribute names,
and an SVG whose `viewBox` became `viewbox` silently loses its scaling.

## Diagrams

**Figures are hand-authored SVG, and the skill needs no diagram toolchain to
render them.** Chromium is already running, so there is no graphviz binary, no
mermaid bundle, and no network fetch at build time. That is deliberate: it is
what lets the skill be handed to someone else and just work.

**Read `references/diagram-style.md` before authoring a figure.** It carries the
sizing arithmetic, the palette, the required accessibility scaffolding, and a
checklist. `references/figure-template.svg` is a copy-and-edit starting point.

The one rule worth repeating here: **an SVG scales to the column, so the font
size you write is not the size that prints.** A 14px label in a 1280-wide
viewBox renders at about 4.5pt, which no one can read. Design at a viewBox width
of 640 to 900. Slide art almost always needs its type scaled up first.

Three authoring forms, all equivalent:

~~~markdown
```svg
<svg ...>...</svg>
```
~~~

```markdown
![Caption text](diagrams/thing.svg)
![](diagrams/thing.svg)          <- caption falls back to the SVG's <title>
```

A raw `<svg>` element also works, but it must stay on contiguous lines or the
markdown parser splits it across paragraphs. Only a standalone image becomes a
figure; an image inside a sentence stays inline and is not numbered.

What the builder does for you:

- **Numbers figures per chapter** (`Figure 3.2`) and builds the Figures page, with page numbers resolved by the same fixed-point loop as everything else.
- **Takes the caption** from the alt text, falling back to the SVG's `<title>`, which is its accessible name either way.
- **Scopes each inline SVG's `<style>` to that figure.** An SVG's `<style>` is global to the page, so two figures both defining `.label` would otherwise collide and the second would win both. This was measured, not theorised.
- **Widens landscape art.** A figure at least 2.6× wider than tall bleeds 0.5in into each margin so its labels stay legible, with its caption still aligned to the text column.
- **Keeps art and caption together** and caps figure height, so a diagram never orphans its own caption.
- **Measures every figure's smallest label and warns when it will print below 8pt**, naming the figure and its viewBox width. That is the same 8pt `references/diagram-style.md` asks for, so the check enforces the guidance rather than sitting under it. Slide art typically lands near 3pt, and no automatic rescale fixes that; the type has to be redesigned. The warning exists so that failure is reported rather than silently shipped.
- **Names every raster figure it could not check.** A `.png`, `.jpg`, `.gif` or `.webp` figure binds and gets the same wide-measure handling, and the builder warns when it prints below 150 DPI. It cannot measure the type inside it, because a raster declares no font sizes, so it lists those figures as *not checked* against the 8pt floor rather than letting their absence from the 8pt warning read as a pass. **Resolution and legibility are independent**: a finely sampled render of 16pt slide text clears any DPI floor and still prints at 7.20pt. Prefer SVG, and check any raster by eye in the built PDF.

**Figures are read in grey more often than in colour**, since every book ships an EPUB and those are usually read on an e-ink device. `references/diagram-style.md` carries the measured collapses in the house palette (accent blue and red are the same grey, 0.5 of 16 steps apart) and the rule that follows: never let hue be the only difference between two marks that mean different things.

## Optional `book.json`

Drop it in the same folder. Every field is optional.

```json
{
  "eyebrow": "Small line above the title",
  "subtitle": "Shown under the title",
  "byline": "Author · Affiliation",
  "description": ["First cover paragraph.", "Second."],
  "description_file": "BOOK.md",
  "footnote": "Small print at the foot of the cover.",
  "contents_note": "One line under the Contents heading.",
  "terms_file": "terms.txt",
  "glossary": true,
  "glossary_file": "glossary.md",
  "cover_image": "cover.jpg",
  "exclude": ["NOTES.md"],
  "sections": [
    { "title": "Part One", "chapters": [1, 2, 3] },
    { "title": "Part Two", "chapters": [4, 5] }
  ]
}
```

- `description` takes a string or a list of paragraphs, and is markdown. `description_file` names a markdown file instead; that file is then excluded from the chapters.
- `sections` groups chapters by their 1-based position in sort order. The section title also prints on each chapter's opening page, and becomes a nested entry in the EPUB's navigation. Omit it for a flat contents page.
- `exclude` drops files from the chapter list. `book.json` and the glossary file are always excluded.
- `glossary` declares that this book is meant to carry one, so a missing file errors rather than binding silently without it. `glossary_file` renames it from the default `glossary.md`. See **The glossary**.
- `cover_image` is **EPUB only**, and optional: the file becomes the book's cover art in a library or on a device. Around 1600×2560 JPEG suits a Kindle Scribe. The PDF ignores it and keeps its typeset cover page. **Omit it and the EPUB still gets cover art**: the builder rasterises the PDF's own cover page at 1600px wide and uses that, so a library shows the book's title rather than a blank tile. It keeps the printed page's 7.1:9.1 proportions, so a device letterboxes it rather than cropping a page that was designed. Name a `cover_image` when you want art of your own; the generated one is never used then.

## The glossary

A `glossary.md` in the book folder binds as back matter, between the last chapter and the index. It is never a chapter: the file is skipped whether or not it gets bound and whether or not `book.json` remembered to exclude it, because a forgotten `exclude` line would otherwise bind the glossary as chapter 7 and that reads like an editorial choice rather than a mistake.

One entry per paragraph:

```markdown
# Glossary

**access method** (ch. 4) The strategy the query planner picks to reach the rows
a query asks for, such as a full scan or an index lookup.

**anomaly** (ch. 10) An update, insertion or deletion that leaves a table saying
two different things at once.
```

- **The term is bold and the chapter reference follows it in parentheses.** Both halves parse strictly, so a paragraph that does not read `**term** (ch. N) definition` stops the build rather than rendering as something that looks deliberate. An entry may wrap across lines; a blank line ends it.
- **The chapter reference is optional in the grammar and wanted in practice.** It is what makes an entry a pointer back into the prose that defines the term properly. The PDF prints it; the EPUB makes it a link to that chapter. A chapter number the book does not have stops the build.
- **A leading `#` heading is the file's own title** and is skipped. Everything else has to parse.
- **Entries are sorted case-insensitively and grouped under letter dividers**, so the source file's order does not matter. A term defined twice stops the build, since one of the two would be unreachable.

**The index stops at the glossary**, so a term is never indexed to the glossary page that defines it. Without that, the one page a reader following an index number does not need is the one they would land on.

`"glossary": true` in `book.json` is a declaration rather than a switch: it says this book is meant to have one, so a missing file is an error instead of a book that quietly ships without the thing it promised. `"glossary": false` or `--no-glossary` suppresses a file that is present.

## The index

One curated term list feeds both formats. The PDF resolves each term to pages; the EPUB resolves it to chapters, since it has no pages (see **The EPUB**).

By default terms are harvested from the text: repeated phrases, acronyms, and code-like identifiers, keeping what is concentrated in a few chapters and discarding what is sprinkled through all of them. A term the book uses on more than fourteen pages is narrowed to the pages that discuss it rather than every page that mentions it.

**Harvesting gives a usable index, not a good one.** For a book that matters, curate:

1. `--report` prints every harvested term with its page count, plus what matched nothing and what got narrowed.
2. Copy the ones worth keeping into `terms.txt` beside the chapters, and add the ones the harvest missed.
3. Rebuild. The presence of `terms.txt` replaces harvesting entirely.

`terms.txt` format, one term per line:

```
# comments and blank lines are ignored
foreign key
!STRICT
point-in-time correctness | \bpoint[- ]in[- ]time\b
```

- A bare term is matched case-insensitively, tolerating plurals and hyphens or slashes between words.
- A `!` prefix matches case-sensitively. Use it for acronyms and SQL keywords, so `SCAN` does not collect every ordinary "scan".
- `display | regex` gives the pattern explicitly, for anything the derived one gets wrong.

`books/reference-guide/terms.txt` is a worked example: 85 curated terms, `!` on the acronyms and SQL keywords so `STRICT` and `OLAP` do not collect ordinary words, and explicit regexes where the derived pattern gets a term wrong.

## Flags

| Flag | Effect |
|---|---|
| `--out PATH` | Output PDF path (default: `<folder>/<title-slug>.pdf`). The EPUB takes the same path with an `.epub` suffix |
| `--terms PATH` | Curated term list (default: `terms.txt` in the folder) |
| `--max-terms N` | Ceiling on harvested terms (default 220) |
| `--no-index` | Omit the index, from both formats |
| `--no-glossary` | Omit the glossary even when the folder holds one |
| `--report` | Print harvested terms, chapter pages, and narrowing decisions |
| `--type-size PT` | The PDF's paragraph type size, 11.8 to 17 (default **14**). A value is required. See **Type size** |

There is no flag for the output format. Both are always written.

## Type size

**The PDF binds at 14pt by default.** That is the size the measurements land on:
67.6 characters to the line against a classical ideal of 66. Large print and the
compact edition are each one flag away, with `--type-size`:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/bookcraft-python \
  ${CLAUDE_PLUGIN_ROOT}/skills/makebook/scripts/build-book.py \
  "Book Title" path/to/folder --type-size 17
```

The flag takes a size from 11.8 to 17 and **a value is required**; there is no
bare form. Outside that range the build stops and says why rather than binding
something odd. Below 11.8 nothing has been measured, and above 17 the chapter
titles outgrow the cover's fixed 34pt title.

Useful sizes, all measured against the reference book (18 chapters,
34,034 words) on 2026-09-13:

| `--type-size` | Pages | What it is for |
|---|---|---|
| `11.8` | 171 | The compact edition. The size the stylesheet was drawn at |
| *(omitted)* → 14 | **226** | The default: 67.6 characters to the line, against an ideal of 66 |
| `17` | 336 | Large print, and the ceiling. Half again the default's paper |

These counts replace a set measured against a retired book, and before a wide
table was found to be shrinking the type of every page in it. A count taken
before that fix understates its size by more than half, so treat any page count
of this guide written earlier than the date above as describing a different
book.

**The ceiling is 17, and the default no longer sits on it.** There is roughly
0.4pt of headroom above 17 before the chapter titles outgrow the cover, so
anyone raising the ceiling has to deal with the cover first. Backing the default
off that size is what gives the three limits below room: each is tightest at 17,
and each has characters to spare at 14.

**One ratio moves every reading size**, so a 14pt body does not leave a 9.5pt
table or a 10pt glossary stranded beside it, and the headings keep the distance
from the text the design was drawn with. The cover is the one part held still:
it has to fit on one page, and the build already warns when it does not.

**The page stays the same size, so the measure does not change.** That is what
keeps figures out of it: a figure is sized to the 6.0in column, so its labels
print at exactly the point size they always did and the 8pt legibility floor
still means what it meant. It also means a figure's type reads smaller relative
to the prose around it as the body grows, 0.68 of the body at 11.8pt, 0.57 at 14
and 0.47 at 17. A reader who asked for large print is the one least served by a
figure that did not follow it, so look at a figure page before binding a
diagram-heavy book at 17.

**Three things get tighter as the type grows, and the build warns about each by
name.** The first two cut silently, in the PDF's text layer as well, so the lost
characters cannot be recovered by selecting them. The third does not cut; it
breaks a word in the middle, which looks deliberate on the page.

| What | At 11.8pt | At 14pt (default) | At 17pt | The build says |
|---|---|---|---|---|
| Running title, capped at a fixed 5in | 77 characters, warns past 77 | 66, warns past 64 | 56, warns past 53 | Names the length and what fits |
| A line inside a fenced code block | 80 characters, warns past 79 | 68, warns past 67 | 55, warns past 54 | Counts every offending line and names its chapter |
| A table column narrower than its own longest word | Rarely reached, since the words scale and the measure does not | Reachable | Nothing is lost; a word prints broken in two | Names the chapter, the column, how far short it is, and the words that broke |

The first two are calibrated to fire a character or two early, so a build that
stays quiet is genuinely clear rather than borderline. The third is not
calibrated at all: it asks Chromium whether a word was actually laid out across
two lines, so it reports the defect rather than a prediction of it.

**Most table cases are repaired rather than reported.** The build measures every
column's longest unbreakable word, and where a table fits the measure but the
layout squeezed a column below its word anyway, it writes explicit column widths
and rebinds. Only a table that genuinely needs more than the 6.0in measure
reaches the warning, and the remedy is then editorial: shorten the cell text,
split the table, move the widest column into a list, or bind smaller.

A book with long commands in it is a book to bind smaller, or to rewrap. The
reference book clears all three at every size. It needed four tables narrowed
before it cleared them at 17, and its longest fenced line is 53 characters,
which clears the default's threshold of 67 by fourteen and 17's threshold of 54
by one.

**The EPUB is untouched.** It reflows to whatever size the reader picked on
their device, so a size baked into the file would be a statement about somebody
else's screen.

`references/type-size.md` carries the measurements behind all of this, the
reason the ceiling is 17, and what the sweep did not cover.

## Notes

- US Letter. The page area is 0.95in top and bottom, 0.7in left and right; body padding holds the text to a 6.0in measure, which leaves 0.55in either side for a wide figure to bleed into. Body is a serif face at 14pt, or at whatever `--type-size` asks for.
- The page number and running title print on every page, the cover included, because Chromium applies one footer template to the whole document. Contents and index numbers are physical PDF pages, so they match the reader's page indicator.
- A render takes a few seconds per pass; most of it is Chromium's cold start. The EPUB adds well under a second, since nothing renders.
- Chapters carry an invisible white marker used to locate them in the text layer. It is not visible in print, but it is present if someone selects the text. The EPUB carries no markers: nothing reads them there, and white 5pt text in a reflowable book is litter.
- The EPUB is typically a fraction of the PDF's size, because it packages the SVG sources rather than a rendered page for each one.

## Security

The script does not sanitize the rendered HTML. markdown-it passes raw HTML through, so a `<script>` tag in a source file reaches Chromium. Run this only on markdown your team wrote.

The EPUB path is stricter by accident rather than by design: it validates the markup as XML before packaging, so unclosed raw HTML stops the build. That is a well-formedness check, not a sanitizer, and it does not make untrusted markdown safe to build.
