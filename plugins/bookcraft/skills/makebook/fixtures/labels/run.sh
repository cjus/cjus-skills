#!/usr/bin/env bash
#
# Bind book/, which sets book.json's labels, code_wrap and code_pt, and assert
# that each one reaches every place it should.
#
# book/ numbers its own chapters: an introduction with an empty label, then 1,
# 1.1 and 2, and an appendix the labels do not count. Chapter 1 holds a fenced
# line far wider than the measure, the introduction and chapter 1.1 each hold a
# figure, and the glossary refers to chapter 1.1 by its place, (ch. 3).
#
# What is checked, and against what:
#
#   contents       each row's number is its label; the introduction's row has
#                  none; the appendix keeps A1; the Figures page numbers each
#                  figure from its chapter's label, in a column wide enough
#                  that "1.1.1" does not run into its caption
#   openers        "CHAPTER 1.1 · PART ONE" on the labelled chapter; the
#                  introduction opens on its part alone, with no number and no
#                  separator; the appendix opens "APPENDIX 1"
#   outline        "Chapter 1.1: Going further", a bare "Introduction", and
#                  "Appendix 1: Reference", nested under the parts
#   figures        Figure 1.1.1 in chapter 1.1; the introduction's figure falls
#                  back to the chapter's place, Figure 1.1
#   glossary       (ch. 3) prints as ch. 1.1, in the PDF and in the EPUB
#   code           the wide line's last word is in the PDF's text layer, which
#                  a clipped line loses, and the bind reports the wrap rather
#                  than warning that lines will print cut short
#   EPUB           the openers carry the same labels, the introduction's
#                  carries its part alone
#   refusals       labels of the wrong length, a code_pt out of range and a
#                  code_wrap that is not a boolean each stop the bind, naming
#                  the key
#
# The toolchain is optional on a laptop and required in CI, as in bind/: with no
# venv or pdftotext this prints skip and exits 0, and --strict (implied by $CI)
# turns that into a failure.
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
if ! command -v pdftotext >/dev/null 2>&1; then
  echo "skip  no pdftotext on PATH; it ships with poppler"
  exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cp -R "$here/book" "$tmp/book"
pdf="$tmp/out/labels.pdf"

bind_out=$("$py" "$binder" "Labels" "$tmp/book" --out "$pdf" --no-index 2>&1); rc=$?
if [ "$rc" -ne 0 ]; then
  report 1 "the book binds (exit $rc)"
  printf '%s\n' "$bind_out" | sed 's/^/      | /'
  exit 1
fi
report 0 "the book binds"

# page_text <first> <last>: the text layer of those pages, -layout kept so a
# contents row reads as one line.
page_text() { pdftotext -layout -f "$1" -l "$2" "$pdf" - 2>/dev/null; }
has() { printf '%s\n' "$1" | grep -qE "$2"; }

# --- contents and the Figures page -------------------------------------------
contents=$(page_text 2 2)
if has "$contents" '^ +Introduction +[0-9]+$' \
  && has "$contents" '^1 +First steps +[0-9]+$' \
  && has "$contents" '^1\.1 +Going further +[0-9]+$' \
  && has "$contents" '^2 +A later addition +[0-9]+$' \
  && has "$contents" '^A1 +Reference +[0-9]+$'; then
  report 0 "contents: each row's number is its label, the introduction has none, the appendix keeps A1"
else
  report 1 "contents: the rows should read Introduction (no number), 1, 1.1, 2 and A1"
  printf '%s\n' "$contents" | sed 's/^/      | /'
fi

figlist=$(page_text 3 3)
if has "$figlist" '^1\.1\.1 +A figure numbered from its chapter' \
  && has "$figlist" '^1\.1 +A figure in a chapter with no label'; then
  report 0 "Figures page: numbers come from the labels, each clear of its caption"
else
  report 1 "Figures page: should list 1.1 and 1.1.1, each set apart from its caption"
  printf '%s\n' "$figlist" | sed 's/^/      | /'
fi

# --- chapter openers ---------------------------------------------------------
# Each opening page's first line is its eyebrow. The chapters open on pages 4
# to 8: the introduction, 1, 1.1, 2, then the appendix.
eyebrows=""
for p in 4 5 6 7 8; do
  eyebrows+="$(pdftotext -f "$p" -l "$p" "$pdf" - 2>/dev/null | head -1)"$'\n'
done
want_eyebrows=$'PART ONE\nCHAPTER 1 · PART ONE\nCHAPTER 1.1 · PART ONE\nCHAPTER 2 · PART TWO\nAPPENDIX 1\n'
if [ "$eyebrows" = "$want_eyebrows" ]; then
  report 0 "openers: labels print, and the introduction opens on its part alone"
else
  report 1 "openers: the eyebrows differ (< expected, > got)"
  diff <(printf '%s' "$want_eyebrows") <(printf '%s' "$eyebrows") | sed 's/^/      | /'
fi

