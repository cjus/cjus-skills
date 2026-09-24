#!/usr/bin/env python3
"""Verify that references INTO a book actually resolve.

    check-references.sh [--since <ref> | --no-baseline] <book-folder> <referring-file>...

Four checks, in ascending order of what they are worth.

  1. Chapter existence. Every "ch. N" / "chapter N" reference names a chapter the
     book has. Cheap, and on its own it proves almost nothing.

  2. Attribution. Every quoted sentence attributed to a chapter appears in THAT
     chapter, not merely somewhere in the book. This is what catches a reference
     repointed by number while the quoted wording stayed behind, and matching
     against the pooled book instead would be the same weak-for-strong
     substitution the tool exists to catch.

     Two decisions set its reach, and both narrow the target rather than the
     check. A quotation is read against the chapters cited in ITS OWN block,
     where a block is a paragraph, a table row or a single list item; pooling a
     run of bullets would check each quotation against chapters only its
     neighbours cite. And a quotation whose nearest preceding attribution is a
     named file rather than a chapter is sourced there, so the book is not
     searched for it and the summary reports how many went that way.

  3. Tag existence. Every "[N-M]" paragraph-tag citation names a paragraph the
     book actually defines. Weak for the same reason check 1 is weak, and it is
     here because its absence was worse: run against the reference book's two prep
     files on 2026-09-10, this tool reported "references: 1  quotations: 0  OK"
     over thirty tag citations it could not see. A green line about a file that
     was never read is the failure mode this whole script exists to refuse.

  4. Tag drift. For every citation that resolves, the paragraph it names now is
     compared against the paragraph it named at a baseline commit. This is the
     check that matters, because a stale tag is not a broken link: insert one
     paragraph into a chapter and every citation after it still resolves, to
     real prose that is no longer the prose meant. Nothing about the citation
     looks wrong, which is precisely why nothing catches it by reading.

Written because check 1 was run alone and passed while 18 of 18 quotations were
attributed to chapters that did not hold them. A chapter number resolving is not
the same claim as a chapter saying what you said it says, and check 3 stands in
the same relation to check 4 one level down.

Exits 0 when everything resolves, 1 on any failure, 2 on bad usage. Drift splits
by cause: FAIL when the chapter also changed length, because the tags after the
change slid, and REVIEW when the count held, because a paragraph edited in place
changes its text without breaking any citation into it. The count is a proxy and
it is not equivalent, so the REVIEW line reports the counts and leaves the
conclusion to the reader; an insert paired with a cut in one chapter is the case
it cannot separate.
"""
import re, sys, json, pathlib, subprocess, unicodedata

MIN_QUOTE = 25   # shorter runs are ordinary phrases, not attributions
REF = re.compile(r"\bch(?:apter|\.)\s*(\d+)\b", re.I)

# A citation anywhere in a line, and a definition at the head of one. The
# anchored form matches check-book.sh's own tag counter, which also refuses a tag
# with leading whitespace, so the two tools agree on what counts as a definition.
#
# Both halves are kept as strings. The chapter half is `3` for a chapter and
# `A2` for an appendix (createbook/reference/guide.md § Appendices), and the
# paragraph half is `4`, or `4a` for a paragraph a revision added after [N-4]
# without renumbering (createbook/reference/chapter-prose.md § Paragraph tags).
# Until 2026-09-24 both were integers and the pattern had no `A`, so a citation
# of an appendix paragraph was not seen at all: `[A1-99]` against a book with
# one appendix passed, uncounted.
TAG = re.compile(r"\[(A?\d+)-(\d+[a-z]?)\]")
TAGDEF = re.compile(r"^\[(A?\d+)-(\d+[a-z]?)\] ")


def tag_key(unit, para):
    """A tag's two halves with leading zeros dropped, so `[03-7]` is `[3-7]`.

    The book spells a tag one way and check-book.sh enforces it, but a referring
    file sits outside the book, and while the halves were integers a citation
    written `[03-7]` resolved. Keeping the halves as strings must not quietly
    start failing it.
    """
    m = re.match(r"(A?)0*(\d+)$", unit)
    p = re.match(r"0*(\d+)([a-z]?)$", para)
    return (m.group(1) + m.group(2), p.group(1) + p.group(2))
# Anchored the way check-book.sh and check-provenance.sh anchor it, so a
# chapter slug that happens to hold the word, `sql-02-appendix-1-of-the-standard.md`,
# stays chapter 2 in all three tools.
APPENDIX_FILE = re.compile(r"^[a-z]+(?:-[a-z]+)*-appendix-(\d+)-")
CHAPTER_FILE = re.compile(r"-(\d{2,})-")


def unit_of(name):
    """The tag's chapter half for a file: `3` for a chapter, `A2` for an
    appendix, or None. The appendix test runs first, because an appendix's own
    number could otherwise be read as a chapter's."""
    m = APPENDIX_FILE.search(name)
    if m:
        return f"A{int(m.group(1))}"
    m = CHAPTER_FILE.search(name)
    return str(int(m.group(1))) if m else None


def para_order(para):
    """Sort key for a paragraph half: 4 < 4a < 4b < 5."""
    m = re.match(r"(\d+)([a-z]?)$", para)
    return (int(m.group(1)), m.group(2))


def unit_label(unit):
    return f"appendix {unit[1:]}" if unit.startswith("A") else f"chapter {unit}"


