#!/usr/bin/env python3
"""Verify that a book's provenance marks point OUT at sources that hold them.

    check-provenance.sh [--locators-only|--quotes-only] [--emit-worklist DIR] [--chapters N,M] <book-folder>

`check-references.sh` runs the other direction: it verifies that citations
pointing INTO a book resolve to chapters and paragraphs that exist. Nothing
checked the marks pointing out. A `<!-- src: syllabus p. 4 -->` naming a page
the syllabus does not have, or a source the book never read, looked exactly
like one that was right.

Three checks, in ascending order of what they are worth. The ladder is the same
one check-references.sh climbs, and the reason is the same: the cheap checks are
here because their absence let a green line be printed over a file nothing had
opened, not because they prove much on their own.

  1. Source existence. Every component of every mark names a source `book.json`
     declares, or is `fill`, or is a reference back into the book. A component
     that names none of those is a source the book does not have: a typo, an
     undeclared file, or an invented name. This is the only check that can
     catch a hallucinated source, and it is cheap.

  2. Locator resolution. `p. 4` is within the PDF's page count, `slide 9` within
     the deck's slide count, `§ Join Algorithms` is a heading the file carries,
     `Q19` an item the quiz defines, `[16-4]` a paragraph the book defines.
     Weak, and known to be weak. Run against the reference book on
     2026-09-13, when this script was written, nothing failed: 188 slide
     citations, 178 page citations, 119 quiz and exam items, 14 steps, 553
     section names and 125 components naming a source whole all resolved, and
     139 paragraph tags plus 24 chapter references checked against the book
     itself. A further 31 locators were left unparsed and counted rather than
     passed. It found nothing the day it was written, and it is here to catch
     the drift a /updatebook edit or a Canvas re-export introduces later.

  3. Quotation attribution. Every quoted run of MIN_QUOTE characters or more in
     a unit appears in one of the sources that unit's mark names. This is the
     check that matters, and it is the external-source analogue of
     check-references.sh check 2: a locator resolving is not the same claim as
     the source saying what the citing paragraph says it says.

     **It reports REVIEW and never FAIL, and that was measured rather than
     chosen.** Run against the reference book before the severity was settled, a
     hard failure fired ten times and was wrong ten times. Four differed from
     the source in punctuation alone, which `words()` now folds away. Three
     were the book quoting a reader's imagined sentence rather than a source
     ("a dataset has many samples" at ch. 7, the shape a student gets wrong),
     and their marks say `fill` beside the source. One was the book quoting
     its own recommendation. One was a deviation the mark itself declares in a
     parenthetical: chapter 18 writes the interview prompt's "Walk me" as "Take
     me", because `OUTLINE.md § House rules` bans "walk" from the page, and the
     mark records the substitution in words no script can read.

     None of those is a defect, and none is separable from a real misquotation
     by machine. A gate that fires only on false positives teaches the reader
     to pass it, so this one reports and counts instead.

**What check 3 cannot reach, and why the number is printed rather than
implied.** Three of the reference book's sources are image-only PDFs (the
syllabus, the Canvas setup guide and the CSC220 syllabus; all "Microsoft: Print
To PDF", 0 extractable characters, measured 2026-09-11 and recorded in the
repo's CLAUDE.md under "Reading large files"). `pdftotext` returns nothing for
them, so a quotation attributed to one cannot be searched at all, and a grep
that finds nothing in them is indistinguishable from a grep that cannot see
them. Such a quotation is counted and reported as UNVERIFIABLE rather than
passed, because a checker that reports OK over material it could not read is
the failure this whole family of scripts exists to refuse.

**UNVERIFIABLE is decided on ANY named source being unreadable, not all of
them**, and the asymmetry is deliberate. A mark naming both the syllabus and the
Course Outline, whose quotation is not in the Course Outline, could be quoting
the syllabus correctly or quoting nothing correctly, and no tool here can tell
which. Reporting it as a REVIEW would assert the stronger of those two readings.
Measured 2026-09-13 on the reference book: 12 of the 28 unverifiable quotations
name a readable source alongside an unreadable one, so this is the common case
rather than an edge.

What none of the three reaches is a PARAPHRASE that drifts from its source. A
mark reading `<!-- src: Prior note -->` on a sentence claiming that note
"assumes Postgres", where the note names no engine, resolves perfectly and
quotes nothing. That needs a model reading both, which is a different kind of
check from anything in this folder. It is a separate filed ticket, and `--emit-worklist` below
is this script's half of it.

## --emit-worklist: handing the paraphrase pass what it needs

`--emit-worklist DIR` writes one JSON file per chapter, holding every unit that
rests on an external source, each with the unit's own prose and a POINTER to
every source its mark names. A reading agent opens those sources and judges
whether the paragraph is supported by what it finds. `--chapters N,M` scopes
the emission to named chapters, which is what an /updatebook run wants: it
already knows which chapters its edit reached, so it has no reason to pay for
the other seventeen.

One file per chapter rather than one per book, because the point of the split
is that no single context ever holds the whole book's prose. Against the reference
book that is 49,509 words across 551 units, measured 2026-09-13.

**It emits pointers rather than excerpts, and that is a correction to the
ticket rather than a shortcut.** That ticket proposed `(unit, source, the excerpt
at the locator)` triples, reasoning that this script already resolves every
component to a file plus a locator and that the excerpt therefore falls out.
The resolution is here. The excerpt is not, and each reader above destroys
exactly the text it would need:

  * `_read_pdf` joins every page and passes the result through `norm`, which
    collapses the `\f` page separators along with all other whitespace. No page
    boundary survives, and `p. 4` is asserted against `count` alone.
  * `_read_markdown` keeps one lowercased blob plus a `set` of headings. A set
    carries no offsets, so there is nothing to slice a section from.
  * `_read_pptx` keeps per-slide text, but in `words()` form: lowercased,
    punctuation dropped, `[a-z0-9]+` runs rejoined. Readable by `in`, not by a
    person.

Writing those slicers would also mean trusting a boundary this script already
declines to trust for a weaker purpose. `holds()` refuses to narrow a page
citation because "pdftotext's page breaks are not reliable enough to fail a
quotation on". A paraphrase judgement resting on a slice the quotation check
will not rest on is the weak-for-strong substitution this whole family of
scripts exists to refuse.

So the line is drawn at what the Read tool can open. Markdown and PDF it opens
directly, and its `pages` parameter renders an image-only PDF visually, which
is the only way the source repo's text-free PDFs can be read at all. A `.pptx` it
does not open, so a deck citation is the one kind that carries its text inline,
taken from `_slide_text` before `norm` reaches it. The decks are small enough
for that to cost nothing: 12 to 14 slides and 250 to 305 words each, measured
2026-09-13 across the reference book's five.

**What travels inline is SLIDE text, and only that.** A deck's speaker notes
live in `ppt/notesSlides/notesSlideN.xml`, which nothing here reads, so a claim
about what a deck's notes do or do not say cannot be settled from the worklist
and the reading agent has to open the `.pptx` itself. Measured on the first full
run, 2026-09-13: eight of the eighteen chapter agents said in their own reports
that they did exactly that, to check a chapter's claim that a deck carries no
speaker notes, and two more opened a deck for other reasons. The claims were
right, and
all 66 notesSlides parts across the five decks hold a slide number and nothing
else, but the worklist gave no way to know it.

Only components naming an external source are emitted. A `fill` component
declares no source and an in-book `[16-4]` is check-references.sh's job, so
neither can be judged against anything here; both are still listed on the unit
under `unchecked`, because a paragraph resting half on a source and half on the
book's own knowledge must not be read as though the source owed all of it.

## What book.json must declare

    "provenance": true,
    "sources": {
      "syllabus":        "../sources/data-modeling-syllabus.pdf",
      "Week 5 deck":     "../sources/week-5-deck.pptx",
      "[L1] to [L5]":    ["...Week 1 Lab...", "...Week 2 Lab...", ...]
    },
    "unsourced": ["measured"]

Keys are the shorthand the marks use, spelled exactly as the book spells it;
the reference book fixes its own spellings in `OUTLINE.md § House rules`. Values
are paths relative to the book folder, or a list of them where one shorthand
names several files (`[L1] to [L5]`, `every assignment page`). A component is
matched against the LONGEST declared key it starts with, so `[L1] to [L5]` wins
over `[L1]` and the shorter key does not have to be reordered out of the way.

`unsourced` extends the built-in `fill` with the book's own words for a
component that names no external source. The reference book adds `measured`,
which introduces a measurement it made itself and records in
`OUTLINE.md § Anchor ledger`.

A book with `"provenance": true` and no `sources` map is reported as
undeclared and exits 0 without claiming anything. Nothing is asserted about it,
and the summary says so rather than printing OK.

Exits 0 when nothing failed, 1 on any failure, 2 on bad usage.
"""
import re, sys, json, html, pathlib, zipfile, subprocess, collections, datetime
import importlib.util, importlib.machinery