# --- outline -----------------------------------------------------------------
outline=$("$py" - "$pdf" 2>&1 <<'EOF'
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
want_outline='  Labels
  Contents
  Figures
+ Part One
      Introduction
      Chapter 1: First steps
      Chapter 1.1: Going further
+ Part Two
      Chapter 2: A later addition
  Appendix 1: Reference
  Glossary'
if [ "$outline" = "$want_outline" ]; then
  report 0 "outline: labelled entries, a bare Introduction, the appendix as Appendix 1"
else
  report 1 "outline: differs from the expected tree (< expected, > got)"
  diff <(printf '%s\n' "$want_outline") <(printf '%s\n' "$outline") | sed 's/^/      | /'
fi

# --- figures, glossary and code in the text layer ----------------------------
text=$(pdftotext "$pdf" - 2>/dev/null)
if has "$text" '^Figure 1\.1\.1 A figure numbered from its chapter' \
  && has "$text" '^Figure 1\.1 A figure in a chapter with no label'; then
  report 0 "figures: 1.1.1 from the label, 1.1 from the unlabelled chapter's place"
else
  report 1 "figures: captions should read Figure 1.1.1 and Figure 1.1"
fi

if has "$text" 'sub-chapter ch\. 1\.1 '; then
  report 0 "glossary: (ch. 3) prints as the chapter's label, ch. 1.1"
else
  report 1 "glossary: (ch. 3) should print as ch. 1.1"
fi

# A clipped line stops at the margin and its tail is absent from the text layer
# too; a wrapped one carries every word.
if has "$text" 'WRAPTAILZQ' \
  && has "$bind_out" '^code: [0-9]+ fenced line\(s\) .* wrap onto a second line \(code_wrap\); nothing is cut$' \
  && ! has "$bind_out" 'print cut short'; then
  report 0 "code: the wide line wraps at code_pt 8 and keeps its last word"
else
  report 1 "code: the wide line should wrap, keep WRAPTAILZQ, and be reported as wrapping"
  printf '%s\n' "$bind_out" | grep -E 'code|fenced|cut' | sed 's/^/      | /'
fi
if has "$bind_out" 'fit at 8\.0625pt'; then
  report 0 "code: the line limit is measured at code_pt, rounded to the quarter pixel"
else
  report 1 "code: the line limit should be measured at 8.0625pt (code_pt 8, rounded)"
fi

# --- EPUB ----------------------------------------------------------------------
epub="${pdf%.pdf}.epub"
leads=$("$py" - "$epub" 2>&1 <<'EOF'
import re, sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
names = sorted(n for n in z.namelist() if re.search(r"chap_\d+\.xhtml$", n))
for n in names:
    m = re.search(r'<p class="lead">(.*?)</p>', z.read(n).decode("utf-8"))
    print(m.group(1).replace("&#183;", "·") if m else "(none)")
gl = "".join(z.read(n).decode("utf-8") for n in z.namelist() if "gloss" in n)
print("glossary:", "ch. 1.1</a>" in gl)
EOF
)
want_leads='Part One
Chapter 1 · Part One
Chapter 1.1 · Part One
Chapter 2 · Part Two
Appendix 1
glossary: True'
if [ "$leads" = "$want_leads" ]; then
  report 0 "EPUB: openers carry the labels, and the glossary links ch. 1.1"
else
  report 1 "EPUB: openers or glossary differ (< expected, > got)"
  diff <(printf '%s\n' "$want_leads") <(printf '%s\n' "$leads") | sed 's/^/      | /'
fi

# --- refusals ------------------------------------------------------------------
# refuse <label> <python edit to book.json> <text the error must carry>
refuse() {
  local dir="$tmp/refuse-$RANDOM" out rc
  cp -R "$here/book" "$dir"
  "$py" - "$dir/book.json" "$2" <<'EOF'
import json, sys
path, edit = sys.argv[1], sys.argv[2]
cfg = json.load(open(path))
exec(edit, {"cfg": cfg})
json.dump(cfg, open(path, "w"))
EOF
  out=$("$py" "$binder" "Labels" "$dir" --out "$dir/out.pdf" --no-index 2>&1); rc=$?
  if [ "$rc" -ne 0 ] && printf '%s\n' "$out" | grep -qF "$3"; then
    report 0 "refuses $1"
  else
    report 1 "should refuse $1 (exit $rc), naming: $3"
    printf '%s\n' "$out" | tail -3 | sed 's/^/      | /'
  fi
}
refuse "labels of the wrong length" 'cfg["labels"] = ["", "1"]' \
  'book.json "labels" has 2 entries for 4 chapters'
refuse "a label that is not a string" 'cfg["labels"] = ["", 1, "1.1", "2"]' \
  'book.json "labels" must be a list of strings'
refuse "a code_pt out of range" 'cfg["code_pt"] = 30' 'book.json "code_pt" takes'
refuse "a code_wrap that is not a boolean" 'cfg["code_wrap"] = "yes"' \
  'book.json "code_wrap" must be true or false'

exit "$fails"
