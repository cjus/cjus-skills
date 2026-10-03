#!/usr/bin/env bash
#
# Bind a real book and assert on what the binder wrote. Nothing else in the
# suite runs build-book.py end to end, so without this a binder regression
# passes every fixture.
#
# It binds a COPY of createbook/fixtures/guide into a temp dir. The binder
# writes its render HTML into the source folder and deletes it afterwards, so a
# bind interrupted mid-run would otherwise leave a dotfile in a tracked fixture.
#
# It binds that copy twice, because the stamp cannot be read back from the book
# as the fixture declares it:
#
#   as declared, no cover_image     both formats are written, page 2 of the
#                                   PDF opens on Contents so the cover did not
#                                   spill, the EPUB's cover art is a PNG
#                                   rasterised from the PDF's cover page, and
#                                   the PDF's outline lists every page, each
#                                   chapter collapsed over its sections and
#                                   none of its ### headings; every link on
#                                   the Contents, Figures and Index pages
#                                   opens the page it prints, on both binds;
#                                   and build_outline refuses an outline that
#                                   is missing or a chapter short
#   with a declared cover_image,    PDF page 1 and EPUB/cover.xhtml carry the
#   parts, and two stray H1s        same Created: stamp, in bind_stamp's form;
#                                   the outline nests each chapter under its
#                                   part, and files an H1 in a chapter's body
#                                   under that chapter: one retitled with the
#                                   spaces Chromium drops where it wraps, and
#                                   one sharing the next chapter's title, which
#                                   only its page tells apart from that title
#
# The second bind takes its parts and its stray H1s on board only because a
# third bind would cost the suite another full render. None of them reaches
# the stamp it checks.
#
# The EPUB keeps a text cover page, and so a stamp a script can read, only
# behind declared art. Rasterised art stands in for that page and carries the
# stamp as pixels. Binding only with declared art would never run the
# rasterising path, whose failure the binder swallows and ships a book with no
# cover art.
#
# Two more books sit beside this script, each a regression test for a binder
# fix that a revert would undo without a sound:
#
#   appendix-slug/     sql-02-appendix-1-of-the-standard.md is a chapter whose
#                      name only looks like an appendix's. Contents must list
#                      1, 2 and A1, with one A1; an unanchored appendix pattern
#                      printed the middle file as a second Appendix 1.
#   appendix-table/    an appendix, placed after two chapters, holding a table
#                      whose long-prose column squeezes a long word. Every long
#                      word must print whole on the appendix's page, and the
#                      bind must not warn of a word broken mid-word; keying the
#                      column plan on the printed label, not the chapter's
#                      number, left the appendix's table unrepaired.
#
# The table check only means something while the column still squeezes, and
# that depends on font metrics. Measured on both CI legs with the pre-fix binder
# (2026-09-25): the column came out 51pt short on macOS and 43pt short on Linux,
# so both legs fail a revert. A font change wide enough to close that gap would
# let the check pass without testing the repair.
#
# The binder's toolchain is optional on a laptop and required in CI. With no
# venv from install.sh, or no pdftotext, this prints skip and exits 0, and
# --strict (implied by $CI) turns that skip into a failure. A toolchain that is
# present but broken is not a skip: the bind fails, and so does this.
#
# Usage: ./run.sh          (from anywhere; paths are resolved from the script)
# Exits 0 when every assertion holds, 1 otherwise.

set -uo pipefail
export LC_ALL=C

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
binder="$here/../../scripts/build-book.py"
book="$here/../../../createbook/fixtures/guide"

fails=0
report() {
  if [ "$1" -eq 0 ]; then echo "ok    $2"; else echo "FAIL  $2"; fails=1; fi
}

# The venv path is install.sh's and bookcraft-python's. It is checked here
# rather than through bookcraft-python so that absent reads as a skip and
# everything else reads as a failure.
py="${XDG_CACHE_HOME:-$HOME/.cache}/bookcraft/venv/bin/python"
if [ ! -x "$py" ]; then
  echo "skip  no binder venv at $py; run scripts/install.sh to bind"
  exit 0
