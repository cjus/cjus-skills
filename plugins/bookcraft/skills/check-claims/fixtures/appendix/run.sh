#!/usr/bin/env bash
#
# Regression test for the claim-check path's appendix concept.
#
# The bug this pins down: `check-provenance.sh --emit-worklist` took a file's
# number from the filename's first digit run, which is the chapter rule. An
# appendix is named `<book-slug>-appendix-N-<slug>.md`, so appendix 1 emitted as
# chapter 1 and collided with the real chapter 1. Three consequences, all of
# them reproduced by the two files in this folder:
#
#   render-report.py refused the whole run with `index.json lists chapter
#   number 1 more than once`, exited 2 and wrote nothing;
#
#   `--chapters 1` silently also emitted appendix 1, which matters because
#   `--chapters` is the flag /updatebook passes after an edit;
#
#   judgement.md gave an appendix no shape for its identifier, so agents
#   invented one.
#
# The fix carries (kind, number) through instead. An appendix is its own kind,
# numbered in its own sequence, exactly as check-book.sh already treats it.
#
# Usage: ./run.sh          (from anywhere; paths are resolved from the script)
# Exits 0 when every half holds, 1 otherwise.

set -uo pipefail
export LC_ALL=C

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
prov="$here/../../../createbook/scripts/check-provenance.sh"
render="$here/../../scripts/render-report.py"

for f in "$prov" "$render"; do
  [ -f "$f" ] || { echo "error: cannot find $f" >&2; exit 2; }
done

