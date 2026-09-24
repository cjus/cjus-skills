#!/usr/bin/env python3
"""Bind a folder of markdown files into a book, as a PDF and as an EPUB.

    build-book.py "Book Title" path/to/folder [--out book.pdf]

The folder's markdown files, in filename sort order, become the chapters. Each
chapter's title is its first H1, falling back to a prettified filename. The
book gets a cover page carrying a description, a contents page, the chapters,
and a back-of-book index of terms with the pages they appear on.

Both formats are written every run, from the same chapters and the same term
list. The PDF is for reading on a fixed page, with a pen; the EPUB is for
reading at whatever font size the reader chose. Everything the PDF builds on
physical pages is dropped from the EPUB rather than approximated, because a
reflowable book has no pages to point at. See the EPUB section below.

Page numbers in the contents and the index are resolved by rendering to a fixed
point. Each pass renders the book, reads the physical pages back out with
pdftotext (chapters carry an invisible marker, index terms are matched by
regex), then re-renders with what it found. It stops once the numbers read out
of the finished PDF are the numbers printed into it, which is the guarantee
worth having: every page reference in the book is verified against the book.

Two passes are not enough. Chromium's fragmentation can move a line when the
document's total page count changes, and filling in an empty index changes it,
so a single substitution pass can leave a stale reference behind.

Index terms are harvested from the text: repeated phrases, acronyms, and
code-like identifiers, with phrases that are merely part of a longer phrase
pruned away. Drop a `terms.txt` beside the chapters to override that with a
curated list.

Diagrams are SVG, written inline or referenced, and Chromium renders them, so
there is no diagram toolchain to install. They are numbered per chapter,
captioned from their own <title>, listed in a Figures page, and each inline
figure's CSS is scoped so two figures cannot collide. See
references/diagram-style.md for how to author one that reads at book size.

An optional `book.json` in the folder supplies the subtitle, byline,
description, footnote, and a grouping of chapters into titled sections. Every
field is optional; see the skill's SKILL.md for the shape.
"""
from __future__ import annotations

import argparse
import html as html_mod
import html.entities
import json
import math
import re
import struct
import subprocess
import sys
import tempfile
import uuid
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path
from string import Template

try:
    from ebooklib import epub
    from markdown_it import MarkdownIt
    from mdit_py_plugins.tasklists import tasklists_plugin
    from playwright.sync_api import sync_playwright
except ImportError as exc:  # pragma: no cover - setup guidance
    # Resolved from this file rather than from CLAUDE_PLUGIN_ROOT, so the line
    # stays copy-pasteable when the script is run directly and that variable is
    # not set. .../<plugin>/skills/makebook/scripts/build-book.py, so the plugin
    # root is three parents up from the scripts directory.
    _installer = Path(__file__).resolve().parents[3] / "scripts" / "install.sh"
    sys.exit(
        f"missing dependency: {exc.name}\n"
        "run the one-time setup:\n"
        f"    {_installer}\n"
        "then run this script through the wrapper it sets up:\n"
        f"    {_installer.with_name('bookcraft-python')} {Path(__file__).resolve()} ..."
    )

# --------------------------------------------------------------------------
# Tunables
# --------------------------------------------------------------------------

# Renders allowed while page numbers settle, plus one. A book with a table to
# plan spends its first render measuring columns and discards the result, so
# the settling itself still gets the six it always had.
MAX_PASSES = 7
# The share of the text measure a lesson-script slide's art prints at. The art
# sits at reduced width so its notes can run beside it, which is the whole point
# of the compact row; both legibility measurements scale by it, because a label
# that clears the floor at full measure does not clear it at two thirds.
SLIDE_WIDTH_SHARE = 0.62
MAX_PAGES_PER_TERM = 14   # above this a term is narrowed to its dense pages
MAX_CHAPTERS_PER_TERM = 8  # the EPUB index counterpart, in chapters not pages
DEFAULT_MAX_TERMS = 220   # ceiling on harvested index entries

MIN_PHRASE_USES = 3       # a multi-word phrase needs this many uses
MIN_WORD_USES = 10        # a bare word needs more, since it carries less
MIN_MARKED_USES = 2       # acronyms and identifiers announce themselves

# An index term is concentrated: it is discussed somewhere rather than sprinkled
# everywhere. These reject the ordinary English that recurs in every chapter.
MAX_WORD_SPREAD = 0.35    # a bare word may appear in at most this share of docs
MAX_PHRASE_SPREAD = 0.80  # phrases are specific enough to allow more
MIN_WORD_PEAK = 0.45      # and this share of a word's uses must sit in one doc
MIN_PHRASE_PEAK = 0.22

STOPWORDS = set("""
a about above across after again against all almost along already also although
always am among an and another any anyone anything are around as at back be
became because become been before began behind being below beside besides best
better between beyond both but by came can cannot could did do does doing done
down during each either else enough even ever every everything except far few
for from further gave get gets getting give given goes going got had has have
having he her here hers herself him himself his how however i if in indeed
instead into is it its itself just keep kept know known last later least left
less let like likely made make makes making many may maybe me mean means might
mine more moreover most much must my myself near need neither never new next no
none nor not nothing now of off often on once one only onto or other others
otherwise ought our ours ourselves out over own past per perhaps put quite
rather really right said same say says see seem seen several shall she should
show shown since so some someone something soon still such take taken takes
tell than that the their theirs them themselves then there therefore these they
thing things this those though three through thus to together too took toward
two under until up upon us use used uses using usually very want was way we well
went were what when where whether which while who whole whom whose why will
with within without would yet you your yours yourself

ability able add added adds allow allowed allows answer answered answers ask
asked asking asks became become becomes begin begins bring brings build builds
built call called calls came care carries carry case cases change changed
changes come comes course courses cut cuts decide decided decides different
does end ends example examples fact fail failed fails find finds follow follows
gave give gives given hand hands happen happens hard held help helps hold holds
idea ideas keeps kind kinds knows large left let line lines little live lives
long look looked looking looks lot made makes matter matters mean meaning means
move moved moves name named names need needed needs new number numbers old open
opens order orders part parts pay pays people place places point points put
question questions reach reached reaches read reading reads reason reasons rest
right run running runs said say saying says second see seen sense set sets shape
shapes short show shows side simple single small sort sorts spent start started
starts stay stays step steps stop stops story take takes talk tell tells thing
things think thinks thought told took top true try trying turn turned turns
understand use useful uses using version versions want wanted wants way ways
whole word words work worked working works write writes writing written wrong
isn arent aren cant couldn didn doesn don hadn hasn haven isnt mustn shan
shouldn wasn weren won wouldn youre theyre theres its lets
box boxes byte bytes class classes claim claims copy copies current field fields
five forty four frame frames grade grades group groups honest hundred item items
layer layers mark marks match matches million millions moment moments month
months nine note notes one opening opposite page pages price prices probe probes
product products project projects promise promises random range ranges refresh
refuse region regions seven six ten thing three top twenty two week weeks
re ve ll vs md py txt csv tsv json yaml yml html htm js ts jsx tsx sh bash
png jpg jpeg gif svg pdf docx pptx xlsx cfg ini toml log tmp
""".split())

TOKEN_RE = re.compile(r"[A-Za-z0-9_]*[A-Za-z][A-Za-z0-9_]*")
PROBE_RE = re.compile(r"ZQ([A-Z0-9]+)QZ")
CLAUSE_SPLIT_RE = re.compile(r"[.;:!?()\[\]{}\"“”]+|,\s|\s[-–—]\s")

# --------------------------------------------------------------------------
# CSS
# --------------------------------------------------------------------------

CSS_TEMPLATE = """
/* The page area is wider than the text measure on purpose. Body padding
   holds the text to 6.0in, which leaves 0.55in on each side that a wide
   figure can bleed into. Chromium clips print content at the page area, so
   a figure cannot reach past this no matter what margins it is given. */
@page { size: Letter; margin: 0.95in 0.7in 0.95in 0.7in; }

:root { color-scheme: light; }

body {
  font-family: Palatino, "Palatino Linotype", "Iowan Old Style", Georgia, serif;
  font-size: ${body}pt;
  line-height: 1.62;
  color: #1a1a1a;
  margin: 0;
  padding: 0 0.55in;
  text-rendering: optimizeLegibility;
}

.sans { font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }
.mono, code, pre {
  font-family: "SF Mono", Menlo, Consolas, "Liberation Mono", monospace;
}

/* Invisible layout probes, read back out of the PDF's text layer each pass. */
.probe { color: #ffffff; font-size: 5pt; letter-spacing: 0; }

/* ---- Cover ---- */
/* min-height, never height: a fixed box lets a long description overflow it,
   and Chromium paints the overflow at the top of page 2, over the Contents
   heading. A box that grows pushes Contents to page 3 instead, which the
   ZQCOVERENDQZ probe reports as a warning. */
.cover { min-height: 8.6in; display: flex; flex-direction: column; }
.cover .rule-top { border-top: 3px solid #1a1a1a; margin-bottom: 0.34in; }
.cover .eyebrow {
  font-family: system-ui, -apple-system, sans-serif;
  font-size: 9.5pt; letter-spacing: 0.16em; text-transform: uppercase;
  color: #6b6b6b; margin-bottom: 0.5in;
}
.cover h1 {
  font-size: 34pt; line-height: 1.1; margin: 0 0 0.12em;
  font-weight: 400; letter-spacing: -0.01em;
}
.cover .subtitle {
  font-size: 15pt; color: #4a4a4a; font-style: italic; margin: 0 0 0.28in;
}
/* The stamp is set in the byline's type, close under it so the two read as one
   block, and it takes over the byline's space before the rule. It prints with
   or without a byline, because it is the bound book's version marker. */
.cover .byline, .cover .stamp {
  font-family: system-ui, -apple-system, sans-serif;
  font-size: 10pt; color: #4a4a4a; margin: 0 0 0.28in;
}
.cover .byline { margin-bottom: 0.06in; }
/* The rule under the title block is its own element, so a cover with no
   byline still gets one. */
.cover .head-rule { border-top: 1px solid #cfcfcf; margin: 0 0 0.34in; }
.cover .description p { font-size: 11pt; margin: 0 0 0.62em; text-align: left; }
.cover .description ul { font-size: 11pt; margin: 0 0 0.62em; }
.cover .footnote {
  margin-top: auto; padding-top: 0.24in; border-top: 1px solid #cfcfcf;
  font-family: system-ui, -apple-system, sans-serif;
  font-size: 8.5pt; color: #6b6b6b; line-height: 1.5;
}

/* ---- Contents ---- */
.frontmatter { break-before: page; }
h2.section-title {
  font-size: ${sectitle}pt; font-weight: 400; margin: 0 0 0.06in;
  padding-bottom: 0.09in; border-bottom: 2px solid #1a1a1a;
}
.lead {
  font-family: system-ui, -apple-system, sans-serif;
  font-size: ${lead}pt; color: #6b6b6b; margin: 0.12in 0 0.14in; line-height: 1.5;
}
.toc-group {
  font-family: system-ui, -apple-system, sans-serif;
  font-size: ${tocgroup}pt; letter-spacing: 0.11em; text-transform: uppercase;
  color: #6b6b6b; margin: 0.14in 0 0.04in; break-after: avoid;
}
.toc-group:first-of-type { margin-top: 0.05in; }
.toc-row {
  display: flex; align-items: baseline; font-size: ${tocrow}pt;
  margin: 0.028in 0; break-inside: avoid;
}
.toc-num {
  flex: 0 0 1.9em; color: #6b6b6b; font-variant-numeric: tabular-nums;
}
/* Capped so a wrapped title still leaves room for the dotted leader. */
.toc-title { flex: 0 1 auto; max-width: 82%; }
.toc-dots {
  flex: 1 1 auto; margin: 0 0.4em;
  border-bottom: 1px dotted #b8b8b8; transform: translateY(-0.22em);
}
/* Fixed width, so filling a number in cannot reflow the contents page. */
.toc-page {
  flex: 0 0 2.6em; text-align: right;
  font-variant-numeric: tabular-nums; color: #1a1a1a;
}
.toc-row.toc-back { margin-top: 0.14in; font-weight: 600; }
.toc-row.toc-front { margin-bottom: 0.08in; font-weight: 600; }

/* ---- Chapters ---- */
.chapter { break-before: page; }
.chapter-head { margin: 0.55in 0 0.34in; }
.chapter-eyebrow {
  font-family: system-ui, -apple-system, sans-serif;
  font-size: ${cheyebrow}pt; letter-spacing: 0.14em; text-transform: uppercase;
  color: #8a8a8a; margin-bottom: 0.16in;
}
.chapter-number {
  font-family: system-ui, -apple-system, sans-serif;
  font-size: ${chnum}pt; letter-spacing: 0.14em; text-transform: uppercase;
  color: #1a1a1a; font-weight: 700;
}
.chapter h2.chapter-title {
  font-size: ${chtitle}pt; font-weight: 400; line-height: 1.16;
  margin: 0 0 0.2in; letter-spacing: -0.005em;
}
.chapter-head .rule { border-top: 2px solid #1a1a1a; width: 2.1in; }
.chapter p {
  margin: 0 0 0.62em; text-align: justify; hyphens: none;
  orphans: 2; widows: 2;
}
.chapter h2:not(.chapter-title) {
  font-size: ${h2}pt; font-weight: 600; margin: 1.1em 0 0.35em;
  break-after: avoid;
}
.chapter h3 {
  font-size: ${h3}pt; font-weight: 600; margin: 1em 0 0.3em; break-after: avoid;
}
.chapter h4 {
  font-size: ${h4}pt; font-weight: 600; font-style: italic;
  margin: 0.9em 0 0.25em; break-after: avoid;
}
.chapter ul, .chapter ol { margin: 0.5em 0 0.7em; padding-left: 1.5em; }
.chapter li { margin: 0.16em 0; }
.chapter li > p { margin: 0.16em 0; text-align: left; }
.chapter blockquote {
  border-left: 2px solid #cfcfcf; margin: 0.7em 0; padding: 0.1em 0 0.1em 0.9em;
  color: #4a4a4a;
}
.chapter table {
  border-collapse: collapse; width: 100%; margin: 0.8em 0;
  font-size: ${table}pt; break-inside: avoid;
}
/* overflow-wrap is `anywhere` and not `break-word` on purpose. Only `anywhere`
   reduces a cell's min-content contribution, and that contribution is what
   `table-layout: auto` honours past the declared width: one long unbreakable
   token (a filename, an identifier) grew the document's layout box wider than
   the page, and Chromium then printed the whole book scaled down. Every page
   lost type, including pages carrying no table. Measured 2026-09-12 on the
   reference book: 6.37in and 91 characters to the line against the 6.0in and 55
   the size asked for, and 148 pages where 327 was right. */
.chapter th, .chapter td {
  border: 1px solid #d4d4d4; padding: 0.35em 0.5em;
  text-align: left; vertical-align: top; overflow-wrap: anywhere;
}
.chapter th { background: #f2f2f2; font-weight: 600; }
.chapter code {
  font-size: 0.86em; background: #f2f2f2;
  padding: 0.08em 0.28em; border-radius: 3px;
}
.chapter pre {
  background: #f6f6f6; border: 1px solid #e6e6e6; border-radius: 4px;
  padding: 0.6em 0.8em; font-size: ${pre}pt; line-height: 1.42;
  overflow-x: auto; break-inside: avoid;
}
.chapter pre code { background: none; padding: 0; font-size: inherit; }
.chapter img { max-width: 100%; height: auto; display: block; margin: 0.8em auto; }

/* ---- Figures ----
   Sized to the text column and capped in height so a landscape diagram never
   pushes its own caption onto the next page. break-inside keeps art and
   caption together, which is the whole point of a <figure> in print. */
figure.figure {
  margin: 1.05em 0 1.15em; padding: 0; break-inside: avoid;
  text-align: center;
}
figure.figure > svg,
figure.figure > img {
  display: block; width: 100%; height: auto;
  max-height: 6.9in; margin: 0 auto;
}
figure.figure > svg { overflow: visible; }
figure.figure figcaption {
  font-family: system-ui, -apple-system, sans-serif;
  font-size: ${figcap}pt; line-height: 1.45; color: #4a4a4a;
  margin-top: 0.5em; padding-top: 0.4em;
  border-top: 1px solid #e0e0e0;
  text-align: left;
}
figure.figure figcaption .fignum {
  font-weight: 700; color: #1a1a1a; letter-spacing: 0.04em;
}
/* Landscape art gets the wider measure: it bleeds into the page margins so its
   own labels stay legible. The caption stays aligned to the text column. */
figure.figure-wide { margin-left: -0.5in; margin-right: -0.5in; }
figure.figure-wide > svg,
figure.figure-wide > img { max-height: 6.4in; }
figure.figure-wide figcaption { margin-left: 0.5in; margin-right: 0.5in; }
.chapter hr { border: none; border-top: 1px solid #e0e0e0; margin: 1.2em 0; }
.chapter a { color: #1a1a1a; text-decoration: underline; }
ul.contains-task-list { list-style: none; padding-left: 1em; }
li.task-list-item input[type=checkbox] { margin-right: 0.4em; }

/* ---- Index ---- */
.index { break-before: page; }
.index-body { column-count: 2; column-gap: 0.34in; margin-top: 0.2in; }
.index-letter {
  font-family: system-ui, -apple-system, sans-serif;
  font-size: ${idxletter}pt; font-weight: 700; letter-spacing: 0.1em;
  color: #1a1a1a; margin: 0.16in 0 0.06in;
  padding-bottom: 0.03in; border-bottom: 1px solid #cfcfcf;
  break-after: avoid; break-inside: avoid;
}
.index-letter:first-child { margin-top: 0; }
.index-entry {
  font-size: ${idx}pt; line-height: 1.42; margin: 0 0 0.035in;
  padding-left: 1.1em; text-indent: -1.1em; break-inside: avoid;
}
.index-entry .pages { color: #4a4a4a; font-variant-numeric: tabular-nums; }

/* ---- Glossary ----
   One column rather than the index's two: an index entry is a term and some
   digits, a glossary entry is a sentence, and a sentence in a 2.8in column
   breaks badly. Letter dividers are shared with the index so the two pieces of
   back matter read as a pair. */
.glossary { break-before: page; }
.front-matter { break-before: page; }
.gloss-body { margin-top: 0.2in; }
.gloss-body .index-letter:first-child { margin-top: 0; }
.gloss-entry {
  font-size: ${gloss}pt; line-height: 1.45; margin: 0 0 0.07in;
  padding-left: 1.3em; text-indent: -1.3em; break-inside: avoid;
}
.gloss-term { font-weight: 700; }
/* A callout is a boxed aside rather than a quotation: the reader has to be able
   to tell at a glance what kind of sentence they are in, which is the one thing
   the narration page could not say. break-inside avoids splitting a four-line
   box across a page, where the title would land alone at the foot. */
.chapter .callout {
  break-inside: avoid; margin: 0.9em 0; padding: 0.5em 0.8em 0.6em;
  border: 0.5pt solid #bdbdbd; border-left: 2.5pt solid #6b6b6b;
  background: #f7f7f7;
}
.chapter .callout-title {
  font-family: system-ui, -apple-system, sans-serif;
  font-size: ${glossch}pt; font-weight: 700; letter-spacing: 0.06em;
  text-transform: uppercase; color: #3a3a3a; margin: 0 0 0.2em;
  text-indent: 0;
}
.chapter .callout-body { margin: 0; text-indent: 0; }
.chapter .callout-warning { border-left-color: #8a4b2a; }
.chapter .callout-decide { border-left-color: #2f5d7c; }
/* The header rows the reading edition moves down. Set smaller than the body and
   hard against the page foot: they are the operator's rows, kept for the record
   rather than for the reading. */
.chapter .endnotes {
  margin: 1.6em 0 0; padding-top: 0.5em; border-top: 0.5pt solid #d4d4d4;
  break-inside: avoid;
}
.chapter .endnotes-title {
  font-family: system-ui, -apple-system, sans-serif;
  font-size: ${glossch}pt; font-weight: 700; letter-spacing: 0.06em;
  text-transform: uppercase; color: #3a3a3a; margin: 0 0 0.3em;
}
.chapter .endnote {
  font-size: ${table}pt; margin: 0.25em 0; text-indent: 0; color: #3a3a3a;
}
.chapter .endnote-label { font-weight: 700; }
/* A lesson-script slide prints as a compact row: the art at a fraction of the
   measure with its notes running beside it, rather than as a framed,
   full-measure figure at the tail of the chapter. The float is what puts the
   notes alongside, and it is also what stops a divider slide carrying a
   one-sentence note from taking half a page on its own. Headings clear it so a
   slide never bleeds past the part it belongs to. */
.chapter .slide-row {
  float: left; width: ${slideshare}%; margin: 0.25em 1.1em 0.55em 0;
  break-inside: avoid;
}
.chapter .slide-art svg, .chapter .slide-art img {
  width: 100%; height: auto; display: block;
}
.chapter .slide-caption {
  font-family: system-ui, -apple-system, sans-serif;
  font-size: ${glossch}pt; color: #4a4a4a; margin: 0.25em 0 0; text-indent: 0;
}
.chapter h2, .chapter h3 { clear: both; }
.gloss-ch {
  font-family: system-ui, -apple-system, sans-serif;
  font-size: ${glossch}pt; color: #4a4a4a; letter-spacing: 0.03em;
  font-variant-numeric: tabular-nums;
}
"""

