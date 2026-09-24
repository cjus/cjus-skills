#!/usr/bin/env bash
#
# The paragraph stop is a failure under the guide profile and a report under
# narration (check-book.sh, para_max). One folder cannot hold both answers,
# because the profile is a book-level declaration, so this runs the chapter
# twice:
#
#   as the folder stands, profile guide   exits 1, and FAILs naming [1-2]
#   a copy with no profile, so narration  exits 0, and REPORTs naming [1-2]
#
# Without the first half, a checker that had stopped counting paragraphs would
# pass. Without the second, a checker that failed the stop under both profiles
# would fail every narration book written before the check existed, and nothing
# here would say so.
#
# Usage: ./run.sh          (from anywhere; paths are resolved from the script)
# Exits 0 when both halves hold, 1 otherwise.

set -uo pipefail
export LC_ALL=C

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
checker="$here/../../scripts/check-book.sh"

fails=0
report() {
  if [ "$1" -eq 0 ]; then echo "ok    $2"; else echo "FAIL  $2"; fails=1; fi
}

# The profile is read from book.json through jq. With no working jq both
# halves would run under narration, and the first would fail for the wrong
# reason, so the fixture declines to grade rather than guess.
if ! command -v jq >/dev/null 2>&1 || ! printf '{}' | jq -e . >/dev/null 2>&1; then
  echo "skip  no working jq, so the profile cannot be read and neither half can run"
  exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

out=$("$checker" "$here" 2>&1); rc=$?
if [ "$rc" -eq 1 ] && printf '%s\n' "$out" | grep -qF 'FAIL  stop-fixture-01-a-paragraph-past-the-stop.md: [1-2] runs'; then
  report 0 "guide: the paragraph past the stop fails the book, by its tag"
else
  report 1 "guide: expected exit 1 and a FAIL naming [1-2]; got exit $rc"
  printf '%s\n' "$out" | sed 's/^/      | /'
fi

mkdir -p "$tmp/narration"
cp "$here"/*.md "$tmp/narration/"
grep -v '"profile"' "$here/book.json" >"$tmp/narration/book.json"
out=$("$checker" "$tmp/narration" 2>&1); rc=$?
if [ "$rc" -eq 0 ] \
  && printf '%s\n' "$out" | grep -qF 'REPORT  stop-fixture-01-a-paragraph-past-the-stop.md: [1-2] runs' \
  && printf '%s\n' "$out" | grep -qF 'profile: narration'; then
  report 0 "narration: the same paragraph is reported and the book passes"
else
  report 1 "narration: expected exit 0 and a REPORT naming [1-2]; got exit $rc"
  printf '%s\n' "$out" | sed 's/^/      | /'
fi

exit "$fails"
