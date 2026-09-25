# Bind a fixture book in CI so makebook changes get a signal

Start date: 2026-09-24 13:00:27 MDT

Nothing automated ran the binder, so a `build-book.py` regression merged with a passing fixtures
check. This branch installs the binder's toolchain in the fixtures workflow and binds fixture books
on every suite run, asserting on what the binder writes.

## Changes

### 2026-09-24 — Phase 1: the binder's toolchain in CI

The workflow runs the same `install.sh` a person runs, installs poppler beside it, and on Linux
runs `playwright install-deps chromium`. **The assertion is a bind in miniature**: Chromium prints a
page through `bookcraft-python` and `pdftotext` reads it back; five broken setups each fail with
their own message. A first draft was a bash syntax error (a brace group closed inside a heredoc's
body). `install.sh` and `bookcraft-python` joined the executable-bit check.

### 2026-09-25 — Phases 2, 3 and 5: the bind fixture

**A `run.sh` inside the suite, per the operator**: it skips without the venv or `pdftotext`, which
`--strict` and CI fail, and fails on a toolchain present but broken. **It binds a copy**, since the
binder writes temp HTML into its source folder. Four mutated binders each fail their assertion.
Open PR #39 was found to collide with the stamp check. The comments and docs that said the suite
cannot bind were corrected.

### 2026-09-25 — Two binds, so the stamp check survives PR #39

**Per the operator, the guide binds twice**: as declared for the formats, page 2 and a real PNG as
cover art (the binder swallows a rasterising failure), and with a `cover_image` for the stamps,
since #39 keeps `cover.xhtml` only behind declared art. Passes against #39's binder at `c55a002`.

### 2026-09-25 — Phase 6: #37's two regression fixtures, after #39 merges

#37 folded two fixtures into #32 by comment: the look-alike appendix slug (#35) and the
appendix-table repair (#20). Both reproduce on `main`'s binder and not on #39's. **The operator
added them as Phase 6**, to land after #39 merges.

### 2026-09-25 — CI green with the bind, and Linux stays advisory

Run 36134364045 on `fafa000`: 16 of 16 on both legs. **Linux stays advisory, per the operator**,
since the bind's checks lean on font metrics; the reason is in the `fixtures.yml` header.

### 2026-09-25 — Phase 6: #37's regression books

Synced `main` @ `5a4d741` (#39) by merge commit. **`bind/` gained `appendix-slug/` and
`appendix-table/`**, from #37's reproductions; both pass on the merged binder and fail on the
pre-#39 one. About 9s for four binds.

### 2026-09-25 — The table check holds on Linux

A throwaway branch with the pre-#39 binder (run 36137670848, deleted) failed both new checks on
both legs, the column 51pt short on macOS and 43pt on Linux, so **the table check tests the repair
on Linux too**. **No Chromium cache, per the operator**: a cold install costs 16 to 19s in CI.

### 2026-09-25 — Pre-test review fixes

The pre-test review (APPROVE) found the table check trusting the binder's own warning, which goes
quiet with the repair if the broken-word detector goes blind. **The check now reads the long words
back off the appendix's page**; a blind-detector mutant fails it, and so does the pre-#39 binder on
both CI legs (run 36141024240). The `book.json` edit is guarded, the EPUB read keeps its traceback,
and three doc phrasings were corrected.

### 2026-09-25 — Close

The close review returned APPROVE (`pr-review-2026-09-25-close.md`). Its one Important finding, a
stray closing keyword naming #37 in the PR summary, and three summary phrasings were fixed before
the summary became the PR body.
