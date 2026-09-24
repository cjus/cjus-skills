# Bind a fixture book in CI so makebook changes get a signal

Start date: 2026-09-24 13:00:27 MDT

Ticket: #32 (status:todo -> status:in-progress)

## Overview

Nothing automated runs the binder. The fixtures workflow and `test-fixtures.sh` exercise
`check-book.sh` and `check-provenance.sh`, and since #33 a makebook fixture lifts
`swap_display_names` out of `build-book.py` and tests it as a pure function, but no run ever binds
a book. CI installs Python and jq and not the Chromium and poppler the binder needs, so a
`build-book.py` regression merges with a passing fixtures check. #19 and #20 are already queued
against the binder.

This branch installs the binder's toolchain in the fixtures workflow and binds one fixture book,
`createbook/fixtures/guide`, into a temp dir on every run. It then asserts on what the bind
produced: both formats are written, the cover does not spill onto page 2, and the PDF and the
EPUB carry the same bind stamp. It also decides whether the Linux leg of that bind blocks.

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred`, never as new scope.

## Plan

- [x] Phase 1: Install the binder's toolchain in `.github/workflows/fixtures.yml`: the packages
      in `makebook/requirements.txt`, Chromium for Playwright, and poppler for `pdftotext`, on
      both legs. Prefer `plugins/bookcraft/scripts/install.sh` over a hand-rolled install if it
      runs on a runner, since that also exercises the install path users take. Assert that
      `pdftotext` and the Playwright Chromium actually run, in the same way the workflow
      asserts jq runs rather than that it exists.
      *Done 2026-09-24, verified locally on the macOS leg; the Linux leg is unproven until
      the first CI run.*
- [ ] Phase 2: Add a bind fixture that binds `createbook/fixtures/guide` into a temp dir and
      cleans up after itself. It must be covered by a manifest row or its own `run.sh`, or
      `test-fixtures.sh` fails the run as uncovered.
- [ ] Phase 3: Assert on the bind's output, each with a failure message that names what broke:
      - the PDF and the EPUB are both written
      - page 2 of the PDF is Contents, so the cover did not spill
      - PDF page 1 and `EPUB/cover.xhtml` carry the same `Created:` stamp
- [ ] Phase 4: Decide whether the Linux leg of the bind is blocking, and record the reason in the
      workflow's header comment beside the existing macOS/Linux rationale.
- [ ] Phase 5: Update the comments this change makes false: the `display-names/run.sh` header
      ("CI installs Python and jq and not the Chromium the binder drives") and the
      `fixtures.yml` header. Confirm a local `test-fixtures.sh` run without Chromium still
      behaves as documented, and that a CI run is green with the bind in it.

## About Ticket

**#32 Bind a fixture book in CI so makebook changes get a signal**
(`status:todo`, `priority:high`, `infra`)

Nothing automated runs the binder. `plugins/bookcraft/scripts/test-fixtures.sh` and
`.github/workflows/fixtures.yml` exercise `check-book.sh` and `check-provenance.sh`, but never
invoke `plugins/bookcraft/skills/makebook/scripts/build-book.py`.

- **Symptom:** a `build-book.py` regression merges with a passing fixtures check.
- **Occasion:** the next `build-book.py` change. #19 and #20 are already queued against it.

### Checklist

- [ ] Install Chromium (playwright) and poppler in the fixtures workflow
- [ ] Bind one fixture (`createbook/fixtures/guide`) into a temp dir
- [ ] Assert the PDF and EPUB are written
- [ ] Assert page 2 of the PDF is Contents (no cover spill)
- [ ] Assert PDF page 1 and `EPUB/cover.xhtml` carry the same `Created:` stamp
- [ ] Decide whether the Linux leg is blocking

Raised by the pre-test review on #27 (PR #31).

### Triage note (2026-09-24, against `main` @ `75f1a0b`)

Still valid. `fixtures.yml` installs no Chromium or poppler, and nothing in CI binds a book.
"Never invokes `build-book.py`" is no longer literally true: `makebook/fixtures/display-names/run.sh`,
added in #33, lifts `swap_display_names` out of `build-book.py` and runs it under
`test-fixtures.sh`. It still does no bind, but a makebook fixture folder and runner already exist
to extend.

## Open Questions

- **Where does the bind run?** A `run.sh` under `makebook/fixtures/` puts it inside
  `test-fixtures.sh`, so a local run without Chromium prints `skip` and `--strict` (implied by
  `$CI`) turns that skip into a failure. A separate workflow step keeps `test-fixtures.sh` fast
  and dependency-free locally, but leaves the bind outside the suite's coverage rule.
- **Is the Linux leg blocking?** The bind is the first thing CI runs that depends on a browser and
  on font rendering, which are the likeliest places for Linux to differ. The existing rule makes
  macOS blocking because it is the only platform the plugins are developed on.
- **Cache the Playwright Chromium between runs?** A cold download on every run adds minutes. A
  cache keyed on the Playwright version would save them, at the cost of one more thing in the
  workflow to keep true.
  *Measured locally:* a cold `install.sh` took 28s, most of it a 94 MiB Chromium download; a
  warm re-run took 2s. The first CI run gives the runner's number.
- ~~**Does `install.sh` work unattended on a runner?**~~ *Resolved in Phase 1:* it never
  prompts and never calls `brew`, and ran clean from a cold venv. It leaves poppler and, on
  Linux, Chromium's system libraries to the caller, so the workflow installs both.