HERE = pathlib.Path(__file__).resolve().parent


def _load_refs():
    """Borrow check-references.sh's quote pairing rather than re-deriving it.

    `quoted_spans` carries three rounds of review and a measured account of what
    each round fixed, and re-implementing it here would give this script a
    second, worse copy that drifts from the first. The import is by path because
    the file is named `.sh` while being Python, which is the convention the
    folder already uses. `check-references.sh` guards its entry point with
    `if __name__ == "__main__"`, so importing it runs nothing.

    The loader is named explicitly because `spec_from_file_location` infers one
    from the suffix and hands back None for `.sh`. That then fails a line later
    as an AttributeError on NoneType, which says nothing about the file.
    """
    path = HERE / "check-references.sh"
    if not path.exists():
        print(f"error: {path} is missing; this script borrows its quote pairing",
              file=sys.stderr)
        sys.exit(2)
    loader = importlib.machinery.SourceFileLoader("check_references", str(path))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


refs = _load_refs()
MIN_QUOTE = refs.MIN_QUOTE

MARK = re.compile(r"<!--\s*src:\s*(.*?)\s*-->")
SUGG = "## Suggested reading"

# In-book references a mark may carry. Both are verified against the book
# itself rather than against any declared source.
TAG = re.compile(r"^\[(\d+)-(\d+)\]$")
CHAPTER = re.compile(r"^ch(?:apter|\.)\s*(\d+)$", re.I)
TAGDEF = re.compile(r"^\[(\d+)-(\d+)\] ")

# Locator grammars. Each is tried against the remainder left after the source
# shorthand has been stripped off the front of a component.
PAGES = re.compile(r"^pp?\.\s*(\d[\d\s,\-–]*(?:\s*and\s*\d+)?)\s*$")
SLIDES = re.compile(r"^slides?\s+(\d[\d\s,\-–]*(?:\s*(?:and|to)\s*\d+)*)\s*$")
# `Q` opens an item citation; every number in it is then checked, the way PAGES,
# SLIDES and STEP already check theirs. Capturing only the first one made
# `exam Q13, Q14, Q22` assert question 13 and count the whole component
# "resolved", which is the weak-for-strong substitution this script is built to
# refuse, committed in the script doing the refusing. 19 live components in the
# reference book name more than one item; measured 2026-09-13.
#
# **Left unanchored on purpose; two review rounds proposed anchoring it to `$`.**
# An anchored pattern would have to enumerate every shape a citation's tail can
# take, and the ones already in the guide include `Q2, Q6`, `Q1 to Q6`,
# `Q3 (options A and B)` and `Q1 to Q6 (items, points, options)`. A tail this
# pattern failed to anticipate would stop matching ITEM, fall through to the
# section branch, and be reported as a heading the quiz does not carry: a false
# FAIL. Unanchored, the same surprise costs an extra number checked against a
# list of real items, which is a false PASS only if that number also happens to
# name a real item. Measured 2026-09-13 across all 55 asserted item pairs in the
# guide: zero false passes. Prefer the failure direction that cannot invent a
# defect.
ITEM = re.compile(r"^Q\d", re.I)
STEP = re.compile(r"^steps?\s+(\d[\d\s,\-–]*(?:\s*(?:and|to)\s*\d+)*)", re.I)
# An ordered-list item at the head of a line. The labs and exercises write their
# requirements this way, so `step 4` and `Requirements 4` both resolve to one.
ORDERED = re.compile(r"^\s*(\d+)\.\s", re.M)
SECTION = re.compile(r"^§\s*(.+)$")
# A trailing item qualifier a heading citation may carry: "Requirements 1",
# "Requirements, item 3", "Stub and Rubric", "first paragraph".
QUALIFIER = re.compile(
    r"(?:,?\s*item\s+\d+"
    r"|\s+\d+(?:\s*(?:,|and)\s*\d+)*"
    r"|,?\s*first paragraph)\s*$", re.I)

fail = 0
review = 0


def problem(msg, detail=None):
    global fail
    fail += 1
    print(f"FAIL  {msg}")
    if detail:
        print(f"      {detail}")


def flag(msg, detail=None):
    global review
    review += 1
    print(f"REVIEW {msg}")
    if detail:
        print(f"       {detail}")


# --------------------------------------------------------------------------
# Reading the sources
# --------------------------------------------------------------------------

def norm(s):
    """Fold everything a quotation may have been re-punctuated through.

    check-references.sh's `norm` folds the quote characters and collapses
    whitespace, which is all it needs for text that never left markdown. A
    source here may be a Canvas HTML export or a slide, so this adds the dashes
    (the book bans the em dash the sources use freely, per the repo's writing
    rules, so a quotation carrying one was rewritten around it), the markdown
    emphasis characters, and case.
    """
    s = refs.norm(s)
    s = s.replace("—", "-").replace("–", "-")
    s = re.sub(r"[*`_]", "", s)
    return re.sub(r"\s+", " ", s).strip().lower()