# An opener is a quote mark NOT preceded by a letter, a digit or closing
# punctuation, because pairing is positional and a bare character class cannot
# tell an opening delimiter from an inch mark: in `A 3" gap. Chapter 9 says "..."`
# it read `3"` as an opener, stole the real quotation's, and shifted every pair
# after it.
#
# **Written as a deny-list on purpose, and an allow-list here was a defect.**
# Listing the characters that may precede an opener (whitespace, brackets, a table
# pipe) hides a quotation whose opener follows anything unforeseen. Measured
# 2026-09-10, `**"…"**`, `*"…"*`, `_"…"_` and `says—"…"` all went silent that way.
# Spell the class out rather than using `\w`, which contains `_` and would keep
# `_"…"_` invisible.
#
# **This rule is still incomplete, and that is expected rather than fixed.** It
# rejects a quote mark directly after a letter, a digit, or any of
# `. , ; : ! ? ) ] ” "`, so `says,"…"` and `says:"…"` are not openers; and it admits
# marks that are not delimiters at all, such as one after a backtick. Three rounds
# of review each closed some of those and opened others, because enumerating what a
# delimiter is cannot be finished. What makes the boundary safe is not this pattern
# but the completeness check in main()'s quotation loop, which reports any quote
# mark the pairing did not use. Landing on this boundary therefore costs a REVIEW
# line naming the block rather than a silent skip, with one exception: when the
# stray marks pair off among themselves and leave the quotation in the gap BETWEEN
# two spans, nothing is left over and the block is textually identical to prose
# between two quoted phrases, which this scanner reads as not a quotation at all.
# Measured by review over 6,000 generated four-mark layouts, that gap is the only
# silent case.
QOPEN = re.compile(r'(?:^|(?<![A-Za-z0-9.,;:!?)\]”"]))(["“])', re.M)

# A closer matches its opener's style, so a curly quotation nested inside a
# straight one cannot end the outer span early and print a truncated excerpt with
# a dangling delimiter. It carries no preceding-character rule: requiring a
# non-space before it stranded a quotation whose last character is a space and let
# the scan run on into the next quotation, which is the straddle this all exists
# to remove, reached through another door.
QCLOSE_FOR = {'"': re.compile(r'(")'), '“': re.compile(r'(”)')}
QALT_FOR = {'"': QCLOSE_FOR['“'], '“': QCLOSE_FOR['"']}

# A list item starts a block of its own, like a table row. See blocks(). The
# ordered form is capped at two digits so a hard-wrapped line opening `2026. `
# stays prose rather than becoming a block boundary.
LISTITEM = re.compile(r"^\s*(?:[-*+]|\d{1,2}[.)])\s")

# A named markdown file, with or without a line number. Used only to decide what
# a quotation is attributed TO; see main()'s quotation loop.
FILEREF = re.compile(r"[\w./-]+\.md(?::\d+)?")

OPENING = 68     # how much of a drifted paragraph to show on each side


def blocks(lines):
    """Yield (first line number, text) for each blank-line separated block.

    A markdown table row stands alone, since each row attributes separately. A
    list item stands alone for the same reason, and it is the stronger case of
    the two: a run of bullets carries no blank line between them, so without this
    they pool into one block and a quotation in the first bullet is checked
    against every chapter any LATER bullet happens to cite. Measured 2026-09-10,
    `OUTLINE.md:582-590` is three bullets, each attributing a different phrase to
    a different chapter, and they arrived here as one block citing chapters 7, 9
    and 12 together. That is the weak-for-strong substitution this tool exists to
    refuse, one level up from the pooled-book target check 2 already refuses.

    An item's continuation lines stay with it, since only a new marker breaks the
    buffer.

    A bullet citing no chapter of its own is the case that makes this a guess
    rather than a rule, because a sibling is a peer while a parent is a scope.
    Tightening the boundary so bullets stop borrowing from each other also stops a
    bullet inheriting from the sentence that introduced it, and the third element
    of each yield is what restores that half: `lead` is the nearest block above
    whose own text ends with a colon, and None for everything that is not a list
    item. A caller may read a bullet's quotation against the lead's chapters when
    the bullet names none itself.

    `lead` APPROXIMATES the block that introduced the list and is not the same
    thing, which is worth knowing before trusting it. A list item that does not end
    with a colon leaves it untouched, which is what lets every sibling under one
    lead-in see it, and the same rule lets it reach a later sibling at the same
    level that the lead-in did not introduce. Such a bullet is reported as citing
    its lead-in, which in that case it does not. The severity rule downstream is
    what bounds the cost: an inherited citation can only ever REVIEW.

    The colon is the signal rather than mere adjacency, and deliberately so. Every
    paragraph above a list is adjacent to it; only one is introducing it. Raised by
    review 2026-09-10 with two shapes where the attribution is structural, a tight
    list under a lead-in sentence and an indented sub-bullet under a parent that
    names the chapter, both of which end the introducing line with a colon. What it
    does not cover is a lead-in written without one, which stays out of check 2.
    """
    raw, buf, start = [], [], 1

    def close(at):
        return (at, "\n".join(buf), LISTITEM.match(buf[0]) is not None)

    for i, ln in enumerate(lines, 1):
        if ln.strip().startswith("|"):
            if buf:
                raw.append(close(start))
                buf = []
            raw.append((i, ln, False))
            start = i + 1
        elif LISTITEM.match(ln):
            if buf:
                raw.append(close(start))
            buf, start = [ln], i
        elif ln.strip() == "":
            if buf:
                raw.append(close(start))
                buf = []
            start = i + 1
        else:
            if not buf:
                start = i
            buf.append(ln)
    if buf:
        raw.append(close(start))

    lead = None
    for bstart, btext, is_item in raw:
        yield bstart, btext, lead if is_item else None
        # A heading closes whatever the colon above it was introducing. A list
        # item leaves the lead alone unless it sets a new one, so every sibling
        # under one lead-in sees it; any other block clears it.
        if btext.lstrip().startswith("#"):
            lead = None
        elif btext.rstrip().endswith(":"):
            lead = btext
        elif not is_item:
            lead = None


def norm(s: str) -> str:
    """Collapse whitespace and fold the quote characters an editor may swap in."""
    s = unicodedata.normalize("NFKC", s)
    s = s.replace("’", "'").replace("‘", "'")
    s = s.replace("“", '"').replace("”", '"')
    return re.sub(r"\s+", " ", s).strip()


