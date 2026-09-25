#!/usr/bin/env bash
#
# Regression test for check-provenance.sh --ledger-only.
#
# The gap this pins down: the three checks in check-provenance.sh run at step 7,
# over finished chapters. Nothing resolved the source ledger that step 2 builds,
# so every error in it reached every chapter agent at once, and was found only
# because the drafting agents open their sources and noticed. This mode resolves
# the ledger at step 3 instead, before the operator gate and before any agent
# exists.
#
# Two halves, because either alone can pass for the wrong reason. The ledger in
# this folder carries one row of each shape the check can reach, so:
#
#   the ledger here       exits 1 and names the heading, the item and the path
#   the same ledger clean exits 0
#
# Without the second half a checker that rejected every ledger would pass the
# first. Without the first, the mode could be deleted and nothing would say so.
#
# Usage: ./run.sh          (from anywhere; paths are resolved from the script)
# Exits 0 when both halves hold, 1 otherwise.

set -uo pipefail
export LC_ALL=C

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
checker="$here/../../scripts/check-provenance.sh"

if [ ! -f "$checker" ]; then
  echo "error: cannot find check-provenance.sh at $checker" >&2
  exit 2
fi

fails=0
report() {
  if [ "$1" -eq 0 ]; then echo "ok    $2"; else echo "FAIL  $2"; fails=1; fi
}

# ---------------------------------------------------------------------------
# Half one: the ledger here carries three faults and one unasserted locator.
# ---------------------------------------------------------------------------
out=$(python3 "$checker" --ledger-only "$here" 2>&1); rc=$?

[ "$rc" -eq 1 ]; report $? "dirty ledger: exits 1 (got $rc)"
printf '%s\n' "$out" | grep -q "carries no heading matching .* Nothing Like This"
report $? "dirty ledger: names the heading the source does not carry"
printf '%s\n' "$out" | grep -q "defines no item Q9"
report $? "dirty ledger: names the item the source does not define"
printf '%s\n' "$out" | grep -q "names a path that does not exist"
report $? "dirty ledger: names the file that is not on disk"
printf '%s\n' "$out" | grep -q "^3 failure(s) in the ledger"
report $? "dirty ledger: counts exactly 3 failures"
printf '%s\n' "$out" | grep -q "^REVIEW.*p\. 6"
report $? "dirty ledger: reviews the page locator aimed at a markdown source"
printf '%s\n' "$out" | grep -q "7 row(s); 5 re-openable source(s) opened; 5 locator(s)"
report $? "dirty ledger: census reads 7 rows, 5 opened, 5 locators"
# The rows that are correct must not be reported. A mode that flagged every row
# would satisfy every check above.
! printf '%s\n' "$out" | grep -q "What The Grain Is"
report $? "dirty ledger: says nothing about the two rows that resolve"
if [ "$rc" -ne 1 ]; then printf '%s\n' "$out" | sed 's/^/      | /'; fi

# ---------------------------------------------------------------------------
# Half two: the same ledger with the three faulty rows removed must pass.
# ---------------------------------------------------------------------------
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/sources"
cp "$here/sources/handbook.md" "$tmp/sources/handbook.md"
grep -v 'Nothing Like This\|Q9\|missing\.md\|p\. 6' "$here/OUTLINE.md" > "$tmp/OUTLINE.md"

out=$(python3 "$checker" --ledger-only "$tmp" 2>&1); rc=$?
[ "$rc" -eq 0 ]; report $? "clean ledger: exits 0 (got $rc)"
printf '%s\n' "$out" | grep -q "^OK    every re-openable ledger row names a file on disk"
report $? "clean ledger: reports the all-clear"
! printf '%s\n' "$out" | grep -q "^FAIL"
report $? "clean ledger: reports no failure"
if [ "$rc" -ne 0 ]; then printf '%s\n' "$out" | sed 's/^/      | /'; fi

# ---------------------------------------------------------------------------
# Half three: a folder with no OUTLINE.md is a usage error, not an all-clear.
# ---------------------------------------------------------------------------
empty=$(mktemp -d)
out=$(python3 "$checker" --ledger-only "$empty" 2>&1); rc=$?
rm -rf "$empty"
[ "$rc" -eq 2 ]; report $? "no OUTLINE.md: exits 2 (got $rc)"
printf '%s\n' "$out" | grep -q "no .*OUTLINE.md"
report $? "no OUTLINE.md: says which file is missing"

# ---------------------------------------------------------------------------
# Half four: a section citation ends where the prose resumes, and a citation
# that opens a sentence is still asserted rather than merely counted.
#
# Both are regressions found by review. CITE_SECTION used to run to the end of
# the cell through an em dash, so a correct heading failed as a missing one.
# CITE_PAGE and CITE_SLIDE carry re.I while PAGES and SLIDES are anchored
# lowercase, so "Slides 4-9" was extracted, counted, and matched by neither.
# ---------------------------------------------------------------------------
mkdir -p "$tmp/prose/sources"
cp "$here/sources/handbook.md" "$tmp/prose/sources/handbook.md"
cat > "$tmp/prose/OUTLINE.md" <<'EOF'
# Prose ledger

| Source | Re-openable | What the book owes it | Paid by |
|---|---|---|---|
| `sources/handbook.md` § What The Grain Is — the definition the book opens on | Yes | The grain | 1 |
| `sources/handbook.md` § Indexes: When To Skip One | Yes | A heading carrying a colon | 2 |
EOF
out=$(python3 "$checker" --ledger-only "$tmp/prose" 2>&1); rc=$?
! printf '%s
' "$out" | grep -q "carries no heading matching"
report $? "section citation: trailing prose after an em dash is not read as the heading"
[ "$rc" -eq 0 ]; report $? "section citation: the row passes (got $rc)"
if [ "$rc" -ne 0 ]; then printf '%s
' "$out" | sed 's/^/      | /'; fi

# The case fold is checked at the unit level: asserting it end to end would mean
# committing a PDF or a .pptx, which fixtures/provenance already declines to do.
cp "$checker" "$tmp/probe.py"
cp "$here/../../scripts/check-references.sh" "$tmp/check-references.sh"
cp "$here/../../scripts/assertions.sh" "$tmp/assertions.sh"
python3 - "$tmp" <<'PROBE'
import sys, importlib.util, pathlib
spec = importlib.util.spec_from_file_location("probe", pathlib.Path(sys.argv[1]) / "probe.py")
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
bad = []
for s in ("Slides 4-9", "PP. 3-5", "P. 12"):
    n = m._lower_lead(s)
    if not (m.SLIDES.match(n) or m.PAGES.match(n)):
        bad.append(s)
# a heading keeps its own casing
if m._lower_lead("§ What The Grain Is") != "§ What The Grain Is":
    bad.append("heading case was folded")
sys.exit(1 if bad else 0)
PROBE
report $? "case fold: a capitalised locator reaches its resolver, a heading keeps its case"

echo
if [ "$fails" -eq 0 ]; then
  echo "OK    --ledger-only holds"
else
  echo "FAIL  --ledger-only has regressed"
fi
exit "$fails"