def words(s):
    """Reduce to the words, so a quotation matches on what it says.

    Check 3 compares this rather than `norm`, and the reason is a house rule
    rather than laziness. The reference book bans the em dash that its sources use
    constantly, and `OUTLINE.md § House rules` says a quotation carrying one "is
    rewritten around the dash or paraphrased". So the correctly-quoted form of
    `in class - show two SCD2 versions` is `in class, show two SCD2 versions`,
    and an exact comparison reports every such quotation as missing. Measured
    2026-09-13 across the reference book: four of the ten quotations that failed
    an exact match differed from their source in punctuation alone, three of
    them in exactly this substitution.

    Dropping the punctuation trades a class of false failure for a class of
    false pass, and that is the right way round here: a quotation whose words
    are the source's words and whose commas are not is the case the house rule
    creates deliberately, while two different sentences sharing every word in
    order is not a shape this material produces.
    """
    return " " + " ".join(re.findall(r"[a-z0-9]+", norm(s))) + " "


def strip_html(s):
    """Canvas page exports are HTML wrapped in a ```html fence.

    Decoding the entities is not cosmetic. The exports carry `&rsquo;`,
    `&ldquo;` and `&amp;` throughout, and a quotation searched against the raw
    text misses every criterion containing an apostrophe. Measured while
    designing this script: a naive search reported 93 of 212 quotations missing,
    and the Grading Outline's five universal checks were among them purely
    because of the entities.
    """
    s = re.sub(r"(?s)<(script|style).*?</\1>", " ", s)
    s = re.sub(r"<br\s*/?>|</p>|</div>|</li>|</h[1-6]>|</tr>", "\n", s)
    s = re.sub(r"<[^>]+>", " ", s)
    return html.unescape(s)


def headings_of(text, is_html):
    """Every heading a source carries, normalised.

    The markdown sources head their sections with `###`. The Canvas exports use
    `<h2>`/`<h3>` and, in places, a bold line standing alone; the lab pages use
    both a `###` heading and a bold total line. Collecting all three shapes is
    deliberate: a citation naming a bold line is a real citation, and refusing
    it would report a heading that exists as missing.
    """
    out = set()
    if is_html:
        for m in re.finditer(r"(?is)<h[1-6][^>]*>(.*?)</h[1-6]>", text):
            out.add(norm(strip_html(m.group(1))))
        for m in re.finditer(r"(?is)<strong[^>]*>(.*?)</strong>", text):
            out.add(norm(strip_html(m.group(1))))
    for line in text.splitlines():
        m = re.match(r"^\s*#{1,6}\s+(.*?)\s*$", line)
        if m:
            out.add(norm(m.group(1)))
        m = re.match(r"^\s*\*\*(.+?)\*\*\s*$", line)
        if m:
            out.add(norm(m.group(1)))
    out.discard("")
    return out


class Source:
    """One declared source, read once.

    `text` is None when nothing could read it, and that is a first-class state
    rather than an empty string: an image-only PDF and a PDF full of prose must
    not both search as "no match".

    `text` is the `norm` form, which keeps the punctuation the heading and item
    checks match on. `wtext` is the `words` form that check 3 searches.
    """

    def __init__(self, name, paths):
        self.name = name
        self.paths = paths
        # Set here as well as in the readers, so it is never read unset on a
        # source whose reader returned early or never ran.
        self.multi = len(paths) > 1
        self.missing = [p for p in paths if not p.exists()]
        self.kind = self._kind()
        self.text = None
        self.wtext = None
        self.headings = set()
        self.steps = set()   # ordered-list numbers the source defines
        self.units = {}      # slide number -> that slide's own word form
        # Slide text as a person would read it: (file stem, index within that
        # file, text). Kept alongside `units` rather than replacing it, because
        # `units` is what check 3 searches and it must stay in `words()` form.
        # This one is what --emit-worklist hands the reading agent, since the
        # Read tool cannot open a .pptx. Populated for multi-path decks too,
        # where `units` is deliberately left empty: pooling slide NUMBERS across
        # decks is what makes a locator resolve wrongly, while pooling slide
        # TEXT under its own file name asserts nothing and still lets the agent
        # read what was cited.
        self.raw_slides = []
        self.count = None    # pages, or slides
        self.why_unreadable = None
        if not self.missing:
            self._read()
        if self.text is not None:
            self.wtext = words(self.text)

    def _kind(self):
        exts = {p.suffix.lower() for p in self.paths}
        if exts == {".pdf"}:
            return "pdf"
        if exts == {".pptx"}:
            return "pptx"
        return "markdown"

    def _read(self):
        if self.kind == "pdf":
            self._read_pdf()
        elif self.kind == "pptx":
            self._read_pptx()
        else:
            self._read_markdown()

    def _read_markdown(self):
        raw = "\n".join(p.read_text(errors="replace") for p in self.paths)
        is_html = "<div" in raw or "<h1" in raw
        body = strip_html(raw) if is_html else raw
        self.text = norm(body)
        self.headings = headings_of(raw, is_html)
        self.steps = {int(m.group(1)) for m in ORDERED.finditer(body)}

    def _read_pdf(self):
        # Same rule as the decks: a shorthand naming several PDFs has no single
        # page number, so it does not get one. Summing them would make `p. 12`
        # resolve against a two-document total that no single document has,
        # which is the multi-deck fault one file type over. All four PDF sources
        # in the reference book are single-path, so this is a guard rather than a
        # fix to observed behaviour.
        self.multi = len(self.paths) > 1
        pages = 0
        chunks = []
        for p in self.paths:
            info = _run(["pdfinfo", str(p)])
            if info is None:
                self.why_unreadable = "poppler's pdfinfo is not installed"
                return
            m = re.search(r"^Pages:\s+(\d+)", info, re.M)
            pages += int(m.group(1)) if m else 0
            out = _run(["pdftotext", "-layout", str(p), "-"])
            chunks.append(out or "")
        self.count = None if self.multi else (pages or None)
        joined = norm("\n".join(chunks))
        if not joined:
            # The seven "Microsoft: Print To PDF" documents in the source repo hold
            # images of text. Page counting still works, so the locator check
            # runs; the quotation check cannot and says so.
            self.why_unreadable = "no text layer (image-only PDF)"
            return
        self.text = joined

    def _read_pptx(self):
        # A shorthand naming several decks has no single slide index, so it does
        # not get one. Restarting the per-file numbering built a `units` map
        # holding only the LAST deck's slides while `count` summed all of them:
        # measured 2026-09-13, `five decks` reported count 66 with units 1..14,
        # so `slide 60` resolved "ok" against a deck that has no slide 60, and a
        # quotation from Week 1's slide 3 was searched against Week 5's. Both
        # directions are wrong, and one of them is a false pass, which is the
        # single thing this script exists not to print. Leaving `count` unset
        # sends a slide locator to "review" (unasserted and counted), and
        # leaving `units` empty pools the text so a quotation is still searched
        # across every deck named.
        self.multi = len(self.paths) > 1
        chunks = []
        total = 0
        for p in self.paths:
            try:
                with zipfile.ZipFile(p) as z:
                    order = _slide_order(z)
                    total += len(order)
                    for i, member in enumerate(order, 1):
                        # `raw` is lifted out of the expression that used to
                        # compute `t` in one go; `t` is still exactly
                        # norm(html.unescape(_slide_text(...))), so nothing the
                        # three checks see has moved.
                        raw = html.unescape(_slide_text(
                            z.read(member).decode("utf-8", "replace")))
                        t = norm(raw)
                        if not self.multi:
                            self.units[i] = words(t)
                        self.raw_slides.append((p.stem, i, raw.strip()))
                        chunks.append(t)
            except (zipfile.BadZipFile, KeyError) as e:
                self.why_unreadable = f"could not read the deck: {e}"
                return
        self.count = None if self.multi else (total or None)
        self.text = " ".join(chunks)

    def holds(self, quote, unit=None):
        """Is this quotation in the source, or in the unit of it that was cited?

        `unit` narrows a deck citation to the slide it names. It is deliberately
        NOT applied to a page or a section: a page number is checked separately
        and pdftotext's page breaks are not reliable enough to fail a quotation
        on, and a section citation that is one heading off would otherwise turn
        a correct quotation into a missing one. Narrowing where the mapping is
        exact and pooling where it is not keeps a wrong answer from looking like
        a finding.
        """
        if self.wtext is None:
            return None
        if unit is not None and self.units:
            return quote in self.units.get(unit, "")
        return quote in self.wtext


