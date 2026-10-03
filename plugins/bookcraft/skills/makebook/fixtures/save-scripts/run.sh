#!/usr/bin/env bash
#
# Bind book/ and assert that code copied out of the PDF can be made to run.
#
# Copying code off a Chromium PDF fails two ways, and they separate:
#
#   the indentation     PDFKit (Preview, Safari) drops every leading indent from
#                       the text layer, at any font and any size. No stylesheet
#                       reaches it, so the binder attaches each script the book
#                       asks the reader to save to the PDF as a file instead.
#   the underscore      Off a quarter pixel, Chromium writes each glyph of a
#                       code line as its own text run, and PDFKit puts every `_`
#                       on a line of its own: `for` / `_` / `in range(7):`. The
#                       stylesheet rounds every code size to a quarter pixel,
#                       which writes the line as one run.
#
# book/ asks for saves in every way the binder reads one, and in the ways it
# must not:
#
#   save-01   a sentence before the block names the file (time_species.py)
#             the fence names it, with no sentence (count_rounds.py)
#             "save the output as `results.txt`" is about the output, not the
#             block beside it, so nothing is attached and nothing is warned
#             a list item's sentence and fence pair up (in_a_list.py), and the
#             attached file carries none of the list's own indent
#   save-02   "Save the code above as `after.py`. Next, run it:" reaches back
#             to the block above (after.py); the "Next" belongs to the other
#             sentence, so the command below is not taken
#             "Save this script" names no file: a warning
#             a sentence naming later.py with no block of its own: a warning,
#             and it must not take the block the sentence before it asked about
#             an ordinary block with no save beside it: neither
#             an indented block, not a fence, beside a save (indented.py).
#             markdown-it marks it on <pre> rather than <code>, and missing
#             that once failed the whole bind
#             "The script above is complete. Save it as `complete.py`." takes
#             the paragraph's "above" when its own sentence names no direction,
#             so the block below it is not taken
#             "Save it as `run_next.py` and run it:" names no direction at all,
#             and the bash block below is skipped: a .py file is never the
#             command that runs it, so it goes to the block above
#
# What is checked, and against what:
#
#   attachments    pdfdetach lists exactly the seven scripts, and not later.py
#   contents       each extracted file is the block byte for byte, indents and
#                  all, and every .py parses
#   warnings       the bind warns for the two gaps and for nothing else
#   text runs      every text object set in a monospace font shows its text in
#                  one run. Reverting the rounding fails this on macOS, where
#                  every code line came out as 20 to 38 runs.
#   PDFKit         on macOS, no line of the copied text is a lone `_`. This is
#                  the reader's own engine, so it is the check that matters;
#                  the text-run check is what makes the same failure visible on
#                  Linux, where there is no PDFKit.
#   links          no marker link survives, so no note points at nothing
#   EPUB           the chapters carry neither the note nor the marker
#
# The toolchain is optional on a laptop and required in CI, as in bind/: with no
# venv, pdftotext or pdfdetach this prints skip and exits 0, and --strict
# (implied by $CI) turns that into a failure. So does a macOS with no swift.
#
# Usage: ./run.sh          (from anywhere; paths are resolved from the script)
# Exits 0 when every assertion holds, 1 otherwise.

set -uo pipefail
export LC_ALL=C

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
binder="$here/../../scripts/build-book.py"

fails=0
report() {
  if [ "$1" -eq 0 ]; then echo "ok    $2"; else echo "FAIL  $2"; fails=1; fi
}

py="${XDG_CACHE_HOME:-$HOME/.cache}/bookcraft/venv/bin/python"
if [ ! -x "$py" ]; then
  echo "skip  no binder venv at $py; run scripts/install.sh to bind"
  exit 0
fi
for tool in pdftotext pdfdetach; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "skip  no $tool on PATH; it ships with poppler"
    exit 0
  fi
done

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cp -R "$here/book" "$tmp/book"
pdf="$tmp/out/save.pdf"

bind_out=$("$py" "$binder" "Save Scripts" "$tmp/book" --out "$pdf" 2>&1); rc=$?
if [ "$rc" -ne 0 ]; then
  report 1 "the book binds (exit $rc)"
  printf '%s\n' "$bind_out" | sed 's/^/      | /'
  exit 1
fi
report 0 "the book binds"

