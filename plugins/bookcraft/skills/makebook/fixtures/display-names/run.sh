#!/usr/bin/env bash
#
# build-book.py's display-name swap (swap_display_names), tested without a bind.
#
# The swap is a pure function of text, so this lifts it and its two patterns
# out of build-book.py by source position and runs it under plain python3.
# Importing the binder would pull in Playwright. bind/ binds a whole book, but
# only where the binder's toolchain is installed, and asserts on the covers and
# contents; this pins every case of the swap exactly, and runs everywhere.
#
# What it pins down:
#   - a key in the Draws-on or Fills-in row becomes its display name, whether it
#     is bare, in a code span, or in a code span with a locator after it
#   - only a key that looks like a repo path is swapped; a key like "syllabus"
#     already reads as a name, and swapping it for "the syllabus" printed
#     "the the syllabus" in 34 header rows of two real guide books
#   - an article already in front of a key is kept, and never doubled
#   - every other row, and the prose, is left exactly as written. An earlier
#     version touched every table row and printed "Check your the syllabus" in
#     the reader's copy.
#
# Usage: ./run.sh          (from anywhere; paths are resolved from the script)
# Exits 0 when every assertion holds, 1 otherwise.

set -uo pipefail
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
binder="$here/../../scripts/build-book.py"

python3 - "$binder" <<'PYEOF'
import re, sys

src = open(sys.argv[1], encoding="utf-8").read()
start = src.index("CODE_SPAN_RE = re.compile(")
end = src.index("def load_chapters(")
ns = {"re": re}
exec(src[start:end], ns)
swap, displays_of = ns["swap_display_names"], ns["source_displays"]

cfg = {"sources": {
    "syllabus": {"path": "s.pdf", "display": "the syllabus"},
    "CLAUDE.md § Teaching Calendar": {"path": "../CLAUDE.md", "display": "the course calendar"},
    "docs/build.md": {"path": "docs/build.md", "display": "the build docs"},
    "notes/policy.md": "notes/policy.md",
}}
d = displays_of(cfg)

cases = [
    ("the Draws-on row: a code span, and a code span with a locator",
     "| **Draws on** | `CLAUDE.md § Teaching Calendar`; `docs/build.md § Caching` |",
     "| **Draws on** | the course calendar; the build docs § Caching |"),
    ("an article already in front of the key is kept, never doubled",
     "| **Draws on** | The `docs/build.md` § Caching; the docs/build.md intro |",
     "| **Draws on** | The build docs § Caching; the build docs intro |"),
    ("the Fills-in row is swapped too",
     "| **Fills in** | What docs/build.md leaves out. |",
     "| **Fills in** | What the build docs leaves out. |"),
    ("a key that already reads as a name is never swapped",
     "| **Draws on** | The syllabus § 4; the syllabus p. 5 |",
     "| **Draws on** | The syllabus § 4; the syllabus p. 5 |"),
    ("a path key with no display name prints as written",
     "| **Draws on** | `notes/policy.md` § Late work |",
     "| **Draws on** | `notes/policy.md` § Late work |"),
    ("the Act-on-this row is the author's, and is left alone",
     "| **Act on this** | Read docs/build.md before week one. |",
     "| **Act on this** | Read docs/build.md before week one. |"),
    ("the This-chapter row is left alone",
     "| **This chapter** | How docs/build.md sets the cache. |",
     "| **This chapter** | How docs/build.md sets the cache. |"),
    ("prose is left alone",
     "The build is set in docs/build.md, and CLAUDE.md § Teaching Calendar agrees.",
     "The build is set in docs/build.md, and CLAUDE.md § Teaching Calendar agrees."),
]
fails = 0
for label, given, want in cases:
    got = swap(given, d)
    if got == want:
        print(f"ok    {label}")
    else:
        fails = 1
        print(f"FAIL  {label}\n      got:  {got}\n      want: {want}")
if set(d) != {"CLAUDE.md § Teaching Calendar", "docs/build.md"}:
    fails = 1
    print(f"FAIL  source_displays read {sorted(d)}; only path-like keys with a display name belong")
else:
    print("ok    source_displays reads only path-like keys with a display name")
sys.exit(fails)
PYEOF
