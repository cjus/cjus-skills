#!/usr/bin/env bash
#
# Run every bookcraft fixture folder and assert what it is supposed to report.
#
# The gap this closes: the fixture folders are the only verification the book
# checkers have, and nothing ran them but a person remembering to. Three defects
# in one earlier ticket were caught only by hand-running them, and two of those
# three would have been caught here immediately.
#
#   ./test-fixtures.sh                 # grade the tree this script sits in
#   ./test-fixtures.sh <plugin path>   # grade an installed copy
#   ./test-fixtures.sh --strict        # a skip is a failure (implied by $CI)
#
# Point it at an INSTALLED copy to catch packaging defects, for the reason
# pr's acceptance suite says the same thing: it already caught a hook shipped
# without its executable bit. Both checkers are invoked through their shebangs
# here rather than through a named interpreter, so a lost executable bit fails
# loudly. That matters more than it looks: check-provenance.sh and
# check-references.sh are Python despite the .sh extension, and running one with
# `bash` produces pages of parse garbage and exit 2 rather than a clean error.
#
# EXPECTED EXIT CODES ARE NOT ENOUGH ON THEIR OWN, and that is the lesson of the
# folder this runner was written for. fixtures/provenance/ exited 1 for a year
# for a structural reason unrelated to provenance, and an exit-code-only
# assertion would have passed it the whole time while reporting nothing about
# what the fixture exists to check. So every non-zero expectation below also
# names a string the output must carry, and a passing one asserts the checker
# printed its summary rather than dying before it.
#
# Every fixture folder must be covered by a manifest row or carry its own
# run.sh. A folder that is covered by neither fails the run, so adding a fixture
# and forgetting to assert anything about it cannot go quiet.
set -uo pipefail
export LC_ALL=C

STRICT=0
ROOT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --strict) STRICT=1 ;;
    -h|--help) sed -n '3,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "error: unknown option $1" >&2; exit 2 ;;
    *)  ROOT="$1" ;;
  esac
  shift
done
[ -n "${CI:-}" ] && STRICT=1

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
[ -n "$ROOT" ] || ROOT="$here/.."
ROOT=$(cd "$ROOT" 2>/dev/null && pwd) || { echo "error: no such directory: $ROOT" >&2; exit 2; }

CHECK_BOOK="$ROOT/skills/createbook/scripts/check-book.sh"
CHECK_PROV="$ROOT/skills/createbook/scripts/check-provenance.sh"

PASS=0; FAIL=0; SKIP=0
pass() { PASS=$((PASS+1)); printf 'ok    %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf 'FAIL  %s\n' "$1"; }
skip() { SKIP=$((SKIP+1)); printf 'skip  %s\n' "$1"; }

# ---------------------------------------------------------------------------
# The checkers have to be there, and have to be executable.
# ---------------------------------------------------------------------------
for c in "$CHECK_BOOK" "$CHECK_PROV"; do
  if [ ! -f "$c" ]; then
    echo "error: cannot find $c" >&2
    echo "       pass the plugin root as the first argument." >&2
    exit 2
  fi
  if [ ! -x "$c" ]; then
    fail "$(basename "$c") is not executable; it ships through its shebang"
  fi
done

# ---------------------------------------------------------------------------
# jq has to work, because the expectations below assume book.json was read.
#
# Absent jq is a supported configuration for check-book.sh -- it falls back to
# inference and says so -- but it is a DIFFERENT configuration, with different
# right answers. fixtures/guide/ passes only because its profile declaration is
# read; with no jq the declaration is invisible, the narration rules apply, and
# the folder correctly fails. Grading this manifest without jq would therefore
# report failures that are not defects. The absent-jq path has its own coverage,
# in fixtures/jq-unrunnable/run.sh.
# ---------------------------------------------------------------------------
JQ_OK=0
if command -v jq >/dev/null 2>&1 && printf '{}' | jq -e . >/dev/null 2>&1; then
  JQ_OK=1
fi

# ---------------------------------------------------------------------------
# folder | checker | expected exit | strings the output must carry (~ separated)
# ---------------------------------------------------------------------------
MANIFEST=$(cat <<'ROWS'
createbook/fence|check-book|0|structure is sound
createbook/guide|check-book|0|structure is sound
createbook/guide-under-narration|check-book|1|body carries an H3 or deeper~body carries a block quote~filename does not match
createbook/jq-unrunnable|check-book|0|structure is sound~provenance: required
createbook/overview|check-book|0|structure is sound
createbook/overview-nothing-carried|check-book|0|structure is sound
createbook/provenance|check-book|0|structure is sound
createbook/provenance|check-provenance|1|6 failure(s)
ROWS
)

if [ "$JQ_OK" -eq 0 ]; then
  skip "no working jq, so the manifest cannot be graded (see the note above)"
else
  while IFS='|' read -r rel checker want must; do
    [ -n "$rel" ] || continue
    skill=${rel%%/*}
    name=${rel#*/}
    folder="$ROOT/skills/$skill/fixtures/$name"
    case "$checker" in
      check-book)       cmd="$CHECK_BOOK" ;;
      check-provenance) cmd="$CHECK_PROV" ;;
      *) fail "$rel: manifest names an unknown checker: $checker"; continue ;;
    esac
    if [ ! -d "$folder" ]; then
      fail "$rel: the manifest names a fixture folder that does not exist"
      continue
    fi
    out=$("$cmd" "$folder" 2>&1 </dev/null); rc=$?
    label="$rel under $checker"
    if [ "$rc" -ne "$want" ]; then
      fail "$label: expected exit $want, got $rc"
      printf '%s\n' "$out" | sed 's/^/      | /'
      continue
    fi
    missing=""
    saved=$IFS; IFS='~'
    for s in $must; do
      printf '%s\n' "$out" | grep -qF -- "$s" || missing="$missing
      missing from the output: $s"
    done
    IFS=$saved
    if [ -n "$missing" ]; then
      fail "$label: exit $rc is right and the output is not$missing"
      continue
    fi
    pass "$label: exit $rc, and the output says so"
  done <<EOF