def _slide_text(xml):
    """One slide's text, with its bullets kept apart.

    The run boundary and the bullet boundary are different things and only one
    of them is a space. `<a:t>` runs inside one `<a:p>` split a single line at a
    formatting change, so they rejoin with nothing between them; each `<a:p>` is
    its own bullet and rejoining those with nothing runs them together.
    Measured 2026-09-13: week 3's slide 6 came out as
    `numeric additive measuresforeign keys to dimensions`, and every quotation
    of one of its bullets reported as missing from the deck that holds it. Four
    chapters' worth of correct citations read as findings for this one reason.
    """
    out = []
    for p in re.finditer(r"(?s)<a:p>(.*?)</a:p>", xml):
        out.append("".join(m.group(1) for m in
                           re.finditer(r"(?s)<a:t>(.*?)</a:t>", p.group(1))))
    if not out:
        out = [m.group(1) for m in re.finditer(r"(?s)<a:t>(.*?)</a:t>", xml)]
    return "\n".join(out)


def _slide_order(z):
    """Slide parts in presentation order, not in filename order.

    `ppt/slides/slide12.xml` is not necessarily the twelfth slide: the order
    lives in presentation.xml's `sldIdLst` and is resolved through the rels
    file. Reading the filenames instead would make `slide 9` search the wrong
    slide's text, which is the "a pointer that resolves is not a pointer that
    resolves to the right thing" failure in miniature. Falls back to a numeric
    filename sort when either part is absent, which still gives a correct count.
    """
    names = sorted(
        (n for n in z.namelist() if re.fullmatch(r"ppt/slides/slide\d+\.xml", n)),
        key=lambda n: int(re.search(r"(\d+)", n).group(1)))
    try:
        pres = z.read("ppt/presentation.xml").decode("utf-8", "replace")
        rels = z.read("ppt/_rels/presentation.xml.rels").decode("utf-8", "replace")
    except KeyError:
        return names
    target = {m.group(1): m.group(2) for m in
              re.finditer(r'<Relationship[^>]*Id="([^"]+)"[^>]*Target="([^"]+)"', rels)}
    ordered = []
    for m in re.finditer(r'<p:sldId[^>]*r:id="([^"]+)"', pres):
        t = target.get(m.group(1), "")
        t = "ppt/" + t.replace("../", "")
        if t in z.namelist():
            ordered.append(t)
    return ordered if len(ordered) == len(names) else names


def _run(argv):
    try:
        r = subprocess.run(argv, capture_output=True, text=True)
    except FileNotFoundError:
        return None
    return r.stdout if r.returncode == 0 else None


# --------------------------------------------------------------------------
# Reading the book
# --------------------------------------------------------------------------

def split_components(s):
    """Split a mark on `;` at parenthesis depth zero.

    `fill (the gloss; the key)` is one component naming one thing. Splitting on
    every semicolon turns it into `fill (the gloss` and `the key)`, and the
    second then reads as a source nothing declares. Measured while designing
    this script: the naive split produced 1,893 components against the reference
    book where the paren-aware one produces 1,822, and all 71 of the difference
    were halves of a parenthetical.
    """
    out, buf, depth = [], [], 0
    for ch in s:
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth = max(0, depth - 1)
        if ch == ";" and depth == 0:
            out.append("".join(buf).strip())
            buf = []
        else:
            buf.append(ch)
    out.append("".join(buf).strip())
    return [c for c in out if c]


def units_of(path):
    """Yield (line number, the unit's text, its mark's components).

    A unit is what check-book.sh's provenance sweep calls one: the run of lines
    since the last blank line or the last mark. A table's rows collect together
    because nothing blank separates them, which is right, since one mark follows
    the whole table there.

    Fenced content is skipped, the way check-book.sh's own body sweeps skip it.
    A lab stub printed in a chapter holds string literals, and reading those as
    quotations would attribute a line of python to the syllabus.
    """
    lines = path.read_text().splitlines()
    buf, infence = [], False
    for ln, line in enumerate(lines, 1):
        if line.strip().startswith("```"):
            infence = not infence
            buf = []
            continue
        if infence:
            continue
        if line.strip() == SUGG:
            return
        m = MARK.search(line)
        if m:
            yield ln, "\n".join(buf), split_components(m.group(1))
            buf = []
        elif line.strip() == "" or line.lstrip().startswith("#"):
            buf = []
        else:
            buf.append(line)


def quotations(text):
    spans, unterminated = refs.quoted_spans(text)
    out = [q for _, q in spans if len(q.strip()) >= MIN_QUOTE]
    return out, unterminated


# --------------------------------------------------------------------------
# Resolving one component
# --------------------------------------------------------------------------

def match_source(component, keys):
    """Longest declared shorthand this component starts with, and the rest.

    Longest-first is what lets `[L1] to [L5]` and `[L1]` both be declared
    without the shorter one shadowing the longer. A leading "the" is dropped
    because the book writes both `the [Info] page` and `[Info] page`.
    """
    c = component
    if c.lower().startswith("the "):
        c = c[4:]
    for k in keys:
        if c == k:
            return k, ""
        if c.startswith(k):
            rest = c[len(k):].lstrip(" ,")
            return k, rest
    return None, component


def numbers(s):
    return [int(x) for x in re.findall(r"\d+", s)]


