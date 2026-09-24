#!/usr/bin/env bash
#
# Lettered paragraph tags, through every checker that reads a tag
# (reference/chapter-prose.md § Paragraph tags). A revision adds a paragraph
# after [1-2] as [1-2a], so nothing renumbers and no citation moves; a chapter
# rewrite is what renumbers them away. Each checker had its own tag pattern,
# and a lettered tag one of them did not match would read as prose, as an
# unknown source, or as a citation of nothing, so each one is asserted here:
#
#   check-book.sh        the folder passes and reports its lettered tags; three
#                        broken sequences each fail with the right message
#   check-references.sh  citations of [1-2a] and [A1-1a] resolve; [1-2c] fails
#   check-provenance.sh  marks citing [1-2a] and [A1-1a] resolve; [1-2z] fails
#
# Usage: ./run.sh          (from anywhere; paths are resolved from the script)
# Exits 0 when every assertion holds, 1 otherwise.

set -uo pipefail
export LC_ALL=C

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
scripts="$here/../../scripts"

fails=0
report() {
  if [ "$1" -eq 0 ]; then echo "ok    $2"; else echo "FAIL  $2"; fails=1; fi
}
# expect <label> <exit> <output> <want-exit> <string>...
expect() {
  label=$1; rc=$2; out=$3; want=$4; shift 4
  bad=""
  [ "$rc" -eq "$want" ] || bad="exit $rc, wanted $want"
  for s in "$@"; do
    printf '%s\n' "$out" | grep -qF -- "$s" || bad="$bad; missing: $s"
  done
  if [ -z "$bad" ]; then report 0 "$label"; else
    report 1 "$label: $bad"; printf '%s\n' "$out" | sed 's/^/      | /'
  fi
}

if ! command -v jq >/dev/null 2>&1 || ! printf '{}' | jq -e . >/dev/null 2>&1; then
  echo "skip  no working jq, so the guide profile cannot be read"
  exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
ch="lettered-fixture-01-a-revised-chapter.md"

out=$("$scripts/check-book.sh" "$here" 2>&1); rc=$?
expect "check-book: a valid lettered sequence passes and is reported" "$rc" "$out" 0 \
  "carries added paragraphs [1-2a], [1-2b]" "carries added paragraphs [A1-1a]" "structure is sound"

mutate() {  # mutate <name> <sed expression>
  rm -rf "$tmp/$1"; cp -R "$here" "$tmp/$1"; rm -f "$tmp/$1/run.sh"
  sed -i.bak "$2" "$tmp/$1/$ch" && rm -f "$tmp/$1/$ch.bak"
}

mutate skip 's/^\[1-2b\] /[1-2c] /'
out=$("$scripts/check-book.sh" "$tmp/skip" 2>&1); rc=$?
expect "check-book: a skipped letter fails" "$rc" "$out" 1 \
  "is tagged [1-2c]; a paragraph added after [1-2a] is [1-2b]"

mutate gap 's/^\[1-3\] /[1-4] /'
out=$("$scripts/check-book.sh" "$tmp/gap" 2>&1); rc=$?
expect "check-book: a plain tag counts on from the last plain one" "$rc" "$out" 1 \
  "is tagged [1-4]; the paragraph number must count 1, 2, 3 through the chapter, so this one is [1-3]"

mutate first 's/^\[1-1\] /[1-1a] /'
out=$("$scripts/check-book.sh" "$tmp/first" 2>&1); rc=$?
expect "check-book: nothing letters the first paragraph" "$rc" "$out" 1 \
  "is tagged [1-1a]; a lettered tag follows the paragraph it was added after, and nothing comes before the first"

printf 'Cites [1-2a], [A1-1a] and [1-2c].\n' >"$tmp/refs.md"
out=$("$scripts/check-references.sh" --no-baseline "$here" "$tmp/refs.md" 2>&1); rc=$?
expect "check-references: lettered and appendix citations resolve, a missing one fails" "$rc" "$out" 1 \
  "cites [1-2c]; chapter 1 ends at paragraph 3" "tag citations: 3    unresolved: 1"

out=$("$scripts/check-provenance.sh" "$here" 2>&1); rc=$?
expect "check-provenance: marks citing lettered tags resolve" "$rc" "$out" 0

mutate badmark 's/<!-- src: \[1-2a\] -->/<!-- src: [1-2z] -->/'
out=$("$scripts/check-provenance.sh" "$tmp/badmark" 2>&1); rc=$?
expect "check-provenance: a mark citing an undefined lettered tag fails" "$rc" "$out" 1 \
  "the mark cites [1-2z], which the book does not define"

exit "$fails"
