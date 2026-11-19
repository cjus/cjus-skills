# bookcraft: fix the makebook/bind fixture failing intermittently on macOS CI

Start date: 2026-11-19 06:41:00 MST

## Overview

Make the `makebook/bind` fixture pass reliably in the `fixtures (macos-latest)` CI job. That
means finding why the bound PDF's pagination varies between runs (the cover overflowing onto
a second page, and links on the Contents, Figures and Index pages pointing at the wrong page),
then fixing the cause, or making the fixture robust to the variation if it turns out harmless.

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred`, never as new scope.

## About Ticket

Issue #135: bookcraft: fix the makebook/bind fixture failing intermittently on macOS CI

The `makebook/bind` fixture fails intermittently in the `fixtures (macos-latest)` CI job.
Ubuntu passes on the same commits, and a re-run of the failed job on unchanged code has passed
every time.

The failures come in two forms:

- **The declared book.** "page 2 opens on 'ZQTOCSTARTQZ', not Contents: the cover spilled onto
  a second page". The Contents, Figures and Index link check then fails too.
- **parts and stray H1s.** "a link on the Contents, Figures and Index pages opens a page other
  than the one it prints".

Every `fixtures` run passed on its first attempt through 2026-11-02. Since 2026-11-19 several
have needed a re-run: feature-branch commits 3be8dca, 73289d4, 771bb5e and dfd5b59, and main
commits 057b2a2 and 87feaff. The first commit with the problem also added a stray-file warning
to `build-book.py` and `strays()` to `book_model.py`. Neither change touches layout, and its own
branch run (af5bbab) passed on the first attempt. Nothing yet shows whether the cause is in this
repo or in the macOS runner.

## Plan

- [x] Compare the macOS runner image and renderer versions between a passing run and a failing one
  - Every Nov 19 macOS job, pass or fail, ran Playwright 1.65.2 / Chromium 159.0.8154.6; the last
    all-green runs (Nov 2) ran 1.64.1 / Chromium 156. Runner image and pdftotext versions do not
    track pass/fail: image 20261102.0473 and poppler 26.10 and 26.11 all appear on both sides.
- [x] Find what makes the cover overflow its page, or the page links point at the wrong page, on some runs and not others
  - Neither happens. Both failure forms are the binder's markers fallback: the clean render's
    text did not match the probed render's, so the probed PDF shipped, and its page 2 opens on
    the white `ZQTOCSTARTQZ` probe instead of "Contents". The mismatch is one character on page 6:
    Chromium 159 writes the slide's "profiles" as `fi` or as the ligature U+FB01 at random.
    Reproduced locally on Chromium 159: 6 of 40 binds; Chromium 151 fixture: 20 of 20 pass.
- [x] Make the bind deterministic, or make the fixture's page assertions robust to the variation if it turns out to be harmless
  - `flat()` in build-book.py now compares NFKC-normalized text. On Chromium 159 locally: 40 of 40
    binds keep no markers (was 34 of 40), 15 of 15 bind fixture runs pass; full suite 27/27 --strict.
- [ ] Prove it: several consecutive first-attempt passes of `fixtures (macos-latest)` on the branch

## Open Questions

- ~~Does the failure reproduce locally on macOS under repeated runs, or only on the hosted runner?~~
  Resolved: it reproduces locally once the venv runs Chromium 159; this Mac's install.sh venv
  is on Chromium 151, which never fails.

## Deferred

- The fixture blames "the cover spilled onto a second page" for any page 2 that does not open on
  Contents, including a page opening on a leftover probe; its message could say which.