# The size CSS_TEMPLATE's literals were hand-written at, and the denominator of
# the single ratio every other size scales by.
#
# This is NOT the default any more, and keeping the two apart is the whole point
# of the name. build_css(BASELINE_BODY_PT) reproduces the hand-written
# stylesheet byte for byte, which is what makes the scaling provable by
# comparison rather than defensible by argument. Move this number and every
# literal in the template silently rescales around it while still claiming to be
# what it says it is.
BASELINE_BODY_PT = 11.8

# What the book prints at when no size is asked for.
#
# 14.0pt is where two independent readings meet. It sets 67.6 characters to the
# line, nearer the classical ideal of 66 than any other size on the table, and
# it is the last size whose justification stays under half a natural word space
# of stretch. Both ends of the range stay one flag away: MAX_BODY_PT is the
# large-print binding and MIN_BODY_PT the compact one.
# references/type-size.md § Why the default is 14.0pt holds the arithmetic.
DEFAULT_BODY_PT = 14.0

# The smallest --type-size accepts. Nothing below it has been measured, and at
# 11.8pt the book already sets 80.6 characters to the line, past the classical
# maximum of 75. Smaller would be a different design question, not a smaller
# number.
MIN_BODY_PT = 11.8

# Every size in CSS_TEMPLATE that belongs to the book's body, with the point
# size it takes at BASELINE_BODY_PT. They all move together, by one ratio, so a
# larger body does not strand a 9.5pt table or a 10pt glossary beside 16pt
# prose, and the headings keep their existing distance from the text.
#
# The chapter and section titles are in here for a reason that was measured
# rather than assumed. Held at 23pt while the body rose to 17pt, the chapter
# title still outranked its h2 on paper (23 against 20.2) and lost to it on the
# page, because the h2 is bold and the title is not: a rendered chapter opening
# at 17pt read as though the section heading were the more important of the two.
# Scaling both keeps the ratio the design was drawn at.
#
# The cover is deliberately absent. It is one designed page that has to fit on
# one page, the build warns when it does not, and nothing on it is read line
# after line. Holding it still is what bounds MAX_BODY_PT: the chapter title
# scales and the cover's own 34pt title does not, so past about 17.4pt the
# chapter openings would outgrow the cover.
TYPE_SCALE = {
    # Bound to the constant rather than repeating 11.8, so the ratio's
    # denominator and the stylesheet's authored baseline cannot drift apart.
    "body": BASELINE_BODY_PT,  # chapter paragraphs; everything else inherits
    "chtitle": 23,      # chapter opening title
    "sectitle": 19,     # Contents, Figures, Glossary, Index
    "h2": 14,           # in-chapter section heading
    "h3": 12,
    "h4": 11,
    "table": 9.5,
    "pre": 8.8,         # fenced code. Inline code is 0.86em and follows on its own
    "figcap": 8.6,
    "gloss": 10,
    "glossch": 8,
    "idx": 9.6,
    "idxletter": 9,
    "tocrow": 10.7,
    "tocgroup": 8.5,
    "lead": 9,
    "cheyebrow": 8.5,
    "chnum": 8.5,
}

# The largest --type-size accepts, and the large-print binding. There is about
# 0.4pt of headroom above it before the scaling chapter titles outgrow the
# cover's fixed 34pt, so anyone raising this has to deal with the cover first.
# Read that headroom as a reason to be careful here, not as room to spend.
#
# It is also the size every per-size limit in this file is worst at, because the
# measure is fixed while the words scale: the running title, the fenced line and
# the table column are all tightest here. The default used to sit exactly on
# this number, which is why those three warnings exist at all.
MAX_BODY_PT = 17.0

# The running folio's size at BASELINE_BODY_PT. It sits outside TYPE_SCALE
# because Chromium renders the header and footer in a separate document that the
# page's own stylesheet never reaches, so the table cannot govern it. It shares
# the table's arithmetic all the same: not being governed by the table and not
# being able to use its ratio are different claims, and only the first is true.
FOOTER_PT = 8

# The running title is capped at 5in by footer_template and ellipsized past it,
# so the characters that survive fall as the folio grows. Measured in Chromium
# at the footer's own stack and letter-spacing on 2026-09-10: 77 characters fit
# at 8pt, 66 at 9.5pt, 56 at 11.5pt. Those products run 616 to 644; this takes
# the low end so the warning fires slightly early rather than slightly late. A
# missed warning ships a cut title, a spurious one costs a glance.
TITLE_CHARS_PER_PT = 616.0

# Characters of a fenced line that survive into the PDF's text layer, per point
# of the scaled `pre` size. A line wider than the measure is cut rather than
# wrapped, because `.chapter pre` carries `overflow-x: auto`, which scrolls on a
# screen and simply stops at the margin on paper. The cut text is absent from
# the text layer too, so it cannot be copied out either. Measured 2026-09-10 at
# 11.8, 14 and 17pt of body, against 8.8, 10.4 and 12.7pt of `pre`: 80, 68 and
# 55 characters survived. Those products run 698.5 to 707; this takes the low
# end so the warning fires slightly early, for the reason TITLE_CHARS_PER_PT
# does. The thresholds it yields are 79, 67 and 54.
CODE_CHARS_PER_PT = 698.0


def scaled_pt(pt: float, body_pt: float) -> float:
    """A design size at `body_pt`, on the one ratio the whole book scales by."""
    return round(pt * (body_pt / TYPE_SCALE["body"]), 1)


def scaled(pt: float, body_pt: float) -> str:
    """`scaled_pt` formatted the way CSS_TEMPLATE's literals were written.

    One decimal is the precision the hand-written sizes already carried, so a
    body of BASELINE_BODY_PT reproduces every one of them exactly rather than to
    within a rounding error. That is what makes the scaling provable.
    """
    return f"{scaled_pt(pt, body_pt):g}"


def build_css(body_pt: float = BASELINE_BODY_PT) -> str:
    """The stylesheet with every reading size scaled to `body_pt`.

    The parameter defaults to BASELINE_BODY_PT and not to DEFAULT_BODY_PT, which
    looks wrong and is the point: a bare build_css() means "the stylesheet as it
    was hand-written", and it returns those literals byte for byte. That
    equality is the check the scaling is proved by, so it has to stay reachable
    without passing an argument. `main` always passes the size the reader asked
    for, so the default here is never what binds a book. See `scaled` for why
    the rounding makes the equality exact rather than approximate.
    """
    sizes = {name: scaled(pt, body_pt) for name, pt in TYPE_SCALE.items()}
    # Not a type size and so not in TYPE_SCALE: the slide column is a share of
    # the measure and does not move with the body. Scaling it would widen the
    # art in a large-print binding, which is the opposite of what that reader
    # needs -- their text wants more of the line, not less.
    sizes["slideshare"] = f"{SLIDE_WIDTH_SHARE * 100:.0f}"
    return Template(CSS_TEMPLATE).substitute(sizes)


EMPTY_HEADER = '<div style="display:none"></div>'


def footer_template(title: str, body_pt: float = BASELINE_BODY_PT) -> str:
    """The running title and folio Chromium prints into the bottom margin.

    The folio scales with the body for the reason the Contents rows do: it is
    the page number a large-print reader has to read, and it is the one on the
    page the Contents entry points at. Left at 8pt it would be the smallest type
    in a large-print book and the only type that mattered for navigating it.

    This size lives here rather than in CSS_TEMPLATE because Chromium builds
    the header and footer in a separate document that the page's own stylesheet
    never reaches, so TYPE_SCALE cannot govern it. It is the one size outside
    that table, and it still scales on the table's own ratio.

    The title's `max-width` beside it does NOT scale, and that is a limit rather
    than an oversight: the footer's content box is 6.0in, so recovering at
    11.5pt the character count the title gets at 8pt would need a cap wider than
    the page allows. Growing type in a fixed box means fewer characters, and the
    only honest response is to say so. `main` warns when a title will be cut.

    This limit reaches further than it used to. 9.5pt is the folio at the
    14.0pt default, so a title draws a warning past 64 characters and is
    actually cut past 66, on an ordinary build rather than on one that asked
    for large print. Asking for large print at 17.0pt takes the folio to 11.5pt
    and those two numbers to 53 and 56. They differ from each other because
    TITLE_CHARS_PER_PT is calibrated to fire early on purpose.

    The parameter defaults to BASELINE_BODY_PT for the reason build_css does:
    no argument means the footer as it was hand-written. `main` always passes
    the real size.
    """
    pt = scaled(FOOTER_PT, body_pt)
    safe = html_mod.escape(title)
    return (
        '<div style="width:100%; font-family:-apple-system,system-ui,sans-serif;'
        f' font-size:{pt}pt; color:#8a8a8a; padding:0 1.25in;'
        ' display:flex; justify-content:space-between; align-items:center;">'
        f'<span style="letter-spacing:0.06em; overflow:hidden;'
        f' text-overflow:ellipsis; white-space:nowrap; max-width:5in;">{safe}</span>'
        '<span class="pageNumber"></span></div>'
    )


# --------------------------------------------------------------------------
# Input
# --------------------------------------------------------------------------

def markdown_renderer() -> MarkdownIt:
    return MarkdownIt("gfm-like").disable("linkify").use(tasklists_plugin)


def prettify(stem: str) -> str:
    """Turn '03-why-models-matter' into 'Why Models Matter'."""
    s = re.sub(r"^[\W_]*\d+[\W_]+", "", stem)
    s = re.sub(r"[-_]+", " ", s).strip()
    return s[:1].upper() + s[1:] if s else stem


def load_config(src: Path) -> dict:
    path = src / "book.json"
    if not path.is_file():
        return {}
    try:
        cfg = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        sys.exit(f"error: {path} is not valid JSON ({exc})")
    if not isinstance(cfg, dict):
        sys.exit(f"error: {path} must hold a JSON object")
    return cfg


# A provenance mark records where a unit of a chapter came from, for the checker
# and for /updatebook. It is working metadata, never content, so it comes off
# here rather than being left to render as an invisible HTML comment. Two
# reasons it has to be stripped rather than tolerated: markdown-it passes an
# HTML comment straight through into the output, so it would ship inside the
# PDF's and the EPUB's markup, and strip_markdown does not remove comments, so
# every source name inside one would reach the term harvest and put "syllabus"
# and "outline" in the index.
PROVENANCE_RE = re.compile(r"^[ \t]*<!--[ \t]*src:.*?-->[ \t]*$\n?", re.M)

# A paragraph tag is an address other files cite, and in the default edition it
# reaches the printed page by design: the operator working on the book wants it
# there. A reader does not, which is what the reading edition is for. The
# appendix form carries an A before the first number
# (createbook/reference/guide.md § Appendices).
#
# Anchored to the start of a line, because that is the only place a tag is a
# tag. A bracketed pair of numbers mid-sentence is prose the book wrote and
# stripping it would silently edit the text.
PARA_TAG_RE = re.compile(r"^\[A?\d+-\d+[a-z]?\] ", re.M)

# An appendix is a chapter-kind file holding reference matter, bound after the
# chapters and before the glossary
# (createbook/reference/guide.md § Appendices). The filename is what
# says so, and it is the same pattern check-book.sh recognises: `-appendix-N-`
# where a chapter carries `-NN-`. `a` sorts after every digit, so the plain
# filename sort that orders the book already puts these last.
#
# The binder still numbers every file sequentially for its own purposes --
# probes, figure numbers, the index -- and that number is not what the reader
# is shown. What they are shown is the label.
APPENDIX_FILE_RE = re.compile(r"-appendix-(\d+)-[a-z0-9-]+\.md$")

# The two header rows the reading edition moves to chapter endnotes. They are
# the operator's rows rather than the reader's: an inventory of sources at the
# head of every chapter is furniture the reader scrolls past to reach the prose
# (createbook/reference/guide.md § The chapter header). They are moved
# rather than cut, because check-provenance.sh and the review passes read them
# and the source file is never touched.
# The chapter header table ends where the first H2 begins, which for a guide
# chapter is "## In short" and for any chapter is the first part heading.
FIRST_H2_RE = re.compile(r"^[ \t]*##[ \t]", re.M)

HEADER_NOTE_RE = re.compile(
    r"^[ \t]*\|[ \t]*\*\*(Draws on|Fills in)\*\*[ \t]*\|(?P<body>.*?)\|[ \t]*$\n?",
    re.M)
CODE_SPAN_RE = re.compile(r"`([^`\n]+)`")
SOURCE_ROW_RE = re.compile(r"^[ \t]*\|[ \t]*\*\*(Draws on|Fills in)\*\*[ \t]*\|")


# A key that looks like a repo path: the test check-book.sh uses to decide a
# key must not reach the page, so the two tools agree on which keys those are.
PATH_KEY_RE = re.compile(r"(\.(md|py|sh|json|ya?ml|txt|csv)([^a-z0-9]|$)|/)")
ARTICLE_TAIL_RE = re.compile(r"(?:^|(?<=[\s(]))(the|a|an) $", re.I)


def source_displays(cfg: dict) -> dict[str, str]:
    """book.json's reader-facing names for the sources whose keys are paths.

    A `sources` value may be a path, a list of paths, or an object carrying a
    `display` beside its path (createbook/SKILL.md § 4). Only a key that looks
    like a repo path is returned. A key like "syllabus" already reads as a name,
    and the header writes it as one, "the syllabus § 4"; swapping it for a
    display name that starts with its own article printed "the the syllabus" in
    34 header rows of two real guide books.
    """
    out = {}
    for key, val in (cfg.get("sources") or {}).items():
        if not PATH_KEY_RE.search(key):
            continue
        if isinstance(val, dict) and isinstance(val.get("display"), str) \
                and val["display"].strip():
            out[key] = val["display"].strip()
    return out


def swap_display_names(text: str, displays: dict[str, str]) -> str:
    """Put each source's display name where the chapter header names its key.

    The header's Draws-on row is an inventory written for the operator, so it
    names sources by the key the marks and check-provenance.sh use, which is
    often a repo path: `CLAUDE.md § Teaching Calendar`. The default edition
    prints that row and the reading edition prints the same text as an
    endnote, so without this a reader of either was shown a path they cannot
    open. The markdown is never touched; this runs on the text being bound.

    Only the `Draws on` and `Fills in` rows are touched: they are where the
    header names sources. The `Act on this` row, the `This chapter` row and a
    narration chapter's opening paragraph are the author's words for a reader.

    A code span whose content is a key, or a key followed by a locator, becomes
    the display name and the locator as plain text: `` `docs/build.md § Caching` ``
    reads "the build docs § Caching". A bare key is swapped where it stands.
    Where the row already puts an article in front of the key and the display
    name starts with one, the row's article is kept and the name's dropped, so
    "the `docs/build.md`" reads "the build docs", never "the the build docs".
    Longer keys are tried first, so a key that is a prefix of another never
    claims the other's text.
    """
    if not displays:
        return text
    keys = sorted(displays, key=len, reverse=True)
    bare = re.compile(r"(?<![\w/.-])(" + "|".join(re.escape(k) for k in keys)
                      + r")(?![\w/-])")

    def named(key: str, before: str) -> str:
        name = displays[key]
        head, _, tail = name.partition(" ")
        if tail and head.lower() in ("the", "a", "an") and ARTICLE_TAIL_RE.search(before):
            return tail
        return name

    def row(line: str) -> str:
        if not SOURCE_ROW_RE.match(line):
            return line
        out, pos = [], 0
        for m in CODE_SPAN_RE.finditer(line):
            out.append(line[pos:m.start()])
            inner, done = m.group(1), m.group(0)
            for k in keys:
                if inner == k or inner.startswith(k + " ") or inner.startswith(k + ","):
                    done = named(k, "".join(out)) + inner[len(k):]
                    break
            out.append(done)
            pos = m.end()
        out.append(line[pos:])
        # Bare keys, outside the code spans just handled.
        parts = re.split(r"(`[^`\n]+`)", "".join(out))
        for i in range(0, len(parts), 2):
            prefix = "".join(parts[:i])
            parts[i] = bare.sub(
                lambda m, i=i: named(m.group(1), prefix + parts[i][:m.start()]),
                parts[i])
        return "".join(parts)

    return "\n".join(row(ln) for ln in text.split("\n"))


def load_chapters(src: Path, skip: set[str], reading: bool = False,
                  displays: dict[str, str] | None = None) -> list[dict]:
    """Chapter records, one per markdown file in filename-sort order.

    `reading` selects the reading edition: paragraph tags come off the page and
    the header's `Draws on` and `Fills in` rows move to chapter endnotes. The
    source file is never touched, so the tags other files cite keep resolving
    and the two editions bind from one folder.

    `displays` maps a source key to its reader-facing name, and in both editions
    the chapter header shows the name where it named the key
    (swap_display_names). The endnotes are built from the header after the
    swap, so they show it too.

    The term harvest reads `plain`, which is built from the text before either
    change. Both editions carry the same words on the page -- the rows moved
    rather than went -- so an index that moved with the edition would be
    reporting the edition rather than the book.
    """
    md = markdown_renderer()
    chapters = []
    for path in sorted(src.glob("*.md")):
        if path.name in skip:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            sys.exit(f"error: {path} is not UTF-8")
        text = PROVENANCE_RE.sub("", text)
        lines = text.splitlines()
        if lines and lines[0].startswith("# "):
            title = lines[0][2:].strip()
            body_md = "\n".join(lines[1:]).strip()
        else:
            title = prettify(path.stem)
            body_md = text.strip()
        harvest_md = body_md
        notes: list[tuple[str, str]] = []
        if displays:
            # The header only: the table above the first H2. The prose is held
            # to display names already (check-book.sh fails a path-like key
            # there), and a chapter quoting a key in a fenced block is showing
            # the key on purpose.
            split = FIRST_H2_RE.search(body_md)
            cut = split.start() if split else len(body_md)
            body_md = swap_display_names(body_md[:cut], displays) + body_md[cut:]
        if reading:
            body_md = PARA_TAG_RE.sub("", body_md)
            # Only the chapter header table, which sits under the H1 and above
            # the first H2. Applied to the whole body this reaches any table
            # whose first cell happens to read **Draws on** -- a book about
            # this format has exactly such a table -- and silently relocates
            # somebody's row into the endnotes. Scoping it to the header keeps
            # the rest of the chapter's tables the author's.
            split = FIRST_H2_RE.search(body_md)
            cut = split.start() if split else len(body_md)
            head, rest = body_md[:cut], body_md[cut:]
            notes = [(m.group(1), m.group("body").strip())
                     for m in HEADER_NOTE_RE.finditer(head)]
            body_md = HEADER_NOTE_RE.sub("", head) + rest
        body_html = boxify_callouts(md.render(body_md))
        if notes:
            body_html += build_endnotes(md, notes)
        am = APPENDIX_FILE_RE.search(path.name)
        chapters.append({
            "appendix": bool(am),
            "label_num": int(am.group(1)) if am else len(chapters) + 1,
            "num": len(chapters) + 1,
            "path": path,
            "title": title,
            "body_html": body_html,
            "plain": strip_markdown(f"{title}\n\n{harvest_md}"),
            "fenced": fenced_lines(body_md),
        })
    return chapters


