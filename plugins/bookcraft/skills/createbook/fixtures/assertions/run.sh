#!/usr/bin/env bash
#
# assertions.json, through the helper that writes it and the checker that reads
# it (createbook/SKILL.md § The assertions file):
#
#   assertions.sh        the committed file is rebuilt from the helper's own
#                        commands and must come back byte-identical, so the
#                        format and its fixed layout cannot drift unnoticed;
#                        check passes it and fails every file in malformed/
#                        with the reason named; a refused write leaves the
#                        file untouched; a newer format stops with exit 2
#   check-provenance.sh  marks citing entries that hold resolve; an uncited
#                        expected entry is reported and an uncited legacy one
#                        is not; the superseded premise is swept out of the
#                        chapter and out of a figure, and the run still passes;
#                        a mark citing a superseded or retired entry fails; a
#                        book with no file says so and fails a mark citing one;
#                        a source named with the reserved word fails
#   check-book.sh        the folder passes, so `assertion <id>` is a mark it
#                        accepts
#
# Usage: ./run.sh            (from anywhere; paths are resolved from the script)
#        ./run.sh --rebuild  rewrite the committed assertions.json from build(),
#                            after a deliberate change to the format
# Exits 0 when every assertion holds, 1 otherwise.

set -uo pipefail
export LC_ALL=C

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
scripts="$here/../../scripts"
A="$scripts/assertions.sh"

fails=0
report() {
  if [ "$1" -eq 0 ]; then echo "ok    $2"; else echo "FAIL  $2"; fails=1; fi
}
# expect <label> <exit> <output> <want-exit> <string>...   a leading ! means must NOT carry
expect() {
  label=$1; rc=$2; out=$3; want=$4; shift 4
  bad=""
  [ "$rc" -eq "$want" ] || bad="exit $rc, wanted $want"
  for s in "$@"; do
    case "$s" in
      '!'*) printf '%s\n' "$out" | grep -qF -- "${s#!}" && bad="$bad; must not carry: ${s#!}" ;;
      *)    printf '%s\n' "$out" | grep -qF -- "$s" || bad="$bad; missing: $s" ;;
    esac
  done
  if [ -z "$bad" ]; then report 0 "$label"; else
    report 1 "$label: $bad"; printf '%s\n' "$out" | sed 's/^/      | /'
  fi
}