# --- attachments -------------------------------------------------------------
# Unique names, because every script is listed twice: once in the document's
# embedded files and once as the annotation over its note.
listed=$(pdfdetach -list "$pdf" 2>&1 | sed -n 's/^[0-9][0-9]*: //p' | sort -u | tr '\n' ' ')
want="after.py complete.py count_rounds.py in_a_list.py indented.py run_next.py time_species.py "
if [ "$listed" = "$want" ]; then
  report 0 "the PDF carries exactly the seven scripts the book asks to be saved"
else
  report 1 "the PDF should carry '$want', and carries '$listed'"
fi

mkdir -p "$tmp/detached"
( cd "$tmp/detached" && pdfdetach -saveall "$pdf" >/dev/null 2>&1 )
contents=$("$py" - "$tmp/detached" <<'EOF' 2>&1
import ast, pathlib, sys
d = pathlib.Path(sys.argv[1])
want = {
    "time_species.py": (
        "import time\n\n\ndef time_species(n_rounds):\n"
        "    start = time.perf_counter()\n"
        "    for _ in range(7):\n"
        "        if n_rounds > 0:\n"
        "            total_count = n_rounds * 2\n"
        "    return time.perf_counter() - start\n"),
    "in_a_list.py": 'for _ in range(3):\n    print("inside a list item")\n',
    "after.py": "def after_the_fact(x_value):\n    return x_value * 2\n",
    "indented.py": 'for _ in range(2):\n    print("an indented block")\n',
    "complete.py": "def complete_above(y_value):\n    return y_value + 1\n",
    "run_next.py": "def run_it_next(z_value):\n    return z_value - 1\n",
}
bad = []
for name, text in want.items():
    got = (d / name).read_text(encoding="utf-8") if (d / name).exists() else None
    if got != text:
        bad.append(f"{name} is {got!r}")
for f in sorted(d.glob("*.py")):
    try:
        ast.parse(f.read_text(encoding="utf-8"))
    except SyntaxError as exc:
        bad.append(f"{f.name} does not parse: {exc}")
print("\n".join(bad))
sys.exit(1 if bad else 0)
EOF
); rc=$?
if [ "$rc" -eq 0 ]; then
  report 0 "each attached file is its block byte for byte, indents kept, and parses"
else
  report 1 "the attached files are not their blocks"
  printf '%s\n' "$contents" | sed 's/^/      | /'
fi

