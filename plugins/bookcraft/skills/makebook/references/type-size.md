# Body type size for makebook

The PDF sets its paragraphs at **14pt**, and `--type-size` moves that anywhere
from 11.8pt to 17pt, which is large print. This file is the arithmetic behind
the default, behind the ceiling above it, and behind what each end of the range
costs.

Two sets of measurements live here and they were taken against different books.
**The type measurements** (characters per line, word space stretch, footer
capacity, code line survival) were taken on 2026-09-10 in Chromium, running the
same font stack, the same 6.0in measure, the same 1.62 line-height, and the same
`text-align: justify; hyphens: none` the book prints with. They are properties
of the type and the measure, so they hold for any book. The stack resolves to
real Palatino on this machine, confirmed by measuring one string at 40pt in each
family: the book stack and Palatino both give 1054.06px, Georgia gives
1063.84px, and the generic serif fallback gives 979.06px.

**The page counts** are properties of one book, and the book they were first
taken against no longer exists. They were re-measured on 2026-09-11 against
`books/reference-guide`, and again on 2026-09-13 after the
column planner changed them. As it now stands: 18 chapters, 10 figures, an
84-term glossary and a 153-term index, binding to 171, 226 and 336 pages at
11.8, 14 and 17pt.

## The geometry that does not move

`--type-size` scales type. It does not touch the page.

| | Value |
|---|---|
| Page | US Letter, 8.5in wide |
| Page area | 7.1in, from 0.7in side margins |
| Text measure | **6.0in**, from 0.55in of body padding on each side |
| Bleed available to a wide figure | 0.55in per side, which is what that padding is for |

Holding the measure still is what keeps the change cheap. Figures are sized to
the column, so their labels print at exactly the point size they always did, and
the 8pt legibility floor in `diagram-style.md` still means what it meant.
Nothing about a figure is recomputed.

**The absolute size holds and the relative one does not, and the second is the
one to look at.** An 8pt label is still 8pt on paper, but the prose beside it
has grown, so the label reads smaller against its surroundings than it did: 0.68
of the body at 11.8pt, 0.57 at 14pt, 0.47 at 17pt. A reader who needed larger
prose is the reader least served by a figure that did not follow it. On a book
that leans on its diagrams, look at a figure page before settling on a size.

## What the measurements say

Characters per line comes from setting every body paragraph as one continuous
block, so exactly one line in the run is a partial last line and
characters ÷ lines is accurate to well under a percent.

Word space stretch is the cost of `hyphens: none`. With hyphenation off, the
only way to fill a justified line is to widen the spaces between its words. The
same prose set ragged-right leaves a measurable gap at the end of each line, and
that gap is precisely the slack justification has to hand to the word spaces.
The column below is the median per-gap stretch as a percentage of Palatino's own
word space at that size.

| Body | Chars/line | Word space stretch, median |
|---|---|---|
| **11.8pt** (the floor) | 80.6 | 41% |
| 12.5pt | 76.0 | 42% |
| 13.0pt | 73.0 | 44% |
| 13.5pt | 70.1 | 46% |
| **14.0pt** (the default) | **67.6** | **49%** |
| 15.0pt | 62.9 | 50% |
| 16.0pt | 58.8 | 55% |
| **17.0pt** (the ceiling) | **55.2** | **59%** |

## What it costs in paper

Measured 2026-09-13 against the current 18-chapter teaching guide, by building
it at each size and reading the page count off the build's own report.

| `--type-size` | Pages | vs. the floor |
|---|---|---|
| `11.8` | 171 | — |
| *(omitted)* → 14 | **226** | **+32%** |
| `17` | 336 | +96% |

These replace a set taken against the retired 17-chapter guide, which ran 139,
176 and 218 at the same three sizes. Do not compare a number from that row to
one from this one: the book gained a chapter and the column planner added pages
of its own, so the two sets describe different books at the same sizes.

The intermediate sizes were not re-measured against this book. The old
twenty-chapter guide ran +8% at 12.5pt, +15% at 13pt, +19% at 13.5pt, +45% at
15pt and +60% at 16pt, and those proportions are the best available guide to
what the sizes between cost.

## Why the default is 14.0pt

Two independent readings land on 14.0pt.

**It is the closest size to the classical optimum.** The range for a single
justified column is 45 to 75 characters and 66 is the figure usually given as
ideal. 14.0pt lands at 67.6, nearer 66 than any other size on the table.

**It is the last size whose justification stays where the book already
justifies.** The median word space stretch crosses half a natural word space
between 14 and 15. Against the 41% the floor sets at, 14.0pt is 49% and 17.0pt
is 59%: a fifth worse, against nearly half again worse.