fi
if ! command -v pdftotext >/dev/null 2>&1; then
  echo "skip  no pdftotext on PATH, and the binder reads its PDF back through it"
  exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cp -R "$book" "$tmp/book"
cp -R "$here/appendix-slug" "$tmp/appendix-slug"
cp -R "$here/appendix-table" "$tmp/appendix-table"

# bind <label> <title> <folder> <out.pdf>: binds a copy, leaves what the binder
# printed in $bind_out, and stops the run if the bind fails, since nothing
# after it has anything to read.
bind_out=""
bind() {
  local rc
  bind_out=$("$py" "$binder" "$2" "$3" --out "$4" 2>&1); rc=$?
  if [ "$rc" -ne 0 ]; then
    report 1 "$1: the bind exits $rc"
    printf '%s\n' "$bind_out" | sed 's/^/      | /'
    exit 1
  fi
  report 0 "$1: the book binds"
}

# --- as declared -----------------------------------------------------------
pdf="$tmp/declared/guide.pdf"
epub="$tmp/declared/guide.epub"
bind "as declared" "Guide Fixture" "$tmp/book" "$pdf"

[ -s "$pdf" ];  report $? "as declared: the PDF is written"
[ -s "$epub" ]; report $? "as declared: the EPUB is written"
[ "$fails" -eq 0 ] || exit 1

p2=$(pdftotext -f 2 -l 2 "$pdf" - 2>&1 | sed -n '/[^[:space:]]/{p;q;}')
if [ "$p2" = "Contents" ]; then
  report 0 "as declared: page 2 is Contents, so the cover fits on page 1"
else
  report 1 "as declared: page 2 opens on '$p2', not Contents: the cover spilled onto a second page"
fi

art=$("$py" - "$epub" <<'EOF' 2>&1
import re, sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
opf = z.read("EPUB/content.opf").decode("utf-8")
item = re.search(r'<item [^>]*properties="cover-image"[^>]*>', opf)
if not item:
    sys.exit("content.opf declares no cover-image")
href = re.search(r'href="([^"]+)"', item.group(0)).group(1)
if not z.read("EPUB/" + href).startswith(b"\x89PNG\r\n\x1a\n"):
    sys.exit(f"the cover-image {href} is not a PNG")
EOF
); rc=$?
if [ "$rc" -eq 0 ]; then
  report 0 "as declared: the EPUB's cover art is a PNG rasterised from the PDF cover"
else
  report 1 "as declared: the EPUB has no rasterised cover art: $art"
fi

# outline_is <label> <pdf> <expected tree>: compares the PDF's outline with the
# tree given, one entry a line, four spaces a level. "- " marks a collapsed
# entry with entries beneath it and "+ " an expanded one; a leaf has neither.
# The whole tree is compared, so a fixture edit that changes a heading changes
# this expectation with it, and the diff names the line.
outline_is() {
  local got
  got=$("$py" - "$2" 2>&1 <<'EOF'
import sys
from pypdf import PdfReader

def walk(node, depth):
    item = node.get("/First")
    while item is not None:
        item = item.get_object()
        count = item.get("/Count")
        mark = "  " if count is None else ("+ " if count > 0 else "- ")
        print("    " * depth + mark + str(item["/Title"]))
        walk(item, depth + 1)
        item = item.get("/Next")

walk(PdfReader(sys.argv[1]).trailer["/Root"]["/Outlines"], 0)
EOF
)
  if [ "$got" = "$3" ]; then
    report 0 "$1: the PDF's outline has the expected tree"
  else
    report 1 "$1: the PDF's outline differs from the expected tree (< expected, > got)"
    diff <(printf '%s\n' "$3") <(printf '%s\n' "$got") | sed 's/^/      | /'
  fi
}

