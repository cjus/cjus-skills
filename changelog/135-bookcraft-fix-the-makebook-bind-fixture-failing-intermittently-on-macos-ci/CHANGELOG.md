# bookcraft: fix the makebook/bind fixture failing intermittently on macOS CI

Start date: 2026-11-19 06:41:00 MST

Make the `makebook/bind` fixture pass reliably on macOS CI by finding why the bound PDF's
pagination varies between runs.

## Changes

- 2026-11-19: The macOS flake was never a pagination change. Chromium 159 (Playwright 1.65.2,
  picked up through the unpinned `playwright>=1.44`) writes the guide slide's "fi" into the text
  layer as two letters or as U+FB01 at random, so the binder's clean-render check saw a changed
  page 6, kept the probed PDF, and page 2 opened on `ZQTOCSTARTQZ`. `flat()` in build-book.py now
  compares NFKC text, as `bare()` already did for index terms. Fixing the comparison rather than
  pinning Chromium, because the same false fallback ships markers in users' books too. Proven on
  PR #136: `fixtures (macos-latest)` passed attempts 1 to 5 on Chromium 159. bookcraft bumped to
  1.20.1 at the review gate, so installs pick the fix up.