At +32% paper against the floor it costs a third of what large print costs, and
it leaves each of the three per-size limits below real room rather than a
character or two.

**The default has been reversed twice, so read the argument rather than the
number.** The floor was the original default, on the grounds that the page cost
was "the reason this is a flag rather than the default". That was reversed to
the ceiling, so that a reader who needed large print would not have to know a
flag existed. This is the second reversal: both ends stay one flag away,
`--type-size 17` for large print and `--type-size 11.8` for the compact
edition, and the default is now the size the measurements recommend rather than
either end of the range.

## What large print costs

`--type-size 17` is the binding to reach for when a reader needs it. What it
spends is why it is no longer what a book gets without asking:

- **+96% paper** on the guide, 171 pages to 336, and half again the default's
  226.
- **Justification at 59% median word space stretch**, against 49% at the
  default and 41% at the floor. Loose word spaces on a narrow measure are what
  large type on a fixed page costs.
- **All of the headroom under the ceiling.** See below: there is about 0.4pt
  left above 17, so a large-print binding leaves none of it in reserve.
- **The tightest form of every limit in this file.** The running title, the
  fenced line and the table column are each worst at 17pt, and the build warns
  about all three by name.

55.2 characters to the line is what it gains besides size, though the default's
67.6 is already inside the 45 to 75 range. It is the floor's 80.6 that sits past
the classical maximum of 75.

## Why the ceiling is 17.0pt

The cover does not scale. It is one designed page, it has to fit on one page,
the build already warns when it does not, and nothing on it is read line after
line. Its title is fixed at 34pt, and a chapter title scales from 23pt, so at
about 17.4pt of body the chapter openings would start to outgrow the cover they
sit behind. 17.0pt is the last round size under that.

The ceiling sits inside the 16pt to 18pt band that large-print editions are
usually set in, which is what makes `--type-size 17` a real large-print binding
rather than merely the limit of the range.

**Anyone raising the ceiling has to deal with the cover first.** The 0.4pt is a
reason to be careful rather than room to spend, and a book bound at 17 is
already using all of it.

## What scales and what does not

One ratio, `body ÷ BASELINE_BODY_PT`, applied to every size in `TYPE_SCALE`.
`BASELINE_BODY_PT` is 11.8, the size the stylesheet's literals were hand-written
at, and it is deliberately a different constant from `DEFAULT_BODY_PT`: the
first is the denominator of the ratio and must not move, the second is what the
CLI picks and did. `build_css(BASELINE_BODY_PT)` reproduces those literals byte
for byte, which is the check the whole scaling scheme is proved by.

The reading text and the headings move together, so a larger body never strands
a 9.5pt table or a 10pt glossary beside it, and the headings keep the distance
from the text that the design was drawn with.

**The chapter and section titles are in that set because holding them still was
tried first and looked wrong.** Pinned at 23pt against a 17pt body, a chapter
title still beat its `h2` on paper, 23 against 20.2, and lost to it on the page,
because the `h2` is bold and the title is not. A rendered chapter opening read
as though the section heading were the more important of the two.

**The cover is the one part left alone**, for the reasons under the ceiling
above.

**The running footer is the one size outside `TYPE_SCALE`, and it is scaled by
hand.** Chromium builds the header and footer in a separate document that the
page's own stylesheet never reaches, so the table cannot govern it;
`footer_template()` takes the body size and applies the same ratio through
`scaled()`. It is worth knowing about because the folio is what a large-print
reader navigates by, and it is the number the Contents entries point at.

**The running title's 5in cap does not scale, so a long title loses characters
as the type grows.** This one is a limit rather than an oversight. The footer's
content box is 6.0in, and recovering at 11.5pt the character count a title gets
at 8pt would need a cap wider than the page has, so no setting recovers it.
Measured in Chromium at the footer's own stack and letter-spacing:

| Body | Folio | Title characters that fit |
|---|---|---|
| 11.8pt | 8pt | 77 |
| **14pt** (default) | 9.5pt | **66** |
| 17pt | 11.5pt | 56 |

Past that, `text-overflow: ellipsis` cuts the title, and the cut form is what
reaches the PDF's text layer, so a search or a copy returns it too. **The build
warns when a title will not fit**, calibrated slightly early so it fires before
the cut rather than after: past 77 characters at 11.8pt, past 64 at the default
and past 53 at 17pt.

**This limit reaches an ordinary build.** At the original 11.8pt default a title
had 77 characters before it was cut, and only a book that asked for large print
was exposed. **A title meant to survive the default footer needs to be about 64
characters or shorter, and one meant to survive a large-print binding about
53.**