def quoted_spans(text):
    """Return (spans, unterminated) for one block.

    `spans` is a list of (index of the opening delimiter, quoted text) in reading
    order. Nothing is length-filtered here; the caller applies MIN_QUOTE
    afterwards, and that ordering is the first reason this function exists.

    `unterminated` is the index of an opening delimiter that nothing closes, or
    None. Pairing is positional, so an opener with no closer ends the scan and
    every quotation after it goes unexamined. That must not happen SILENTLY:
    check 2's key-row path fails a build, so a row skipped without a word in the
    report turns an exit 1 into an exit 0, which is the one shape this script's
    own docstring names as its reason for existing. Raised by review 2026-09-10,
    where `main`'s regex was immune because it retried at every offset: a pattern
    that restarts everywhere tolerates malformed input in a way a positional scan
    does not, and replacing one with the other does not inherit that.

    Asking for the length INSIDE the pattern, as `["“]([^"“”]{25,})[”"]` does,
    gets it wrong in a way that reads like a finding rather than a bug. When a
    pair is too short to satisfy the quantifier the scan does not step over the
    pair, it resumes inside it, so the next attempt opens on that pair's CLOSING
    quote and runs to the next opening one. What it reports as a quotation is the
    ordinary prose between two quoted phrases.

    Measured 2026-09-10 against the reference book's own referring files:
    four of the eight REVIEW items were this, each downstream of a quoted word
    too short to match on its own (`"covering"`, `"optionality"`, `"member"`,
    `"simulator"`). One reported 595 characters spanning three bullets as a
    single quotation. The same straddle also HIDES quotations, because it
    consumes the opening delimiter of the next real one: the syllabus phrase
    "the bundled course simulators" sat at OUTLINE.md:107 and was never examined.
    """
    spans, pos = [], 0
    while True:
        o = QOPEN.search(text, pos)
        if o is None:
            return spans, None
        c = QCLOSE_FOR[o.group(1)].search(text, o.end())
        if c is None:
            # A half-converted editor artefact opens curly and closes straight, or
            # the reverse. Style matching is what protects a nested quotation, so
            # the other style is tried only once the matching one is absent, which
            # cannot cost the nested case anything.
            c = QALT_FOR[o.group(1)].search(text, o.end())
        if c is None:
            return spans, o.start(1)
        spans.append((o.start(1), text[o.end():c.start(1)]))
        pos = c.end()


def tag_paragraphs(text):
    """Map (chapter, paragraph) -> that paragraph's own normalised text.

    The paragraph runs from its tag to the next blank line. The reference book
    writes each one as a single long line, so the continuation case never fires
    there; a hard-wrapped book is the same book and allowing it costs nothing.

    Normalising through norm() is what keeps check 4 honest in the other
    direction: rewrapping a paragraph, or an editor swapping a straight quote
    for a curly one, changes the bytes without changing what the paragraph says,
    and reporting that as drift would train the reader to skim the report.

    **The map is assumed injective and this function does not enforce it.** A
    chapter defining [1-2] twice keeps the last one and counts one paragraph
    fewer, which feeds the length comparison behind the FAIL/REVIEW split and
    can demote a real FAIL. check-book.sh rejects a duplicate tag, and
    updatebook/SKILL.md § 5 runs it first, so the workflow covers this; nothing
    here does.
    """
    out, key, buf, infence = {}, None, [], False
    for ln in text.splitlines():
        # Fences are skipped here for the same reason tag_citations skips them,
        # so the two functions agree on what a tag is. A [N-M] at the head of a
        # line inside a fenced block is code being shown, not a paragraph.
        if ln.lstrip().startswith("```"):
            infence = not infence
            continue
        if infence:
            continue
        m = TAGDEF.match(ln)
        if m:
            if key:
                out[key] = norm(" ".join(buf))
            key, buf = tag_key(m.group(1), m.group(2)), [ln[m.end():]]
        elif key is not None:
            # A provenance mark ends the paragraph the way a blank line does,
            # as it does in check-book.sh's unit sweep. A mark is not prose: a
            # book that writes it on the line under its paragraph, with no blank
            # between, would otherwise report every re-sourced mark as drift in
            # the paragraph above it.
            if ln.strip() == "" or ln.lstrip().startswith("<!--"):
                out[key], key, buf = norm(" ".join(buf)), None, []
            else:
                buf.append(ln)
    if key:
        out[key] = norm(" ".join(buf))
    return out


def tag_citations(lines):
    """Yield (lineno, chapter, paragraph) for every [N-M] outside a code fence.

    The fence rule is not tidiness. The grep in `skills/updatebook/SKILL.md
    § Cutting prose` carries `[0-9]` inside a bash block: a regex character class that this
    pattern matches exactly, because `0`, `-`, `9` is a digit run, a hyphen and
    a digit run. Reading a fence as prose reports a grep command as a broken
    citation into a book, and one confident false positive costs more of a
    reader's trust than several quiet misses.

    **Inline code spans are deliberately NOT skipped, and this was measured
    before it was decided.** The same argument seems to carry: a regex written
    in prose is more often `[0-9]` between backticks than inside a fence. It
    does not carry, because the house style writes a real citation the same way.
    All 38 tag citations in the reference book's four referring files sit inside
    backticks, counted 2026-09-10, so stripping code spans takes checks 3 and 4
    from 38 citations to nothing while still reporting OK. The regex case is
    real but latent: the only instances here are in this plugin's own `skills/`
    files, which are documentation of the tool rather than referring files, and
    nothing passes them in. A false positive there costs one puzzled reader; the
    strip costs the whole feature, silently.
    """
    infence = False
    for i, ln in enumerate(lines, 1):
        if ln.lstrip().startswith("```"):
            infence = not infence
            continue
        if infence:
            continue
        for m in TAG.finditer(ln):
            yield (i, *tag_key(m.group(1), m.group(2)))