# The four callout labels of the guide profile
# (createbook/reference/guide.md § Callouts). markdown-it
# renders each as an ordinary blockquote, which on the page is a grey rule and
# nothing else: the label is the only thing saying what kind of sentence the
# reader is in, and it reads as bold prose inside a quotation. Boxing them is
# what makes the signal visible at a glance, which is the whole reason the
# profile allows them.
#
# Matched on the rendered HTML rather than the markdown because the label has to
# come out of the paragraph to become the box title, and by render time it is
# already <strong>. Blockquotes do not nest here, so the non-greedy run to
# </blockquote> is exact.
CALLOUT_LABELS = {
    "Decide": "decide",
    "Warning": "warning",
    "In the room": "room",
    "Grade this": "grade",
}
CALLOUT_RE = re.compile(
    r"<blockquote>\s*<p>\s*<strong>(?P<label>"
    + "|".join(re.escape(k) for k in CALLOUT_LABELS)
    + r")\.</strong>\s*(?P<rest>.*?)</blockquote>",
    re.S,
)


def boxify_callouts(body_html: str) -> str:
    """Render the profile's labelled block quotes as boxed asides.

    A block quote that is not one of the four is left exactly as it was. Under
    the guide profile check-book.sh has already refused it, and under narration
    it refused every block quote, so anything reaching here untouched is a book
    that was never checked -- which is not a reason to restyle it.
    """
    def one(m: re.Match) -> str:
        label = m.group("label")
        slug = CALLOUT_LABELS[label]
        rest = m.group("rest").rstrip()
        if rest.endswith("</p>"):
            rest = rest[: -len("</p>")].rstrip()
        return (f'<aside class="callout callout-{slug}">'
                f'<p class="callout-title">{html_mod.escape(label)}</p>'
                f'<p class="callout-body">{rest}</p></aside>')
    return CALLOUT_RE.sub(one, body_html)


def build_endnotes(md, notes: list[tuple[str, str]]) -> str:
    """The moved header rows, rendered at the foot of the chapter.

    Rendered inline rather than as markdown blocks because a row's content is a
    sentence with inline code and links in it, not a document: `renderInline`
    keeps the code spans and leaves out the wrapping paragraph that would put a
    blank line between the label and its text.
    """
    rows = "".join(
        f'<p class="endnote"><span class="endnote-label">{html_mod.escape(label)}.</span> '
        f'{md.renderInline(body)}</p>'
        for label, body in notes
    )
    return (f'<section class="endnotes"><h2 class="endnotes-title">Notes</h2>'
            f'{rows}</section>')


def fenced_lines(body_md: str) -> list[str]:
    """Every line inside a fenced code block, in order.

    Collected by toggling on fence markers line by line rather than with the
    non-greedy regex `strip_markdown` uses. That one pairs a fence with the next
    one anywhere in the file, which is the right shape for deleting code and the
    wrong shape for locating particular lines inside it.

    The whole set is kept rather than the longest, so the build can report every
    line that will be cut instead of only the worst one. A book can carry
    several over-long commands and hearing about one of them is how the other
    two ship.
    """
    out, inside = [], False
    for line in body_md.splitlines():
        if line.lstrip().startswith("```"):
            inside = not inside
            continue
        if inside:
            out.append(line)
    return out


def strip_markdown(text: str) -> str:
    """Plain text for term harvesting: no fences, links, or markup noise."""
    text = re.sub(r"```.*?```", " ", text, flags=re.S)
    # SVG source is markup, not prose; harvesting it would index "viewBox".
    text = re.sub(r"<svg\b.*?</svg>", " ", text, flags=re.S | re.I)
    text = re.sub(r"`([^`]*)`", r"\1", text)
    text = re.sub(r"!\[[^\]]*\]\([^)]*\)", " ", text)
    text = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", text)
    text = re.sub(r"^\s{0,3}#{1,6}\s*", "", text, flags=re.M)
    text = re.sub(r"[*>|]+", " ", text)
    return text


# --------------------------------------------------------------------------
# Index terms
# --------------------------------------------------------------------------

def singularize(word: str) -> str:
    if len(word) > 4 and word.endswith("ies"):
        return word[:-3] + "y"
    if len(word) > 4 and word.endswith(("sses", "shes", "ches", "xes")):
        return word[:-2]
    if len(word) > 3 and word.endswith("s") and not word.endswith(("ss", "us", "is")):
        return word[:-1]
    return word


def term_regex(key: str) -> str:
    """Match a canonical key, tolerating plurals and hyphens between words."""
    words = key.split()
    parts = [re.escape(w) for w in words[:-1]]
    last = words[-1]
    # "query" pluralises to "queries", but "key" pluralises to "keys", so the
    # y->ies rule only applies after a consonant.
    if len(last) > 3 and last.endswith("y") and last[-2].lower() not in "aeiou":
        parts.append(re.escape(last[:-1]) + r"(?:y|ies)")
    elif last.endswith("s"):
        parts.append(re.escape(last))
    else:
        parts.append(re.escape(last) + r"(?:e?s)?")
    return r"\b" + r"[\s\-/]+".join(parts) + r"\b"


def harvest_terms(chapters: list[dict], max_terms: int) -> list[tuple[str, str, bool]]:
    """Pull index-worthy terms out of the corpus itself."""
    uses: Counter[str] = Counter()
    per_doc: dict[str, Counter[int]] = defaultdict(Counter)
    forms: dict[str, Counter[str]] = defaultdict(Counter)

    for i, ch in enumerate(chapters):
        for clause in CLAUSE_SPLIT_RE.split(ch["plain"]):
            toks = TOKEN_RE.findall(clause)
            if not toks:
                continue
            lows = [t.lower() for t in toks]
            for n in (1, 2, 3):
                for j in range(len(toks) - n + 1):
                    win_low, win_raw = lows[j:j + n], toks[j:j + n]
                    if win_low[0] in STOPWORDS or win_low[-1] in STOPWORDS:
                        continue
                    if any(len(w) < 2 for w in win_low):
                        continue
                    if n == 1 and len(win_low[0]) < 4 and not win_raw[0].isupper():
                        continue
                    key = " ".join(win_low[:-1] + [singularize(win_low[-1])])
                    uses[key] += 1
                    per_doc[key][i] += 1
                    forms[key][" ".join(win_raw)] += 1

    def modal_form(key: str) -> str:
        return forms[key].most_common(1)[0][0]

    def is_acronym(key: str) -> bool:
        top = modal_form(key)
        return len(key.split()) == 1 and top.isupper() and len(top) >= 2

    def is_identifier(key: str) -> bool:
        return "_" in key or bool(re.search(r"[a-z]\d", key))

    docs = {k: set(c) for k, c in per_doc.items()}
    total_docs = max(1, len(chapters))

    kept: dict[str, int] = {}
    for key, count in uses.items():
        multiword = len(key.split()) > 1
        marked = is_acronym(key) or is_identifier(key)
        spread = len(docs[key]) / total_docs
        peak = max(per_doc[key].values()) / count
        if marked:
            if count >= MIN_MARKED_USES:
                kept[key] = count
        elif multiword:
            if (count >= MIN_PHRASE_USES and spread <= MAX_PHRASE_SPREAD
                    and peak >= MIN_PHRASE_PEAK):
                kept[key] = count
        else:
            if (count >= MIN_WORD_USES and spread <= MAX_WORD_SPREAD
                    and peak >= MIN_WORD_PEAK):
                kept[key] = count

    # Drop a phrase that is nearly always swallowed by a longer kept phrase.
    by_length = sorted(kept, key=lambda k: -len(k.split()))
    doomed: set[str] = set()
    for short in kept:
        s_words = short.split()
        for long in by_length:
            if len(long.split()) <= len(s_words) or long in doomed:
                continue
            if f" {short} " in f" {long} " and kept[long] >= 0.65 * kept[short]:
                doomed.add(short)
                break
    survivors = {k: v for k, v in kept.items() if k not in doomed}

    def score(key: str) -> float:
        words = len(key.split())
        weight = 2.0 if words > 1 else (1.6 if is_acronym(key) or is_identifier(key) else 1.0)
        concentration = math.log(1 + total_docs / len(docs[key]))
        return survivors[key] * weight * (1 + concentration)

    chosen = sorted(survivors, key=score, reverse=True)[:max_terms]

    terms = []
    for key in chosen:
        last = key.split()[-1]
        best = sorted(
            forms[key].items(),
            key=lambda kv: (
                kv[1] * (2 if kv[0].split()[-1].lower() == last else 1),
                -sum(c.isupper() for c in kv[0]),
            ),
            reverse=True,
        )[0][0]
        display = best if best.split()[-1].lower() == last else key
        if is_acronym(key):
            # Match the acronym as it is written, and only in that casing, so
            # SCAN does not pick up every ordinary "scan" in the prose.
            terms.append((display, r"\b" + re.escape(display) + r"s?\b", True))
        else:
            terms.append((display, term_regex(key), False))

    terms.sort(key=lambda t: t[0].lower())
    return terms


def load_terms_file(path: Path) -> list[tuple[str, str, bool]]:
    """One term per line. '!' prefix means case-sensitive. '|' gives a regex."""
    terms = []
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        cased = line.startswith("!")
        line = line[1:].strip() if cased else line
        if "|" in line:
            display, pattern = (p.strip() for p in line.split("|", 1))
        else:
            # A case-sensitive term keeps its casing in the pattern, or !STRICT
            # would compile to lowercase and match nothing.
            words = line.split()
            if not cased:
                words = [w.lower() for w in words]
            display = line
            pattern = term_regex(" ".join(words[:-1] + [singularize(words[-1])]))
        terms.append((display, pattern, cased))
    terms.sort(key=lambda t: t[0].lower())
    return terms


# A glossary entry is one paragraph: the term in bold, the chapter that defines
# it, then the definition. That reads as ordinary markdown to anyone editing the
# file by hand and still parses strictly, so a malformed entry is reported here
# rather than rendered as something that looks deliberate.
#
# The chapter reference is optional in the grammar and wanted in practice. It is
# what makes a glossary entry a pointer back into the prose that defines the term
# properly, rather than a replacement for reading it.
# \s rather than [ \t] around the chapter reference, because an entry that wraps
# puts a newline exactly there. Matching only spaces made a wrapped entry parse
# with no chapter and the literal "(ch. 14)" absorbed into its definition, which
# is the silent-wrong-output case this parser exists to make loud.
#
# The lookahead in `body` closes the same fault from the other side. Because the
# chapter reference is optional it can be given back on backtracking, so an entry
# with a reference and no definition ("**Gamma** (ch. 3)") would otherwise match
# with no chapter and "(ch. 3)" as the whole definition, and print exactly that.
# Refusing a body that is only a reference makes the group's failure the entry's
# failure, which is what the format promise in SKILL.md says happens.
GLOSSARY_ENTRY_RE = re.compile(
    r"^\*\*(?P<term>[^*\n]+?)\*\*\s*"
    r"(?:\(ch\.\s*(?P<ch>\d+)\)\s*)?"
    r"(?P<body>(?!\(ch\.\s*\d+\)\s*$)\S.*)$",
    re.S,
)


def load_glossary(path: Path) -> list[tuple[str, int | None, str]]:
    """Parse a glossary file into sorted (term, chapter, definition) entries."""
    entries: list[tuple[str, int | None, str]] = []
    bad: list[str] = []
    for block in re.split(r"\n[ \t]*\n", path.read_text(encoding="utf-8")):
        block = block.strip()
        # A heading is the file's own title, not an entry. Everything else has
        # to parse: silently skipping an unrecognised block is how a glossary
        # ends up quietly missing the term someone came looking for.
        if not block or block.startswith("#"):
            continue
        m = GLOSSARY_ENTRY_RE.match(block)
        if not m:
            bad.append(" ".join(block.split())[:72])
            continue
        entries.append((
            m.group("term").strip(),
            int(m.group("ch")) if m.group("ch") else None,
            " ".join(m.group("body").split()),
        ))
    if bad:
        sys.exit(
            f"error: {path.name} holds {len(bad)} entry/entries that do not read "
            f"'**term** (ch. N) definition':\n  " + "\n  ".join(bad))
    if not entries:
        sys.exit(f"error: {path.name} holds no glossary entries")
    seen: dict[str, int] = {}
    for term, _, _ in entries:
        key = term.lower()
        seen[key] = seen.get(key, 0) + 1
    dupes = sorted(t for t, n in seen.items() if n > 1)
    if dupes:
        sys.exit(f"error: {path.name} defines these terms more than once, so one "
                 f"of each pair is unreachable: {', '.join(dupes)}")
    entries.sort(key=lambda e: gloss_sort_key(e[0]))
    return entries


# A glossary term may be an identifier, and an identifier is written in a code
# span: `PRAGMA foreign_keys`, `STRICT`. Sorting on the raw text puts those
# under the backtick, which collates before every letter, so the two entries
# that most look like they need looking up were filed under "#" at the top of
# the page instead of under P and S.
#
# The same strip drives the letter heading, so the fix lands in both places from
# one definition rather than from two that can disagree. The index builders
# below sort the same way and need no such strip: they harvest from prose that
# strip_markdown has already taken the backticks out of.
GLOSS_MARKUP_RE = re.compile(r"[`*_]")


def gloss_sort_key(term: str) -> str:
    """The term as a reader would look for it: markup off, case folded."""
    return GLOSS_MARKUP_RE.sub("", term).strip().lower()


def inline_code_html(text: str) -> str:
    """Escape for HTML, then render `code spans` as <code>.

    Escaping first is what makes this safe: html.escape leaves the backtick
    alone, so the spans are still findable afterwards, and any < or & inside one
    has already been made inert.
    """
    out = html_mod.escape(text)
    return re.sub(r"`([^`]+)`", r"<code>\1</code>", out)


def build_term_index(terms, pages_text: list[str], body_start: int,
                     body_end: int, footer: str):
    """Locate every term's pages inside the body range (inclusive, 1-based)."""
    cleaned = []
    for text in pages_text:
        t = PROBE_RE.sub(" ", text).replace(footer, " ")
        cleaned.append(re.sub(r"\s+", " ", t))

    entries, missing, narrowed = [], [], []
    for display, pattern, cased in terms:
        try:
            rx = re.compile(pattern, 0 if cased else re.IGNORECASE)
        except re.error as exc:
            sys.exit(f"error: bad pattern for {display!r}: {exc}")
        counts = {
            p: len(rx.findall(cleaned[p - 1]))
            for p in range(body_start, body_end + 1)
            if p - 1 < len(cleaned)
        }
        hits = {p: c for p, c in counts.items() if c}
        if not hits:
            missing.append(display)
            continue
        if len(hits) <= MAX_PAGES_PER_TERM:
            entries.append((display, sorted(hits)))
            continue
        # Too common to list every mention. Raise the bar until the list fits.
        chosen, rule = None, None
        for threshold in range(2, 12):
            dense = [p for p, c in hits.items() if c >= threshold]
            if 0 < len(dense) <= MAX_PAGES_PER_TERM:
                chosen, rule = sorted(dense), f">={threshold} uses/page"
                break
        if chosen is None:
            top = sorted(hits.items(), key=lambda x: (-x[1], x[0]))[:MAX_PAGES_PER_TERM]
            chosen, rule = sorted(p for p, _ in top), "densest pages"
        narrowed.append((display, len(hits), len(chosen), rule))
        entries.append((display, chosen))

    entries.sort(key=lambda e: e[0].lower())
    return entries, missing, narrowed


# --------------------------------------------------------------------------
# HTML
# --------------------------------------------------------------------------

def probe(tag: str) -> str:
    return f'<span class="probe">ZQ{tag}QZ</span>'


def default_description(title: str, chapters: list[dict], src: Path) -> str:
    n = len(chapters)
    return (
        f"<p>{html_mod.escape(title)} collects {n} "
        f"chapter{'s' if n != 1 else ''} from "
        f"<span class='mono'>{html_mod.escape(src.name)}</span>, in the order "
        "the files sort. Each chapter is one source document, and its title is "
        "that document's own heading.</p>"
        "<p>The contents page and the index carry physical page numbers, so "
        "they match your reader's page indicator. The index lists the terms "
        "that recur across the chapters and the pages they appear on.</p>"
    )


def bind_stamp() -> str:
    """The line both covers print under the byline: when this binding ran, in
    local time with the zone's abbreviation, or its UTC offset (+04) where the
    zone has none.

    It is the bound book's version marker. Two bindings of one folder otherwise
    look the same to a reader, down to the EPUB's identifier, which is derived
    from the folder and the title so a re-send replaces the book on a device.
    The PDF's CreationDate and the EPUB's dcterms:modified do record a time,
    but only in metadata a reader never sees. Seconds are kept because a
    rebind after a one-line fix can land inside the same minute. Read once per
    run by the caller, never per cover, so the PDF, its every settling pass,
    and the EPUB all carry the same one.
    """
    return f"Created: {datetime.now().astimezone():%Y-%m-%d %H:%M:%S %Z}"


def build_cover(title, cfg, chapters, src, stamp: str) -> str:
    md = markdown_renderer()
    desc = cfg.get("description")
    if isinstance(desc, list):
        desc = "\n\n".join(desc)
    if desc:
        desc_html = md.render(desc)
    elif cfg.get("description_file"):
        p = src / cfg["description_file"]
        if not p.is_file():
            sys.exit(f"error: description_file {p} not found")
        desc_html = md.render(p.read_text(encoding="utf-8"))
    else:
        desc_html = default_description(title, chapters, src)

    # The probe rides inside the cover's last paragraph, so the page it lands
    # on is the page the cover ends on. Anything but 1 means the cover spilled.
    bits = ['<section class="cover">', '<div class="rule-top"></div>']
    if cfg.get("eyebrow"):
        bits.append(f'<div class="eyebrow">{html_mod.escape(cfg["eyebrow"])}</div>')
    bits.append(f"<h1>{html_mod.escape(title)}</h1>")
    if cfg.get("subtitle"):
        bits.append(f'<div class="subtitle">{html_mod.escape(cfg["subtitle"])}</div>')
    if cfg.get("byline"):
        bits.append(f'<div class="byline">{html_mod.escape(cfg["byline"])}</div>')
    bits.append(f'<div class="stamp">{html_mod.escape(stamp)}</div>')
    bits.append('<div class="head-rule"></div>')
    if cfg.get("footnote"):
        bits.append(f'<div class="description">{desc_html}</div>')
        bits.append('<div class="footnote">'
                    f'{with_probe(md.render(cfg["footnote"]), "ZQCOVERENDQZ")}</div>')
    else:
        bits.append(f'<div class="description">'
                    f'{with_probe(desc_html, "ZQCOVERENDQZ")}</div>')
    bits.append("</section>")
    return "".join(bits)


def with_probe(html_text: str, tag: str) -> str:
    """Tuck an invisible probe inside the last paragraph, where it adds no
    height. Appended after a non-paragraph ending, it costs one 5pt line."""
    probe = f'<span class="probe">{tag}</span>'
    s = html_text.rstrip()
    if s.endswith("</p>"):
        return s[:-4] + probe + "</p>"
    return s + probe


def group_for(num: int, sections: list[dict]) -> str | None:
    for sec in sections:
        if num in sec.get("chapters", []):
            return sec.get("title")
    return None


def build_toc(chapters, cfg, pages, index_page, has_index,
              has_figures=False, lof_page=None,
              has_glossary=False, gloss_page=None) -> str:
    sections = cfg.get("sections") or []
    rows, current = [], object()
    if has_figures:
        lof = str(lof_page) if lof_page else "&nbsp;"
        rows.append(
            '<div class="toc-row toc-front">'
            '<span class="toc-num"></span>'
            '<span class="toc-title">Figures</span>'
            '<span class="toc-dots"></span>'
            f'<span class="toc-page">{lof}</span></div>'
        )
    for ch in chapters:
        grp = group_for(ch["num"], sections)
        if grp != current:
            if grp:
                rows.append(f'<div class="toc-group">{html_mod.escape(grp)}</div>')
            current = grp
        pg = str(pages[ch["num"]]) if pages else "&nbsp;"
        rows.append(
            '<div class="toc-row">'
            f'<span class="toc-num">'
            f'{"A" if ch.get("appendix") else ""}'
            f'{ch.get("label_num", ch["num"])}</span>'
            f'<span class="toc-title">{html_mod.escape(ch["title"])}</span>'
            '<span class="toc-dots"></span>'
            f'<span class="toc-page">{pg}</span>'
            "</div>"
        )
    if has_glossary:
        gl = str(gloss_page) if gloss_page else "&nbsp;"
        rows.append(
            '<div class="toc-row toc-back">'
            '<span class="toc-num"></span>'
            '<span class="toc-title">Glossary</span>'
            '<span class="toc-dots"></span>'
            f'<span class="toc-page">{gl}</span></div>'
        )
    if has_index:
        back = str(index_page) if index_page else "&nbsp;"
        rows.append(
            '<div class="toc-row toc-back">'
            '<span class="toc-num"></span>'
            '<span class="toc-title">Index</span>'
            '<span class="toc-dots"></span>'
            f'<span class="toc-page">{back}</span></div>'
        )
    lead = cfg.get(
        "contents_note",
        "Page numbers are the physical pages of this PDF, so they match your "
        "reader's page indicator.",
    )
    return (
        '<section class="frontmatter">'
        + probe("TOCSTART")
        + '<h2 class="section-title">Contents</h2>'
        + f'<p class="lead">{html_mod.escape(lead)}</p>'
        + "".join(rows)
        + "</section>"
    )


