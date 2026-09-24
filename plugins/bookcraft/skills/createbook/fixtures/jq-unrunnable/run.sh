#!/usr/bin/env bash
#
# Regression test for check-book.sh's jq guard, the `jq -e` probe above its
# book.json block.
#
# The bug this pins down: `command -v jq` succeeds for a jq that is on PATH and
# cannot execute, every `jq ... 2>/dev/null` below it then returns the empty
# string, and a book.json declaring tags, provenance, suggested_reading and
# glossary reads as a book that declared nothing. The folder is graded in the
# weakest mode available and the run still ends "OK  structure is sound". Found
# on an arm64 Mac carrying a stale x86_64 jq at /usr/local/bin/jq.
#
# Three halves, because no one of them can pass for the right reason alone. The
# book in this folder is valid and fully declared, so:
#
#   with a working jq   the run exits 0 and reports the three modes as required
#   with a broken jq    the run exits non-zero and names the jq it found
#   with no jq at all   the run exits 0, grades in the weakest mode, and says so
#
# Without the first half, a checker that rejected every book would pass the
# second. Without the second, the guard could be deleted and nothing would say
# so.
#
# Usage: ./run.sh          (from anywhere; paths are resolved from the script)
# Exits 0 when both halves hold, 1 otherwise.

set -uo pipefail
export LC_ALL=C

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
checker="$here/../../scripts/check-book.sh"

if [ ! -x "$checker" ] && [ ! -f "$checker" ]; then
  echo "error: cannot find check-book.sh at $checker" >&2
  exit 2
fi

fails=0
report() {
  if [ "$1" -eq 0 ]; then echo "ok    $2"; else echo "FAIL  $2"; fails=1; fi
}

# A working jq, for the first half. The one on PATH is not assumed to be it:
# this fixture exists because the one on PATH may be exactly the broken case.
working_jq=""
for cand in $(command -v -a jq 2>/dev/null) /usr/bin/jq /opt/homebrew/bin/jq /usr/local/bin/jq; do
  [ -x "$cand" ] || continue
  if printf '{}' | "$cand" -e . >/dev/null 2>&1; then working_jq="$cand"; break; fi
done

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# ---------------------------------------------------------------------------
# Half one: a working jq reads the declarations, so the book is held to them.
# ---------------------------------------------------------------------------
if [ -z "$working_jq" ]; then
  echo "skip  no working jq found; the declared-mode half cannot run"
  echo "      (install jq, or put a working one on PATH, to check it)"
else
  mkdir -p "$tmp/good"
  ln -sf "$working_jq" "$tmp/good/jq"
  out=$(PATH="$tmp/good:$PATH" bash "$checker" "$here" 2>&1); rc=$?
  [ "$rc" -eq 0 ]; report $? "working jq: exits 0 (got $rc)"
  printf '%s\n' "$out" | grep -q "provenance: required"; report $? "working jq: provenance mode is required"
  printf '%s\n' "$out" | grep -q "suggested reading: required"; report $? "working jq: suggested-reading mode is required"
  printf '%s\n' "$out" | grep -q "(required)"; report $? "working jq: tag mode is required"
  ! printf '%s\n' "$out" | grep -q "(inferred)"; report $? "working jq: tag mode did not fall back to inferred"
  if [ "$rc" -ne 0 ]; then printf '%s\n' "$out" | sed 's/^/      | /'; fi
fi

# ---------------------------------------------------------------------------
# Half two: a jq that is present and will not run must stop the run.
#
# The stub exits 126, which is what a shell returns for a binary it found and
# could not execute -- the same code /usr/local/bin/jq returns on an arm64 Mac.
# It is executable, so `command -v jq` finds it exactly as the real one was
# found, which is the whole shape of the bug.
# ---------------------------------------------------------------------------
mkdir -p "$tmp/broken"
cat > "$tmp/broken/jq" <<'STUB'
#!/bin/sh
echo "$0: Bad CPU type in executable" >&2
exit 126
STUB
chmod +x "$tmp/broken/jq"

out=$(PATH="$tmp/broken:$PATH" bash "$checker" "$here" 2>&1); rc=$?
[ "$rc" -ne 0 ]; report $? "broken jq: exits non-zero (got $rc)"
printf '%s\n' "$out" | grep -q "will not run"; report $? "broken jq: says the jq it found will not run"
! printf '%s\n' "$out" | grep -q "structure is sound"; report $? "broken jq: does not report the structure sound"
! printf '%s\n' "$out" | grep -q "(inferred)"; report $? "broken jq: does not fall back to inferred mode"
if [ "$rc" -eq 0 ]; then printf '%s\n' "$out" | sed 's/^/      | /'; fi

# ---------------------------------------------------------------------------
# Half three: no jq at all is a SUPPORTED configuration, and a different one.
#
# The guard above is about a jq that is present and will not run. Absent jq is
# the documented fallback: no declaration in book.json is read, the book is
# graded in the weakest mode, and check-book.sh says so rather than implying it.
# Nothing tested that path, which matters because it is the one a CI runner
# without jq would silently take -- every folder here would still exit 0 while
# proving nothing the declared mode covers.
#
# Hiding jq means a PATH with no jq on it, and pruning whole directories will
# not do: on a stock Linux jq sits in /usr/bin beside awk, sed and grep. So this
# builds a symlink farm of everything on PATH except jq, preserving precedence.
# ---------------------------------------------------------------------------
# One ln per directory rather than one per file: a $(basename) subshell per
# entry costs about thirty seconds across a populated PATH, which is too slow to
# run on every commit. Links from earlier directories win, because ln refuses to
# clobber, so PATH precedence survives. Then jq goes, wherever it came from.
mkdir -p "$tmp/nojq"
saved_ifs=$IFS
IFS=:
for d in $PATH; do
  [ -d "$d" ] || continue
  ln -s "$d"/* "$tmp/nojq/" 2>/dev/null
done
IFS=$saved_ifs
rm -f "$tmp/nojq/jq"

if PATH="$tmp/nojq" command -v jq >/dev/null 2>&1; then
  echo "skip  could not build a jq-free PATH; the absent-jq half cannot run"
else
  out=$(PATH="$tmp/nojq" bash "$checker" "$here" 2>&1); rc=$?
  [ "$rc" -eq 0 ]; report $? "absent jq: exits 0, since the book is valid in any mode (got $rc)"
  printf '%s\n' "$out" | grep -q "book.json is present and jq is not"; report $? "absent jq: says no declaration was read"
  printf '%s\n' "$out" | grep -q "(inferred)"; report $? "absent jq: tag mode fell back to inferred"
  ! printf '%s\n' "$out" | grep -q "will not run"; report $? "absent jq: does not confuse absent with unrunnable"
  if [ "$rc" -ne 0 ]; then printf '%s\n' "$out" | sed 's/^/      | /'; fi
fi

echo
if [ "$fails" -eq 0 ]; then echo "OK    the jq guard holds"; else echo "FAIL  the jq guard has regressed"; fi
exit "$fails"