# links_open <label> <pdf> <listing>...: every link on each listing named opens
# the page it prints (see page-links.py). The index's links are also held to
# the bind's own count of page references, read from $bind_out, so a number
# printed without a link cannot pass.
links_open() {
  local label=$1 out rc want got names
  shift
  out=$("$py" "$here/page-links.py" "$@" 2>&1); rc=$?
  names=$(printf '%s, ' "${@:2}" | sed 's/, $//; s/, \([^,]*\)$/ and \1/')
  case " $* " in
    *" Index "*)
      want=$(printf '%s\n' "$bind_out" | sed -n 's/^index: [0-9]* entries, \([0-9]*\) page references.*/\1/p')
      got=$(printf '%s\n' "$out" | sed -n 's/.*Index: \([0-9]*\) links.*/\1/p')
      if [ -z "$want" ] || [ "$got" != "$want" ]; then
        rc=1
        out="$out
the bind reported ${want:-no} page references and the index carries ${got:-no} links"
      fi
      ;;
  esac
  if [ "$rc" -eq 0 ]; then
    report 0 "$label: every link on the $names pages opens the page it prints"
  else
    report 1 "$label: a link on the $names pages opens a page other than the one it prints"
    printf '%s\n' "$out" | sed 's/^/      | /'
  fi
}

links_open "as declared" "$pdf" Contents Figures Index

# The bind's refusal, tested where no book could reach it. Two pages go through
# the binder's own render(): one with no heading, so Chromium writes no outline,
# and one that is a chapter short.
refusals=$("$py" - "$binder" "$tmp" 2>&1 <<'EOF'
import importlib.util, sys
from pathlib import Path
spec = importlib.util.spec_from_file_location("binder", sys.argv[1])
binder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(binder)
out = Path(sys.argv[2])
page = "<section style='break-before: page'><h1>{}</h1><p>Text.</p></section>"
cases = [
    ("no outline", "<p>No heading at all.</p>", []),
    ("a chapter short", "".join(page.format(t) for t in ("T", "Contents", "One")),
     [{"num": 1, "title": "One"}, {"num": 2, "title": "Two"}]),
]
for name, body, chapters in cases:
    html = f"<!DOCTYPE html><html><body>{body}</body></html>"
    pdf = out / f"refusal-{len(chapters)}.pdf"
    binder.render(html, out, pdf, "T")
    try:
        binder.build_outline(pdf, html, "T", chapters, {}, None, False, False,
                             False, {"pages": {1: 3, 2: 4}})
        print(f"{name}: accepted")
    except RuntimeError as exc:
        print(f"{name}: {exc}")
EOF
)
if printf '%s\n' "$refusals" | grep -qF "no outline: Chromium wrote no outline at all" \
  && printf '%s\n' "$refusals" | grep -qF "a chapter short: it has 3 of the 4 top-level entries" \
  && printf '%s\n' "$refusals" | grep -qF "the first missing is 'Two' opening page 4"; then
  report 0 "build_outline refuses a PDF with no outline, and one a chapter short"
else
  report 1 "build_outline should refuse a PDF with no outline and one a chapter short"
  printf '%s\n' "$refusals" | sed 's/^/      | /'
fi