def strip_gloss(s):
    """Drop a trailing parenthetical gloss, counting nested parentheses.

    A regex anchored on `\\([^()]*\\)$` cannot cut
    `Stub (the to_ddl() example)`, because the inner `()` breaks the character
    class, and the uncut string then matches no heading. Scanning from the right
    with a depth counter costs four lines and handles it.
    """
    s = s.strip()
    if not s.endswith(")"):
        return s
    depth = 0
    for i in range(len(s) - 1, -1, -1):
        if s[i] == ")":
            depth += 1
        elif s[i] == "(":
            depth -= 1
            if depth == 0:
                return s[:i].strip()
    return s


def _slide_only(rest):
    """The slide a locator names, when it names exactly one.

    `--quotes-only` skips locator resolution but still needs this, because
    narrowing a deck quotation to its slide is what makes check 3 strong there.
    """
    m = SLIDES.match(strip_gloss(rest))
    if not m:
        return None
    nums = numbers(m.group(1))
    return nums[0] if len(nums) == 1 else None


def _pages_only(rest):
    """Every page a locator names, expanded, for the worklist's Read hint.

    `resolve_locator` checks these numbers against the page count and then
    throws them away, because narrowing a quotation to a page is exactly what
    `holds()` refuses to do. The worklist wants them for a different purpose:
    the Read tool's `pages` parameter is the only way to open an image-only
    PDF, and it needs numbers.

    **A range is expanded rather than passed through as its endpoints**, which
    is the difference between reading pages 4, 5 and 6 and reading 4 and 6. The
    middle page of a three-page range is exactly where a claim the mark points
    at can sit, so handing the agent the endpoints would build a silent gap
    into the check. A reversed or implausible range falls back to the endpoints
    rather than generating thousands of numbers; `resolve_locator` fails such a
    citation against the page count anyway whenever it ran.
    """
    m = PAGES.match(strip_gloss(rest))
    if not m:
        return []
    out = []
    for part in re.split(r",|\s+and\s+", m.group(1)):
        ends = numbers(part)
        if len(ends) == 2 and 0 <= ends[1] - ends[0] <= 50:
            out.extend(range(ends[0], ends[1] + 1))
        else:
            out.extend(ends)
    return sorted(set(out))


def heading_hit(cited, headings):
    """Does this section name a heading the source carries?

    Tried whole first, then split on `and` / commas, because a citation may name
    two sections at once: the reference book writes
    `Big-O guide § Worked Reasoning #1 and #2` against two real headings,
    `### Worked Reasoning #1 - Why the unindexed filter is O(n)` and
    `### Worked Reasoning #2 - Nested-loop vs. hash vs. merge`. Whole-first
    matters because a heading may itself contain "and", and splitting such a
    citation would fail both halves.
    """
    def one(c):
        c = norm(re.sub(r"^\s*§\s*", "", c.strip()))
        if not c:
            return True
        # A citation may be a prefix of the real heading, because the sources
        # head sections `Worked Reasoning #1 - Why the unindexed filter is O(n)`
        # and the book cites `Worked Reasoning #1`. The converse is deliberately
        # NOT allowed: a citation LONGER than the heading is the trailing-item
        # shape (`§ Requirements 4`), and admitting it here would let the item
        # number pass unexamined on the strength of the heading alone. Measured
        # on the fixture: with `c.startswith(h)` in place, a citation naming a
        # ninth item of a two-item list resolved clean.
        return any(c == h or h.startswith(c) for h in headings)

    if one(cited):
        return True
    # `§ Feature Stores, § Train/Serve Skew` and `§ [L5] and § Universal Checks`
    # each name two real headings. Each part keeps its own `§`, which `one`
    # strips, because the citation repeats the sign rather than factoring it out.
    parts = [p for p in re.split(r"\s+and\s+|,\s*", cited) if p.strip()]
    if len(parts) > 1:
        # A later part may elide a prefix the first part spelled out:
        # `§ Worked Reasoning #1 and #2` names `Worked Reasoning #1 - ...` and
        # `Worked Reasoning #2 - ...`, and `#2` alone matches no heading. So a
        # failing part is retried under each prefix of the first part's words,
        # longest first. Without this the citation reads as two missing headings
        # where both exist.
        head = parts[0].split()
        def part_ok(p):
            if one(p):
                return True
            return any(one(" ".join(head[:k]) + " " + p)
                       for k in range(len(head) - 1, 0, -1))
        if all(part_ok(p) for p in parts):
            return True
    # Last resort: a heading followed by a gloss clause, as in
    # `§ Train/Serve Skew, with its four comment lines removed`. Taking the head
    # before the first comma is generous, and generous is the right direction
    # here, since an explicit `§` that misses is reported as a failure.
    return "," in cited and one(cited.split(",", 1)[0])


def resolve_locator(src, rest, where):
    """Assert what the locator claims, and say when nothing was asserted.

    Returns "ok", "review" or "fail", and the slide number when the locator
    named one, so the quotation check can narrow to it.
    """
    if rest == "":
        return "ok", None

    body = strip_gloss(rest)
    if body == "":
        return "ok", None

    if src.kind == "pdf":
        m = PAGES.match(body)
        if not m:
            return "review", None
        if src.count is None:
            return "review", None
        for n in numbers(m.group(1)):
            if n < 1 or n > src.count:
                problem(f"{where}: {src.name} has {src.count} pages; the mark cites p. {n}",
                        rest)
                return "fail", None
        return "ok", None

    if src.kind == "pptx":
        m = SLIDES.match(body)
        if not m:
            return "review", None
        if src.count is None:
            return "review", None
        nums = numbers(m.group(1))
        for n in nums:
            if n < 1 or n > src.count:
                problem(f"{where}: {src.name} has {src.count} slides; the mark cites slide {n}",
                        rest)
                return "fail", None
        return "ok", (nums[0] if len(nums) == 1 else None)

    # markdown, including the Canvas HTML exports
    if ITEM.match(body):
        if src.text is None:
            return "review", None
        for n in numbers(body):
            # The number needs a boundary after it. A bare `in` test asks
            # whether "question 1" appears anywhere, and it appears inside
            # "question 13", so an item the source never defines can pass on the
            # strength of a larger one that shares its prefix. No live citation
            # reaches it, because every quiz and the exam here number
            # contiguously from 1, which makes any prefix of a defined number
            # defined too; it is guarded rather than left to that coincidence.
            if not re.search(rf"question {n}(?!\d)", src.text):
                problem(f"{where}: {src.name} defines no item Q{n}", rest)
                return "fail", None
        return "ok", None

    m = STEP.match(body)
    if m:
        if not src.steps:
            return "review", None
        for n in numbers(m.group(1)):
            if n not in src.steps:
                problem(f"{where}: {src.name} defines no step {n}", rest)
                return "fail", None
        return "ok", None

    m = SECTION.match(body)
    cited = m.group(1) if m else body
    if not src.headings:
        return "review", None

    # The whole string is tried as a heading before any qualifier is stripped,
    # and the order is load-bearing. The Testing guide heads its sections
    # `Layer 1` to `Layer 4`, so stripping first would reduce `§ Layer 4` to
    # `Layer`, match it against `Layer 1` by prefix, and then go looking for a
    # fourth ordered-list item that has nothing to do with the citation.
    if heading_hit(cited, src.headings):
        return "ok", None

    # A trailing item number is a claim of its own, so a heading that only
    # matches once it is stripped has to answer for the number too.
    # `[L5] Requirements 4` would otherwise pass on the word "Requirements"
    # while saying nothing about whether a fourth requirement exists, which is
    # the weak-for-strong substitution this family of scripts refuses.
    qual = QUALIFIER.search(cited)
    if qual:
        head = QUALIFIER.sub("", cited).strip()
        # A non-empty head is required: an all-qualifier citation would leave
        # `head` empty, and `heading_hit("")` answers True by design, so the
        # branch would report a heading match nothing looked for.
        if head and heading_hit(head, src.headings):
            wanted = numbers(qual.group(0))
            if wanted and not src.steps:
                # The heading is real and the item number could not be checked,
                # because this source numbers nothing. Saying "ok" would count
                # an unasserted number as resolved, which is the same fault as
                # the multi-item `Q` citation above one layer down.
                return "review", None
            for n in wanted:
                if n not in src.steps:
                    problem(f"{where}: {src.name} carries § {head} "
                            f"but defines no item {n}", rest)
                    return "fail", None
            return "ok", None

    if m:
        # An explicit `§` is a heading claim, so a miss is a failure.
        problem(f"{where}: {src.name} carries no heading matching § {cited}", rest)
        return "fail", None
    # No `§`, so this may not have been a heading citation at all.
    return "review", None