# -- Figures ---------------------------------------------------------------
#
# Diagrams are SVG, and nothing renders them but Chromium, which is already
# here. That is the whole reason this skill needs no diagram toolchain: no
# graphviz binary, no mermaid bundle, no network. See references/diagram-style.md.

SVG_FENCE_RE = re.compile(
    r'<pre><code class="language-svg">(.*?)</code></pre>', re.S)
# A raw <svg> may or may not be wrapped in a paragraph: markdown-it treats an
# opening tag alone on a line as an HTML block and leaves it bare, but an
# indented or inline one ends up inside <p>. Handle both.
SVG_PARA_RE = re.compile(r"<p>\s*(<svg\b.*?</svg>)\s*</p>", re.S | re.I)
SVG_BARE_RE = re.compile(r"(<svg\b.*?</svg>)", re.S | re.I)
IMG_PARA_RE = re.compile(r"<p>\s*(<img\b[^>]*>)\s*</p>", re.S | re.I)
SVG_TITLE_RE = re.compile(r"<title[^>]*>(.*?)</title>", re.S | re.I)
ALT_RE = re.compile(r'\balt="([^"]*)"', re.I)
SRC_RE = re.compile(r'\bsrc="([^"]*)"', re.I)
TAG_RE = re.compile(r"<[^>]+>")
CSS_RULE_RE = re.compile(r"([^{}]+)\{([^{}]*)\}", re.S)
VIEWBOX_RE = re.compile(r'viewBox="([^"]+)"', re.I)
FONT_PX_RE = re.compile(r'font(?:-size)?\s*:[^;{}"]*?([\d.]+)px', re.I)
FONT_ATTR_RE = re.compile(r'font-size="([\d.]+)(?:px)?"', re.I)
# Past this width-to-height ratio a figure squeezed into the text column
# renders its own labels too small to read, so it gets the wider measure.
WIDE_ASPECT = 2.6
# Text column and bleed width, in points, used to convert an SVG font size
# into the size that actually prints.
COLUMN_MEASURE_PT = 432.0   # 6.0in
WIDE_MEASURE_PT = 504.0     # 7.0in
# The one legibility floor, matching references/diagram-style.md rather than
# sitting just under it. This was 7.0 while the style guide asked for 8, so a
# figure landing between the two passed the check and still broke the guidance,
# and the check read as enforcement of a rule it did not enforce. Measured
# across all 43 SVGs in the source repo on 2026-09-10, BEFORE this change: 32
# sat below 7 (slide art that no book binds), 10 sat at or
# above 8, and exactly one lived in the 7-to-8 band. That one was lifted in the
# same commit, so the band is now empty. Nothing legitimately inhabits it, which
# is why this is one number rather than two with a relationship to state.
MIN_LEGIBLE_PT = 8.0
# The resolution floor for a raster figure, in dots per inch at the size it
# prints. This is NOT the legibility floor above and must not be described as
# one. MIN_LEGIBLE_PT measures the text inside a figure; a raster declares no
# text, so nothing here can measure it (see raster_metrics). What this measures
# is how many pixels the image spends per printed inch, which is a different
# defect: a low number is soft edges and visible pixels, and a high number says
# only that the image is finely sampled, never that anything in it is readable.
# 150 is the conventional floor for line art at reading distance, half the 300
# usually asked of print. Chosen as a convention rather than measured here.
MIN_FIGURE_DPI = 150.0


def scope_svg_css(svg: str, fid: str) -> str:
    """An inline SVG's <style> is global to the page, so class names like .st
    collide between figures and leak into the book's own CSS. Confine each
    rule to its own figure."""
    def rewrite(match: re.Match) -> str:
        rules = []
        for rule in CSS_RULE_RE.finditer(match.group(1)):
            selector, body = rule.group(1).strip(), rule.group(2)
            if selector.startswith("@"):          # leave at-rules alone
                rules.append(f"{selector}{{{body}}}")
                continue
            scoped = ",".join(f"#{fid} {s.strip()}"
                              for s in selector.split(",") if s.strip())
            rules.append(f"{scoped}{{{body}}}")
        return "<style>" + "".join(rules) + "</style>"
    return re.sub(r"<style[^>]*>(.*?)</style>", rewrite, svg, flags=re.S | re.I)


def svg_title(svg: str) -> str:
    """The <title> is an SVG's accessible name, so it doubles as the caption."""
    m = SVG_TITLE_RE.search(svg)
    if not m:
        return ""
    return re.sub(r"\s+", " ", html_mod.unescape(TAG_RE.sub("", m.group(1)))).strip()


def svg_min_font_px(svg: str) -> float | None:
    """Smallest declared font size, in the SVG's own user units."""
    sizes = [float(v) for v in FONT_PX_RE.findall(svg)]
    sizes += [float(v) for v in FONT_ATTR_RE.findall(svg)]
    sizes = [s for s in sizes if s > 0]
    return min(sizes) if sizes else None


def svg_legibility(svg: str, wide: bool) -> tuple[float, float] | None:
    """(smallest rendered point size, viewBox width), or None if unknowable.

    An SVG scales to its column, so the size written in the source is not the
    size that prints. Slide-sized art with 10px labels lands near 3pt in a book
    column, which is the single most common way a figure fails silently.
    """
    m = VIEWBOX_RE.search(svg)
    smallest = svg_min_font_px(svg)
    if not m or smallest is None:
        return None
    try:
        nums = [float(v) for v in re.split(r"[\s,]+", m.group(1).strip())]
    except ValueError:
        return None
    if len(nums) != 4 or nums[2] <= 0:
        return None
    measure_pt = WIDE_MEASURE_PT if wide else COLUMN_MEASURE_PT
    return smallest * measure_pt / nums[2], nums[2]


def svg_aspect(svg: str) -> float | None:
    m = VIEWBOX_RE.search(svg)
    if not m:
        return None
    try:
        nums = [float(v) for v in re.split(r"[\s,]+", m.group(1).strip())]
    except ValueError:
        return None
    if len(nums) != 4 or nums[3] <= 0:
        return None
    return nums[2] / nums[3]


