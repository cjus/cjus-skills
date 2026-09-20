#!/usr/bin/env bash
#
# One-time setup for bookcraft's only skill that needs third-party packages:
# makebook, whose build-book.py renders the PDF through headless Chromium.
#
# The venv is deliberately NOT placed inside the plugin. Claude Code installs a
# plugin to a version-scoped directory (.../cache/<marketplace>/<plugin>/<version>),
# so ${CLAUDE_PLUGIN_ROOT} moves on every release and a venv living under it
# would be silently discarded on each update, costing a fresh ~150 MB install
# plus a Chromium download. It goes to a stable per-user path instead, and one
# venv serves every plugin version and every project.
#
# Re-running is safe: an existing venv is reused and its packages upgraded.
#
# Usage: install.sh
set -euo pipefail

VENV="${XDG_CACHE_HOME:-$HOME/.cache}/bookcraft/venv"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REQUIREMENTS="$HERE/../skills/makebook/requirements.txt"

if [[ ! -f "$REQUIREMENTS" ]]; then
  echo "install.sh: cannot find $REQUIREMENTS" >&2
  echo "Run this script from where it ships, inside the bookcraft plugin." >&2
  exit 1
fi

command -v python3 >/dev/null 2>&1 || {
  echo "install.sh: python3 is not on PATH" >&2
  exit 1
}

# build-book.py uses nested same-quote f-strings (PEP 701, Python 3.12), so an
# older interpreter fails at PARSE time. That matters here rather than later:
# the error is a SyntaxError pointing at a line deep in the script, with nothing
# to suggest the interpreter is the problem, and a venv built on 3.9 would
# install every package successfully and still never run. Measured 2026-09-14:
# macOS's own /usr/bin/python3 (3.9.6) cannot parse the file; 3.14.2 parses it.
PYVER="$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')"
if ! python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 12) else 1)'; then
  echo "install.sh: python3 is $PYVER, but makebook needs 3.12 or newer." >&2
  echo >&2
  echo "The python3 on your PATH is $(command -v python3)." >&2
  echo "macOS ships 3.9 at /usr/bin/python3, which cannot parse build-book.py." >&2
  echo "Install a newer one (brew install python@3.12) and put it ahead on PATH," >&2
  echo "then re-run this script." >&2
  exit 1
fi
echo "==> python3 $PYVER at $(command -v python3)"

echo "==> venv at $VENV"
mkdir -p "$(dirname "$VENV")"
python3 -m venv "$VENV"

echo "==> installing packages from $REQUIREMENTS"
"$VENV/bin/pip" install --upgrade pip
"$VENV/bin/pip" install -r "$REQUIREMENTS"

# Playwright ships the browser separately from the package. It caches to
# ~/Library/Caches/ms-playwright (macOS) or ~/.cache/ms-playwright (Linux), and
# skips the download when that cache is already populated.
echo "==> installing Chromium for Playwright"
"$VENV/bin/python" -m playwright install chromium

echo
echo "Done. makebook is ready."
echo

# Two host tools makebook uses that a venv cannot supply. Neither is fatal here,
# because the failure they cause is specific and better reported than guessed at.
if ! command -v pdftotext >/dev/null 2>&1; then
  echo "NOTE: pdftotext (poppler) is not on PATH. build-book.py reads the"
  echo "      rendered PDF back to resolve page numbers and will fail without"
  echo "      it. Install with: brew install poppler"
fi
if ! command -v epubcheck >/dev/null 2>&1; then
  echo "NOTE: epubcheck is not on PATH. It is optional, and only needed to"
  echo "      verify a built EPUB rather than trust it: brew install epubcheck"
fi