fails=0
report() {
  if [ "$1" -eq 0 ]; then echo "ok    $2"; else echo "FAIL  $2"; fails=1; fi
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp" "$here/claim-checks"' EXIT

# ---------------------------------------------------------------------------
# One: the two files emit as different kinds rather than colliding.
# ---------------------------------------------------------------------------
out=$(python3 "$prov" --emit-worklist "$tmp/wl" "$here" 2>&1); rc=$?
[ "$rc" -eq 0 ]; report $? "emit: exits 0 (got $rc)"

ids=$(python3 -c "
import json,sys
d=json.load(open('$tmp/wl/index.json'))
print(' '.join('%s-%s'%(c['kind'],c['number']) for c in d['chapters']))
" 2>&1)
[ "$ids" = "chapter-1 appendix-1" ]
report $? "emit: index lists chapter-1 and appendix-1 (got '$ids')"

# ---------------------------------------------------------------------------
# Two: the report renders, and names the appendix as one.
# ---------------------------------------------------------------------------
cat > "$tmp/wl/findings-claimfix-01-the-only-chapter.json" <<'EOF'
{"kind": "chapter", "number": 1, "file": "claimfix-01-the-only-chapter.md",
 "units_checked": 2,
 "counts": {"supported": 2, "overstated": 0, "misstated": 0, "unsupported": 0, "unclear": 0, "unreadable": 0},
 "findings": [], "notes": []}
EOF
cat > "$tmp/wl/findings-claimfix-appendix-1-the-labels.json" <<'EOF'
{"kind": "appendix", "number": 1, "file": "claimfix-appendix-1-the-labels.md",
 "units_checked": 2,
 "counts": {"supported": 2, "overstated": 0, "misstated": 0, "unsupported": 0, "unclear": 0, "unreadable": 0},
 "findings": [], "notes": []}
EOF

out=$(python3 "$render" "$tmp/wl" "$here" 2>&1); rc=$?
[ "$rc" -eq 0 ]; report $? "render: exits 0 (got $rc)"
! printf '%s\n' "$out" | grep -q "more than once"
report $? "render: does not refuse the run as a duplicate"
printf '%s\n' "$out" | grep -q "1 chapter, 1 appendix"
report $? "render: counts the two kinds separately"

md=$(cat "$here/claim-checks/"*.md 2>/dev/null)
printf '%s\n' "$md" | grep -q "^| appendix 1 |"
report $? "render: the report carries a row reading 'appendix 1'"
printf '%s\n' "$md" | grep -q "^| ch\. 1 |"
report $? "render: the report still carries a row reading 'ch. 1'"

# ---------------------------------------------------------------------------
# Three: --chapters scopes to one kind. This is the flag /updatebook passes,
# so a leak here reads a file the edit never touched.
# ---------------------------------------------------------------------------
scope() {
  rm -rf "$tmp/s"
  python3 "$prov" --emit-worklist "$tmp/s" --chapters "$1" "$here" >/dev/null 2>&1
  python3 -c "
import json
d=json.load(open('$tmp/s/index.json'))
print(' '.join('%s-%s'%(c['kind'],c['number']) for c in d['chapters']))
" 2>&1
}
got=$(scope 1);  [ "$got" = "chapter-1" ];  report $? "--chapters 1: chapter only (got '$got')"
got=$(scope A1); [ "$got" = "appendix-1" ]; report $? "--chapters A1: appendix only (got '$got')"

out=$(python3 "$prov" --chapters B2 "$here" 2>&1); rc=$?
[ "$rc" -eq 2 ]; report $? "--chapters B2: exits 2 (got $rc)"
printf '%s\n' "$out" | grep -q "cannot read 'B2'"
report $? "--chapters B2: refused by name rather than silently dropped"

# isdigit() accepts a superscript that int() then rejects; main no longer wraps
# the parse in a ValueError guard, so this used to traceback and exit 1.
sup=$(printf '\302\262')
out=$(python3 "$prov" --chapters "$sup" "$here" 2>&1); rc=$?
[ "$rc" -eq 2 ]; report $? "--chapters superscript: exits 2, not a traceback (got $rc)"
! printf '%s\n' "$out" | grep -q "Traceback"
report $? "--chapters superscript: no traceback"

# ---------------------------------------------------------------------------
# Four: the old shape is refused by name, and the rest of the run still renders.
# A findings file the spec no longer defines must be reported, not counted.
# ---------------------------------------------------------------------------
rm -rf "$here/claim-checks"
cat > "$tmp/wl/findings-claimfix-appendix-1-the-labels.json" <<'EOF'
{"chapter": 1, "file": "claimfix-appendix-1-the-labels.md",
 "units_checked": 2,
 "counts": {"supported": 2, "overstated": 0, "misstated": 0, "unsupported": 0, "unclear": 0, "unreadable": 0},
 "findings": [], "notes": []}
EOF
out=$(python3 "$render" "$tmp/wl" "$here" 2>&1); rc=$?
[ "$rc" -eq 1 ]; report $? "old shape: exits 1 (got $rc)"
printf '%s\n' "$out" | grep -q "NOT USED.*names kind None and number None"
report $? "old shape: names the file it could not use, and why"
ls "$here/claim-checks/"*.md >/dev/null 2>&1
report $? "old shape: the report is still written for the chapter that was fine"

# ---------------------------------------------------------------------------
# Five: the appendix filename rule is anchored, so a CHAPTER whose slug happens
# to contain "appendix-N-" is still a chapter.
#
# An unanchored pattern reopened the very collision this fixture exists to close:
# guide-07-the-appendix-2-problem.md returned ('appendix', 2). check-book.sh:291
# is the authority on the filename shape and anchors it, so chapter_id must
# agree with it. No book folder can carry that file as a fixture, since
# check-book.sh rejects the name, so the rule is checked at the unit level.
# ---------------------------------------------------------------------------
cp "$prov" "$tmp/probe.py"
cp "$here/../../../createbook/scripts/check-references.sh" "$tmp/check-references.sh"
python3 - "$tmp" <<'PROBE'
import sys, importlib.util, pathlib
spec = importlib.util.spec_from_file_location("probe", pathlib.Path(sys.argv[1]) / "probe.py")
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
cases = {
    # a chapter whose SLUG contains the word, which must stay a chapter
    "guide-07-the-appendix-2-problem.md": ("chapter", 7),
    "book-11-appendix-3-conventions.md": ("chapter", 11),
    # real appendices
    "claimfix-appendix-1-the-labels.md": ("appendix", 1),
    "guide-fixture-appendix-12-late.md": ("appendix", 12),
    # ordinary chapters
    "book-03-normal.md": ("chapter", 3),
}
bad = [f"{n}: got {m.chapter_id(n)}, want {w}"
       for n, w in cases.items() if m.chapter_id(n) != w]
for b in bad:
    print("   ", b, file=sys.stderr)
sys.exit(1 if bad else 0)
PROBE
report $? "appendix filename: anchored, so a chapter's slug cannot make it an appendix"

echo
if [ "$fails" -eq 0 ]; then
  echo "OK    the appendix concept holds"
else
  echo "FAIL  the appendix concept has regressed"
fi
exit "$fails"