# --------------------------------------------------------------------------
# Emitting the worklist
# --------------------------------------------------------------------------

def chapter_number(name):
    """The chapter number in a filename, by the book format's own rule.

    `createbook/SKILL.md` fixes the chapter number as the filename's first digit
    run and forbids a digit in the book slug for exactly this reason, so there
    is one candidate rather than two. Returns None when the filename carries no
    digit at all, which `--chapters` then reports rather than silently skipping.
    """
    m = re.search(r"\d+", name)
    return int(m.group(0)) if m else None


def _slides_for(src, slide):
    """The slide text a deck citation carries into the worklist.

    A multi-path shorthand gets every slide of every deck it names, each
    labelled with the file it came from. It deliberately does NOT get narrowed
    by `slide`, for the reason `_read_pptx` leaves `units` empty there: slide
    numbers do not pool across decks, so a pooled index would hand the agent
    the wrong deck's slide. Labelling by file asserts nothing and still lets the
    agent read what was cited.
    """
    if src.multi:
        return [{"label": f"{stem} slide {i}", "text": t}
                for stem, i, t in src.raw_slides]
    if slide is not None:
        return [{"label": f"slide {i}", "text": t}
                for stem, i, t in src.raw_slides if i == slide]
    return [{"label": f"slide {i}", "text": t} for stem, i, t in src.raw_slides]


def _tidy(rec):
    """Drop an empty `notes` list so its presence is itself the signal.

    1,208 pointers each carrying `"notes": []` trains the reader to skip the
    key, which is the one place a pointer says it is weaker than it looks.
    """
    if not rec.get("notes"):
        rec.pop("notes", None)
    return rec


def worklist_source(src, name):
    """Everything about one source that does not vary between citations.

    Declared once per chapter file and referred to by name from each unit. The
    split is not tidiness: `every assignment page` names 23 files, chapter 2
    cites it 108 times, and inlining the paths on every citation made that one
    chapter's worklist 104 KB of mostly repeated absolute paths. A deck's text
    is here for the same reason, since 37 citations in chapter 7 reach 13
    slides and the whole deck is 260 words.
    """
    rec = {
        "kind": src.kind,
        "paths": [str(p.resolve()) for p in src.paths],
        "readable_as_text": src.text is not None,
        "notes": [],
    }
    if src.why_unreadable:
        rec["notes"].append(src.why_unreadable)
    if len(src.paths) > 1:
        rec["notes"].append(
            f"this shorthand names {len(src.paths)} files, so a claim against "
            f"it is a claim about all of them at once; a verdict rests on "
            f"finding a counterexample among them and is weaker than one "
            f"against a single file")

    if src.kind == "pptx":
        rec["read"] = "inline"
        rec["slides"] = _slides_for(src, None)
        if src.multi:
            rec["notes"].append(
                "slide numbers do not pool across decks, so a `slide N` "
                "locator against this shorthand is not resolved; every slide "
                "is given, labelled by the file it came from")
    elif src.kind == "pdf":
        rec["read"] = "pages"
        rec["page_count"] = src.count
        if src.text is None:
            rec["notes"].append(
                "open this with the Read tool's `pages` parameter, which "
                "renders the page as an image; no text extraction can see it")
    else:
        rec["read"] = "open"
    return _tidy(rec)


def worklist_component(src, name, component, rest, slide, verdict="ok"):
    """One resolved component, as the pointer a reading agent acts on.

    Carries only what this citation adds to its source's entry: the mark as the
    book wrote it, the locator, and the page or slide the locator names.
    Nothing is sliced; see the module docstring for why an excerpt is not on
    offer.

    **`verdict` is what `resolve_locator` said, and it is carried because an
    unasserted locator must not look like an asserted one.** The census already
    refuses to print a `review` as `resolved`, and the pointer owes the reading
    agent the same distinction: 31 of the reference book's locators are in no
    grammar this script reads, the run exits 0, and without this their pointers
    were shaped identically to the 1,177 that were checked. That is "treating a
    resolution as a verification" (root `CLAUDE.md § Evidence Discipline`) built
    into the artifact the whole paraphrase pass reads from.
    """
    rec = {"mark": component, "name": name, "locator": rest, "notes": []}
    if verdict == "review":
        rec["notes"].append(
            "nothing asserted that this locator resolves: it is in no grammar "
            "check-provenance.sh reads, so only the source's existence was "
            "checked. Read the source and say in `read` what you actually used")
    elif verdict == "skipped":
        rec["notes"].append(
            "this locator was not checked, because --quotes-only was given")
    if src.kind == "pdf":
        rec["pages"] = _pages_only(rest)
        if not rec["pages"]:
            rec["notes"].append(
                f"this locator names no page, so the claim is against the "
                f"document as a whole ({src.count} pages)"
                if src.count else
                "this locator names no page, so the claim is against the "
                "document as a whole")
    elif src.kind == "pptx" and not src.multi:
        rec["slide"] = slide
        if slide is not None and not any(i == slide for _, i, _ in src.raw_slides):
            rec["notes"].append(
                f"the locator names slide {slide}, which this deck does not "
                f"have; read the whole deck and say so")
        elif slide is None:
            rec["notes"].append(
                "this locator names no single slide, so the claim is against "
                "the deck as a whole")
    return _tidy(rec)