$MANIFEST
EOF
fi

# ---------------------------------------------------------------------------
# Every fixture folder carrying its own run.sh runs it. Those are the cases an
# exit code cannot express: a guard that has to be probed with a broken tool, a
# mode that has to be run against a mutated copy to show it is still switched on.
# ---------------------------------------------------------------------------
for f in "$ROOT"/skills/*/fixtures/*/run.sh; do
  [ -f "$f" ] || continue
  name=$(basename "$(dirname "$f")")
  skill=$(basename "$(dirname "$(dirname "$(dirname "$f")")")")
  if [ ! -x "$f" ]; then
    fail "$skill/$name/run.sh is not executable"
    continue
  fi
  out=$("$f" 2>&1 </dev/null); rc=$?
  if [ "$rc" -ne 0 ]; then
    fail "$skill/$name/run.sh exits $rc"
    printf '%s\n' "$out" | sed 's/^/      | /'
    continue
  fi
  n_skipped=$(printf '%s\n' "$out" | grep -c '^skip ' || true)
  if [ "$n_skipped" -gt 0 ] && [ "$STRICT" -eq 1 ]; then
    fail "$skill/$name/run.sh exits 0 but skipped $n_skipped check(s), which --strict forbids"
    printf '%s\n' "$out" | grep '^skip ' | sed 's/^/      | /'
    continue
  fi
  if [ "$n_skipped" -gt 0 ]; then
    skip "$skill/$name/run.sh passed with $n_skipped check(s) skipped"
    continue
  fi
  pass "$skill/$name/run.sh"
done

# ---------------------------------------------------------------------------
# Nothing may be uncovered. A fixture folder asserted by neither a manifest row
# nor a run.sh is a folder whose regressions are invisible, which is the whole
# condition this runner exists to end.
# ---------------------------------------------------------------------------
for d in "$ROOT"/skills/*/fixtures/*/; do
  [ -d "$d" ] || continue
  name=$(basename "$d")
  skill=$(basename "$(dirname "$(dirname "$d")")")
  [ -f "$d/run.sh" ] && continue
  printf '%s\n' "$MANIFEST" | grep -q "^$skill/$name|" && continue
  fail "$skill/fixtures/$name/ is asserted by nothing: no manifest row and no run.sh"
done

echo
printf 'passed %s   failed %s   skipped %s\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ] || exit 1
[ "$SKIP" -eq 0 ] || [ "$STRICT" -eq 0 ] || exit 1
exit 0