# --- warnings ----------------------------------------------------------------
warned=$(printf '%s\n' "$bind_out" | grep -E '^    ch [0-9]+: ' || true)
if printf '%s\n' "$warned" | grep -qF 'ch 2: "Save this script so you can run it again tomorrow:" names no file' \
  && printf '%s\n' "$warned" | grep -qF 'ch 2: "Save the script as `later.py` once you have written it." has no code block beside it' \
  && [ "$(printf '%s\n' "$warned" | grep -c 'ch [0-9]*: "')" -eq 2 ]; then
  report 0 "the bind warns for the two uncovered saves, and for nothing else"
else
  report 1 "the bind should warn for exactly the two uncovered saves in ch 2"
  printf '%s\n' "$bind_out" | sed 's/^/      | /'
fi

# --- text runs, links, attachments annotations --------------------------------
runs=$("$py" - "$pdf" <<'EOF' 2>&1
import re, sys
from pypdf import PdfReader
from pypdf.generic import ContentStream
MONO = re.compile(r"mono|menlo|courier|consolas", re.I)
reader = PdfReader(sys.argv[1])
blocks, split, links, attach = 0, [], [], 0
for pno, page in enumerate(reader.pages, start=1):
    fonts = page.get("/Resources", {}).get_object().get("/Font", {})
    mono = {k for k, v in fonts.get_object().items()
            if MONO.search(str(v.get_object().get("/BaseFont", "")))}
    font, shows = None, None
    content = page.get_contents()
    if content is None:
        continue
    for operands, op in ContentStream(content, reader).operations:
        if op == b"BT":
            shows = 0
        elif op == b"Tf":
            font = str(operands[0])
        elif op in (b"Tj", b"TJ", b"'", b'"') and font in mono:
            shows += 1
        elif op == b"ET" and shows:
            blocks += 1
            if shows > 1:
                split.append(f"page {pno}: a code line in {shows} runs")
            shows = None
    for a in page.get("/Annots") or []:
        a = a.get_object()
        if a.get("/Subtype") == "/FileAttachment":
            attach += 1
        uri = str((a.get("/A") or {}).get("/URI", ""))
        if "bookcraft.invalid" in uri:
            links.append(f"page {pno}: {uri}")
print(f"blocks={blocks} attach={attach}")
print("\n".join(split[:6] + links))
EOF
); rc=$?
first=$(printf '%s\n' "$runs" | head -1)
if [ "$rc" -ne 0 ]; then
  report 1 "the PDF's content streams could not be read"
  printf '%s\n' "$runs" | sed 's/^/      | /'
else
  nblocks=$(printf '%s' "$first" | sed -n 's/.*blocks=\([0-9]*\).*/\1/p')
  nattach=$(printf '%s' "$first" | sed -n 's/.*attach=\([0-9]*\).*/\1/p')
  rest=$(printf '%s\n' "$runs" | sed 1d | sed '/^$/d')
  if [ "${nblocks:-0}" -gt 0 ] && ! printf '%s\n' "$rest" | grep -q 'runs$'; then
    report 0 "all $nblocks monospace text objects show their text in one run"
  else
    report 1 "code should be written one run to a line ($first)"
    printf '%s\n' "$rest" | grep 'runs$' | sed 's/^/      | /'
  fi
  if printf '%s\n' "$rest" | grep -q 'bookcraft.invalid'; then
    report 1 "a marker link survives into the finished PDF"
    printf '%s\n' "$rest" | grep 'bookcraft.invalid' | sed 's/^/      | /'
  else
    report 0 "no marker link survives into the finished PDF"
  fi
  if [ "${nattach:-0}" -eq 7 ]; then
    report 0 "each script's note carries a file attachment annotation"
  else
    report 1 "seven notes should carry a file attachment annotation, and $nattach do"
  fi
fi

# attach_scripts rewrites link annotations, so the contents page's own links
# have to come out of it still opening their pages. The check is the bind
# fixture's.
links=$("$py" "$here/../bind/contents-links.py" "$pdf" Contents 2>&1); rc=$?
if [ "$rc" -eq 0 ]; then
  report 0 "every Contents row still links to the page it prints"
else
  report 1 "a Contents row's link did not survive the attachments"
  printf '%s\n' "$links" | sed 's/^/      | /'
fi

# --- PDFKit ------------------------------------------------------------------
if [ "$(uname -s)" = "Darwin" ]; then
  if ! command -v swift >/dev/null 2>&1; then
    echo "skip  no swift, so the text cannot be read through PDFKit"
  else
    cat > "$tmp/pdfkit.swift" <<'EOF'
import Foundation
import PDFKit
let doc = PDFDocument(url: URL(fileURLWithPath: CommandLine.arguments[1]))!
let s = doc.page(at: 0)!, e = doc.page(at: doc.pageCount - 1)!
print(doc.selection(from: s, atCharacterIndex: 0,
                    to: e, atCharacterIndex: e.numberOfCharacters - 1)!.string ?? "")
EOF
    text=$(swift "$tmp/pdfkit.swift" "$pdf" 2>&1); rc=$?
    if [ "$rc" -ne 0 ]; then
      report 1 "PDFKit could not read the PDF"
      printf '%s\n' "$text" | sed 's/^/      | /'
    elif ! printf '%s\n' "$text" | grep -qF 'for _ in range(7):'; then
      report 1 "PDFKit's copy has no 'for _ in range(7):' line"
      printf '%s\n' "$text" | grep -n -B1 -A1 '^_$' | head -12 | sed 's/^/      | /'
    elif printf '%s\n' "$text" | grep -q '^_$'; then
      report 1 "PDFKit's copy puts a '_' on a line of its own"
    else
      report 0 "PDFKit's copy keeps every '_' on its line"
    fi
  fi
fi

# --- EPUB ----------------------------------------------------------------------
epub_read=$("$py" - "${pdf%.pdf}.epub" <<'EOF' 2>&1
import sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
bad = [n for n in z.namelist() if n.endswith(".xhtml")
       and any(s in z.read(n).decode("utf-8")
               for s in ("data-script", "script-note", "bookcraft.invalid"))]
print(" ".join(bad))
sys.exit(1 if bad else 0)
EOF
); rc=$?
if [ "$rc" -eq 0 ]; then
  report 0 "the EPUB carries neither the attachment note nor its marker"
else
  report 1 "the EPUB carries the PDF's attachment note or marker: $epub_read"
fi

exit "$fails"