def baseline_paragraphs(book, units, excluded, ref):
    """Read every chapter at `ref` and return its tag map, plus a status note.

    Returns (paragraphs, note). A None map means there is no baseline and check
    4 did not run, which the summary then says out loud. Reporting "nothing
    drifted" because nothing could be compared is the same silence-as-pass this
    script refuses everywhere else.

    Chapters are matched to the baseline BY CHAPTER NUMBER, read out of the
    baseline tree, rather than by their current path. Resolving by path looks
    equivalent and is not, on the one path that matters most: inserting a
    chapter renames every later file, so `git show <ref>:<current name>` fails
    for each of them, and reading that failure as "the chapter did not exist"
    drops from check 4 exactly the citations the insert broke. Chapter 7 under
    a new filename is still chapter 7, and its prose is what a citation into it
    has to be compared against.
    """
    try:
        root = subprocess.run(["git", "rev-parse", "--show-toplevel"],
                              capture_output=True, text=True, check=True).stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None, "not a git repository, so no baseline to compare against", set()
    if subprocess.run(["git", "-C", root, "rev-parse", "--verify", "--quiet", ref + "^{commit}"],
                      capture_output=True).returncode != 0:
        return None, f"'{ref}' is not a commit this repository has", set()
    try:
        rel_book = book.resolve().relative_to(pathlib.Path(root).resolve()).as_posix()
    except ValueError:
        return None, f"{book} is outside the repository, so it has no state at {ref}", set()

    # The baseline's own chapter numbering, read the same way the working
    # tree's is at main()'s chapter loop, so the two agree on what a chapter is.
    # "." rather than "" when the book IS the repository root: git rejects an
    # empty pathspec outright. Its return code is read because a failure here is
    # indistinguishable from an empty listing, and reading empty as "no chapter
    # existed at the baseline" is the same unchecked inference that made check 4
    # blind on renames, one layer down.
    ls = subprocess.run(["git", "-C", root, "ls-tree", "--name-only", ref,
                         (rel_book + "/") if rel_book != "." else "."],
                        capture_output=True, text=True)
    if ls.returncode != 0:
        return None, f"could not read {book} at {ref}: {ls.stderr.strip()}", set()
    base_paths = {}
    for name in ls.stdout.splitlines():
        leaf = name.rsplit("/", 1)[-1]
        if not leaf.endswith(".md") or leaf in excluded:
            continue
        u = unit_of(leaf)
        if u:
            base_paths[u] = name

    out, missing, renamed = {}, [], []
    for n in sorted(units, key=lambda u: (u.startswith("A"), int(u.lstrip("A")))):
        if n not in base_paths:
            # A chapter genuinely added since the baseline has no earlier text,
            # so every citation into it is new and cannot have drifted. That is
            # a fact about the baseline rather than a fault, and it is reported
            # as one.
            missing.append(n)
            continue
        r = subprocess.run(["git", "-C", root, "show", f"{ref}:{base_paths[n]}"],
                           capture_output=True, text=True)
        if r.returncode != 0:
            missing.append(n)
            continue
        if base_paths[n].rsplit("/", 1)[-1] != units[n].name:
            renamed.append(n)
        out.update(tag_paragraphs(r.stdout))

    notes = []
    if missing:
        one = len(missing) == 1
        notes.append(", ".join(unit_label(n) for n in missing) +
                     f" did not exist at {ref}, so citations into " +
                     ("it were" if one else "them were") + " not drift-checked")
    if renamed:
        one = len(renamed) == 1
        notes.append(", ".join(unit_label(n) for n in renamed) +
                     (" was" if one else " were") + " renamed since " + ref +
                     ", and compared by chapter number")
    return out, "; ".join(notes), set(renamed)