# A number inside an index term is never taken for a page number. Matched one
# number at a time, the 2 in "Top 2 lists" took the first link and the printed 2
# went without, and nothing else here would notice: the link count still
# matched, and the link still opened page 2. One page of index and three to link
# to, through the binder's own render() and link_pages().
term_digits=$("$py" - "$binder" "$tmp" 2>&1 <<'EOF'
import importlib.util, re, subprocess, sys
from pathlib import Path
from pypdf import PdfReader
spec = importlib.util.spec_from_file_location("binder", sys.argv[1])
binder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(binder)
out = Path(sys.argv[2])
entries = [("Top 2 lists", [2, 3]), ("Week 4", [4])]
rows = "".join(f"<p>{d} {', '.join(map(str, p))}</p>" for d, p in entries)
filler = "".join(f"<section style='break-before: page'><p>Page {n}.</p></section>"
                 for n in (2, 3, 4))
html = f"<!DOCTYPE html><html><body><h1>Index</h1>{rows}{filler}</body></html>"
pdf = out / "term-digits.pdf"
binder.render(html, out, pdf, "T")
made = binder.link_pages(pdf, entries, 1)
reader = PdfReader(str(pdf))
page = reader.pages[0]
h = float(page.mediabox.top)
by_ref = {p.indirect_reference.idnum: i + 1 for i, p in enumerate(reader.pages)}
links = [(tuple(float(v) for v in a.get_object()["/Rect"]),
          by_ref[a.get_object()["/Dest"][0].idnum]) for a in page["/Annots"]]
bbox = subprocess.run(["pdftotext", "-raw", "-bbox", "-f", "1", "-l", "1", str(pdf), "-"],
                      capture_output=True, text=True, check=True).stdout
words = [(float(a), h - float(d), float(c), h - float(b), t) for a, b, c, d, t in
         re.findall(r'<word xMin="([\d.]+)" yMin="([\d.]+)" xMax="([\d.]+)" '
                    r'yMax="([\d.]+)">([^<]*)</word>', bbox)]
def under(rect):
    cx, cy = (rect[0] + rect[2]) / 2, (rect[1] + rect[3]) / 2
    return [w for w in words if w[0] <= cx <= w[2] and w[1] <= cy <= w[3]]
problems = []
for rect, target in links:
    hit = under(rect)
    if len(hit) != 1 or hit[0][4].rstrip(",") != str(target):
        problems.append(f"a link opening page {target} lies over {[w[4] for w in hit]}")
for i, w in enumerate(words[1:], 1):
    if w[4] in ("2", "4") and words[i - 1][4] in ("Top", "Week"):
        if any(under(r) == [w] for r, _ in links):
            problems.append(f"the {w[4]} in the term after {words[i - 1][4]!r} carries a link")
print(f"made={made} links={len(links)}")
print("\n".join(problems) or "clean")
EOF
)
if [ "$(printf '%s\n' "$term_digits" | sed -n 1p)" = "made=3 links=3" ] \
  && [ "$(printf '%s\n' "$term_digits" | sed -n 2p)" = "clean" ]; then
  report 0 "link_pages links each printed index number, and no number inside a term"
else
  report 1 "link_pages should link the three printed numbers and neither number inside a term"
  printf '%s\n' "$term_digits" | sed 's/^/      | /'
fi

# A term whose last word wraps at its hyphen still links, and numbers that never
# printed fail the bind. Anchored on the term's last word, "pre-training" set as
# "pre-" / "training" at 17pt and failed a bind that main would have passed. The
# real stylesheet and build_index() are used, because the wrap depends on both,
# and the wrap is asserted before the links, so a probe that stopped wrapping
# fails rather than passing without testing anything.
hyphen=$("$py" - "$binder" "$tmp" 2>&1 <<'EOF'
import importlib.util, subprocess, sys
from pathlib import Path
spec = importlib.util.spec_from_file_location("binder", sys.argv[1])
binder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(binder)
out = Path(sys.argv[2])
entries = [("large language model pre-training", [2, 3, 4, 5])]
filler = "".join(f"<section style='break-before: page'><p>Page {n}.</p></section>"
                 for n in (2, 3, 4, 5))
html = (f"<!DOCTYPE html><html><head><style>{binder.build_css(binder.MAX_BODY_PT)}"
        f"</style></head><body>{binder.build_index(entries)}{filler}</body></html>")
pdf = out / "hyphen.pdf"
binder.render(html, out, pdf, "T")
text = subprocess.run(["pdftotext", "-raw", "-f", "1", "-l", "1", str(pdf), "-"],
                      capture_output=True, text=True, check=True).stdout.split()
print("wraps" if "pre-" in text and "training" in text else f"does not wrap: {text[-8:]}")
print(f"links={binder.link_pages(pdf, entries, 1)}")
try:
    binder.link_pages(pdf, entries + [("Never printed", [2, 3])], 1)
    print("unprinted: accepted")
except RuntimeError as exc:
    print(f"unprinted: {exc}")
EOF
)
if [ "$(printf '%s\n' "$hyphen" | sed -n 1p)" = "wraps" ] \
  && [ "$(printf '%s\n' "$hyphen" | sed -n 2p)" = "links=4" ] \
  && printf '%s\n' "$hyphen" | grep -qF "unprinted: the page numbers of 'Never printed' (2, 3) were not found after its term"; then
  report 0 "link_pages links a term that wraps at its hyphen at 17pt, and refuses numbers that never printed"
