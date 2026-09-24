# Bind a fixture book in CI so makebook changes get a signal

Start date: 2026-09-24 13:00:27 MDT

Nothing automated runs the binder, so a `build-book.py` regression merges with a passing fixtures
check. This branch installs the binder's toolchain in the fixtures workflow and binds one fixture
book on every run, asserting on what the bind produces.

## Changes

### 2026-09-24 — Phase 1: the binder's toolchain in CI

The fixtures workflow now runs the same `install.sh` a person runs, rather than a hand-rolled pip
install, so every run exercises the venv path, `requirements.txt` and Playwright's Chromium. It
installs poppler beside it, since the binder reads its own PDF back through `pdftotext` and a venv
cannot supply that. On Linux it also runs `playwright install-deps chromium`: `install.sh` leaves
system libraries to the caller, and the runner has passwordless sudo.

**The assertion is a bind in miniature.** Chromium prints a page to PDF through `bookcraft-python`,
and `pdftotext` has to read the page's text back. Checked locally against five broken setups (no
Chromium, no venv, a `pdftotext` that exits 126, one that reads nothing, none on PATH); each fails
with its own message. A first draft of the step was a bash syntax error: a brace group opened on
a heredoc's line and closed on the next, where the heredoc body had already begun.

`install.sh` and `bookcraft-python` joined the executable-bit check, since CI now runs both through
their shebangs.