def main(argv):
    # HEAD is the default because it is the right baseline for the case this
    # check was written for: /updatebook step 0 refuses to start over a dirty
    # book folder, so during an update HEAD is the book as it stood before the
    # edit, and the comparison is exactly the edit.
    ref, asked_for_baseline, rest = "HEAD", False, []
    it = iter(argv[1:])
    for a in it:
        if a == "--since":
            if ref is None:
                print("error: --since and --no-baseline contradict each other", file=sys.stderr)
                return 2
            ref, asked_for_baseline = next(it, None), True
            if ref is None:
                print("error: --since needs a commit", file=sys.stderr)
                return 2
        elif a == "--no-baseline":
            # Contradicting flags are a usage error rather than a last-one-wins
            # race. The caller asked for a baseline and asked for none, and
            # picking either silently gives them a run they did not request.
            if asked_for_baseline:
                print("error: --since and --no-baseline contradict each other", file=sys.stderr)
                return 2
            ref = None
        elif a.startswith("-"):
            print(f"error: unknown option: {a}", file=sys.stderr)
            return 2
        else:
            rest.append(a)

    if len(rest) < 2:
        print(__doc__.strip().splitlines()[2].strip(), file=sys.stderr)
        return 2
    book = pathlib.Path(rest[0])
    if not book.is_dir():
        print(f"error: no such folder: {book}", file=sys.stderr)
        return 2

    # book.json says which files are not chapters. The filename pattern below
    # already excludes OUTLINE.md and glossary.md, which carry no digit run, but
    # a book may exclude a file that does; reading the same keys check-book.sh
    # reads (:79-97) is what keeps the two tools looking at one set of chapters.
    excluded, tags_declared = set(), None
    bj = book / "book.json"
    if bj.is_file():
        try:
            cfg = json.loads(bj.read_text(encoding="utf-8"))
        except json.JSONDecodeError as e:
            print(f"error: {bj} is not readable JSON: {e}", file=sys.stderr)
            return 2
        excluded = set(cfg.get("exclude", []))
        excluded.add(cfg.get("glossary_file", "glossary.md"))
        if "tags" in cfg:
            tags_declared = bool(cfg["tags"])

    # Chapters by number, for the chapter references and quotations of checks 1
    # and 2; and every tagged file by its tag's chapter half, appendices
    # included, for checks 3 and 4. An appendix is tested for first, so its own
    # number is never read as a chapter's.
    chapters, units = {}, {}
    for p in sorted(book.glob("*.md")):
        if p.name in excluded:
            continue
        u = unit_of(p.name)
        if u is None:
            continue
        units[u] = p
        if not u.startswith("A"):
            chapters[int(u)] = p
    if not chapters:
        print(f"error: no numbered chapters in {book}", file=sys.stderr)
        return 2
    # Per chapter, not one pooled corpus. Matching a quotation against the whole
    # book and then reporting that it matched the chapter cited is the same
    # substitution of a weak check for a strong one this tool exists to catch:
    # a row citing ch. 5 while quoting ch. 15 would pass.
    text = {n: norm(p.read_text(encoding="utf-8")) for n, p in chapters.items()}
    whole = "\n".join(text.values())

    # The definition set for checks 3 and 4. A book that declares "tags": false
    # has no addresses, so a [N-M]-shaped string in a referring file is not a
    # citation into it and reporting one as unresolved would be noise. Inference
    # from the chapters covers a book that declares nothing, and says which of
    # the two it used on the summary, because a check that quietly got weaker
    # reads exactly like a check that passed.
    # Parsed per chapter and merged, rather than over one concatenation, so that
    # an unbalanced code fence in one chapter cannot suppress every definition
    # in the chapters after it. baseline_paragraphs already reads one chapter at
    # a time, and the two sides have to agree on the definition set or check 4
    # compares different books.
    paras = {}
    for p in units.values():
        paras.update(tag_paragraphs(p.read_text(encoding="utf-8")))
    # A declaration the chapters contradict is a finding, not a state to resolve
    # toward the quieter answer. "tags": true with nothing parsing means the tags
    # were stripped by an edit or the parser stopped matching, and both are the
    # moment a red line is most wanted; falling through to the untagged branch
    # would print "this book carries no paragraph tags" over a book whose own
    # book.json says otherwise. The two genuinely silent cases are different:
    # "tags": false is a book with no addresses, and no declaration at all is a
    # book the tool has to infer from.
    if tags_declared is True and not paras:
        print(f"error: {bj} declares \"tags\": true but no chapter defines a [N-M] tag; "
              "checks 3 and 4 cannot run", file=sys.stderr)
        return 2
    if tags_declared is False:
        tag_mode = "declared untagged"
    elif tags_declared is True:
        tag_mode = "declared"
    else:
        tag_mode = "inferred" if paras else "inferred untagged"
    check_tags = tags_declared is not False and bool(paras)

    base, base_note, renamed = (None, "disabled with --no-baseline", set())
    if check_tags and ref is not None:
        base, base_note, renamed = baseline_paragraphs(book, units, excluded, ref)
        # A baseline the caller ASKED for and did not get is a usage error, not
        # a degraded run. Reporting the reason and then exiting 0 hands back a
        # green result for a check that never happened, which is the whole
        # failure this script exists to refuse. An unavailable DEFAULT baseline
        # is different: nobody asked, so it degrades to a note and carries on.
        if base is None and asked_for_baseline:
            print(f"error: --since {ref}: {base_note}", file=sys.stderr)
            return 2

    # Which chapters changed length since the baseline. This is what separates a
    # tag that slid from a paragraph that was reworded where it stood, and it is
    # computed once here rather than per citation.
    #
    # Only plain tags are counted. A paragraph added with a lettered tag, [5-3a],
    # lengthens the chapter and slides nothing, so counting it would turn a
    # rewording elsewhere in that chapter into a false "the tags slid". A
    # renumber, which is what absorbs lettered tags at a chapter rewrite, still
    # changes the plain count and is still caught.
    def counts(m):
        out = {}
        for c, para in (m or {}):
            if para.isdigit():
                out[c] = out.get(c, 0) + 1
        return out
    cur_count, base_count = counts(paras), counts(base)
    # Two signals that a tag slid rather than a paragraph being reworded. A
    # chapter that changed length is the direct one. A chapter whose FILE was
    # renamed is the other, and it is the one that catches an insert: inserting
    # a chapter renames every later file and shifts the chapter half of every
    # tag in them, so chapter 7's prose afterwards is the old chapter 6's, and
    # the paragraph counts can match by coincidence while nothing else does.
    shifted = {c for c in cur_count if c in base_count and base_count[c] != cur_count[c]}
    renamed_reason = {c: "was renamed" for c in renamed}
    for c in shifted:
        renamed_reason[c] = f"went from {base_count[c]} paragraphs to {cur_count[c]}"
    # Lettered tags slide too, without moving the plain count. Letters run with
    # no gap, so cutting [5-12a] reletters [5-12b] as [5-12a], and a citation
    # of [5-12a] now names what was [5-12b]. Adding a letter at the end of a run
    # slides nothing, so a run is only suspect when what it held at the
    # baseline is no longer the start of what it holds now.
    def letter_runs(m):
        out = {}
        for c, para in (m or {}):
            num, let = para_order(para)
            if let:
                out.setdefault((c, num), []).append(let)
        return {k: sorted(v) for k, v in out.items()}
    cur_runs, base_runs = letter_runs(paras), letter_runs(base)
    for (c, num), was in base_runs.items():
        if cur_runs.get((c, num), [])[:len(was)] != was and c not in shifted:
            shifted.add(c)
            renamed_reason[c] = (f"lost or relettered a paragraph added after "
                                 f"[{c}-{num}]")
    shifted |= renamed

    # The book's own chapter filenames. A block that names one of these before a
    # quotation is attributing it to the book, so the exemption below must not
    # treat it as an attribution to something else.
    chapter_files = {p.name for p in chapters.values()}

    # Markdown files this run can see, by basename, so the exemption can ask
    # whether a named file EXISTS rather than only whether the text is shaped like
    # a filename. A file it cannot find is not an exemption, so a miss here fails
    # in the strict direction.
    #
    # Rooted at THE BOOK'S repository, never at the working directory. `rglob` from
    # "." makes the same book give different answers from different places: run from
    # inside the book folder, both of the reference book's exemptions vanish and a
    # REVIEW item reappears, and run from a PARENT of the repo, unrelated
    # repositories' basenames start satisfying a check that can fail a build. The
    # `-C` is what makes the comment true: resolving the toplevel from the process's
    # own cwd would still answer with whichever repository the CALLER stands in.
    try:
        search_root = pathlib.Path(subprocess.run(
            ["git", "-C", str(book), "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, check=True).stdout.strip())
    except (subprocess.CalledProcessError, FileNotFoundError):
        search_root = pathlib.Path(".")
    visible_md = {p.name for p in search_root.rglob("*.md")}
    visible_md.update(pathlib.Path(a).name for a in rest[1:])

    fail = 0
    # n_examined, not n_quotes: it counts the quotations check 2 actually looked
    # for in the book, and it now has two exceptions, an exemption and a block the
    # scanner could not read. A counter named for the thing rather than for the
    # measurement is how both exceptions reached a summary line that still assumed
    # the old meaning.
    n_refs = n_examined = n_review = n_elsewhere = n_unreadable = 0
    exempted = []
    n_tags = n_unresolved = n_drift = n_shift = n_compared = 0

    for arg in rest[1:]:
        f = pathlib.Path(arg)
        if not f.is_file():
            print(f"FAIL  {arg}: no such file")
            fail = 1
            continue
        lines = f.read_text(encoding="utf-8").splitlines()

        for lineno, line in enumerate(lines, 1):
            for m in re.finditer(REF, line):
                n_refs += 1
                n = int(m.group(1))
                if n not in chapters:
                    print(f"FAIL  {f.name}:{lineno}: cites chapter {n}, which the book does not have")
                    fail = 1

        # Checks 3 and 4. Both walk the same citations, and the split between
        # them is the point: existence answers a weaker question than the one a
        # reader following the citation actually asks.
        if check_tags:
            for lineno, ch, para in tag_citations(lines):
                n_tags += 1
                if (ch, para) not in paras:
                    n_unresolved += 1
                    fail = 1
                    held = sorted((p for c, p in paras if c == ch), key=para_order)
                    if not held:
                        why = f"the book has no {unit_label(ch)}" if ch not in units \
                              else f"{unit_label(ch)} carries no paragraph tags"
                    else:
                        why = f"{unit_label(ch)} ends at paragraph {held[-1]}"
                    print(f"FAIL  {f.name}:{lineno}: cites [{ch}-{para}]; {why}")
                    continue
                # A citation that resolves is not a citation that still means
                # what it meant. Only the baseline can tell those apart.
                if base is None or (ch, para) not in base:
                    continue
                # Counted separately from n_tags because they are different
                # claims. A citation into a chapter that did not exist at the
                # baseline is checked for existence and nothing more, and the
                # closing banner may only speak for the ones actually compared.
                n_compared += 1
                if base[(ch, para)] == paras[(ch, para)]:
                    continue
                n_drift += 1
                # Two causes produce drift and they deserve different verdicts.
                # If the chapter's paragraph COUNT also changed, prose was
                # inserted or cut and every tag after that point slid by one, so
                # this citation names a different paragraph than the one written
                # down: a fault, and the one this check exists for. If the count
                # held, the paragraph was edited where it stood, the citation
                # still names the right paragraph, and only a reader can say
                # whether it still supports the sentence citing it.
                if ch in shifted:
                    n_shift += 1
                    fail = 1
                    print(f"FAIL  {f.name}:{lineno}: [{ch}-{para}] names different prose than at "
                          f"{ref}, and {unit_label(ch)} {renamed_reason[ch]}, so the tags slid")
                else:
                    # Report the evidence, not the conclusion. An equal count
                    # makes a rewording likely and does not prove one: inserting
                    # a paragraph and cutting another in the same chapter leaves
                    # the count alone while sliding every tag between them, and
                    # so does reordering two paragraphs. Claiming certainty here
                    # would spend the reader's trust on the one sentence in the
                    # report that can be false.
                    n_review += 1
                    print(f"REVIEW  {f.name}:{lineno}: [{ch}-{para}] names different prose than "
                          f"at {ref}; {unit_label(ch)} has {cur_count.get(ch, 0)} numbered paragraphs at both, so "
                          f"this is more likely a rewording in place than a tag that slid. "
                          f"Confirm which.")
                for label, s in (("was", base[(ch, para)]), ("now", paras[(ch, para)])):
                    print(f'        {label}:  "{s[:OPENING]}{"..." if len(s) > OPENING else ""}"')

        # Only quotations ATTRIBUTED to the book are checked. A referring file
        # also quotes things that are not the book: a quiz stem, an answer
        # option, another document. The attribution signal is a chapter
        # reference in the same block, so scan block by block rather than line
        # by line, which also survives a quotation wrapped across two lines.
        for start, block, lead_in in blocks(lines):
            # A list item naming no chapter reads against the chapters of the
            # block that introduced the list. An inherited citation is a weaker
            # claim about what the text meant than one the item makes itself, so
            # it can only ever REVIEW: see the severity choice further down.
            inherited = False
            if re.search(REF, block):
                cited_src = block
            elif lead_in and re.search(REF, lead_in):
                cited_src, inherited = lead_in, True
            else:
                continue
            is_row = block.lstrip().startswith("|")
            cited = [int(x) for x in REF.findall(cited_src) if int(x) in text]
            # The quotation must be in a chapter this block actually names.
            target = "\n".join(text[n] for n in cited) if cited else whole
            spans, unterminated = quoted_spans(block)
            for qstart, q in spans:
                # The length test the old inline pattern made part of the match.
                # Applied here instead, so a phrase too short to be an
                # attribution is skipped rather than becoming the opening of a
                # straddle across the prose after it. See quoted_spans().
                if len(q) < MIN_QUOTE:
                    continue
                # What is this quotation attributed to? Whichever signal sits
                # CLOSEST BEFORE it: a chapter reference, or a named file. A
                # block naming a file right before the quotation is sourcing it
                # there, and checking it against the book then asks a question
                # nobody posed. `OUTLINE.md:114` quotes `course-outline.md:59`
                # inside a sentence that also says "Chapter 2's agent", and the
                # chapter is who did the work rather than what is quoted.
                #
                # Closest-before rather than anywhere-in-block, because a block
                # that names both is the ordinary case and the order is the only
                # thing separating them. A chapter FILENAME is not an attribution
                # elsewhere: that is the book, named a second way.
                #
                # This applies to key rows too. Narrowing it to prose would leave
                # a row attributing a quotation to a file failing the build over
                # wording nobody claimed was the book's, and a false FAIL costs
                # more than a false REVIEW. Measured 2026-09-10: no key row in
                # `assessments/` carries a file-attributed quotation,
                # so the answer keys' output is byte-identical either way.
                #
                # The named file must be one this run can SEE. FILEREF matches a
                # shape, not a file, so without this a key row reading
                # ``Chapter 9 (see `notes.md`) says "..."`` exempts itself from
                # the FAIL path with a parenthetical naming nothing. Raised by
                # review 2026-09-10; `notes.md` exists nowhere in the source repo.
                before = block[:qstart]
                last_ch = max((m.start() for m in REF.finditer(before)), default=None)
                named = [(m.start(), m.group().rsplit("/", 1)[-1].split(":")[0])
                         for m in FILEREF.finditer(before)]
                last_file = max((at for at, name in named
                                 if name not in chapter_files and name in visible_md),
                                default=None)
                if last_file is not None and (last_ch is None or last_file > last_ch):
                    # Counted AND named, not merely skipped. A check that quietly
                    # stopped examining something reads exactly like a check that
                    # passed, and every other class in this report carries a
                    # file:line, so the skip does too.
                    source = next(name for at, name in named if at == last_file)
                    exempted.append((f.name, start + before.count("\n"), source))
                    n_elsewhere += 1
                    continue
                n_examined += 1
                nq = norm(q).strip(" .")
                if nq in target:
                    continue
                elsewhere = cited and nq in whole
                where = start + block[: qstart].count("\n")
                flat = re.sub(r"\s+", " ", q)
                # Naming the chapter that DOES hold it is the useful half of the
                # report: it turns "wrong" into "you meant this one".
                if elsewhere:
                    holder = next((n for n in sorted(text) if nq in text[n]), None)
                    detail = f"is in chapter {holder}, not the chapter {'/'.join(map(str, cited))} cited here"
                else:
                    detail = "is in no chapter of the book"
                if is_row and not inherited:
                    # A key table's note column exists to evidence the keyed
                    # answer, so a quotation there is unambiguously attributed.
                    print(f"FAIL  {f.name}:{where}: key row quotes text that {detail}")
                    fail = 1
                else:
                    # Prose near a chapter reference also quotes things that are
                    # not the book: a lab title, a quiz stem, a proposed
                    # rewording. The tool cannot tell which, so it says so. An
                    # inherited citation lands here even in a key row, because
                    # the row did not name the chapter itself and a build must
                    # not fail on a citation this script inferred.
                    n_review += 1
                    how = " (citing the chapter its list's lead-in names)" if inherited else ""
                    print(f"REVIEW  {f.name}:{where}: quotes text that {detail}{how}; may not be quoting the book")
                print(f'        "{flat[:88]}{"..." if len(flat) > 88 else ""}"')

            # Every quote mark the scan did not account for, plus a mark nothing
            # closed. A mark INSIDE an emitted span is accounted for, which is what
            # keeps a nested curly quotation quiet; a mark left over means the
            # pairing did not use every delimiter, so a quotation here may never
            # have been examined.
            #
            # Every sentence this block prints hedges that last clause, and they
            # have to agree. Review found the hedge applied to one of four places
            # stating the same conclusion, leaving two report lines and the closing
            # banner speaking with different voices about one piece of evidence, four
            # lines apart in the same report. After fixing a sentence, grep for the
            # claim rather than for the line.
            #
            # REVIEW for both, in a key row as much as in prose. The signal proves
            # that the scanner could not account for a delimiter, never that the row
            # is wrong, and a FAIL would fail a build over a formatting choice: a
            # note column reading `SQLite accepts ' and " for different things` is
            # correct prose. "Say it out loud" and "fail the build" are different
            # answers to a skipped block, and which is honest follows from what the
            # signal proves.
            #
            # **This is a completeness check, deliberately not another recognition
            # rule, and that distinction is the whole lesson of this branch.**
            # Three rounds of review each found the previous round's fix had
            # reopened the same silent skip through a different door: an allow-list
            # of what may precede an opener, then a deny-list, then the closer's
            # preceding-character rule, then the style fallback. Every one of those
            # tries to enumerate what a delimiter is, the enumeration keeps having
            # holes, and a hole is silent because a mis-paired span under MIN_QUOTE
            # is dropped without a word and the scan then resumes inside the real
            # quotation. What CAN be made total is "did every delimiter in this
            # block get used", which is true whatever the recognition rule misses.
            #
            # Coverage rather than arithmetic: counting `2 * len(spans)` against the
            # delimiters present reports a nested `“…”` that style matching stepped
            # over on purpose. An accounting rule also has to err toward the honest
            # answer on the case it does not understand.
            covered = [(o, o + 1 + len(q) + 1) for o, q in spans]
            leftover = [m.start() for m in re.finditer(r'["“”]', block)
                        if m.start() != unterminated
                        and not any(a <= m.start() < b for a, b in covered)]
            # A lone mark in a sentence about quote marks is not a quotation, and
            # with no second delimiter there was none to examine either.
            if len(re.findall(r'["“”]', block)) > 1 and (unterminated is not None or leftover):
                at = unterminated if unterminated is not None else leftover[0]
                where = start + block[:at].count("\n")
                n_review += 1
                n_unreadable += 1
                # The cost of choosing REVIEW, stated where the choice is made: a
                # key row whose real quotation IS swallowed reports REVIEW at exit 0
                # where `main` exited 1.
                #
                # Report the evidence and hedge the conclusion, the way the drift
                # REVIEW further up reports its counts and leaves the reading to a
                # human. A leftover mark does not prove anything went unexamined:
                # `says naïve" and says "..."` pairs its real quotation correctly and
                # leaves the stray mark beside it, and an inch mark does the same.
                # Both are indistinguishable from a dropped delimiter from here, so
                # the line says that rather than asserting a miss it cannot see.
                what = "a key row" if is_row else "prose"
                if unterminated is not None:
                    print(f"REVIEW  {f.name}:{where}: {what} has a quote mark that nothing closes, so "
                          "check 2 stopped reading this block, and anything quoted after it "
                          "was not examined. A mark mentioned in prose looks the same from here")
                else:
                    print(f"REVIEW  {f.name}:{where}: {what} leaves {len(leftover)} quote mark(s) "
                          "that check 2 could not pair, so a quotation here may not have been "
                          "examined. A stray mark beside a quotation read correctly looks the "
                          "same from here")

    print()
    print(f"chapters: {len(chapters)}    references: {n_refs}    quotations: {n_examined}    book: {book}")
    if check_tags:
        drift_state = f"drifted: {n_drift} ({n_shift} where the chapter itself moved)" \
                      if base is not None else "drift: NOT CHECKED"
        print(f"tags defined: {len(paras)} ({tag_mode})    tag citations: {n_tags}    "
              f"unresolved: {n_unresolved}    {drift_state}")
        if base is not None:
            print(f"baseline: {ref}" + (f"    note: {base_note}" if base_note else ""))
            # A vacuous comparison and a clean one print the same zero, so say
            # which this was. The trap is ordinary: commit the update, then run
            # the check, and HEAD is now the edited book. Check 4 compares it to
            # itself, finds nothing, and reads exactly like a book whose
            # citations all held.
            if base == paras:
                print(f"note: the book's tags are identical at {ref}, so check 4 compared it to")
                print("      itself and could not have found drift. If an edit is already")
                print("      committed, pass --since <the commit before it>.")
        else:
            print(f"note: no baseline, so check 4 did not run: {base_note}")
    else:
        print(f"tags: none ({tag_mode}), so no paragraph-tag citation was checked")

    if n_review:
        print()
        print(f"{n_review} REVIEW item(s) need a human. A quotation in prose beside a chapter")
        print("reference may be quoting something else entirely, a paragraph edited in place")
        print("drifts without any citation into it having broken, and a block whose delimiters")
        print("check 2 could not pair may not have been examined. None of the three fails a run.")
    if n_elsewhere:
        one = n_elsewhere == 1
        print(f"note: {n_elsewhere} quotation{'' if one else 's'} "
              f"{'was' if one else 'were'} attributed to a named file rather than")
        print("      a chapter, so check 2 did not look for "
              f"{'it' if one else 'them'} in the book:")
        for fname, lineno, source in exempted:
            print(f"      {fname}:{lineno}: sourced to {source}")
    # Gated on BOTH exceptions, because n_examined counts what check 2 looked for
    # and two things now reduce it without the text being quiet: a quotation
    # sourced elsewhere, and a block whose delimiters the scanner could not pair.
    # Saying "nothing quotes the book" under findings that say a quotation opened
    # is the contradiction review found here twice on 2026-09-10, once per
    # exception, because the gate was not revisited when the second arrived.
    if n_examined == 0 and n_refs and not n_elsewhere and not n_unreadable:
        print("note: chapter references resolve by number and nothing quotes the book, so")
        print("      check 2 had nothing to examine. That is the weaker reading of check 1.")
    if check_tags and n_tags == 0:
        print(f"note: nothing among these {len(rest) - 1} file(s) cites a paragraph tag, so")
        print(f"      checks 3 and 4 examined none of the book's {len(paras)} addresses.")
    def tag_claim(conj):
        """The tag half of the closing banner, which claims only the checks that
        actually ran. An untagged book never reached checks 3 and 4, and saying
        every tag citation resolved would be a green line about work not done."""
        if check_tags and n_compared and n_compared == n_tags and base != paras:
            print(f"      {conj} every paragraph-tag citation names a paragraph the book defines,")
            print(f"      which is the same paragraph it named at {ref}")
        elif check_tags and n_compared and base != paras:
            # Partial coverage is not the strong claim. One citation compared
            # does not license a sentence about every citation, and the gap is
            # where a chapter postdates the baseline.
            print(f"      {conj} every paragraph-tag citation names a paragraph the book defines;")
            print(f"      {n_compared} of {n_tags} were compared against {ref}, and the rest")
            print("      name paragraphs absent there, so check 4 is silent about them")
        elif check_tags:
            # Reached when the book is byte-identical at the baseline, so check
            # 4 could not have found anything, or when no citation was compared
            # at all. The note above says which; the banner must not imply the
            # comparison meant something.
            print(f"      {conj} every paragraph-tag citation names a paragraph the book defines")
            print("      (a citation resolving is not a citation still meaning what it meant;")
            print("       that is check 4, and it needs a baseline to say anything at all)")
        else:
            print("      (this book carries no paragraph tags, so checks 3 and 4 had nothing")
            print("       to examine and this run says nothing about tag citations)")

    # An exemption qualifies the run exactly as an unread REVIEW item does, so it
    # reaches the same banner. Gating this on n_review alone let the strong OK
    # print over quotations nobody had looked for, which review found here on
    # 2026-09-10: the `OK` line's claim about every key-row quotation is false the
    # moment one was skipped.
    if fail == 0 and (n_review or n_elsewhere):
        # Nothing failed, and that is not the same as an all-clear. Printing a
        # bare OK under REVIEW items is the substitution this script refuses:
        # the reader takes the banner and skips the reasons it was qualified.
        why = []
        if n_review:
            why.append(f"{n_review} REVIEW item(s) above are still unread")
        if n_elsewhere:
            why.append(f"{n_elsewhere} quotation(s) were sourced elsewhere and never "
                       "checked against the book")
        print(f"OK*   nothing failed, and {', and '.join(why)}.")
        print("      This is not an all-clear until someone has been through them.")
        # Only where an exemption is what diverted an otherwise-clean run here. A
        # run already qualified by REVIEW items has never printed the tag claim,
        # and adding one now would change output this branch has always produced.
        if n_elsewhere and not n_review:
            tag_claim("Separately,")
    elif fail == 0:
        print("OK    every quotation attributed in a key row is in the chapter that row cites")
        tag_claim("and")
    return fail


if __name__ == "__main__":
    sys.exit(main(sys.argv))