The warning was exercised with a 61-character string while 17pt was the default,
and it fires there, printing a cut form with an ellipsis at each end. That same
string clears the allowance at 14pt, which is the point of the table above: this
warning is a function of the size, not a property of the title. The reference
book's own title is 21 characters, read out of the running footer of both bound
PDFs, and it clears the allowance at every size.

**Vertical spacing is deliberately left absolute.** `.chapter-head`'s
`margin: 0.55in 0 0.34in`, `.toc-row`'s `0.028in`, `.index-letter`'s `0.16in`
and the rest are in inches, so the space around a heading tightens relative to
the type as the body grows: roughly 18% at 14pt and 44% at 17pt. Converting them
to `em` would change the output at every size, and sampled chapter openings at
14 and 17pt read correctly as they are. Anyone raising the ceiling should look
here first.

**The EPUB is not touched at all.** It reflows to whatever size the reader picks
on their device, so a size baked into the file would be a statement about
somebody else's screen. `--type-size` changes the PDF and nothing else.

## Fenced code is the case to check as the type grows

A fenced line wider than the measure is clipped, and it was clipped long before
the size became an argument. A 111-character `docker run` line survives into the
PDF's text layer as 80 characters at 11.8pt, 68 at 14.0pt and 55 at 17.0pt. The
`overflow-x: auto` on `.chapter pre` scrolls on a screen and simply cuts on
paper, and the lost text is gone from the text layer too, so it cannot even be
copied out. Larger type shortens the survivor; it does not cause the cut.

**At 17pt this stops being a corner case**, because a command that prints cut is
a command a reader cannot run and cannot recover by selecting it. So the build
warns, rather than this file merely saying so. A documentation line does not
reach the person binding a book full of long commands; the same reasoning made
the running title a warning rather than a note.

`CODE_CHARS_PER_PT` carries the calibration, on the same arithmetic as
`TITLE_CHARS_PER_PT`: survivable characters times the scaled `pre` size is
704, 707 and 698.5 at the three measured points, and the constant takes the low
end so the warning fires slightly early. The thresholds that fall out are **79
characters at 11.8pt, 67 at the default and 54 at 17pt.**

**Re-checked against a correctly sized build on 2026-09-13, and unchanged.** The
original calibration was taken while a wide table was still shrinking every
page, so the size it measured was not the size the stylesheet asked for and the
whole constant was open to doubt. Binding fenced lines of 48 to 63 characters at
17pt, which was the default when the check was run, and reading them back out of
the PDF: every line to 55 characters survives whole, and every line of 56 or
more is cut at 55. The threshold of 54 therefore fires exactly one character
before the real cut, which is the margin it was designed to have. The constant
was right for a reason that had not been established when it was written. That
check was made at the size where the margin is thinnest, which is where it is
worth making. The warning counts
every fenced line past the threshold, lists up to eight worst-first with the
chapter each is in, prints the part of each that will survive, and says that the
remainder is gone from the text layer too. That is the shape the figure
legibility floor already reports in, deliberately: a book can carry several
over-long commands, and hearing about one of them is how the others ship.

**Eleven** of the reference book's chapters carry fenced content (04, 05, 08, 10,
11, 12, 13, 14, 15, 16 and 17), and its longest fenced line is **53**
characters, with four chapters tied at it. That clears the default's threshold
of 67 by fourteen and 17pt's threshold of 54 by one.

Re-measured 2026-09-13 with the script's own `fenced_lines()`. Run this with the
skill's own interpreter, `${CLAUDE_PLUGIN_ROOT}/scripts/bookcraft-python`, because
`build-book.py` imports `ebooklib` at module scope and a bare `python3` fails
before `fenced_lines` is reachable:

```python
import importlib.util, os, pathlib
spec = importlib.util.spec_from_file_location(
    "bb", os.environ["CLAUDE_PLUGIN_ROOT"] + "/skills/makebook/scripts/build-book.py")
bb = importlib.util.module_from_spec(spec); spec.loader.exec_module(bb)

folder = pathlib.Path("books/reference-guide")
hits = {p.name: max(map(len, bb.fenced_lines(p.read_text())), default=0)
        for p in sorted(folder.glob("*.md"))}
carrying = {n: m for n, m in hits.items() if m}
print(len(carrying), "chapters carry fenced content; longest line",
      max(carrying.values()))
```

**It prints both figures, and that is the point of printing both.** These
numbers replace "four fenced blocks (chapters 05, 10, 14 and 16)" and "54
characters", which were wrong in both halves and had been carried across
unmeasured since 2026-09-11. The inventory is the half that mattered, since
anyone re-checking this book after an edit would have looked at four chapters
instead of eleven, so a re-measure that returned only the longest line would
leave the more damaging figure to be carried forward again.