def write_worklist(emit_dir, book, by_chapter, scoped):
    """One JSON file per chapter, plus a small index the caller can read.

    The split is the point: an orchestrator reads `index.json` and hands each
    chapter's file to its own agent, so the book's prose never lands in one
    context. `index.json` carries counts and no prose for the same reason.
    """
    d = pathlib.Path(emit_dir)
    d.mkdir(parents=True, exist_ok=True)
    today = datetime.date.today().isoformat()
    index = []
    for path, units, used in by_chapter:
        out = d / (path.stem + ".json")
        out.write_text(json.dumps({
            "book": str(book.resolve()),
            "chapter": {"number": chapter_number(path.name), "file": path.name},
            "generated": today,
            "sources": used,
            "units": units,
        }, indent=2, ensure_ascii=False) + "\n")
        index.append({
            "number": chapter_number(path.name),
            "file": path.name,
            "worklist": str(out.resolve()),
            "units": len(units),
            "sources": sum(len(u["sources"]) for u in units),
            "files_to_read": len(used),
        })
    (d / "index.json").write_text(json.dumps({
        "book": str(book.resolve()),
        "generated": today,
        "scoped_to": scoped,
        "chapters": index,
    }, indent=2, ensure_ascii=False) + "\n")
    return index


# --------------------------------------------------------------------------

