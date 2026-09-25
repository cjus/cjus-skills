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
#                                   spill, and the EPUB's cover art is a PNG
#                                   rasterised from the PDF's cover page
#   with a declared cover_image     PDF page 1 and EPUB/cover.xhtml carry the
#                                   same Created: stamp, in bind_stamp's form
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

# --- with a declared cover_image ---------------------------------------------
# Checked, because a failed edit would bind with no cover_image and report a
# missing stamp, blaming the binder for a fault in the fixture.
if ! edit_out=$("$py" - "$tmp/book/book.json" 2>&1 <<'EOF'
import json, sys
cfg = json.load(open(sys.argv[1], encoding="utf-8"))
cfg["cover_image"] = "diagrams/the-two-profiles.svg"
json.dump(cfg, open(sys.argv[1], "w", encoding="utf-8"), indent=2)
EOF
); then
  report 1 "cover_image: could not add cover_image to the copy's book.json"
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