# The committed file, as the helper writes it. Every date is fixed, so the
# output is the same on every run and every machine.
build() {
  d=$1
  "$A" init "$d" --how backfill --from OUTLINE.md --from "provenance marks" \
    --from "git log" --candidates 10 --confirmed 9 \
    --reader "An instructor preparing one evening session." \
    --reader-origin argument --profile-origin unrecorded --date 2026-09-25 &&
  "$A" brief "$d" --argument="A fixture book for assertions.json" &&
  "$A" add "$d" --kind premise --statement "Every session plan assumes a class of twenty." \
    --by book --how "no source states enrollment" --date 2026-09-20 \
    --reaches "every session plan" --search "room of twenty" --search "twenty seats" \
    --applies-to prose --citation legacy &&
  "$A" supersede "$d" 1 --statement "The roster is eleven students." --by operator \
    --how "read from a portal behind sign-in" --date 2026-09-22 \
    --search "roster of eleven" --citation legacy &&
  "$A" add "$d" --kind ruling --statement "Where the handbook and another source disagree, the handbook wins." \
    --by operator --date 2026-09-21 --applies-to book &&
  "$A" add "$d" --kind given --statement "Nothing cites this legacy entry, and nothing should report it." \
    --by operator --date 2026-09-21 --applies-to prose --citation legacy &&
  "$A" add "$d" --kind given --statement "Nothing cites this expected entry, so the uncited report names it." \
    --by operator --date 2026-09-23 --applies-to prose &&
  "$A" add "$d" --kind measured --statement "SQLite has no EXPLAIN ANALYZE." --by measurement \
    --date 2026-09-20 --ran "EXPLAIN ANALYZE SELECT 1;" --on "sqlite3 3.54.0" \
    --result 'Parse error near "SELECT"' --applies-to prose &&
  "$A" add "$d" --kind settled --statement "The answer key to the handbook's questions, derived by the book and checked." \
    --by book --how "the handbook marks no correct answer" --date 2026-09-20 \
    --answer "Question 3" B --answer "Question 4" C --applies-to prose --citation legacy &&
  "$A" correct "$d" 7 --item "question 3" --answer D --date 2026-09-22 &&
  "$A" add "$d" --kind ruling --statement "No compensation figures appear in the book." \
    --by operator --date 2026-09-21 --applies-to book &&
  "$A" retire "$d" 8 --reason "the operator lifted the exclusion" &&
  "$A" add "$d" --kind adopted --statement "The review session is held in week six." \
    --by book --acted-on "booked by the operator" --date 2026-09-22 \
    --applies-to prose --citation legacy &&
  "$A" expect "$d" 2 7
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

if [ "${1:-}" = "--rebuild" ]; then
  mkdir "$tmp/b" && build "$tmp/b" >/dev/null && cp "$tmp/b/assertions.json" "$here/assertions.json" &&
    echo "rewrote $here/assertions.json" && exit 0
  echo "FAIL  build() did not complete; nothing was rewritten"; exit 1
fi

# ---------------------------------------------------------------------------
# The helper
# ---------------------------------------------------------------------------
mkdir "$tmp/b"
out=$(build "$tmp/b" 2>&1); rc=$?
expect "assertions.sh: every command in build() succeeds" "$rc" "$out" 0 "added 9 (adopted)"
if cmp -s "$tmp/b/assertions.json" "$here/assertions.json"; then
  report 0 "assertions.sh: the rebuilt file is byte-identical to the committed one"
else
  report 1 "assertions.sh: the rebuilt file differs from the committed one"
  diff "$here/assertions.json" "$tmp/b/assertions.json" | sed 's/^/      | /'
fi

out=$("$A" check "$here" 2>&1); rc=$?
expect "assertions.sh check: the committed file passes" "$rc" "$out" 0 \
  "passes: format 1, 9 entries (7 hold, 1 superseded, 1 retired), next ID 10"

out=$("$A" list "$here" 2>&1); rc=$?
expect "assertions.sh list: a table, with the supersession and the correction shown" "$rc" "$out" 0 \
  "| # | Kind | Statement |" "superseded by 2" "holds; supersedes 1" \
  "Question 3 = D (corrected 2026-09-22, was B)" "retired: the operator lifted the exclusion"

# file | a string check must print for it
while IFS='|' read -r f want; do
  [ -n "$f" ] || continue
  mkdir -p "$tmp/m/$f" && cp "$here/malformed/$f" "$tmp/m/$f/assertions.json"
  out=$("$A" check "$tmp/m/$f" 2>&1); rc=$?
  expect "assertions.sh check fails malformed/$f" "$rc" "$out" 1 "$want"
done <<'CASES'
bad-json.json|the file is not valid JSON
unknown-kind.json|kind is "rule"
reused-id.json|the ID is used twice
one-sided-supersession.json|superseded_by 2, but entry 2 supersedes nothing
unknown-key.json|unknown key "superseeded_by" (did you mean "superseded_by"?)
empty-entries-no-created.json|the file has no "created" block. With no entries
citation-on-book-entry.json|citation is for a prose entry
repeated-answer-item.json|appears twice in its answers
repeated-json-key.json|appears twice in one object
deleted-entry.json|no entry carries ID 9
CASES
for f in "$here"/malformed/*.json; do
  grep -q "^$(basename "$f")|" "$0" || report 1 "malformed/$(basename "$f") is asserted by nothing in run.sh"
done

cp -R "$here" "$tmp/w" && rm -f "$tmp/w/run.sh"
out=$("$A" add "$tmp/w" --kind premise --statement "No search phrases." --by book \
  --reaches "nothing" --applies-to prose 2>&1); rc=$?
expect "assertions.sh add: a premise with no --search is refused" "$rc" "$out" 1 "a premise needs search"
cmp -s "$tmp/w/assertions.json" "$here/assertions.json"
report $? "assertions.sh add: the refused write left the file byte-identical"

python3 - "$tmp/w/assertions.json" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p)); d["format"] = 2; json.dump(d, open(p, "w"))
PY
out=$("$A" check "$tmp/w" 2>&1); rc=$?
expect "assertions.sh check: a newer format stops with exit 2" "$rc" "$out" 2 "Update bookcraft"
out=$("$scripts/check-provenance.sh" "$tmp/w" 2>&1); rc=$?
expect "check-provenance: a newer format stops with exit 2" "$rc" "$out" 2 "Update bookcraft"

# ---------------------------------------------------------------------------
# check-provenance.sh
# ---------------------------------------------------------------------------
out=$("$scripts/check-provenance.sh" "$here" 2>&1); rc=$?
expect "check-provenance: the folder passes, with the three REVIEW lines it should carry" "$rc" "$out" 0 \
  "sources declared 1   components 6   fill 1   in-book 0   assertion 4" \
  "assertions 9 entries, 7 hold   cited 4   uncited 1   superseded premises swept 1, passages found 2" \
  "REVIEW assertion 5 holds and rests in the prose, and no mark in the book cites it" \
  'assertions-fixture-01-entries-that-hold.md:16: "room of twenty" matches assertion 1, a premise superseded by 2' \
  'diagrams/seating.svg:2: "Twenty seats" matches assertion 1, a premise superseded by 2' \
  "OK*   nothing failed, and 3 REVIEW item(s)" \
  "!assertion 4 holds" "!assertion 9 holds" "!FAIL"

ch="assertions-fixture-01-entries-that-hold.md"
mutate() {  # mutate <name> <a unit to append to the chapter>
  rm -rf "$tmp/$1"; cp -R "$here" "$tmp/$1"; rm -f "$tmp/$1/run.sh"
  printf '\n%s\n' "$2" >> "$tmp/$1/$ch"
}
mutate superseded "$(printf 'A paragraph still citing the old premise.\n<!-- src: assertion 1 -->')"
out=$("$scripts/check-provenance.sh" "$tmp/superseded" 2>&1); rc=$?
expect "check-provenance: a mark citing a superseded entry fails" "$rc" "$out" 1 \
  "the mark cites assertion 1, which is superseded by 2" "1 failure(s)"

mutate retired "$(printf 'A paragraph citing a lifted exclusion.\n<!-- src: assertion 8 -->')"
out=$("$scripts/check-provenance.sh" "$tmp/retired" 2>&1); rc=$?
expect "check-provenance: a mark citing a retired entry fails" "$rc" "$out" 1 \
  "the mark cites assertion 8, which is retired" "1 failure(s)"

mutate unreadable "$(printf 'Two entries in one component.\n<!-- src: assertions 2 and 3 -->')"
out=$("$scripts/check-provenance.sh" "$tmp/unreadable" 2>&1); rc=$?
expect "check-provenance: a component that only starts like a citation fails by name" "$rc" "$out" 1 \
  'starts with "assertion" and does not read as one'

rm -rf "$tmp/nofile"; cp -R "$here" "$tmp/nofile"; rm -f "$tmp/nofile/run.sh" "$tmp/nofile/assertions.json"
out=$("$scripts/check-provenance.sh" "$tmp/nofile" 2>&1); rc=$?
expect "check-provenance: with no file, the summary says so and a citation fails" "$rc" "$out" 1 \
  "assertions NOT CHECKED: this book has no assertions.json" \
  "the mark cites assertion 2, and the book has no assertions.json"

rm -rf "$tmp/reserved"; cp -R "$here" "$tmp/reserved"; rm -f "$tmp/reserved/run.sh"
python3 - "$tmp/reserved/book.json" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p)); d["sources"]["assertions log"] = "sources/handbook.md"; json.dump(d, open(p, "w"))
PY
out=$("$scripts/check-provenance.sh" "$tmp/reserved" 2>&1); rc=$?
expect "check-provenance: a source named with the reserved word fails" "$rc" "$out" 1 \
  'declares a source named "assertions log"'

# The worklist is a second output with a different consumer: /check-claims
# gives each agent one chapter file and nothing else, so the entries have to
# travel inside it.
out=$("$scripts/check-provenance.sh" --emit-worklist "$tmp/wl" "$here" 2>&1); rc=$?
if [ "$rc" -eq 0 ]; then
  python3 - "$tmp/wl/assertions-fixture-01-entries-that-hold.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
assert [e["id"] for e in d["settled"]] == [7], d["settled"]
assert d["settled"][0]["answers"][0]["was"] == "B", d["settled"]
cited = {e["id"] for u in d["units"] for e in u["entries"]}
assert cited == {3}, cited  # the one unit resting on a source as well; the rest are not emitted
PY
  report $? "check-provenance --emit-worklist: a unit carries its entries, the chapter file the settled one"
else
  report 1 "check-provenance --emit-worklist exits $rc"; printf '%s\n' "$out" | sed 's/^/      | /'
fi

# A premise that changes twice: "now" is the end of the chain, not the next link.
rm -rf "$tmp/chain"; cp -R "$here" "$tmp/chain"; rm -f "$tmp/chain/run.sh"
"$A" supersede "$tmp/chain" 2 --statement "The roster is twelve students." --by operator \
  --date 2026-09-24 --search "roster of twelve" --citation legacy >/dev/null
out=$("$scripts/check-provenance.sh" "$tmp/chain" 2>&1); rc=$?
expect "check-provenance: a premise changed twice names the end of the chain" "$rc" "$out" 1 \
  "the mark cites assertion 2, which is superseded by 10" \
  "now: assertion 10: The roster is twelve students." \
  '"room of twenty" matches assertion 1, a premise superseded by 2' \
  "!now: assertion 2:"

# A book whose marks are not read is still swept: the backfill fires on any
# book with a book.json, and the oldest books are the likeliest to need one.
rm -rf "$tmp/nomarks"; cp -R "$here" "$tmp/nomarks"; rm -f "$tmp/nomarks/run.sh"
python3 - "$tmp/nomarks/book.json" <<'PY'
import json, sys
p = sys.argv[1]; d = json.load(open(p)); d["provenance"] = False; json.dump(d, open(p, "w"))
PY
out=$("$scripts/check-provenance.sh" "$tmp/nomarks" 2>&1); rc=$?
expect "check-provenance: with no marks read, the file is still checked and the premise swept" "$rc" "$out" 0 \
  "superseded premises swept 1, passages found 2   (no marks were read" \
  '"Twenty seats" matches assertion 1' "OK*   nothing failed, and 2 REVIEW item(s)"

# A figure spelling a space as an entity is still swept.
rm -rf "$tmp/entity"; cp -R "$here" "$tmp/entity"; rm -f "$tmp/entity/run.sh"
printf '<svg xmlns="http://www.w3.org/2000/svg"><text>a room of&#32;twenty</text></svg>\n' \
  > "$tmp/entity/diagrams/entity.svg"
out=$("$scripts/check-provenance.sh" "$tmp/entity" 2>&1); rc=$?
expect "check-provenance: an XML entity in a figure is decoded before the sweep" "$rc" "$out" 0 \
  'diagrams/entity.svg:1: "room of twenty" matches assertion 1'

# init --how createbook marks a file as written before any prose, so it refuses
# a folder that already holds a book; that folder is backfilled instead.
rm -rf "$tmp/old"; cp -R "$here" "$tmp/old"; rm -f "$tmp/old/run.sh" "$tmp/old/assertions.json"
out=$("$A" init "$tmp/old" --how createbook --argument=x --reader r \
  --reader-origin argument --profile-origin argument 2>&1); rc=$?
expect "assertions.sh init: --how createbook refuses a folder that already holds a book" "$rc" "$out" 1 \
  "already holds markdown"

# A write keeps the file's mode rather than leaving it owner-only. 0640 is what
# neither mkstemp's 0600 nor a umask default of 0644 would produce by accident.
chmod 640 "$tmp/chain/assertions.json"
"$A" expect "$tmp/chain" 4 >/dev/null
mode=$(python3 -c 'import os, stat, sys; print(oct(stat.S_IMODE(os.stat(sys.argv[1]).st_mode)))' "$tmp/chain/assertions.json")
[ "$mode" = "0o640" ]
report $? "assertions.sh: a write keeps the file's mode (got $mode)"

# ---------------------------------------------------------------------------
# check-book.sh reads book.json through jq, so without a working one this half
# would grade the folder in a different mode (scripts/test-fixtures.sh says why).
# ---------------------------------------------------------------------------
if command -v jq >/dev/null 2>&1 && printf '{}' | jq -e . >/dev/null 2>&1; then
  out=$("$scripts/check-book.sh" "$here" 2>&1); rc=$?
  expect "check-book: the folder passes, so an assertion mark is a mark it accepts" "$rc" "$out" 0 \
    "structure is sound"
else
  echo "skip  no working jq, so check-book.sh cannot read this folder's book.json"
fi

exit $fails