def main(argv):
    mode = "both"
    folder = None
    emit_dir = None
    want_chapters = None
    args = argv[1:]
    i = 0
    while i < len(args):
        a = args[i]
        if a == "--locators-only":
            mode = "locators"
        elif a == "--quotes-only":
            mode = "quotes"
        elif a in ("--emit-worklist", "--chapters"):
            # Both take a value. A missing one would otherwise swallow the book
            # folder and report "no such folder", which sends the reader
            # looking at the wrong end of the command.
            if i + 1 >= len(args):
                print(f"error: {a} needs a value", file=sys.stderr)
                return 2
            i += 1
            if a == "--emit-worklist":
                emit_dir = args[i]
            else:
                try:
                    want_chapters = {int(x) for x in args[i].split(",") if x.strip()}
                except ValueError:
                    print(f"error: --chapters wants numbers, got: {args[i]}",
                          file=sys.stderr)
                    return 2
                if not want_chapters:
                    print("error: --chapters was given no numbers", file=sys.stderr)
                    return 2
        elif a.startswith("-"):
            print(f"error: unknown option: {a}", file=sys.stderr)
            return 2
        elif folder is None:
            folder = a
        else:
            print("error: more than one folder given", file=sys.stderr)
            return 2
        i += 1
    if folder is None:
        print(__doc__.strip().splitlines()[2].strip(), file=sys.stderr)
        return 2

    book = pathlib.Path(folder)
    if not book.is_dir():
        print(f"error: no such folder: {book}", file=sys.stderr)
        return 2

    conf = {}
    cf = book / "book.json"
    if cf.exists():
        try:
            conf = json.loads(cf.read_text())
        except json.JSONDecodeError as e:
            print(f"error: {cf} is not valid JSON: {e}", file=sys.stderr)
            return 2

    if conf.get("provenance") is not True:
        print(f"note: {book}/book.json does not declare \"provenance\": true;")
        print("      this book carries no marks to check. Nothing was asserted.")
        return 0

    declared = conf.get("sources") or {}
    if not declared:
        print(f"note: {book}/book.json declares \"provenance\": true but no \"sources\" map,")
        print("      so no mark can be resolved to a file. Nothing was asserted.")
        print("      Add a \"sources\" object mapping each shorthand a mark uses to its path.")
        return 0

    sources = {}
    for name, val in declared.items():
        paths = [book / p for p in ([val] if isinstance(val, str) else val)]
        sources[name] = Source(name, paths)
    keys = sorted(sources, key=len, reverse=True)

    for s in sources.values():
        if s.missing:
            problem(f"book.json declares \"{s.name}\" at a path that does not exist",
                    "; ".join(str(p) for p in s.missing))

    unsourced = ["fill"] + list(conf.get("unsourced") or [])

    # Chapters, skipping what /makebook skips.
    skip = {"OUTLINE.md", "glossary.md", "about-this-book.md"}
    skip |= set(conf.get("exclude") or [])
    chapters = sorted(p for p in book.glob("*.md") if p.name not in skip)
    if not chapters:
        print(f"error: no chapters found in {book}", file=sys.stderr)
        return 2

    # The book's own tags and chapter count, for the in-book components.
    # **Built from every chapter, never from the scoped subset below.** A mark
    # in chapter 3 may cite `[16-4]` or `ch. 18`, and those are claims about the
    # book rather than about the chapters this run happens to be looking at.
    # Narrowing either would turn `--chapters 3` into a run that fails a correct
    # citation, which is a false FAIL invented by the scoping flag itself.
    defined = set()
    for p in chapters:
        for line in p.read_text().splitlines():
            m = TAGDEF.match(line)
            if m:
                defined.add((int(m.group(1)), int(m.group(2))))
    n_chapters = len(chapters)

    scan = chapters
    if want_chapters is not None:
        by_number = {}
        for p in chapters:
            by_number.setdefault(chapter_number(p.name), []).append(p)
        missing = sorted(n for n in want_chapters if n not in by_number)
        if missing:
            # Refused rather than skipped: a typo'd number would otherwise emit
            # a smaller worklist that looks exactly like a correct one.
            print(f"error: {book} has no chapter "
                  f"{', '.join(str(n) for n in missing)}", file=sys.stderr)
            return 2
        scan = [p for p in chapters if chapter_number(p.name) in want_chapters]
        print(f"note: scoped to chapter(s) "
              f"{', '.join(str(n) for n in sorted(want_chapters))} of "
              f"{n_chapters}; every figure below describes those chapters only.")
        print()

    census = collections.Counter()
    unparsed_shapes = collections.Counter()
    unverifiable_by_source = collections.Counter()
    q_checked = q_unverifiable = 0

    worklist = []               # (chapter path, [unit records]), in book order

    for p in scan:
        base = p.name
        wl_units = []
        wl_used = {}            # shorthand -> its source entry, this chapter's
        for ln, unit, comps in units_of(p):
            where = f"{base}:{ln}"
            named = []          # (Source, slide) the quotation check may search
            has_unreadable = None
            wl_sources = []     # resolved pointers, for --emit-worklist
            wl_unchecked = []   # fill and in-book components, named not judged

            for c in comps:
                # Both spellings, because the book writes `fill (the gloss)` and
                # `the simulator search of 2026-09-12`, and the article belongs
                # to the prose rather than to the word being declared.
                forms = [c.lower()]
                if forms[0].startswith("the "):
                    forms.append(forms[0][4:])
                if any(f == u or f.startswith(u + " ") or f.startswith(u + "(")
                       for f in forms for u in unsourced):
                    census["fill"] += 1
                    wl_unchecked.append(c)
                    continue

                m = TAG.match(c)
                if m:
                    census["in-book"] += 1
                    wl_unchecked.append(c)
                    if (int(m.group(1)), int(m.group(2))) not in defined:
                        problem(f"{where}: the mark cites {c}, which the book does not define")
                    continue
                m = CHAPTER.match(c)
                if m:
                    census["in-book"] += 1
                    wl_unchecked.append(c)
                    if not 1 <= int(m.group(1)) <= n_chapters:
                        problem(f"{where}: the mark cites {c}; the book has {n_chapters} chapters")
                    continue

                key, rest = match_source(c, keys)
                if key is None:
                    census["unknown"] += 1
                    problem(f"{where}: no declared source matches this mark component", c)
                    continue

                src = sources[key]
                if src.missing:
                    census["missing-file"] += 1
                    continue

                if mode != "quotes":
                    verdict, slide = resolve_locator(src, rest, where)
                else:
                    # --quotes-only did not look at this locator, so it is
                    # counted as skipped. Counting it "resolved" would print a
                    # figure that reads as an assertion nothing made.
                    verdict, slide = "skipped", _slide_only(rest)
                census["locator-" + verdict] += 1
                if verdict == "review":
                    census["unparsed"] += 1
                    unparsed_shapes[(key, re.sub(r"\d+", "N", rest))] += 1

                named.append((src, slide))
                if emit_dir:
                    if key not in wl_used:
                        wl_used[key] = worklist_source(src, key)
                    wl_sources.append(
                        worklist_component(src, key, c, rest, slide, verdict))
                if src.text is None and (
                        has_unreadable is None or src.name < has_unreadable.name):
                    # Deterministic rather than last-wins. A mark may name two
                    # unreadable sources and the per-source breakdown below
                    # credits one of them, so which one must not depend on the
                    # order the components happen to sit in. 11 of the reference
                    # book's 28 name more than one.
                    has_unreadable = src

            # Emitted before the quotation check returns, so that
            # --locators-only still produces a worklist. The two flags answer
            # different questions and neither is a reason to withhold the other.
            if emit_dir and wl_sources:
                wl_units.append({
                    "line": ln,
                    "text": unit,
                    "sources": wl_sources,
                    "unchecked": wl_unchecked,
                })

            if mode == "locators" or not named:
                continue

            quotes, unterminated = quotations(unit)
            if unterminated is not None:
                flag(f"{where}: a quote mark in this unit is never closed, so the "
                     f"quotations after it were not examined")
            for q in quotes:
                qn = words(q)
                hits = [s.holds(qn, slide) for s, slide in named]
                if any(h is True for h in hits):
                    q_checked += 1
                    continue
                if has_unreadable is not None:
                    q_unverifiable += 1
                    unverifiable_by_source[has_unreadable.name] += 1
                    continue
                q_checked += 1
                flag(f"{where}: this quotation is in none of the sources the mark names "
                     f"({', '.join(sorted({s.name for s, _ in named}))})",
                     '"' + (q.strip()[:100]) + ('..."' if len(q.strip()) > 100 else '"'))

        # A chapter with no external component still gets an entry, holding an
        # empty list. Dropping it would leave the caller unable to tell a
        # chapter that rests entirely on `fill` from one this run never opened,
        # which is the same distinction check-book.sh's `content-checked` count
        # exists to keep.
        if emit_dir:
            worklist.append((p, wl_units, wl_used))

    # ----------------------------------------------------------------------
    print()
    unreadable = [s for s in sources.values() if not s.missing and s.text is None]
    if unreadable:
        print("NOTE  sources nothing can search, so no quotation attributed to one was checked:")
        for s in unreadable:
            print(f"      {s.name}: {s.why_unreadable}")
        print("      A quotation not found in any source its mark names is reported")
        print("      UNVERIFIABLE rather than REVIEW when ANY of those sources is on")
        print("      this list, because a search that could not read one of them")
        print("      cannot tell 'not there' from 'not readable'.")
        print()

    total = sum(census[k] for k in
                ("fill", "in-book", "unknown", "missing-file", "locator-ok",
                 "locator-review", "locator-fail", "locator-skipped"))
    print(f"sources declared {len(sources)}   components {total}   "
          f"fill {census['fill']}   in-book {census['in-book']}")
    if mode == "quotes":
        print(f"locators NOT CHECKED ({census['locator-skipped']}): --quotes-only was given")
    else:
        print(f"locators resolved {census['locator-ok']}   "
              f"unparsed {census['unparsed']}   failed {census['locator-fail']}")
    if mode == "locators":
        print("quotations NOT CHECKED: --locators-only was given")
    else:
        print(f"quotations checked {q_checked}   unverifiable {q_unverifiable}")
    if unverifiable_by_source:
        for name, n in unverifiable_by_source.most_common():
            print(f"      {n} naming {name} (a mark may name more than one)")
    print()

    if census["unparsed"]:
        print(f"REVIEW {census['unparsed']} locator(s) were not asserted. Most were not in a grammar")
        print("       this script reads, so nothing about them was checked beyond the source")
        print("       existing; the rest named a real heading and an item number the source")
        print("       gave nothing to check against. They are counted rather than passed, and")
        print("       listed here by shape so a grammar worth adding shows as a group:")
        for (name, rest), n in unparsed_shapes.most_common(20):
            print(f"       {n:3d}  {name}  |  {rest}")
        if len(unparsed_shapes) > 20:
            print(f"       ... and {len(unparsed_shapes) - 20} more shape(s)")
        print()

    if emit_dir:
        scoped = sorted(want_chapters) if want_chapters is not None else None
        index = write_worklist(emit_dir, book, worklist, scoped)
        n_units = sum(c["units"] for c in index)
        n_ptr = sum(c["sources"] for c in index)
        print(f"WORKLIST {n_units} unit(s) across {len(index)} chapter(s), "
              f"{n_ptr} pointer(s), written to {emit_dir}/")
        print(f"         index at {emit_dir}/index.json, one file per chapter "
              f"beside it. Give each agent ONE chapter file.")
        if fail:
            # Said here rather than left to the reader to join up. A failed
            # locator is a pointer aimed at something that is not there, and a
            # paraphrase judged against it is work spent on a question whose
            # premise is already known to be false.
            print(f"         {fail} locator(s) failed above. Those pointers are "
                  f"wrong; fix them before spending a reading pass on them.")
        print()

    if fail:
        print(f"{fail} failure(s). A mark naming a source the book does not have, a locator")
        print("outside its source, or a quotation in none of the sources its mark names.")
        return 1

    if review:
        print(f"OK*   nothing failed, and {review} REVIEW item(s) above are still unread.")
        print("      This is not an all-clear until someone has been through them.")
        return 0

    # The OK line names only what this run actually examined. Claiming the
    # locators under --quotes-only, or the quotations under --locators-only,
    # would be the whole point of the script asserted over a check that never
    # ran.
    did = []
    if mode != "quotes":
        did.append("every locator resolves")
    if mode != "locators":
        did.append("every quotation that could be searched is in a source its mark names")
    print("OK    every mark names a declared source, and " + ", and ".join(did) + ".")
    if mode != "both":
        print(f"      Only part of the check ran: {mode}-only.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