def image_size(data: bytes) -> tuple[int, int] | None:
    """(width, height) in pixels, read out of the file header.

    Stdlib only, deliberately: requirements.txt carries no image library, and
    every raster format MEDIA_TYPES packages writes its dimensions into a fixed
    header field. Anything unrecognised returns None rather than a guess, so an
    unmeasurable figure reports as unmeasured instead of reporting as wrong.
    """
    # PNG. The 8-byte signature is followed by an IHDR whose first two fields
    # are the size, big-endian.
    if data[:8] == b"\x89PNG\r\n\x1a\n" and len(data) >= 24:
        w, h = struct.unpack(">II", data[16:24])
        return (w, h) if w and h else None
    # GIF. Little-endian, immediately after the version stamp.
    if data[:6] in (b"GIF87a", b"GIF89a") and len(data) >= 10:
        w, h = struct.unpack("<HH", data[6:10])
        return (w, h) if w and h else None
    # WEBP. One RIFF container over three sub-formats, and two of the three
    # pack the size into bit fields rather than whole bytes.
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP" and len(data) >= 30:
        chunk = data[12:16]
        if chunk == b"VP8 ":
            w, h = struct.unpack("<HH", data[26:30])
            w, h = w & 0x3FFF, h & 0x3FFF
            return (w, h) if w and h else None
        if chunk == b"VP8L":
            bits = int.from_bytes(data[21:25], "little")
            return ((bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1)
        if chunk == b"VP8X":
            return (int.from_bytes(data[24:27], "little") + 1,
                    int.from_bytes(data[27:30], "little") + 1)
        return None
    # JPEG. The size lives only in a start-of-frame header, at no fixed offset,
    # so the segment chain has to be walked to find one.
    if data[:2] == b"\xff\xd8":
        i, n = 2, len(data)
        while i + 9 < n:
            if data[i] != 0xFF:
                i += 1
                continue
            marker = data[i + 1]
            if marker == 0xFF:          # fill byte, not a marker yet
                i += 1
                continue
            # Standalone markers carry no length field to skip over.
            if marker in (0xD8, 0x01) or 0xD0 <= marker <= 0xD7:
                i += 2
                continue
            seg = struct.unpack(">H", data[i + 2:i + 4])[0]
            # SOF0 through SOF15, minus the three in that range that are not
            # frame headers (DHT, JPG, DAC).
            if 0xC0 <= marker <= 0xCF and marker not in (0xC4, 0xC8, 0xCC):
                h, w = struct.unpack(">HH", data[i + 5:i + 9])
                return (w, h) if w and h else None
            if seg < 2:                 # malformed length, walking would loop
                return None
            i += 2 + seg
    return None


def raster_metrics(data: bytes, wide: bool) -> dict | None:
    """What a raster figure can honestly say about how it will print.

    This is **not** the legibility check, and the difference is the whole
    reason it is a separate function. svg_legibility reads the font sizes
    declared in the markup and scales them to the column. A raster declares
    none: its glyphs are pixels, so recovering a text size from one needs OCR,
    and there is no image library here to do it with. What a raster does
    declare is its pixel dimensions, and those give the aspect exactly, the
    effective print resolution exactly, and the size of the text inside it not
    at all. A figure measured here is therefore still unchecked for legibility,
    which is what the `unchecked_text` flag downstream exists to say out loud.
    """
    dims = image_size(data)
    if not dims:
        return None
    px_w, px_h = dims
    measure_in = (WIDE_MEASURE_PT if wide else COLUMN_MEASURE_PT) / 72.0
    return {"px_width": px_w, "px_height": px_h, "dpi": px_w / measure_in}


def slide_dir_of(cfg: dict) -> str:
    """The folder whose figures are lesson-script slides, or "" for none.

    Normalised to a trailing slash so the membership test below is a prefix
    match on a path segment. Without it, "diagrams/slide" would claim
    "diagrams/slides-old/" as well, which is the kind of near-miss that only
    shows up once somebody has such a folder.
    """
    raw = (cfg.get("slide_figures") or "").strip().strip("/")
    return f"{raw}/" if raw else ""


def figurize(body_html: str, chapter_num: int, counter: list[int],
             figures: list[dict], src: Path,
             slide_dir: str = "", slides: list[dict] | None = None,
             fig_prefix: str | None = None) -> str:
    """Wrap diagrams in numbered, captioned <figure> elements.

    Three authoring forms, all dependency-free: an ```svg fence, a raw <svg>
    block, and a paragraph-level markdown image. The caption is the alt text,
    falling back to the SVG's own <title>. An image inside a sentence is left
    inline, since only a standalone image is a figure.

    Matches are stashed behind tokens as they are found, so a later pattern
    cannot reach inside a figure that an earlier one already produced.
    """
    local = [0]
    slots: dict[str, str] = {}
    slide_n = [0]
    # A figure's number names the page it sits on. Inside an appendix that page
    # is headed "Appendix 1", so `3.1` sent a reader looking for a chapter 3
    # the book does not have.
    if fig_prefix is None:
        fig_prefix = str(chapter_num)

    def emit_slide(inner: str, caption: str, is_svg: bool,
                   aspect: float | None = None, source: str | None = None,
                   raster: bytes | None = None) -> str:
        """A lesson-script slide: compact row, no number, not on the Figures page.

        Slides are not figures and numbering them as figures was the defect
        this exists to fix. In the reference book 66 of the Figures page's 76
        entries were slides, so the page that exists to help a reader find the
        one diagram they remember had been buried under the teaching aids, and
        each slide had taken a framed, captioned, full-measure block at the tail
        of the chapter it belonged to.

        They are still measured. The legibility floor is about whether printed
        type can be read, which has nothing to do with whether the art is
        numbered, so the measurements go into their own list and the report
        prints them under their own heading.
        """
        slide_n[0] += 1
        sid = f"slide{chapter_num:03d}{slide_n[0]:02d}"
        # Numbered off the same prefix the figures use, so an appendix slide
        # reads A1.s1 beside figures numbered A1.1 rather than 3.s1.
        rec: dict = {"chapter": chapter_num, "caption": caption,
                     "number": f"{fig_prefix}.s{slide_n[0]}"}
        if is_svg:
            inner = scope_svg_css(inner, sid)
            inner = re.sub(r"<svg\b", f'<svg id="{sid}"', inner, count=1)
        # Measurement branches on what was READ, never on how it was authored,
        # exactly as `emit` above does it. Nesting this under `is_svg` made the
        # whole check dead: every slide arrives through `from_img`, which passes
        # is_svg=False because the markup is an <img> tag, while handing over the
        # referenced .svg file's text as `source`. The result was a slide report
        # that could never flag anything -- the same art measured 2.4pt and was
        # reported as a figure, and silently passed as a slide.
        if source is not None:
            # Measured against the narrow slide column rather than the text
            # measure, because that is the width it prints at. Measuring it
            # at the full measure would clear the floor for art that is
            # about to be set at two thirds the size.
            legible = svg_legibility(source, False)
            if legible:
                rec["min_pt"] = legible[0] * SLIDE_WIDTH_SHARE
                rec["vb_width"] = legible[1]
        elif raster is not None:
            rec["unchecked_text"] = True
            metrics = raster_metrics(raster, False)
            if metrics:
                metrics["dpi"] *= 1.0 / SLIDE_WIDTH_SHARE
                rec.update(metrics)
        if slides is not None:
            slides.append(rec)
        token = f"@@MAKEBOOKSLIDE{chapter_num}_{slide_n[0]}@@"
        cap = (f'<p class="slide-caption">{html_mod.escape(caption)}</p>'
               if caption else "")
        slots[token] = (f'<div class="slide-row">'
                        f'<div class="slide-art">{inner}</div>{cap}</div>')
        return token

    def emit(inner: str, caption: str, is_svg: bool,
             aspect: float | None = None, source: str | None = None,
             raster: bytes | None = None, external: bool = False) -> str:
        local[0] += 1
        counter[0] += 1
        gid = counter[0]
        fid = f"fig{gid:03d}"
        number = f"{fig_prefix}.{local[0]}"
        figures.append({"id": gid, "number": number, "caption": caption,
                        "chapter": chapter_num})
        if is_svg:
            inner = scope_svg_css(inner, fid)
            inner = re.sub(r"<svg\b", f'<svg id="{fid}"', inner, count=1)
        is_wide = bool(aspect and aspect >= WIDE_ASPECT)
        wide = " figure-wide" if is_wide else ""
        if source is not None:
            legible = svg_legibility(source, is_wide)
            if legible:
                figures[-1]["min_pt"], figures[-1]["vb_width"] = legible
        elif raster is not None:
            # Both measurements need the measure the figure actually prints
            # at, so they wait until is_wide is known, exactly as the SVG
            # legibility call above does.
            figures[-1]["unchecked_text"] = True
            figures[-1]["external_src"] = external
            metrics = raster_metrics(raster, is_wide)
            if metrics:
                figures[-1].update(metrics)
        cap = (f'<figcaption><span class="fignum">Figure {number}</span>'
               f'{" " + html_mod.escape(caption) if caption else ""}'
               f'{probe(f"FIG{gid:03d}")}</figcaption>')
        token = f"@@MAKEBOOKFIG{gid}@@"
        slots[token] = f'<figure class="figure{wide}">{inner}{cap}</figure>'
        return token

    def from_fence(m: re.Match) -> str:
        svg = html_mod.unescape(m.group(1)).strip()
        return emit(svg, svg_title(svg), True, svg_aspect(svg), svg)

    def from_svg(m: re.Match) -> str:
        svg = m.group(1)
        return emit(svg, svg_title(svg), True, svg_aspect(svg), svg)

    def from_img(m: re.Match) -> str:
        tag = m.group(1)
        alt = ALT_RE.search(tag)
        caption = html_mod.unescape(alt.group(1)).strip() if alt else ""
        aspect, text, blob, external = None, "", None, False
        ref = SRC_RE.search(tag)
        if ref:
            path = (src / html_mod.unescape(ref.group(1))).resolve()
            if ref.group(1).lower().endswith(".svg"):
                # Read the file once: its <title> is the caption when alt is
                # empty, and its viewBox decides whether the figure needs the
                # wider measure.
                try:
                    text = path.read_text(encoding="utf-8")
                except (OSError, UnicodeDecodeError):
                    text = ""
                if text:
                    aspect = svg_aspect(text)
                    caption = caption or svg_title(text)
            else:
                # A raster. Its pixel dimensions give the aspect on the same
                # terms a viewBox does, so the wide measure transfers exactly.
                # Its text does not transfer at all; see raster_metrics.
                raw = html_mod.unescape(ref.group(1))
                # A data: URI or a remote src is not on disk. Asking the
                # filesystem gets an OSError, which would report it as
                # "dimensions unreadable" -- a false signal in the one report
                # whose whole job is being trusted about what went unchecked,
                # since those dimensions are readable, just not from here. It
                # is still unchecked, so it is still listed, under its own
                # wording. Same guard collect_images uses before it resolves.
                external = bool(re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*:", raw)
                                or raw.startswith("//"))
                if external:
                    blob = b""
                else:
                    try:
                        blob = path.read_bytes()
                    except OSError:
                        # Empty rather than None: the figure is still a raster
                        # whose text nobody checked, and that is what the flag
                        # downstream reports. None would silently drop it from
                        # the unchecked list and read as a figure that passed.
                        blob = b""
                dims = image_size(blob) if blob else None
                if dims and dims[1]:
                    aspect = dims[0] / dims[1]
        # A figure whose file sits under the declared slide folder is a lesson
        # script slide rather than a figure of the book's argument.
        if slide_dir and ref and html_mod.unescape(ref.group(1)).lstrip("./").startswith(slide_dir):
            return emit_slide(tag, caption, False, aspect, text or None, blob)
        return emit(tag, caption, False, aspect, text or None, blob, external)

    body_html = SVG_FENCE_RE.sub(from_fence, body_html)
    body_html = SVG_PARA_RE.sub(from_svg, body_html)
    body_html = SVG_BARE_RE.sub(from_svg, body_html)
    body_html = IMG_PARA_RE.sub(from_img, body_html)
    for token, figure_html in slots.items():
        body_html = body_html.replace(token, figure_html)
    return body_html


# markdown-it emits a bare `<table>`, but that is not the only producer: the
# renderer runs with `html: True`, so a source file's own raw `<table
# class="...">` reaches the document as written and Chromium counts it. Matching
# only the bare form desyncs this index from the browser's, and the damage is
# silent rather than loud: every table after the raw one shifts by a place, so a
# `<colgroup>` computed for one table lands on another and the build reports
# nothing. Measured 2026-09-13 on a chapter holding one raw table and one
# markdown table: the bare pattern found 1 of the 2 that Chromium enumerates.
# A `<table>` written inside a code span or a fence is escaped to `&lt;table&gt;`
# and correctly matches neither.
TABLE_OPEN_RE = re.compile(r"<table\b[^>]*>")

# Width held back when planning columns, so that planned widths always sum to
# less than the table they are written into. `width: 100%` plus column widths
# summing to a hair more makes the browser scale them all down to fit, which
# put a column a fraction of a point under its own longest word and broke
# "attendance" on a table with 57pt to spare. A point is far below anything
# visible and well above the rounding that caused it.
PLAN_SLACK_PT = 1.0


def plan_columns(tables: list[dict]) -> dict[tuple[int, int], list[float]]:
    """Explicit column widths for tables that fit the measure and broke anyway.

    `overflow-wrap: anywhere` is what stops one long token growing the
    document's layout box, and it does that by dropping a cell's min-content
    width to a single character. Auto layout then has no reason to give a
    column its longest word, so it can hand a column 39pt for a word needing
    91pt on a table using 314pt of the 432pt it has. Measured across the reference
    book on 2026-09-12: 58 of 70 tables broke a word and 53 of them had room
    to spare, which is the population this restores.

    Writing the widths back as a `<colgroup>` returns the minimum that
    `anywhere` removed, without returning the overflow it was added to prevent:
    a table whose columns cannot all fit is left alone deliberately, so it
    still degrades to a broken word rather than to a book-wide type reduction.
    That is the whole reason the sum is tested before a plan is emitted.

    Keyed by (chapter number, index of the table within that chapter), which is
    stable because assembly is deterministic and the measurement walks the
    document in the same order.
    """
    plan: dict[tuple[int, int], list[float]] = {}
    seen: dict[int, int] = {}
    for t in tables:
        ch = t["ch"]
        if ch is None:
            continue
        i = seen.get(ch, 0)
        seen[ch] = i + 1
        natural = t["col_natural_pt"]
        # Only a table that actually broke, and only one with the room to fix
        # itself. Widening the rest would re-proportion every table in every
        # book to buy nothing.
        if not natural or not t["broken"]:
            continue
        if sum(natural) + PLAN_SLACK_PT <= t["avail_pt"]:
            plan[(ch, i)] = share_width(natural, t["col_max_pt"],
                                        t["avail_pt"] - PLAN_SLACK_PT)
    return plan


def share_width(natural: list[float], longest: list[float],
                avail: float) -> list[float]:
    """Split `avail` across columns, each at least its longest word.

    This is the rule auto layout would have applied by itself if
    `overflow-wrap: anywhere` had not collapsed the min-content widths it reads:
    columns grow from their minimum toward the width that would set their
    content on one line, sharing whatever is left over in proportion to how much
    each still wants. Supplying it explicitly is what makes the minimum binding.

    Handing every column its bare minimum instead would satisfy the same
    guarantee and set the book badly, because the spare width would land
    wherever the browser chose to put it: that spelling cost the reference book 23
    pages, narrowing columns of prose to widen columns of single digits.
    """
    slack = avail - sum(natural)
    if slack <= 0:
        return natural
    # How much more each column could still use. A column already able to set
    # its content on one line wants none of the remainder.
    want = [max(0.0, m - n) for n, m in zip(natural, longest)]
    total = sum(want)
    if total <= slack:
        # Everything fits on one line. Share what is still left equally, which
        # is what a browser does once no column wants more.
        extra = (slack - total) / len(natural)
        return [n + w + extra for n, w in zip(natural, want)]
    return [n + slack * (w / total) for n, w in zip(natural, want)]


def inject_colgroups(body_html: str, ch: int,
                     plan: dict[tuple[int, int], list[float]]) -> str:
    """Write a planned table's column widths in front of its first row."""
    if not plan:
        return body_html
    out: list[str] = []
    last = 0
    for i, m in enumerate(TABLE_OPEN_RE.finditer(body_html)):
        widths = plan.get((ch, i))
        if not widths:
            continue
        cols = "".join(f'<col style="width:{w:.1f}pt">' for w in widths)
        out.append(body_html[last:m.end()])
        out.append(f"<colgroup>{cols}</colgroup>")
        last = m.end()
    out.append(body_html[last:])
    return "".join(out)


def build_chapters(chapters, cfg, figures: list[dict], src: Path,
                   col_plan: dict | None = None,
                   slides: list[dict] | None = None) -> str:
    sections = cfg.get("sections") or []
    counter = [0]
    out = []
    for ch in chapters:
        # An appendix sits outside the chapter parts, so a `sections` range
        # that happens to span its sequential number must not label it.
        grp = None if ch.get("appendix") else group_for(ch["num"], sections)
        tail = f" &nbsp;&middot;&nbsp; {html_mod.escape(grp)}" if grp else ""
        body = figurize(ch["body_html"], ch["num"], counter, figures, src,
                        slide_dir_of(cfg), slides,
                        fig_prefix=(f'A{ch["label_num"]}' if ch.get("appendix")
                                    else str(ch["num"])))
        body = inject_colgroups(body, ch["num"], col_plan or {})
        out.append(
            '<section class="chapter">'
            '<div class="chapter-head">'
            '<div class="chapter-eyebrow">'
            f'<span class="chapter-number">'
            f'{"Appendix" if ch.get("appendix") else "Chapter"} '
            f'{ch.get("label_num", ch["num"])}</span>'
            f'{tail}{probe(f"CH{ch["num"]:03d}")}</div>'
            f'<h2 class="chapter-title">{html_mod.escape(ch["title"])}</h2>'
            '<div class="rule"></div></div>'
            f"{body}</section>"
        )
    return "".join(out)


def build_figure_list(figures, fig_pages) -> str:
    rows = []
    for fig in figures:
        pg = str(fig_pages[fig["id"]]) if fig_pages else "&nbsp;"
        rows.append(
            '<div class="toc-row">'
            f'<span class="toc-num">{fig["number"]}</span>'
            f'<span class="toc-title">{html_mod.escape(fig["caption"])}</span>'
            '<span class="toc-dots"></span>'
            f'<span class="toc-page">{pg}</span></div>'
        )
    return (
        '<section class="frontmatter">'
        + probe("LOFSTART")
        + '<h2 class="section-title">Figures</h2>'
        '<p class="lead">Numbered by chapter. Every figure is vector art, so it '
        "stays sharp at any zoom and in print.</p>"
        + "".join(rows)
        + "</section>"
    )


def build_front_matter(path: Path) -> str:
    """The about-this-book page: what the book was built from, and what it fills in.

    Rendered from markdown like a chapter, but it is not one: no paragraph tags,
    no provenance marks, no concept list, and no entry on the contents page. It
    sits between the contents and the book the way a preface does, and a reader
    who skips it loses only the provenance, never the argument.
    """
    md = markdown_renderer()
    text = PROVENANCE_RE.sub("", path.read_text(encoding="utf-8"))
    lines = text.splitlines()
    if lines and lines[0].startswith("# "):
        title, body_md = lines[0][2:].strip(), "\n".join(lines[1:]).strip()
    else:
        title, body_md = "About This Book", text.strip()
    return (
        '<section class="front-matter">'
        + probe("FMSTART")
        + f'<h2 class="section-title">{html_mod.escape(title)}</h2>'
        + md.render(body_md)
        + "</section>"
    )


def build_glossary(entries) -> str:
    blocks, current = [], None
    for term, ch, body in entries:
        # The letter comes off the stripped term for the reason the sort does:
        # a term written as a code span is filed under its first letter, not
        # under its backtick.
        key = gloss_sort_key(term)
        letter = key[0].upper() if key and key[0].isalpha() else "#"
        if letter != current:
            blocks.append(f'<div class="index-letter">{letter}</div>')
            current = letter
        ref = f' <span class="gloss-ch">ch. {ch}</span>' if ch else ""
        blocks.append(
            '<div class="gloss-entry">'
            f'<span class="gloss-term">{inline_code_html(term)}</span>{ref} '
            f'{inline_code_html(body)}</div>'
        )
    return (
        '<section class="glossary">'
        + probe("GLOSSTART")
        + '<h2 class="section-title">Glossary</h2>'
        '<p class="lead">Every term this book defines, with the chapter that '
        "defines it. The chapter is where the term is explained in context; "
        "this page is the reminder.</p>"
        f'<div class="gloss-body">{"".join(blocks)}</div></section>'
    )


def build_index(entries) -> str:
    blocks, current = [], None
    for display, pgs in entries:
        letter = display[0].upper() if display[0].isalpha() else "#"
        if letter != current:
            blocks.append(f'<div class="index-letter">{letter}</div>')
            current = letter
        nums = ", ".join(str(p) for p in pgs)
        blocks.append(
            f'<div class="index-entry">{html_mod.escape(display)} '
            f'<span class="pages">{nums}</span></div>'
        )
    return (
        '<section class="index">'
        + probe("IDXSTART")
        + '<h2 class="section-title">Index</h2>'
        '<p class="lead">Page numbers run in order, so a term is usually '
        "introduced at the first page listed. For a term the book uses on most "
        "pages, only the pages that discuss it are listed.</p>"
        f'<div class="index-body">{"".join(blocks)}</div></section>'
    )


def assemble(title, cfg, chapters, src, state, want_index, css: str,
             stamp: str, glossary=None, front_matter: str | None = None,
             col_plan: dict | None = None) -> list:
    """Returns [html, figures, slides]. Both are discovered while building the
    chapters, so the caller learns about them from the same call that renders.
    Slides are kept apart from figures because they are numbered differently
    (not at all) and reported differently; see figurize's emit_slide.

    `css` is required rather than defaulting. It used to fall back to
    `build_css()`, which was harmless while that meant "the default stylesheet"
    and stopped being harmless when the default moved to 17pt: the fallback
    still yields the 11.8pt baseline, so a caller who omitted it would get
    compact pages wrapped in a footer scaled to whatever size was asked for.
    Requiring the argument removes the mismatch and the question of which size
    the fallback means.

    `stamp` is required for a related reason: it is read once per run, and a
    cover that read the clock itself would print a different time on every
    settling pass and another again in the EPUB.
    """
    figures: list[dict] = []
    slides: list[dict] = []
    chapter_html = build_chapters(chapters, cfg, figures, src, col_plan, slides)
    parts = [
        "<!DOCTYPE html>",
        '<html lang="en"><head><meta charset="utf-8">',
        f"<title>{html_mod.escape(title)}</title>",
        f"<style>{css}</style></head><body>",
        build_cover(title, cfg, chapters, src, stamp),
        build_toc(chapters, cfg, state.get("pages"), state.get("index_page"),
                  want_index, bool(figures), state.get("lof_page"),
                  bool(glossary), state.get("gloss_page")),
    ]
    # After the contents and before everything else, the way a preface sits.
    # It gets no contents entry of its own: a reader reaches it by turning the
    # page rather than by looking it up, and the page it would list is the one
    # immediately after the listing.
    if front_matter:
        parts.append(front_matter)
    if figures:
        parts.append(build_figure_list(figures, state.get("fig_pages")))
    parts.append(chapter_html)
    # Glossary before index. The glossary is read; the index is looked things up
    # in, so it belongs last where a thumb finds it.
    if glossary:
        parts.append(build_glossary(glossary))
    if want_index:
        parts.append(build_index(state.get("entries") or []))
    parts.append("</body></html>")
    return ["\n".join(parts), figures, slides]


# --------------------------------------------------------------------------
# Render and read back
# --------------------------------------------------------------------------

# The bleed each side of the text column, from the body padding in
# CSS_TEMPLATE. Measure plus both bleeds is the printed page area, and that is
# the width the table check has to lay out at: the measure is page area minus
# padding rather than a width anything declares, so a table read at the default
# viewport is read at the wrong width entirely.
BLEED_PT = 39.6             # 0.55in
PAGE_AREA_PT = COLUMN_MEASURE_PT + 2 * BLEED_PT   # 7.1in

# Whether a table's columns can hold their longest words, asked of Chromium
# rather than estimated from character counts.
#
# `overflow-wrap: anywhere` on a cell stops a wide table deforming the document
# (see the note in CSS_TEMPLATE) by letting a word break at any character. It
# does not make the table read well: past the measure the words simply break
# mid-token, and the reference book's four-model comparison printed "Relatio /
# nal" and "embeddi / ngs". Nothing errors and the page looks deliberate, so
# this is the same silent failure the figure legibility floor and the
# fenced-line check exist to refuse.
#
# Two numbers come back, and they answer different questions. `broken` is the
# observation: a Range over one token reporting more than one client rect means
# that token was laid out across two lines, which is the defect itself rather
# than a proxy for it. `natural_pt` is the arithmetic behind the advice: the sum
# over columns of the widest word each column has to hold, plus that cell's own
# padding and borders read from the computed style. It says how much too narrow
# the table is, which is what an author needs in order to fix it. The
# observation is the trigger; the arithmetic only ever explains it.
#
# Nothing here is calibrated, and that is deliberate. Every width is measured in
# the font the cell actually uses, so a cell of monospace code and a cell of
# Palatino prose are each read correctly, and the check does not carry a
# characters-per-point constant that a font change would silently invalidate.
TABLE_FIT_JS = """
(pageAreaPt) => {
  const PT = 72 / 96;                       // CSS px -> points
  const prev = document.body.style.cssText;
  // The measure is body width minus padding, so the body has to be laid out at
  // the printed page area before any of this means anything.
  document.body.style.boxSizing = 'border-box';
  document.body.style.width = (pageAreaPt / PT) + 'px';

  const ruler = document.createElement('span');
  ruler.style.cssText =
    'position:absolute;left:-9999px;top:0;white-space:pre;visibility:hidden';
  document.body.appendChild(ruler);

  // A token's width in the font of the element that holds it. Copying the
  // parent's own font is what keeps a `<code>` cell from being measured in the
  // body serif, which reads about 7% narrow at the same point size.
  const widthOf = (el, text) => {
    const cs = getComputedStyle(el);
    ruler.style.font = cs.font;
    ruler.style.fontFamily = cs.fontFamily;
    ruler.style.fontSize = cs.fontSize;
    ruler.style.fontWeight = cs.fontWeight;
    ruler.style.fontStyle = cs.fontStyle;
    ruler.style.letterSpacing = cs.letterSpacing;
    ruler.textContent = text;
    return ruler.getBoundingClientRect().width;
  };

  const out = [];
  for (const tbl of document.querySelectorAll('.chapter table')) {
    const sec = tbl.closest('section.chapter');
    const numEl = sec && sec.querySelector('.chapter-number');
    const m = numEl && numEl.textContent.match(/(\\d+)/);
    const ch = m ? parseInt(m[1], 10) : null;

    const rows = Array.from(tbl.rows);
    if (!rows.length) continue;
    const colNatural = [];
    const colMax = [];
    const broken = [];

    for (const row of rows) {
      Array.from(row.cells).forEach((cell, i) => {
        const cs = getComputedStyle(cell);
        const chrome = parseFloat(cs.paddingLeft) + parseFloat(cs.paddingRight)
                     + parseFloat(cs.borderLeftWidth)
                     + parseFloat(cs.borderRightWidth);
        let widest = 0;
        // The cell set on one line. This is the column's max-content width,
        // and it is what says how the spare width should be shared out: a
        // column of long prose wants more of it than a column of single
        // digits. Without it the planned widths guarantee the minimum and
        // leave the sharing to the browser, which cost the reference book 23
        // pages by narrowing its prose columns to widen its numeric ones.
        let oneLine = 0;
        const walker = document.createTreeWalker(cell, NodeFilter.SHOW_TEXT);
        let node;
        while ((node = walker.nextNode())) {
          const text = node.nodeValue;
          if (text.trim()) oneLine += widthOf(node.parentElement, text);
          // Runs that cannot break rather than whole words. A line may break
          // after a hyphen or dash without anything being wrong, so
          // "Entity-Relationship" splitting across two lines is ordinary
          // typography and was reported as a defect while this matched \\S+.
          // The same split decides the width a column needs: that cell needs
          // room for "Relationship", not for the whole compound.
          //
          // Only the dashes qualify. Measured 2026-09-13 by sweeping the box
          // width with text in front of the compound: a hyphen, en dash or em
          // dash never left a line ending mid-run, while a slash, underscore
          // or period each did at 16 to 18 of the 50 widths tried. Chromium
          // uses a slash as a break opportunity only when the compound is the
          // whole line, and once the run has to break at all it fills greedily
          // instead, which is how "completion/attendance" printed as
          // "completion/attend ance" in a cell with room for the word twice
          // over. U+2011 is excluded on purpose: a non-breaking hyphen is not
          // a break opportunity.
          const re = /[^\\s\\-\\u2010\\u2012-\\u2015]+/g;
          let tok;
          while ((tok = re.exec(text)) !== null) {
            const w = widthOf(node.parentElement, tok[0]);
            if (w > widest) widest = w;
            // A token split across line boxes is the defect. Counting rects
            // does NOT find it: getClientRects() also returns zero-width rects
            // at line boundaries, which reported every short word in a tight
            // column as broken, including words on tables with width to spare.
            // Counting distinct line tops among the rects that actually have
            // width is the question we meant to ask.
            if (tok[0].length > 1) {
              const r = document.createRange();
              r.setStart(node, tok.index);
              r.setEnd(node, tok.index + tok[0].length);
              const tops = new Set();
              for (const rect of r.getClientRects()) {
                if (rect.width > 0.5) tops.add(Math.round(rect.top));
              }
              if (tops.size > 1) broken.push(tok[0]);
            }
          }
        }
        const need = widest + chrome;
        if (!(i in colNatural) || need > colNatural[i]) colNatural[i] = need;
        const full = oneLine + chrome;
        if (!(i in colMax) || full > colMax[i]) colMax[i] = full;
      });
    }

    const natural = colNatural.reduce((a, b) => a + (b || 0), 0);
    const avail = tbl.getBoundingClientRect().width;
    // What each column was actually given. `overflow-wrap: anywhere` drops a
    // cell's min-content width to a single character, so auto layout may hand
    // a column less than its own longest word even when the table as a whole
    // has room to spare. Comparing the two per column is what names the column
    // to shorten; the table-level sum cannot, and goes negative in exactly
    // that case.
    const actual = rows[0] ? Array.from(rows[0].cells)
      .map(c => c.getBoundingClientRect().width) : [];
    // The header cells name the table far better than an index does, and they
    // are what the author will search the markdown for.
    out.push({
      ch: ch,
      cols: colNatural.length,
      natural_pt: natural * PT,
      avail_pt: avail * PT,
      col_natural_pt: colNatural.map(v => (v || 0) * PT),
      col_max_pt: colMax.map(v => (v || 0) * PT),
      col_actual_pt: actual.map(v => v * PT),
      broken: Array.from(new Set(broken)),
      heads: rows[0] ? Array.from(rows[0].cells).map(c => c.textContent.trim())
                     : [],
    });
  }

  ruler.remove();
  document.body.style.cssText = prev;
  return out;
}
"""


def render(html_str: str, base_dir: Path, out_path: Path, title: str,
           body_pt: float = BASELINE_BODY_PT) -> list[dict]:
    """Temp HTML lives in base_dir so file:// resolves relative image paths.

    body_pt reaches only the footer. The page's own type comes from the
    stylesheet already baked into html_str.

    Returns one record per table in the book, measured after the PDF is written
    so that nothing this check does can reach the pagination. See TABLE_FIT_JS.
    """
    with tempfile.NamedTemporaryFile(
        mode="w", encoding="utf-8", suffix=".html",
        prefix=".__makebook_", dir=base_dir, delete=False,
    ) as tf:
        tf.write(html_str)
        tmp = Path(tf.name)
    try:
        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True)
            try:
                page = browser.new_page()
                page.goto(tmp.absolute().as_uri(), wait_until="load")
                page.emulate_media(media="print")
                page.pdf(
                    path=str(out_path),
                    format="Letter",
                    margin={"top": "0.95in", "bottom": "0.95in",
                            "left": "0.7in", "right": "0.7in"},
                    print_background=True,
                    display_header_footer=True,
                    header_template=EMPTY_HEADER,
                    footer_template=footer_template(title, body_pt),
                )
                # After the PDF, never before: this widens the body to the
                # printed page area to read the tables at the width they
                # actually print at, and doing that first would repaginate the
                # book being measured.
                return page.evaluate(TABLE_FIT_JS, PAGE_AREA_PT)
            finally:
                browser.close()
    finally:
        tmp.unlink(missing_ok=True)


# Letter, the one page size this book is set on (@page in CSS_TEMPLATE).
LETTER_W_IN, LETTER_H_IN = 8.5, 11.0
CSS_PX_PER_IN = 96.0
# The EPUB cover art's pixel width. 1600 is the width SKILL.md already names
# for a Kindle Scribe. The height is not a target: this is a picture of the
# PDF's cover page, so it keeps that page's proportions and lets the device
# letterbox it rather than crop or stretch a page that was designed.
COVER_PNG_WIDTH_PX = 1600
PAGE_RULE_RE = re.compile(r"@page\s*\{([^}]*)\}", re.I | re.S)
PAGE_SIZE_RE = re.compile(r"size:\s*([A-Za-z0-9]+)", re.I)
PAGE_MARGIN_RE = re.compile(
    r"margin:\s*([\d.]+)in\s+([\d.]+)in(?:\s+([\d.]+)in\s+([\d.]+)in)?", re.I)