## Tables are the thing that goes wrong as the type grows

The table size scales with everything else, from 9.5pt at the floor to 11.3pt at
the default and 13.7pt at 17pt, inside the same fixed 6.0in measure. That makes
a table the most likely thing to be quietly wrong at 17pt, and it twice has
been. Both failures were silent, both were found by reading a bound PDF rather
than a build report, and the build now refuses each of them. Both were found
while 17pt was the default, which is why the measurements below are at that
size.

**A cell's longest word used to set the width of the whole book.** `table-layout:
auto` honours a cell's min-content width past the declared `width: 100%`, so one
long unbreakable token grew the document's layout box wider than the page, and
Chromium printed every page scaled down to fit. Pages with no table on them lost
type too. Measured on this guide on 2026-09-12: a 6.37in measure and 91
characters to the line where the size asks for 6.0in and 55.2, and 148 pages
where the same content correctly set was 327, before the column planner below
took it to 336. `overflow-wrap: anywhere` on
`.chapter th, .chapter td` fixes it, and only `anywhere` does: it is the one
value that reduces the min-content contribution, which is the quantity that
widens the layout.

**Then the cure let columns be squeezed below their own words.** Dropping a
cell's min-content width to a single character is exactly what stops the layout
box growing, and it equally frees auto layout to hand a column less than its
longest word. Measured across this guide on 2026-09-12, immediately after the
fix above: 58 of 70 tables printed a word broken mid-word, and 53 of them had
room to spare. One column was given 39pt for a word needing 91pt on a table
using 314pt of its 432pt. In print that reads as `Excell / ent`, `Profici / ent`
and `Develo / ping` down a rubric's header row.

The build now measures each column's longest unbreakable run and its one-line
width, and writes the widths back as a `<colgroup>` for any table that fits the
measure and broke anyway. A table that genuinely needs more width is left alone
on purpose, so it still degrades to a broken word rather than to a book-wide
type reduction, and **the build warns and names it**. The same guide now binds
with no table warnings at any of the three sizes.

Two details worth keeping, both measured 2026-09-13 in Chromium:

- **Only a hyphen, en dash and em dash are reliable break opportunities.**
  Sweeping 50 box widths with text in front of the compound, each of those never
  left a line ending mid-run, while a slash, underscore and period each did at
  16 to 18 of them. `completion/attendance` is therefore one unbreakable run 21
  characters wide, not two of 10. Chromium uses the slash only when the compound
  is the whole line; once the run has to break at all it fills greedily instead.
- **A width a column wants is not a width it gets.** The sum of per-column
  longest words predicts nothing on its own, because the squeeze above is
  unrelated to whether the table fits. Ask whether a token was laid out across
  two line boxes, which is the defect itself rather than a proxy for it.

Tables still behave differently from fenced code once they fit, and the CSS is
the reason. `.chapter table` is `width: 100%` with wrapping cells, so growing
type makes a table **taller**; `.chapter pre` has `overflow-x: auto`, which
scrolls on screen and cuts on paper. Height is recoverable by turning a page.
Width is not. This is also why `--type-size` buys a table real room and buys a
fenced line none: the measure is a fixed 6.0in at every size while the words
scale with the type, so a smaller binding is a real remedy for a table warning
and the only one of the three that is. This guide raises no table warning at any
size, so the remedy is one to reach for in another book rather than in this one.

## A term in a fence is indexed by one format and not the other

The PDF resolves index terms against the rendered text layer, which includes
fenced code. The EPUB resolves them against the chapter source after
`strip_markdown()` has removed the fences. A term written *only* inside a fence
therefore lands in the PDF's index and not the EPUB's, and both are working as
written.

The guide has one: `automatic covering index` appears only in chapter 16's
`EXPLAIN QUERY PLAN` output, so the PDF index carries 88 entries and the EPUB
carries 87. **Both indexes now report what they dropped** on an ordinary build,
which is how this was found; before that the counts simply differed and nothing
said why. Mention such a term in prose as well if it belongs in both.

## What this was not tested against

- **Only one machine.** Palatino is a macOS system face. A machine without it
  falls back to Georgia, which is wider, so every characters-per-line figure
  above would come down a little and the fallback would want a slightly smaller
  size than the same reading suggests here.
- ~~**Tables other than the largest one.**~~ No longer a gap. Every table in
  every build is now measured for whether a column is narrower than its own
  longest word, so the coverage this bullet described as one table is the whole
  book. What is still unmeasured is a table outside a chapter: the check reads
  `.chapter table`, so a table in front matter, the glossary or the index is
  not seen.
- **The intermediate sizes against the current book.** Only 11.8, 14 and 17
  were re-measured on 2026-09-11.
