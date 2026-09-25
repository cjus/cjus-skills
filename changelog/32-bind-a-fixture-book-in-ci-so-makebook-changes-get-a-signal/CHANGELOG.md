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

### 2026-09-25 — Phases 2, 3 and 5: the bind fixture

**The bind runs inside the suite, per the operator,** as `makebook/fixtures/bind/run.sh`, so a
contributor with the toolchain catches a binder break before pushing. It costs about 3s. Without
`install.sh`'s venv or `pdftotext` it prints `skip`, which `--strict` and CI fail; a toolchain that
is present but broken fails the bind.

**It binds a copy of `createbook/fixtures/guide`,** because the binder writes its render HTML into
the source folder and deletes it after, and an interrupted bind would leave a dotfile in a tracked
fixture. Four mutated binders (a cover spilling to page 2, an EPUB stamp that differs, a stamp in
the wrong form, no EPUB written) each fail on the assertion meant for them.

**Open PR #39 collides with the stamp assertion.** With no `cover_image` it stops building
`EPUB/cover.xhtml`, the file the assertion reads, so the check needs a decision before either
branch merges second.

The headers of `fixtures.yml` and `display-names/run.sh`, the bookcraft README's fixture section,
`createbook/NOTES.md`'s note that the suite does not bind, and the root README's CI section now say
what is true.

### 2026-09-25 — Two binds, so the stamp check survives PR #39

**The fixture binds its copy twice, per the operator.** As declared, it checks the formats, page 2
and the EPUB's cover art, which has to be a real PNG: the binder swallows a rasterising failure and
ships no art. With a `cover_image` added, it compares the stamps, since #39 keeps `cover.xhtml` only
behind declared art. Measured against #39's binder at `c55a002`: the declared bind has no
`cover.xhtml`, and the fixture passes. About 5s for both binds. A fifth mutant, rasterising that
returns nothing, fails on the cover-art check.

### 2026-09-25 — Phase 6: #37's two regression fixtures, after #39 merges

#37 closed by folding two fixtures into #32 through a comment on the ticket: the look-alike
appendix slug (#35) and the appendix-table repair (#20). Both reproduce, from #37's own repro
files: `main`'s binder prints the middle file of the slug book as a second `A1` and warns on the
table, and #39's does neither. **The operator added them as Phase 6, to land after #39 merges,**
since on `main` they fail by design.

### 2026-09-25 — CI green with the bind, and Linux stays advisory

CI run 36134364045 on `fafa000` passed 16 of 16 on both legs, the bind included. **The Linux leg
stays advisory, per the operator**: the bind's checks lean on font metrics, where a Linux-only
failure is likelier a font difference than a regression. The reason sits in the `fixtures.yml`
header beside the macOS rationale.

### 2026-09-25 — Phase 6: #37's regression books

Synced `main` @ `5a4d741` (#39) with a merge commit; its binder is the one the fixture was already
tested against. **`bind/run.sh` now binds two more books kept beside it**, copied from #37's own
reproductions: `appendix-slug/`, whose Contents must list 1, 2 and one A1, and `appendix-table/`,
whose appendix table must bind with no word broken mid-word. Both pass on the merged binder and
fail on the pre-#39 binder, which is what a revert of either fix looks like. The fixture takes
about 9s for its four binds. The table squeeze was measured on macOS; where Linux fonts leave the
column wide enough, that check passes without testing the repair, and the header says so.

### 2026-09-25 — The table check holds on Linux

A throwaway branch with the pre-#39 binder went through CI (run 36137670848) and was deleted.
Both new checks failed on both legs, and the table's column came out 51pt short of its longest
word on macOS and 43pt on Linux. **So the table check tests the repair on Linux as well,** which
the earlier entry could not say. The `run.sh` header now gives the measurement in place of the
macOS-only caveat.

**No Chromium cache, per the operator:** a cold install costs 16 to 19s in CI. Every open question
in the plan is now settled.