PAGE_SIZES_IN = {"letter": (LETTER_W_IN, LETTER_H_IN), "a4": (8.268, 11.693)}


def page_box_in(css: str) -> tuple[float, float] | None:
    """The printed content box in inches, read out of the stylesheet's own
    @page rule.

    Parsed rather than restated so the cover render cannot drift from what the
    PDF prints. **Every quantity it needs comes out of that one rule**, page
    size included: an earlier version parsed the margins and restated the page
    size, which bought drift-safety for one of the two numbers and quietly
    returned a Letter-shaped box for an A4 rule.

    Returns None whenever the rule says something this function cannot express,
    and the caller treats that as "no cover art" rather than guessing. The
    asymmetric case is the one that matters: adding a binding gutter is the
    likeliest edit to that line, and a wrong box renders a silently misshapen
    cover where a None reaches a visible warning.
    """
    rule = PAGE_RULE_RE.search(css)
    if not rule:
        return None
    body = rule.group(1)
    size = PAGE_SIZE_RE.search(body)
    page = PAGE_SIZES_IN.get(size.group(1).lower()) if size else None
    m = PAGE_MARGIN_RE.search(body)
    if not page or not m:
        return None
    top, right = float(m.group(1)), float(m.group(2))
    bottom = float(m.group(3)) if m.group(3) else top
    left = float(m.group(4)) if m.group(4) else right
    # One box cannot describe an asymmetric page, so refuse rather than pick a
    # side. A gutter belongs on alternating margins the screenshot has no way
    # to alternate between.
    if bottom != top or left != right:
        return None
    w_in = page[0] - 2 * right
    h_in = page[1] - 2 * top
    if w_in <= 0 or h_in <= 0:
        return None
    return w_in, h_in


def render_cover_png(title, cfg, chapters, src, stamp: str,
                     body_pt: float = BASELINE_BODY_PT) -> bytes | None:
    """The PDF's own cover page, rasterised for the EPUB's cover slot.

    Takes the binding's own body size and passes it to build_css, rather than
    rendering at the baseline. Most of the cover does not scale (34pt title,
    15pt subtitle, 11pt description, 8.6in min-height are all fixed), which
    made a no-argument build_css() look safe, and it is not quite: only
    `.cover .description p` and `ul` carry a fixed size, so a description
    written with an ol, a heading or a blockquote falls through to
    `body { font-size: ${body}pt }` and moves with --type-size. Rendering at
    the caller's size makes "this is a picture of that build's cover page"
    true by construction instead of true for most descriptions.

    Returns None rather than raising, on any failure. The EPUB is the second
    artifact of a build that has already written and reported the PDF, so a
    browser that will not start costs the cover art and not the book.
    """
    css = build_css(body_pt)
    box = page_box_in(css)
    if not box:
        return None
    w_in, h_in = box
    vw, vh = round(w_in * CSS_PX_PER_IN), round(h_in * CSS_PX_PER_IN)
    doc = (
        "<!DOCTYPE html>"
        '<html lang="en"><head><meta charset="utf-8">'
        f"<title>{html_mod.escape(title)}</title>"
        f"<style>{css}"
        # The viewport is the printed content box, so body's own 0.55in
        # padding still yields the 6.0in measure the cover was set on. The
        # probes are white-on-white in the PDF and would rasterise the same
        # way, but hiding them keeps the image free of text nobody wrote.
        "html,body{background:#ffffff;margin:0;}"
        ".probe{display:none !important;}"
        "</style></head><body>"
        f"{build_cover(title, cfg, chapters, src, stamp)}"
        "</body></html>"
    )
    tmp = None
    try:
        # In src, like render() does, so a description_file's relative image
        # paths resolve through file:// the same way.
        with tempfile.NamedTemporaryFile(
            mode="w", encoding="utf-8", suffix=".html",
            prefix=".__makebookcover_", dir=src, delete=False,
        ) as tf:
            tf.write(doc)
            tmp = Path(tf.name)
        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True)
            try:
                page = browser.new_page(
                    viewport={"width": vw, "height": vh},
                    device_scale_factor=COVER_PNG_WIDTH_PX / vw)
                page.goto(tmp.absolute().as_uri(), wait_until="load")
                page.emulate_media(media="print")
                return page.screenshot(type="png")
            finally:
                browser.close()
    except Exception:
        return None
    finally:
        if tmp is not None:
            tmp.unlink(missing_ok=True)


def page_texts(pdf: Path) -> list[str]:
    try:
        raw = subprocess.run(
            ["pdftotext", "-layout", str(pdf), "-"],
            check=True, capture_output=True, text=True,
        ).stdout
    except FileNotFoundError:
        sys.exit("error: pdftotext not found. Install poppler (brew install poppler).")
    return raw.split("\f")


def locate(pages_text: list[str]):
    """Chapter and figure numbers -> physical page, plus where the glossary, the
    index and the list of figures start and where the cover ends."""
    chapters: dict[int, int] = {}
    figures: dict[int, int] = {}
    index_page = lof_page = cover_end = gloss_page = 0
    for i, text in enumerate(pages_text, start=1):
        for tag in PROBE_RE.findall(re.sub(r"\s+", "", text)):
            if tag.startswith("CH"):
                chapters.setdefault(int(tag[2:]), i)
            elif tag.startswith("FIG"):
                figures.setdefault(int(tag[3:]), i)
            elif tag == "IDXSTART" and not index_page:
                index_page = i
            elif tag == "GLOSSTART" and not gloss_page:
                gloss_page = i
            elif tag == "LOFSTART" and not lof_page:
                lof_page = i
            elif tag == "COVEREND" and not cover_end:
                cover_end = i
    return chapters, index_page, figures, lof_page, cover_end, gloss_page


# --------------------------------------------------------------------------
# EPUB
# --------------------------------------------------------------------------
#
# The same book, rendered for a reflowable reader. Everything the PDF builds on
# physical pages is dropped here rather than approximated: an EPUB has no pages,
# so a page number printed into one is a number that means nothing on a device
# whose font size the reader chooses. The contents becomes the nav document, the
# figures page becomes links, and the index counts chapters instead of pages.
#
# There is no fixed-point loop on this path. That loop exists because Chromium's
# fragmentation moves lines between passes; nothing here paginates, so a single
# pass is exact by construction.

EPUB_CSS = """
body { font-family: Palatino, "Palatino Linotype", Georgia, serif;
       line-height: 1.5; margin: 0 1em; }
h1 { font-size: 1.5em; font-weight: normal; line-height: 1.2;
     margin: 1.2em 0 0.6em; page-break-before: always; }
h2 { font-size: 1.2em; margin: 1.4em 0 0.4em; }
h3 { font-size: 1.05em; margin: 1.2em 0 0.3em; }
h4 { font-size: 1em; font-style: italic; margin: 1.1em 0 0.3em; }
p { margin: 0; text-indent: 1.2em; }
p:first-of-type, h1 + p, h2 + p, h3 + p, h4 + p,
blockquote p, li p, figcaption, td p, th p { text-indent: 0; }
ul, ol { margin: 0.7em 0; }
li { margin: 0.3em 0; }
blockquote { margin: 0.8em 1.2em; font-style: italic; }
/* The guide profile's callouts, boxed here as they are in the PDF. No fixed
   point sizes: a reflowable book sets its own, so these are all relative. */
.callout {
  margin: 1em 0; padding: 0.5em 0.7em 0.6em;
  border: 1px solid #bdbdbd; border-left: 3px solid #6b6b6b;
  background: #f7f7f7; page-break-inside: avoid;
}
.callout-title {
  font-size: 0.75em; font-weight: bold; letter-spacing: 0.06em;
  text-transform: uppercase; margin: 0 0 0.25em; text-indent: 0;
}
.callout-body { margin: 0; text-indent: 0; }
.callout-warning { border-left-color: #8a4b2a; }
.callout-decide { border-left-color: #2f5d7c; }
.endnotes { margin: 1.8em 0 0; padding-top: 0.6em; border-top: 1px solid #d4d4d4; }
.endnotes-title {
  font-size: 0.75em; font-weight: bold; letter-spacing: 0.06em;
  text-transform: uppercase; margin: 0 0 0.35em;
}
.endnote { font-size: 0.85em; margin: 0.3em 0; text-indent: 0; }
.endnote-label { font-weight: bold; }
/* Lesson-script slides. No float here: reflowable readers handle floats
   unevenly and a slide stranded mid-column reads worse than one stacked above
   its notes. The compact width is kept, so the art still reads as an aid
   rather than as a figure of the argument. */
.slide-row { margin: 0.9em 0; page-break-inside: avoid; }
.slide-art { width: 62%; margin: 0 auto; }
.slide-art svg, .slide-art img { width: 100%; height: auto; display: block; }
.slide-caption { font-size: 0.8em; margin: 0.3em 0 0; text-indent: 0; }
code, pre { font-family: monospace; }
code { font-size: 0.9em; }
pre { font-size: 0.8em; line-height: 1.35; margin: 0.9em 0;
      white-space: pre-wrap; word-wrap: break-word; }
pre code { font-size: inherit; }
table { border-collapse: collapse; width: 100%; margin: 0.9em 0;
        font-size: 0.85em; }
th, td { border: 1px solid #999; padding: 0.3em 0.45em;
         text-align: left; vertical-align: top; }
th { font-weight: bold; }
hr { border: 0; border-top: 1px solid #999; margin: 1.2em 0; }
img, svg { max-width: 100%; height: auto; }
figure { margin: 1.2em 0; page-break-inside: avoid; text-align: center; }
figure img, figure svg { display: block; margin: 0 auto; }
figcaption { font-size: 0.85em; margin-top: 0.5em; text-align: left; }
figcaption .fignum { font-weight: bold; }
.subtitle { font-size: 1.1em; font-style: italic; margin: 0.4em 0 1em; }
/* The stamp sits close under the byline and takes over its space before the
   description. Neither indents: they are the title block, not prose, and
   `p`'s indent would otherwise catch whichever one no heading precedes. */
.byline, .stamp { margin: 0 0 1.4em; text-indent: 0; }
.byline { margin-bottom: 0.2em; }
.footnote { font-size: 0.85em; margin-top: 2em; }
.lead { font-size: 0.9em; font-style: italic; margin: 0 0 1.2em; }
.entry { text-indent: -1.1em; margin-left: 1.1em; margin-bottom: 0.25em; }
.entry-letter { font-weight: bold; margin: 1em 0 0.3em; }
nav ol { list-style: none; padding-left: 1em; }
"""

# XHTML is XML, so every void element closes and every entity is one XML knows.
# markdown-it already emits <br />, <hr /> and <img ... />, but the tasklists
# plugin emits a bare <input ...>, which is well-formed HTML and malformed XML.
#
# Attributes are matched quote-aware rather than as [^>]*. A raw-HTML tag may
# carry a > inside a quoted value (alt="a > b"), and stopping at the first >
# cuts the tag in half: the remainder of the attribute lands in the page as
# visible prose. Well-formedness does not catch that, because the truncated tag
# is still valid XML, so the validation step is no backstop here.
TAG_ATTRS = r'(?:[^>"\']|"[^"]*"|\'[^\']*\')*'
VOID_TAG_RE = re.compile(
    r"<(area|base|br|col|embed|hr|img|input|link|meta|param|source|track|wbr)"
    r"\b(" + TAG_ATTRS + r")>", re.I)
EPUB_IMG_TAG_RE = re.compile(r"<img\b" + TAG_ATTRS + r">", re.I)
NAMED_ENTITY_RE = re.compile(r"&([a-zA-Z][a-zA-Z0-9]{1,31});")
XML_ENTITIES = {"amp", "lt", "gt", "quot", "apos"}
XHTML_NS = "http://www.w3.org/1999/xhtml"
SVG_NS = "http://www.w3.org/2000/svg"


def close_void_tags(markup: str) -> str:
    def fix(m: re.Match) -> str:
        attrs = m.group(2).strip()
        if attrs.endswith("/"):           # already self-closed; do not double it
            attrs = attrs[:-1].rstrip()
        return f"<{m.group(1).lower()}{' ' + attrs if attrs else ''}/>"
    return VOID_TAG_RE.sub(fix, markup)


def numeric_entities(markup: str) -> str:
    """&nbsp; is undefined in XML. Only the five XML entities survive by name."""
    def rewrite(m: re.Match) -> str:
        name = m.group(1)
        if name in XML_ENTITIES:
            return m.group(0)
        char = html.entities.html5.get(name + ";")
        if char is None:
            return m.group(0)
        return "".join(f"&#{ord(c)};" for c in char)
    return NAMED_ENTITY_RE.sub(rewrite, markup)


def xhtmlify(markup: str, where: str) -> str:
    """Make a rendered-markdown fragment well-formed XML, or say why it is not.

    Validation is a parse, not a re-serialisation. ebooklib's own EpubHtml
    round-trips content through lxml's HTML parser, which lowercases attribute
    names, so an inline diagram's viewBox becomes viewbox and the figure loses
    its scaling. Measured with ebooklib 0.20. This path keeps the bytes.
    """
    from lxml import etree

    fixed = numeric_entities(close_void_tags(markup))
    try:
        etree.fromstring(f'<div xmlns="{XHTML_NS}">{fixed}</div>')
    except etree.XMLSyntaxError as exc:
        sys.exit(
            f"error: {where} does not convert to XHTML: {exc}\n"
            "The EPUB is XML, so raw HTML in a source file has to close its "
            "tags and escape its ampersands."
        )
    return fixed


def epub_document(title: str, body: str, css_href: str, lang: str = "en") -> str:
    return (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        "<!DOCTYPE html>\n"
        f'<html xmlns="{XHTML_NS}" xmlns:epub="http://www.idpf.org/2007/ops"'
        f' lang="{lang}" xml:lang="{lang}">\n'
        f'<head><meta charset="utf-8"/><title>{html_mod.escape(title)}</title>'
        f'<link rel="stylesheet" type="text/css" href="{css_href}"/></head>\n'
        f"<body>{body}</body>\n</html>\n"
    )


class RawXhtml(epub.EpubHtml):
    """An EpubHtml whose content reaches the zip byte for byte.

    See xhtmlify for why the inherited get_content cannot be used.
    """

    def get_content(self, default=None):
        content = self.content if self.content is not None else default
        if isinstance(content, str):
            return content.encode("utf-8")
        return content


def epub_asset_name(path: Path, taken: dict[Path, str]) -> str:
    """A flat images/ folder, so two diagrams sharing a basename stay distinct."""
    if path in taken:
        return taken[path]
    stem = re.sub(r"[^A-Za-z0-9._-]+", "-", path.name).strip("-") or "image"
    name, n = stem, 1
    while name in taken.values():
        n += 1
        name = f"{Path(stem).stem}-{n}{Path(stem).suffix}"
    taken[path] = name
    return name


MEDIA_TYPES = {
    ".svg": "image/svg+xml", ".png": "image/png", ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg", ".gif": "image/gif", ".webp": "image/webp",
}


def figurize_epub(body_html: str, chapter_num: int, counter: list[int],
                  figures: list[dict], src: Path, slide_dir: str = "") -> str:
    """The EPUB's figures: numbered and captioned, anchored, and no probes.

    The PDF path plants an invisible marker in each caption so pdftotext can
    report the page it landed on. Nothing reads a marker here, and white 5pt
    text in a reflowable book is litter, so this path emits none.
    """
    local = [0]
    slots: dict[str, str] = {}

    def emit(inner: str, caption: str, is_svg: bool) -> str:
        local[0] += 1
        counter[0] += 1
        gid = counter[0]
        fid = f"fig{gid:03d}"
        number = f"{chapter_num}.{local[0]}"
        figures.append({"id": gid, "number": number, "caption": caption,
                        "chapter": chapter_num, "anchor": fid})
        if is_svg:
            # One XHTML file per chapter still holds every figure in that
            # chapter, so two inline diagrams defining .label would collide
            # exactly as they do on a PDF page. Scope them the same way.
            inner = scope_svg_css(inner, fid)
            inner = re.sub(r"<svg\b", f'<svg id="{fid}-art"', inner, count=1)
            if "xmlns=" not in inner[:400]:
                inner = re.sub(r"<svg\b", f'<svg xmlns="{SVG_NS}"',
                               inner, count=1)
        cap = (f'<figcaption><span class="fignum">Figure {number}</span>'
               f'{" " + html_mod.escape(caption) if caption else ""}'
               "</figcaption>")
        token = f"@@MAKEBOOKEPUBFIG{gid}@@"
        slots[token] = f'<figure id="{fid}">{inner}{cap}</figure>'
        return token

    def from_fence(m: re.Match) -> str:
        svg = html_mod.unescape(m.group(1)).strip()
        return emit(svg, svg_title(svg), True)

    def from_svg(m: re.Match) -> str:
        svg = m.group(1)
        return emit(svg, svg_title(svg), True)

    def from_img(m: re.Match) -> str:
        tag = m.group(1)
        alt = ALT_RE.search(tag)
        caption = html_mod.unescape(alt.group(1)).strip() if alt else ""
        ref = SRC_RE.search(tag)
        if ref and ref.group(1).lower().endswith(".svg") and not caption:
            path = (src / html_mod.unescape(ref.group(1))).resolve()
            try:
                caption = svg_title(path.read_text(encoding="utf-8"))
            except (OSError, UnicodeDecodeError):
                caption = ""
        # A slide is not a figure here either: no number, no Figures entry.
        # The EPUB has no Figures page, but the numbering is shared with the
        # PDF's by intent, and a slide numbered in one edition and unnumbered in
        # the other would give the same art two different names.
        if slide_dir and ref and html_mod.unescape(ref.group(1)).lstrip("./").startswith(slide_dir):
            cap = (f'<p class="slide-caption">{html_mod.escape(caption)}</p>'
                   if caption else "")
            return f'<div class="slide-row"><div class="slide-art">{tag}</div>{cap}</div>'
        return emit(tag, caption, False)

    body_html = SVG_FENCE_RE.sub(from_fence, body_html)
    body_html = SVG_PARA_RE.sub(from_svg, body_html)
    body_html = SVG_BARE_RE.sub(from_svg, body_html)
    body_html = IMG_PARA_RE.sub(from_img, body_html)
    for token, figure_html in slots.items():
        body_html = body_html.replace(token, figure_html)
    return body_html


def collect_images(body_html: str, src: Path, assets: dict[Path, str],
                   missing: list[str]) -> str:
    """Point every local <img> at its packaged copy, and record what to pack.

    Runs over the whole body, not just the figures: an image inside a sentence
    is still a file the package has to carry, and a src left pointing outside
    the zip is a broken image and an epubcheck error.
    """
    def rewrite(m: re.Match) -> str:
        tag = m.group(0)
        ref = SRC_RE.search(tag)
        if not ref:
            return tag
        raw = html_mod.unescape(ref.group(1))
        if re.match(r"^[a-zA-Z][a-zA-Z0-9+.-]*:", raw) or raw.startswith("//"):
            return tag                      # remote, or a data: URI already
        path = (src / raw).resolve()
        if not path.is_file():
            # A src pointing outside the zip is an invalid package, not a
            # broken image icon: epubcheck fails the whole book on RSC-007.
            # Say so on the page, so the gap is visible rather than silent.
            missing.append(raw)
            return (f'<em class="missing">[missing image: '
                    f"{html_mod.escape(raw)}]</em>")
        name = epub_asset_name(path, assets)
        return tag.replace(ref.group(0), f'src="images/{name}"')

    return EPUB_IMG_TAG_RE.sub(rewrite, body_html)


def epub_index(terms, chapters) -> tuple[list[tuple[str, list[int]]], list[str]]:
    """Which chapters discuss each term.

    The PDF resolves a term to physical pages by matching the rendered text
    layer. A reflowable book has no pages to resolve to, so the unit becomes the
    chapter and the source becomes the chapter's own text, which is the more
    accurate of the two: no hyphenation, no column breaks, no footer to strip.
    """
    entries, missing = [], []
    for display, pattern, cased in terms:
        try:
            rx = re.compile(pattern, 0 if cased else re.IGNORECASE)
        except re.error as exc:
            sys.exit(f"error: bad pattern for {display!r}: {exc}")
        hits = {}
        for ch in chapters:
            n = len(rx.findall(ch["plain"]))
            if n:
                hits[ch["num"]] = n
        if not hits:
            missing.append(display)
            continue
        if len(hits) <= MAX_CHAPTERS_PER_TERM:
            entries.append((display, sorted(hits)))
            continue
        chosen = None
        for threshold in range(2, 20):
            dense = [c for c, n in hits.items() if n >= threshold]
            if 0 < len(dense) <= MAX_CHAPTERS_PER_TERM:
                chosen = sorted(dense)
                break
        if chosen is None:
            top = sorted(hits.items(), key=lambda x: (-x[1], x[0]))
            chosen = sorted(c for c, _ in top[:MAX_CHAPTERS_PER_TERM])
        entries.append((display, chosen))
    entries.sort(key=lambda e: e[0].lower())
    return entries, missing