else
  report 1 "link_pages should link a term that wraps at its hyphen, and refuse numbers that never printed"
  printf '%s\n' "$hyphen" | sed 's/^/      | /'
fi

# The ### headings under "What this chapter uses" are absent: a chapter
# expands to its sections and stops.
outline_is "as declared" "$pdf" "$(cat <<'TREE'
  Guide Fixture
  Contents
  Figures
- Chapter 1: What a Profile Selects
      In short
      Why two sets rather than one
      What this chapter uses
      Suggested reading
- Chapter 2: What the Checker Reads
      In short
      What makes a rule checkable
      What is left to reading
      Suggested reading
  Appendix 1: The Callout Labels
  Glossary
  Index
TREE
)"

# --- with a declared cover_image, parts, and a stray H1 ----------------------
# Checked, because a failed edit would bind with no cover_image and report a
# missing stamp, blaming the binder for a fault in the fixture.
#
# Chapter 2's stray H1 is long enough to wrap at any type size, and Chromium
# drops the space at the wrap from the outline entry it writes. Chapter 1's
# shares chapter 2's title: matched on text alone, it took chapter 2's entry
# and sent the reader into chapter 1.
if ! edit_out=$("$py" - "$tmp/book" 2>&1 <<'EOF'
import json, sys
from pathlib import Path
book = Path(sys.argv[1])
cfg = json.loads((book / "book.json").read_text(encoding="utf-8"))
cfg["cover_image"] = "diagrams/the-two-profiles.svg"
cfg["sections"] = [{"title": "Part One: Profiles", "chapters": [1]},
                   {"title": "Part Two: Checking", "chapters": [2]}]
(book / "book.json").write_text(json.dumps(cfg, indent=2), encoding="utf-8")
ch1 = book / "guide-fixture-01-what-a-profile-selects.md"
ch1.write_text(ch1.read_text(encoding="utf-8") + (
    "\n# What the Checker Reads\n\nA heading inside chapter 1 that shares "
    "chapter 2's title.\n"), encoding="utf-8")
ch2 = book / "guide-fixture-02-what-the-checker-reads.md"
ch2.write_text(ch2.read_text(encoding="utf-8") + (
    "\n# A heading set at the top level inside a chapter, long enough that it "
    "has to wrap onto a second line\n\nIts paragraph.\n\n"
    "## A heading under it\n\nAnother paragraph.\n"), encoding="utf-8")
EOF
); then
  report 1 "cover_image: could not add cover_image, sections and the stray H1s to the copy"
  printf '%s\n' "$edit_out" | sed 's/^/      | /'
  exit 1
fi
pdf="$tmp/cover-image/guide.pdf"
epub="$tmp/cover-image/guide.epub"
bind "cover_image" "Guide Fixture" "$tmp/book" "$pdf"

# One stamp per bind, in bind_stamp's form. Matching the form, and not just the
# word, is what catches a stamp that was printed but broken.
stamp_re='^Created: [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} '
pdf_stamp=$(pdftotext -f 1 -l 1 "$pdf" - 2>/dev/null | grep -E -m1 "$stamp_re")
# The read is kept whole before it is filtered, so a corrupt EPUB shows its
# traceback rather than reading as a missing stamp.
epub_read=$("$py" - "$epub" 2>&1 <<'EOF'
import re, sys, zipfile
cover = zipfile.ZipFile(sys.argv[1]).read("EPUB/cover.xhtml").decode("utf-8")
print("\n".join(re.findall(r"Created: [^<]*", cover)))
EOF
)
epub_stamp=$(printf '%s\n' "$epub_read" | grep -E -m1 "$stamp_re")
if [ -z "$pdf_stamp" ]; then
  report 1 "cover_image: PDF page 1 carries no Created: stamp in bind_stamp's form"
elif [ -z "$epub_stamp" ]; then
  report 1 "cover_image: EPUB/cover.xhtml carries no Created: stamp in bind_stamp's form"
  printf '%s\n' "$epub_read" | sed 's/^/      | /'
