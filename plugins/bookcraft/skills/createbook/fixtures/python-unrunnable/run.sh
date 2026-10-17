#!/usr/bin/env bash
#
# Regression test for check-book.sh's python3 guard, the probe that runs
# python3 before the script reads the book through the plugin's book model.
#
# The bug this pins down came first through jq, which check-book.sh used to read
# book.json with. `command -v jq` succeeded for a jq that was on PATH and could
# not execute, every `jq ... 2>/dev/null` then returned the empty string, and a
# book.json declaring tags, provenance, suggested_reading and glossary read as a
# book that declared nothing. The folder was graded in the weakest mode
# available and the run still ended "OK  structure is sound". Found on an arm64
# Mac carrying a stale x86_64 jq at /usr/local/bin/jq. python3 replaced jq, and
# the same shape of failure is open to it, so the guard moved with it.
#
# Three halves, because no one of them can pass for the right reason alone. The
# book in this folder is valid and fully declared, so:
#
#   with a working python3   the run exits 0 and reports the three modes as required
#   with a broken python3    the run exits non-zero and names the python3 it found
#   with no python3 at all   the run exits non-zero and says python3 is missing
#
# Without the first half, a checker that rejected every book would pass the
# other two. Without the second, the guard could be deleted and nothing would
# say so. Without the third, a CI runner with no python3 could grade every
# folder in some weaker mode while still reporting success; there is no such
# mode any more, and the third half is what keeps one from coming back.
#
# Usage: ./run.sh          (from anywhere; paths are resolved from the script)
# Exits 0 when all three halves hold, 1 otherwise.

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

# A working python3, for the first half. The one on PATH is not assumed to be
# it: this fixture exists because the one on PATH may be exactly the broken case.
working_py=""
for cand in $(command -v -a python3 2>/dev/null) /usr/bin/python3 /opt/homebrew/bin/python3 /usr/local/bin/python3; do
  [ -x "$cand" ] || continue
  if "$cand" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)' >/dev/null 2>&1; then
    working_py="$cand"; break
  fi
done

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# ---------------------------------------------------------------------------
# Half one: a working python3 reads the declarations, so the book is held to them.
# ---------------------------------------------------------------------------
if [ -z "$working_py" ]; then
  echo "skip  no working python3 found; the declared-mode half cannot run"
  echo "      (install Python 3.9 or newer, or put a working one on PATH, to check it)"
else
  mkdir -p "$tmp/good"
  ln -sf "$working_py" "$tmp/good/python3"
  out=$(PATH="$tmp/good:$PATH" bash "$checker" "$here" 2>&1); rc=$?
  [ "$rc" -eq 0 ]; report $? "working python3: exits 0 (got $rc)"
  printf '%s\n' "$out" | grep -q "provenance: required"; report $? "working python3: provenance mode is required"
  printf '%s\n' "$out" | grep -q "suggested reading: required"; report $? "working python3: suggested-reading mode is required"
  printf '%s\n' "$out" | grep -q "(required)"; report $? "working python3: tag mode is required"
  ! printf '%s\n' "$out" | grep -q "(inferred)"; report $? "working python3: tag mode did not fall back to inferred"
  if [ "$rc" -ne 0 ]; then printf '%s\n' "$out" | sed 's/^/      | /'; fi
fi

# ---------------------------------------------------------------------------
# Half two: a python3 that is present and will not run must stop the run.
#
# The stub exits 126, which is what a shell returns for a binary it found and
# could not execute, the code the stale jq returned on an arm64 Mac. It is
# executable, so `command -v python3` finds it exactly as a real one is found,
# which is the whole shape of the bug.
# ---------------------------------------------------------------------------
mkdir -p "$tmp/broken"
cat > "$tmp/broken/python3" <<'STUB'
#!/bin/sh
echo "$0: Bad CPU type in executable" >&2
exit 126
STUB
chmod +x "$tmp/broken/python3"

out=$(PATH="$tmp/broken:$PATH" bash "$checker" "$here" 2>&1); rc=$?
[ "$rc" -ne 0 ]; report $? "broken python3: exits non-zero (got $rc)"
printf '%s\n' "$out" | grep -q "will not run"; report $? "broken python3: says the python3 it found will not run"
! printf '%s\n' "$out" | grep -q "structure is sound"; report $? "broken python3: does not report the structure sound"
! printf '%s\n' "$out" | grep -q "(inferred)"; report $? "broken python3: does not fall back to inferred mode"
if [ "$rc" -eq 0 ]; then printf '%s\n' "$out" | sed 's/^/      | /'; fi

# ---------------------------------------------------------------------------
# Half three: no python3 at all stops the run too.
#
# check-book.sh once had a supported fallback for a machine without jq, which
# graded in the weakest mode and said so. Reading the book through the model
# retired it, so an absent python3 is now a stop, and this half proves it is not
# quietly a fallback again.
#
# Hiding python3 means a PATH with no python3 on it, and pruning whole
# directories will not do: on a stock Linux python3 sits in /usr/bin beside awk,
# sed and grep. So this builds a symlink farm of everything on PATH except
# python3, preserving precedence.
# ---------------------------------------------------------------------------
# One ln per directory rather than one per file: a $(basename) subshell per
# entry costs about thirty seconds across a populated PATH, which is too slow to
# run on every commit. Links from earlier directories win, because ln refuses to
# clobber, so PATH precedence survives. Then python3 goes, wherever it came from.
mkdir -p "$tmp/nopy"
saved_ifs=$IFS
IFS=:
for d in $PATH; do
  [ -d "$d" ] || continue
  ln -s "$d"/* "$tmp/nopy/" 2>/dev/null
done
IFS=$saved_ifs
rm -f "$tmp/nopy/python3"

if PATH="$tmp/nopy" command -v python3 >/dev/null 2>&1; then
  echo "skip  could not build a python3-free PATH; the absent-python3 half cannot run"
else
  out=$(PATH="$tmp/nopy" bash "$checker" "$here" 2>&1); rc=$?
  [ "$rc" -eq 2 ]; report $? "absent python3: exits 2 (got $rc)"
  printf '%s\n' "$out" | grep -q "python3 is not on PATH"; report $? "absent python3: says python3 is missing"
  ! printf '%s\n' "$out" | grep -q "structure is sound"; report $? "absent python3: does not report the structure sound"
  ! printf '%s\n' "$out" | grep -q "will not run"; report $? "absent python3: does not confuse absent with unrunnable"
  if [ "$rc" -ne 2 ]; then printf '%s\n' "$out" | sed 's/^/      | /'; fi
fi

echo
if [ "$fails" -eq 0 ]; then echo "OK    the python3 guard holds"; else echo "FAIL  the python3 guard has regressed"; fi
exit "$fails"