def epub_chapter_href(num: int) -> str:
    return f"chap_{num:03d}.xhtml"


def epub_cover_body(title, cfg, chapters, src, stamp: str) -> str:
    md = markdown_renderer()
    desc = cfg.get("description")
    if isinstance(desc, list):
        desc = "\n\n".join(desc)
    if desc:
        desc_html = md.render(desc)
    elif cfg.get("description_file"):
        path = src / cfg["description_file"]
        if not path.is_file():
            sys.exit(f"error: description_file {path} not found")
        desc_html = md.render(path.read_text(encoding="utf-8"))
    else:
        desc_html = default_description(title, chapters, src)

    bits = []
    if cfg.get("eyebrow"):
        bits.append(f'<p class="lead">{html_mod.escape(cfg["eyebrow"])}</p>')
    bits.append(f"<h1>{html_mod.escape(title)}</h1>")
    if cfg.get("subtitle"):
        bits.append(f'<p class="subtitle">{html_mod.escape(cfg["subtitle"])}</p>')
    if cfg.get("byline"):
        bits.append(f'<p class="byline">{html_mod.escape(cfg["byline"])}</p>')
    bits.append(f'<p class="stamp">{html_mod.escape(stamp)}</p>')
    bits.append(desc_html)
    if cfg.get("footnote"):
        bits.append(f'<div class="footnote">{md.render(cfg["footnote"])}</div>')
    return xhtmlify("".join(bits), "the cover")


def epub_front_matter_body(path: Path) -> str:
    """The about-this-book page for the reflowable build.

    The PDF wraps this in a <section> and gives it a page break; an EPUB has
    neither pages nor breaks, so it becomes its own document in the spine and
    the nav lists it. The markdown is the same file, rendered the same way.
    """
    md = markdown_renderer()
    text = PROVENANCE_RE.sub("", path.read_text(encoding="utf-8"))
    lines = text.splitlines()
    body_md = "\n".join(lines[1:]).strip() if (
        lines and lines[0].startswith("# ")) else text.strip()
    return md.render(body_md)


def epub_figures_body(figures: list[dict]) -> str:
    rows = []
    for fig in figures:
        href = f'{epub_chapter_href(fig["chapter"])}#{fig["anchor"]}'
        caption = html_mod.escape(fig["caption"]) if fig["caption"] else ""
        rows.append(
            f'<li><a href="{href}">Figure {fig["number"]}</a>'
            f'{" " + caption if caption else ""}</li>'
        )
    return (
        "<h1>Figures</h1>"
        '<p class="lead">Every figure is vector art, so it stays sharp at any '
        "size. Each entry links to the figure in its chapter.</p>"
        f'<ol>{"".join(rows)}</ol>'
    )


def epub_glossary_body(entries, chapters) -> str:
    titles = {ch["num"]: ch["title"] for ch in chapters}
    blocks, current = [], None
    for term, ch, body in entries:
        # Letter and rendering both come off the stripped term, exactly as
        # build_glossary does it for the PDF. The two glossary builders are
        # separate because their markup is, and a term filed under P in one
        # edition and under "#" in the other is the bug that split them.
        key = gloss_sort_key(term)
        letter = key[0].upper() if key and key[0].isalpha() else "#"
        if letter != current:
            blocks.append(f'<p class="entry-letter">{letter}</p>')
            current = letter
        ref = ""
        if ch:
            ref = (f' <a href="{epub_chapter_href(ch)}" title="'
                   f'{html_mod.escape(titles.get(ch, ""), quote=True)}">'
                   f'ch. {ch}</a>')
        blocks.append(
            f'<p class="entry"><strong>{inline_code_html(term)}</strong>{ref} '
            f'{inline_code_html(body)}</p>'
        )
    return (
        "<h1>Glossary</h1>"
        '<p class="lead">Every term this book defines. Each entry links to the '
        "chapter that defines it, where the term is explained in context.</p>"
        f'{"".join(blocks)}'
    )


def epub_index_body(entries, chapters) -> str:
    titles = {ch["num"]: ch["title"] for ch in chapters}
    blocks, current = [], None
    for display, nums in entries:
        letter = display[0].upper() if display[0].isalpha() else "#"
        if letter != current:
            blocks.append(f'<p class="entry-letter">{letter}</p>')
            current = letter
        links = ", ".join(
            f'<a href="{epub_chapter_href(n)}" title="'
            f'{html_mod.escape(titles.get(n, ""), quote=True)}">{n}</a>'
            for n in nums
        )
        blocks.append(
            f'<p class="entry">{html_mod.escape(display)} {links}</p>')
    return (
        "<h1>Index</h1>"
        '<p class="lead">The numbers are chapters, not pages: this book '
        "reflows, so it has no fixed pages to point at. For a term the book "
        "uses throughout, only the chapters that discuss it are listed.</p>"
        f'{"".join(blocks)}'
    )


def epub_toc(chapters, items, cfg, front, back) -> tuple:
    """Nested nav entries where book.json groups chapters into sections."""
    sections = cfg.get("sections") or []
    out, current, bucket = list(front), None, []

    def flush():
        if not bucket:
            return
        if current:
            out.append((epub.Section(current), tuple(bucket)))
        else:
            out.extend(bucket)
        bucket.clear()

    for ch, item in zip(chapters, items):
        grp = group_for(ch["num"], sections)
        if grp != current:
            flush()
            current = grp
        bucket.append(item)
    flush()
    out.extend(back)
    return tuple(out)


def build_epub(title, cfg, chapters, src, out_path, terms, want_index,
               stamp: str, glossary=None, front_matter_path: Path | None = None,
               body_pt: float = BASELINE_BODY_PT) -> dict:
    # Drop any previous build first. Assembling the book can exit part-way
    # through, on a source file whose raw HTML will not convert, and that
    # happens after the PDF has been written and reported. Leaving the old
    # EPUB in place would sit a stale book beside a fresh PDF with nothing
    # on disk to say which is which.
    out_path.unlink(missing_ok=True)
    book = epub.EpubBook()
    # Derived, never generated: a fresh identifier on every build makes a
    # re-send a second book on the device instead of a replacement.
    ident = uuid.uuid5(uuid.NAMESPACE_URL, f"makebook:{src.name}:{title}")
    book.set_identifier(f"urn:uuid:{ident}")
    book.set_title(title)
    book.set_language("en")
    if cfg.get("byline"):
        book.add_author(cfg["byline"])
    blurb = cfg.get("description")
    if isinstance(blurb, list):
        blurb = " ".join(blurb)
    if cfg.get("subtitle"):
        blurb = f"{cfg['subtitle']}. {blurb}" if blurb else cfg["subtitle"]
    if blurb:
        book.add_metadata("DC", "description",
                          re.sub(r"\s+", " ", strip_markdown(blurb)).strip())

    style = epub.EpubItem(uid="style", file_name="style/main.css",
                          media_type="text/css", content=EPUB_CSS)
    book.add_item(style)

    def page(uid, filename, heading, body) -> RawXhtml:
        item = RawXhtml(title=heading, file_name=filename, lang="en", uid=uid)
        # Bytes, not str: ebooklib re-parses content while building the nav,
        # and lxml refuses a str that carries an encoding declaration.
        item.content = epub_document(f"{heading} - {title}", body,
                                     "style/main.css").encode("utf-8")
        # A document holding inline SVG has to say so in the manifest, or
        # epubcheck rejects the package (OPF-014). A referenced .svg does not
        # count: the property describes markup in this file, not what it links.
        if re.search(r"<svg\b", body, re.I):
            item.properties.append("svg")
        book.add_item(item)
        return item

    assets: dict[Path, str] = {}
    lost_images: list[str] = []
    figures: list[dict] = []
    counter = [0]

    chapter_items = []
    for ch in chapters:
        body = figurize_epub(ch["body_html"], ch["num"], counter, figures, src,
                             slide_dir_of(cfg))
        body = collect_images(body, src, assets, lost_images)
        heading = html_mod.escape(ch["title"])
        section = (None if ch.get("appendix")
                   else group_for(ch["num"], cfg.get("sections") or []))
        eyebrow = (f'<p class="lead">'
                   f'{"Appendix" if ch.get("appendix") else "Chapter"} '
                   f'{ch.get("label_num", ch["num"])}'
                   f'{" &#183; " + html_mod.escape(section) if section else ""}'
                   "</p>")
        body = xhtmlify(f"{eyebrow}<h1>{heading}</h1>{body}", str(ch["path"]))
        chapter_items.append(
            page(f"chap{ch['num']:03d}", epub_chapter_href(ch["num"]),
                 ch["title"], body))

    cover = page("cover-page", "cover.xhtml", title,
                 epub_cover_body(title, cfg, chapters, src, stamp))

    front = []
    # Before the figures, as it sits before everything in the PDF.
    if front_matter_path is not None and front_matter_path.is_file():
        fm_lines = front_matter_path.read_text(encoding="utf-8").splitlines()
        fm_title = (fm_lines[0][2:].strip()
                    if fm_lines and fm_lines[0].startswith("# ")
                    else "About This Book")
        front.append(page("front-matter", "about.xhtml", fm_title,
                          epub_front_matter_body(front_matter_path)))
    if figures:
        front.append(page("figures", "figures.xhtml", "Figures",
                          epub_figures_body(figures)))

    entries: list[tuple[str, list[int]]] = []
    idx_missing: list[str] = []
    back = []
    if glossary:
        back.append(page("glossary", "glossary.xhtml", "Glossary",
                         epub_glossary_body(glossary, chapters)))
    if want_index:
        # This list used to be discarded here, which made the EPUB the quieter
        # half of the same silence the PDF's index was fixed for: the entry
        # count simply came up short and nothing said which term went. It is
        # carried out to the report now.
        entries, idx_missing = epub_index(terms, chapters)
        if entries:
            back.append(page("index", "index.xhtml", "Index",
                             epub_index_body(entries, chapters)))

    for path, name in assets.items():
        book.add_item(epub.EpubItem(
            uid=f"img-{name}", file_name=f"images/{name}",
            media_type=MEDIA_TYPES.get(path.suffix.lower(),
                                       "application/octet-stream"),
            content=path.read_bytes()))

    cover_image = cfg.get("cover_image")
    generated_cover = False
    if cover_image:
        cover_path = (src / cover_image).resolve()
        if not cover_path.is_file():
            sys.exit(f"error: cover_image {cover_path} not found")
        book.set_cover(f"cover{cover_path.suffix.lower()}",
                       cover_path.read_bytes(), create_page=False)
    else:
        # No cover art declared leaves a library or a device showing a blank
        # tile, which is the EPUB's own version of the silent failure this
        # build reports everywhere else. Rasterise the PDF's cover page rather
        # than invent a second design: one cover, both formats, and a book
        # whose typography already fits it.
        # body_pt reaches only this call. An EPUB is reflowable and takes its
        # size from the reader, so nothing else here scales; the cover art is
        # a picture of a fixed page and has to match the page it pictures.
        png = render_cover_png(title, cfg, chapters, src, stamp, body_pt)
        if png:
            book.set_cover("cover.png", png, create_page=False)
            generated_cover = True

    book.toc = epub_toc(chapters, chapter_items, cfg, front, back)
    book.add_item(epub.EpubNcx())
    book.add_item(epub.EpubNav())
    book.spine = [cover, "nav"] + front + chapter_items + back

    epub.write_epub(str(out_path), book)
    return {"path": out_path, "figures": len(figures), "entries": len(entries),
            "assets": len(assets), "missing_images": lost_images,
            "missing_terms": idx_missing, "cover_declared": bool(cover_image),
            "generated_cover": generated_cover,
            "glossary": len(glossary or [])}


# --------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------