elif [ "$pdf_stamp" != "$epub_stamp" ]; then
  report 1 "cover_image: the stamps differ: PDF page 1 says '$pdf_stamp', EPUB/cover.xhtml says '$epub_stamp'"
else
  report 0 "cover_image: PDF page 1 and EPUB/cover.xhtml carry the same stamp"
fi

# A Figures row above the first part heading is the layout a contents row
# turned into an <a> would have moved (see .toc-link).
links_open "parts and stray H1s" "$pdf" Contents Figures Index

# Parts open over chapters that stay collapsed. Each stray H1 is the last of its
# chapter's sections, and the H2 under chapter 2's is gone with the other
# subsections.
outline_is "parts and stray H1s" "$pdf" "$(cat <<'TREE'
  Guide Fixture
  Contents
  Figures
+ Part One: Profiles
    - Chapter 1: What a Profile Selects
          In short
          Why two sets rather than one
          What this chapter uses
          Suggested reading
          What the Checker Reads
+ Part Two: Checking
    - Chapter 2: What the Checker Reads
          In short
          What makes a rule checkable
          What is left to reading
          Suggested reading
          A heading set at the top level inside a chapter, long enough that it has to wrap onto a second line
  Appendix 1: The Callout Labels
  Glossary
  Index
TREE
)"

# --- appendix-slug -----------------------------------------------------------
pdf="$tmp/appendix-slug-out/book.pdf"
bind "appendix-slug" "Appendix Slug" "$tmp/appendix-slug" "$pdf"
contents=$(pdftotext -f 2 -l 2 -layout "$pdf" - 2>&1)
has() { printf '%s\n' "$contents" | grep -qE "$1"; }
if has '^ *1 +Intro +[0-9]+$' \
  && has '^ *2 +Appendix One of the Standard +[0-9]+$' \
  && has '^ *A1 +Answer Key +[0-9]+$' \
  && [ "$(printf '%s\n' "$contents" | grep -cE '^ *A1 ')" -eq 1 ]; then
  report 0 "appendix-slug: Contents lists 1, 2 and A1, and the look-alike stays a chapter"
else
  report 1 "appendix-slug: Contents should list 1 Intro, 2 Appendix One of the Standard and one A1 Answer Key"
  printf '%s\n' "$contents" | grep -E '^ *(A?[0-9]+) ' | sed 's/^/      | /'
fi

# --- appendix-table ----------------------------------------------------------
# The words are read back off the page, not only the warning, because the
# binder's warning and its repair hang off one detector (plan_columns repairs
# only a table the detector flagged). If that detector went blind, the table
# would print broken and the warning would stay quiet together. Only the
# appendix's own page is read, so a word printed whole in an index cannot pass.
pdf="$tmp/appendix-table-out/book.pdf"
bind "appendix-table" "Appendix Table" "$tmp/appendix-table" "$pdf"
a1=$(pdftotext -f 2 -l 2 -layout "$pdf" - 2>/dev/null \
  | sed -n -E 's/^ *A1 +The Squeezed Table +([0-9]+)$/\1/p')
if [ -z "$a1" ]; then
  report 1 "appendix-table: Contents lists no A1 The Squeezed Table, so the table's page cannot be found"
else
  page=$(pdftotext -f "$a1" -l "$a1" "$pdf" - 2>&1)
  broken=""
  for w in Denormalization Characteristically Referential; do
    printf '%s\n' "$page" | grep -qw "$w" || broken="$broken $w"
  done
  if [ -z "$broken" ]; then
    report 0 "appendix-table: page $a1 prints every long word in the table whole"
  else
    report 1 "appendix-table: page $a1 prints a word broken mid-word:$broken"
  fi
fi
if printf '%s\n' "$bind_out" | grep -qF 'broken mid-word'; then
  report 1 "appendix-table: the bind warns of a word broken mid-word, so the appendix's table was not repaired"
  printf '%s\n' "$bind_out" | grep -A3 -F 'broken mid-word' | sed 's/^/      | /'
else
  report 0 "appendix-table: the bind does not warn of a word broken mid-word"
fi

exit "$fails"