def slugify(title: str) -> str:
    s = re.sub(r"[^A-Za-z0-9]+", "-", title).strip("-").lower()
    return s or "book"


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(
        description="Bind a folder of markdown files into a PDF and an EPUB.")
    ap.add_argument("title", help='Book title, quoted')
    ap.add_argument("folder", type=Path, help="Folder holding the markdown files")
    ap.add_argument("--out", type=Path, default=None,
                    help="Output PDF (default: <folder>/<title-slug>.pdf). "
                         "The EPUB takes the same path with an .epub suffix")
    ap.add_argument("--terms", type=Path, default=None,
                    help="Curated index terms (default: terms.txt in the folder)")
    ap.add_argument("--max-terms", type=int, default=DEFAULT_MAX_TERMS)
    ap.add_argument("--no-index", action="store_true", help="Omit the index")
    # A flag wins over book.json, and neither given falls back to the default
    # edition. That order is check-book.sh's for the tag decision, and the two
    # tools reading a declaration the same way is worth more than either
    # ordering is on its own. The default is `default` so that a folder bound
    # before this option existed binds identically now.
    ed = ap.add_mutually_exclusive_group()
    ed.add_argument("--reading-edition", dest="reading_edition",
                    action="store_true", default=None,
                    help="Bind the reading edition: paragraph tags off the "
                         "page, the header's Draws-on and Fills-in rows moved "
                         "to chapter endnotes. The markdown is not touched")
    ed.add_argument("--no-reading-edition", dest="reading_edition",
                    action="store_false",
                    help='Bind the default edition even where book.json sets '
                         '"edition": "reading"')
    ap.add_argument("--no-glossary", action="store_true",
                    help="Omit the glossary even when the folder holds one")
    ap.add_argument("--report", action="store_true",
                    help="Print the harvested terms and chapter pages")
    # A required value rather than nargs="?", which is what the old
    # --large-print used. Optional-value flags sit badly in front of two
    # required positionals: `--large-print "Book Title" folder` read the title
    # as the point size and failed somewhere further in. `--type-size "Book
    # Title"` now fails in argparse, by name, before anything is built.
    ap.add_argument("--type-size", type=float, default=None, metavar="PT",
                    help=f"The PDF's paragraph type size in points, "
                         f"{MIN_BODY_PT:g} to {MAX_BODY_PT:g} (default "
                         f"{DEFAULT_BODY_PT:g}). Every reading size moves with "
                         f"it. Pass {MAX_BODY_PT:g} for large print or "
                         f"{MIN_BODY_PT:g} for the compact edition. The EPUB "
                         f"is unaffected: a reflowable book already sets its "
                         f"own size")

    # --large-print is gone rather than aliased, and its name is the reason: it
    # named one binding rather than a size, and the size it meant has been a
    # point on a range since --type-size replaced it. Left to argparse this
    # would be "unrecognized arguments", which says nothing about where the
    # option went or which size now gives what it gave.
    if any(a == "--large-print" or a.startswith("--large-print=") for a in argv):
        print(f"error: --large-print is gone. Use --type-size PT instead "
              f"({MIN_BODY_PT:g} to {MAX_BODY_PT:g}); --type-size "
              f"{MAX_BODY_PT:g} is the large-print binding it named. The "
              f"default is {DEFAULT_BODY_PT:g}pt, and --type-size "
              f"{MIN_BODY_PT:g} is the compact edition.",
              file=sys.stderr)
        return 1
    args = ap.parse_args(argv)

    body_pt = args.type_size if args.type_size is not None else DEFAULT_BODY_PT
    if not MIN_BODY_PT <= body_pt <= MAX_BODY_PT:
        print(f"error: --type-size takes a size from {MIN_BODY_PT:g}pt to "
              f"{MAX_BODY_PT:g}pt; {body_pt:g} is outside that. Below "
              f"{MIN_BODY_PT:g} nothing has been measured, and above "
              f"{MAX_BODY_PT:g} the chapter titles outgrow the cover's own "
              f"title, which does not scale.", file=sys.stderr)
        return 1
    css = build_css(body_pt)

    src = args.folder.expanduser().resolve()
    if not src.is_dir():
        print(f"error: {src} is not a directory", file=sys.stderr)
        return 1

    cfg = load_config(src)
    skip = {"book.json"}
    if cfg.get("description_file"):
        skip.add(cfg["description_file"])
    skip.update(cfg.get("exclude", []))

    # The glossary is back matter, never a chapter, so it is skipped whether or
    # not it gets bound and whether or not book.json remembered to exclude it.
    # Leaving that to `exclude` would turn a forgotten line into a glossary bound
    # as chapter 7, which reads like an editorial choice rather than a mistake.
    gloss_name = cfg.get("glossary_file", "glossary.md")
    skip.add(gloss_name)

    # Front matter, skipped for the same reason the glossary is: it is not a
    # chapter, and a forgotten `exclude` line would otherwise bind it as chapter
    # one, where its filename sorts it ahead of everything.
    fm_name = cfg.get("front_matter_file", "about-this-book.md")
    skip.add(fm_name)

    # The flag wins; else book.json; else the default edition.
    declared_edition = cfg.get("edition", "default")
    if declared_edition not in ("default", "reading"):
        print(f'error: book.json "edition" must be "reading" or "default", '
              f'not: {declared_edition!r}', file=sys.stderr)
        return 1
    if args.reading_edition is None:
        reading_edition = declared_edition == "reading"
    else:
        reading_edition = args.reading_edition

    chapters = load_chapters(src, skip, reading=reading_edition,
                             displays=source_displays(cfg))
    if not chapters:
        print(f"error: no markdown files in {src}", file=sys.stderr)
        return 1

    out = (args.out.expanduser().resolve() if args.out
           else src / f"{slugify(args.title)}.pdf")
    if out.suffix.lower() == ".epub":
        # The EPUB path is derived from this one, so an .epub here would name
        # both formats the same file and the second write would eat the first.
        print("error: --out names the PDF; give it a .pdf path. The EPUB is "
              "written beside it with the same stem.", file=sys.stderr)
        return 1
    out.parent.mkdir(parents=True, exist_ok=True)

    # Built once, before the fixed-point loop: its content does not depend on
    # page numbers, so re-rendering it on every pass would only cost time.
    fm_path = src / fm_name
    front_matter = build_front_matter(fm_path) if fm_path.is_file() else None

    # A glossary is bound when the folder holds one. `"glossary": true` in
    # book.json is a declaration rather than a switch: it says this book is
    # meant to have one, so a missing file is an error instead of a book that
    # quietly ships without the thing it promised.
    gloss_path = src / gloss_name
    glossary: list[tuple[str, int | None, str]] = []
    if cfg.get("glossary") is True and not gloss_path.is_file():
        print(f"error: book.json declares a glossary but {gloss_name} is not in "
              f"{src}", file=sys.stderr)
        return 1
    if gloss_path.is_file() and not args.no_glossary and cfg.get("glossary") is not False:
        glossary = load_glossary(gloss_path)
        stray = sorted({c for _, c, _ in glossary if c
                        and c not in {ch["num"] for ch in chapters}})
        if stray:
            print(f"error: {gloss_name} points at chapter(s) this book does not "
                  f"have: {', '.join(str(c) for c in stray)}", file=sys.stderr)
            return 1

    want_index = not args.no_index
    terms: list[tuple[str, str, bool]] = []
    terms_source = "none"
    terms_curated = False
    if want_index:
        terms_path = args.terms or (src / cfg.get("terms_file", "terms.txt"))
        if terms_path.is_file():
            terms = load_terms_file(terms_path)
            terms_curated = True
            terms_source = f"{terms_path.name} ({len(terms)} curated)"
        else:
            terms = harvest_terms(chapters, args.max_terms)
            terms_source = f"harvested from the text ({len(terms)} candidates)"

    # Read here, once, before the first render. Every settling pass and the
    # EPUB after them print this same value, so one binding carries one stamp.
    stamp = bind_stamp()
    footer = args.title
    state: dict = {}
    figures: list[dict] = []
    slides: list[dict] = []
    missing: list[str] = []
    narrowed: list[tuple] = []
    tables: list[dict] = []
    col_plan: dict = {}
    settled = 0

    for attempt in range(1, MAX_PASSES + 1):
        page_html, figures, slides = assemble(args.title, cfg, chapters, src,
                                              state, want_index, css=css,
                                              stamp=stamp, glossary=glossary,
                                              front_matter=front_matter,
                                              col_plan=col_plan)
        tables = render(page_html, src, out, args.title, body_pt)
        # Planned once, from the first render, and then held. The widths come
        # from font measurements of the cells' own words, which no later pass
        # changes, so recomputing could only let the plan chase the layout it
        # had just altered. Holding it also keeps the settling test below
        # honest: after this pass the HTML is fixed and only page numbers move.
        if attempt == 1:
            col_plan = plan_columns(tables)
            if col_plan:
                # The HTML the next pass assembles differs from the one just
                # measured, so nothing read off this render can be treated as
                # settled. `state` is still empty here, so skipping the rest of
                # the body is all it takes to make the next pass a fresh first
                # pass against the planned HTML.
                continue
        texts = page_texts(out)
        (new_pages, new_index, new_figs, new_lof,
         new_cover, new_gloss) = locate(texts)

        absent = [c["num"] for c in chapters if c["num"] not in new_pages]
        lost = [f["number"] for f in figures if f["id"] not in new_figs]
        if absent or lost or (want_index and not new_index) or (
                glossary and not new_gloss):
            print(f"error: pass {attempt} could not locate chapters {absent}, "
                  f"figures {lost}, the glossary, or the index", file=sys.stderr)
            return 1

        # The index points into the chapters, so the body it searches has to
        # stop at whichever piece of back matter comes first. Without this a
        # term would be indexed to the glossary page that defines it, which is
        # the one page a reader following that number does not need.
        if glossary:
            body_end = new_gloss - 1
        elif want_index:
            body_end = new_index - 1
        else:
            body_end = len(texts) - 1
        new_entries: list[tuple[str, list[int]]] = []
        if want_index:
            new_entries, missing, narrowed = build_term_index(
                terms, texts, new_pages[1], body_end, footer)

        fresh = {"pages": new_pages, "index_page": new_index,
                 "fig_pages": new_figs, "lof_page": new_lof,
                 "cover_end": new_cover, "entries": new_entries,
                 "gloss_page": new_gloss}
        if fresh == state:
            settled = attempt
            break
        state = fresh
    else:
        print(f"error: page numbers did not settle in {MAX_PASSES} passes",
              file=sys.stderr)
        return 1

    pages, index_page = state["pages"], state["index_page"]
    entries = state["entries"]

    # The probes are how every page number above was found, and they are white
    # 5pt text, so until now they stayed in the finished PDF's text layer: a
    # screen reader read "ZQCH016QZ" aloud and a copy and paste picked it up.
    # Now the settled book is rendered once more with them hidden. Hidden, not
    # removed: `visibility: hidden` keeps each probe's box, so nothing on any
    # page can move, and Chromium paints no text for it. That is checked rather
    # than assumed. The clean render has to match the probed one page for page
    # once the probe strings are taken out, or the probed PDF is put back and
    # the run says why, because a page number that moved is worse than a marker
    # in the text layer.
    probed = page_texts(out)
    clean_html = page_html.replace(
        "</head>", "<style>.probe{visibility:hidden !important;}</style></head>", 1)
    tables = render(clean_html, src, out, args.title, body_pt)
    final = page_texts(out)

    # Whitespace first, as locate() does: pdftotext can split a 5pt probe
    # across a space, and a probe left half-matched would read as a changed
    # page and keep the markers in for the wrong reason.
    def flat(page: str) -> str:
        return PROBE_RE.sub("", re.sub(r"\s+", "", page))

    markers_hidden = (len(final) == len(probed)
                      and all(flat(a) == flat(b) for a, b in zip(probed, final))
                      and not any(PROBE_RE.search(re.sub(r"\s+", "", t)) for t in final))
    if not markers_hidden:
        tables = render(page_html, src, out, args.title, body_pt)
        final = page_texts(out)
    total = len(final) - (1 if not final[-1].strip() else 0)
    print(f"wrote {out}")
    print(f"pages: {total}   chapters: {len(chapters)}")
    # The size is the one input that changes the page count by more than half
    # and leaves no trace in the output, so say which one bound this book. Naming
    # both ends beside it means the edition someone actually wanted is one line
    # away for anyone who came here because the count surprised them.
    if body_pt == DEFAULT_BODY_PT:
        print(f"type: {body_pt:g}pt body (the default; --type-size "
              f"{MAX_BODY_PT:g} binds large print, {MIN_BODY_PT:g} the "
              f"compact edition)")
    else:
        print(f"type: {body_pt:g}pt body (--type-size; "
              f"the default is {DEFAULT_BODY_PT:g}pt)")
    if state["cover_end"] != 1:
        print(f"  warning: the cover runs onto page {state['cover_end'] or '?'}, "
              f"so Contents is not page 2. Shorten the description or the "
              f"footnote until the cover fits on one page.")
    # A title too long for the footer's cap is ellipsized on every page, and the
    # cut form is what reaches the text layer, so a search or a copy returns it
    # too. Nothing errors and nobody sees it without looking at a footer, which
    # is the same silent failure the figure legibility check exists to refuse.
    footer_pt = scaled_pt(FOOTER_PT, body_pt)
    fits = int(TITLE_CHARS_PER_PT / footer_pt)
    if len(args.title) > fits:
        print(f"  warning: the running title is {len(args.title)} characters and "
              f"roughly {fits} fit the footer at {footer_pt:g}pt, so it will "
              f"print cut short on every page.")
        print(f"    The cap is a fixed 5in, so a larger body leaves less room: "
              f"about {int(TITLE_CHARS_PER_PT / scaled_pt(FOOTER_PT, MIN_BODY_PT))} "
              f"characters at {MIN_BODY_PT:g}pt against {fits} here. Shorten "
              f"the title, or bind at a smaller size with --type-size.")
    # The same silent cut as the running title, one measure over. `.chapter pre`
    # scrolls on a screen and stops at the margin on paper, and the lost tail is
    # gone from the text layer as well, so a reader cannot recover it by
    # selecting the line. A documentation note does not reach the person binding
    # a book full of long commands; this does.
    pre_pt = scaled_pt(TYPE_SCALE["pre"], body_pt)
    code_fits = int(CODE_CHARS_PER_PT / pre_pt)
    over = [(len(ln), ch, ln) for ch in chapters for ln in ch["fenced"]
            if len(ln) > code_fits]
    if over:
        over.sort(key=lambda t: -t[0])
        print(f"  warning: {len(over)} fenced line(s) run past the "
              f"{code_fits} characters that fit the measure at {pre_pt:g}pt, "
              f"so they will print cut short:")
        for n, ch, ln in over[:8]:
            print(f"    ch {ch['num']} ({n} chars): {ln[:code_fits]}")
        if len(over) > 8:
            print(f"    ...and {len(over) - 8} more")
        print(f"  The cut text is absent from the PDF's text layer too, so it "
              f"cannot be copied out. Shorten the line, or bind at a smaller "
              f"size with --type-size.")
    # A table too wide for the measure breaks its words mid-token rather than
    # overflowing, because the cells carry `overflow-wrap: anywhere`. That is
    # the right trade against the alternative, which was the whole book
    # shrinking (see CSS_TEMPLATE), and it is still not something to ship
    # unseen: the page looks deliberate and only a reader notices "Relatio /
    # nal". The break is observed rather than predicted, so a table listed here
    # has already broken a word in the PDF just written.
    wide = [t for t in tables if t["broken"]]
    if wide:
        def worst_column(t):
            """The column furthest below the width its own longest word needs.

            Reported per column rather than per table because the table-level
            sum does not explain the common case: 53 of the reference book's 58
            breaking tables wanted less than the full measure and were squeezed
            anyway, so their table-level figure is negative and says nothing
            about what to shorten.
            """
            pairs = list(zip(t["col_natural_pt"], t["col_actual_pt"]))
            best = (float("-inf"), -1)
            for i, (need, got) in enumerate(pairs):
                if need - got > best[0]:
                    best = (need - got, i)
            return best if best[1] >= 0 else (0.0, -1)

        wide.sort(key=lambda t: -worst_column(t)[0])
        print(f"  warning: {len(wide)} of {len(tables)} table(s) print a word "
              f"broken mid-word, because a column is narrower than its own "
              f"longest word:")
        for t in wide[:6]:
            short, i = worst_column(t)
            ch = f"ch {t['ch']}" if t["ch"] else "front matter"
            shown = ", ".join(t["broken"][:4])
            more = f", +{len(t['broken']) - 4} more" if len(t["broken"]) > 4 else ""
            name = ""
            if 0 <= i < len(t["heads"]) and t["heads"][i]:
                name = f' "{t["heads"][i][:24]}"'
            room = t["avail_pt"] - t["natural_pt"]
            fit = (f"the table has {room:.0f}pt to spare" if room >= 0
                   else f"the table needs {-room:.0f}pt more than the measure")
            where = (f"column {i + 1}{name} is {short:.0f}pt short of its "
                     f"longest word" if i >= 0 and short > 0 else
                     "no column is short of its longest word")
            print(f"    {ch} ({t['cols']} columns): {where}, and {fit}.")
            print(f"      breaks: {shown}{more}")
        if len(wide) > 6:
            print(f"    ...and {len(wide) - 6} more")
        roomy = sum(1 for t in wide if t["avail_pt"] >= t["natural_pt"])
        if roomy:
            print(f"  {roomy} of these have room to spare and were squeezed "
                  f"anyway: `overflow-wrap: anywhere` drops a cell's "
                  f"min-content width to one character, so auto layout can "
                  f"hand a column less than its longest word. Shortening the "
                  f"neighbouring column's text is what widens this one.")
        if len(wide) - roomy:
            print(f"  {len(wide) - roomy} genuinely need more than the "
                  f"{COLUMN_MEASURE_PT / 72:g}in measure. Shorten the cell "
                  f"text, split the table, or move the widest column into a "
                  f"list.")
        # Worth saying only when there is room below to move into, and worth
        # saying at all because the intuition runs the other way: the measure
        # is a fixed 6.0in at every size while the type scales, so a smaller
        # binding buys real width here. It buys none for a fenced line, whose
        # threshold is a ratio of the same two quantities.
        if body_pt > MIN_BODY_PT:
            ratio = (scaled_pt(TYPE_SCALE["table"], MIN_BODY_PT)
                     / scaled_pt(TYPE_SCALE["table"], body_pt))
            print(f"  --type-size buys width here, unlike for a fenced line: "
                  f"the measure is a fixed {COLUMN_MEASURE_PT / 72:g}in at "
                  f"every size while the words scale, so the same table at "
                  f"{MIN_BODY_PT:g}pt needs about {ratio:.0%} of the width it "
                  f"needs at {body_pt:g}pt.")
    if figures:
        print(f"figures: {len(figures)}, list on page {state['lof_page']}")
        # A figure whose labels land below the legibility floor prints as a
        # smudge. Nothing errors, so say so rather than shipping it silently.
        cramped = [f for f in figures
                   if f.get("min_pt") and f["min_pt"] < MIN_LEGIBLE_PT]
        if cramped:
            print(f"  {len(cramped)} figure(s) will print text below "
                  f"{MIN_LEGIBLE_PT:.0f}pt and need their type scaled up:")
            for f in sorted(cramped, key=lambda x: x["min_pt"])[:8]:
                print(f"    Figure {f['number']}: smallest label "
                      f"{f['min_pt']:.1f}pt (viewBox {f['vb_width']:.0f} wide) "
                      f"- {f['caption'][:44]}")
            if len(cramped) > 8:
                print(f"    ...and {len(cramped) - 8} more")
            print("  See references/diagram-style.md, 'The sizing rule'.")
        # A raster figure splits into one thing that can be measured and one
        # that cannot, and the two are reported separately on purpose. Folding
        # them together would let a passing resolution number read as a
        # legibility pass, which is the confusion this whole check exists to
        # remove: they are independent, and a finely-sampled render of tiny
        # type clears every DPI floor while still printing as a smudge.
        soft = [f for f in figures
                if f.get("dpi") and f["dpi"] < MIN_FIGURE_DPI]
        if soft:
            print(f"  {len(soft)} raster figure(s) print below "
                  f"{MIN_FIGURE_DPI:.0f} DPI and will look soft on paper:")
            for f in sorted(soft, key=lambda x: x["dpi"])[:8]:
                need = math.ceil(MIN_FIGURE_DPI * f["px_width"] / f["dpi"])
                print(f"    Figure {f['number']}: {f['dpi']:.0f} DPI "
                      f"({f['px_width']}px wide, needs {need}px) "
                      f"- {f['caption'][:44]}")
            if len(soft) > 8:
                print(f"    ...and {len(soft) - 8} more")
            print("  Re-export at the larger pixel width, or redraw as SVG.")
        unchecked = [f for f in figures if f.get("unchecked_text")]
        if unchecked:
            print(f"  {len(unchecked)} raster figure(s) were NOT checked "
                  f"against the {MIN_LEGIBLE_PT:.0f}pt legibility floor:")
            for f in unchecked[:8]:
                if f.get("px_width"):
                    size = f"{f['px_width']}x{f['px_height']}px"
                elif f.get("external_src"):
                    size = "not a local file (data: or remote src)"
                else:
                    size = "dimensions unreadable"
                print(f"    Figure {f['number']}: {size} "
                      f"- {f['caption'][:44]}")
            if len(unchecked) > 8:
                print(f"    ...and {len(unchecked) - 8} more")
            print(f"  A raster declares no font sizes, so nothing here can "
                  f"measure the type inside it. Absence from the "
                  f"{MIN_LEGIBLE_PT:.0f}pt list above is not a pass for these. "
                  f"Check them by eye in the built PDF, or redraw as SVG and "
                  f"let the builder measure them.")
    if slides:
        # Reported apart from the figures, under their own heading, because
        # they are a different kind of thing: teaching aids rather than figures
        # of the book's argument, unnumbered and absent from the Figures page.
        # Folding the two counts together is what buried the reference book's
        # ten real figures under sixty-six slides.
        print(f"slides: {len(slides)} lesson-script slide(s), set at "
              f"{SLIDE_WIDTH_SHARE * 100:.0f}% measure, not numbered and not "
              f"on the Figures page")
        tight = [f for f in slides
                 if f.get("min_pt") and f["min_pt"] < MIN_LEGIBLE_PT]
        if tight:
            print(f"  {len(tight)} slide(s) print text below "
                  f"{MIN_LEGIBLE_PT:.0f}pt at that width:")
            for f in sorted(tight, key=lambda x: x["min_pt"])[:8]:
                print(f"    Slide {f['number']}: smallest label "
                      f"{f['min_pt']:.1f}pt (viewBox {f['vb_width']:.0f} wide) "
                      f"- {f['caption'][:44]}")
            if len(tight) > 8:
                print(f"    ...and {len(tight) - 8} more")
            print(f"  The floor is the same {MIN_LEGIBLE_PT:.0f}pt a figure "
                  f"answers to; the slide column is narrower, so art that "
                  f"cleared it as a figure may not clear it here.")
        dim = [f for f in slides if f.get("dpi") and f["dpi"] < MIN_FIGURE_DPI]
        if dim:
            print(f"  {len(dim)} raster slide(s) print below "
                  f"{MIN_FIGURE_DPI:.0f} DPI:")
            for f in sorted(dim, key=lambda x: x["dpi"])[:8]:
                print(f"    Slide {f['number']}: {f['dpi']:.0f} DPI "
                      f"({f['px_width']}px wide) - {f['caption'][:44]}")
        blind = [f for f in slides if f.get("unchecked_text")]
        if blind:
            print(f"  {len(blind)} raster slide(s) were NOT checked against "
                  f"the {MIN_LEGIBLE_PT:.0f}pt floor; a raster declares no "
                  f"font sizes. Check those by eye or redraw as SVG.")
    if glossary:
        linked = sum(1 for _, c, _ in glossary if c)
        print(f"glossary: {len(glossary)} terms, {linked} carrying a chapter "
              f"reference, starting on page {state['gloss_page']}")
    if want_index:
        refs = sum(len(p) for _, p in entries)
        print(f"index: {len(entries)} entries, {refs} page references, "
              f"starting on page {index_page}")
        print(f"terms: {terms_source}")
        # A term that matches nothing subtracts itself silently: the index
        # simply comes up an entry short and the count above reads as ordinary
        # as any other. It was reported only under --report, so the one real
        # instance was found by diffing two builds. Say it here for the same
        # reason the figure legibility floor is said here.
        #
        # "curated" only when they were. A harvested run has no terms file to
        # widen, and a harvested multi-word term whose one occurrence straddles
        # a page break lands here through no fault of anyone's.
        if missing:
            noun = "curated term" if terms_curated else "index term"
            print(f"  warning: {len(missing)} {noun}(s) matched nothing "
                  f"and are absent from the index:")
            for d in missing[:8]:
                print(f"    {d}")
            if len(missing) > 8:
                print(f"    ...and {len(missing) - 8} more")
            print(f"  A term can also fall out at one size and not another: the "
                  f"PDF's text layer breaks a line inside the term, so a "
                  f"pattern allowing a single separator stops matching the "
                  f"wrapped form.")
            if terms_curated:
                print(f"  Widen the pattern in {terms_path.name}.")
    print(f"page numbers settled after {settled} passes "
          f"(re-reading the finished PDF reproduces every printed number)")
    if not markers_hidden:
        print("  warning: hiding the page markers changed the layout, so they were "
              "left in the PDF's text layer. A screen reader or a copy will pick up "
              "strings like ZQCH001QZ in this file.")

    # Both formats, every run. The PDF is for reading with a pen on a fixed
    # page; the EPUB is for reading at whatever font size the reader picked.
    epub_out = out.with_suffix(".epub")
    report = build_epub(args.title, cfg, chapters, src, epub_out,
                        terms, want_index, stamp, glossary,
                        front_matter_path=fm_path, body_pt=body_pt)
    print(f"wrote {epub_out}")
    print(f"epub: {len(chapters)} chapters, {report['figures']} figures, "
          f"{report['assets']} packaged images, "
          f"{report['glossary']} glossary terms, "
          f"{report['entries']} index entries (chapter-linked, no page numbers)")
    if report["generated_cover"]:
        print(f"  cover: generated from the PDF's cover page, "
              f"{COVER_PNG_WIDTH_PX}px wide. Set cover_image in book.json to "
              f"supply your own. A device letterboxes this to its own shape, "
              f"since it keeps the printed page's proportions.")
    elif not report["cover_declared"]:
        print("  warning: no cover_image in book.json and the cover page "
              "could not be rendered, so the EPUB ships without cover art "
              "and a library will show a blank tile.")
    if report["missing_images"]:
        print(f"  warning: {len(report['missing_images'])} image(s) were not "
              f"found and are not in the package: "
              f"{', '.join(report['missing_images'][:5])}")
    # The EPUB matches terms against the chapter source and the PDF matches the
    # rendered text layer, so the two indexes can disagree about one term and
    # both be working as written. A term only ever written inside a fenced code
    # block is the case that actually occurs: strip_markdown drops fences, so
    # the EPUB cannot see it, while the PDF renders the fence and finds it.
    if report["missing_terms"]:
        miss = report["missing_terms"]
        noun = "curated term" if terms_curated else "index term"
        print(f"  warning: {len(miss)} {noun}(s) matched nothing in the "
              f"chapter text and are absent from the EPUB index:")
        for d in miss[:8]:
            print(f"    {d}")
        if len(miss) > 8:
            print(f"    ...and {len(miss) - 8} more")
        print(f"  A term the PDF index carries and this one does not is "
              f"usually written only inside a fenced code block, which the "
              f"EPUB's matching does not read. Mention it in prose too if it "
              f"belongs in both indexes.")

    if args.report:
        print("\n-- chapter start pages --")
        for ch in chapters:
            print(f"   {ch['num']:3d}  p{pages[ch['num']]:<4} {ch['title']}")
        if figures:
            print("\n-- figures --")
            for f in figures:
                print(f"   {f['number']:>5}  p{state['fig_pages'][f['id']]:<4} "
                      f"{f['caption'][:60]}")
        if want_index:
            print("\n-- terms that matched nothing --")
            for d in missing or ["   (none)"]:
                print(f"   {d}")
            print("\n-- terms narrowed to their discussion pages --")
            for d, was, now, rule in sorted(narrowed, key=lambda x: -x[1]):
                print(f"   {d}: {was} pages -> {now} ({rule})")
            print("\n-- index entries --")
            for display, pgs in entries:
                print(f"   {len(pgs):3d}  {display}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
