# Bind a fixture book in CI so makebook changes get a signal

## Overview

Nothing automated ran the binder. The fixtures workflow and `test-fixtures.sh` graded the book
checkers, and one makebook fixture tested a single pure function lifted out of `build-book.py`,
but no run ever bound a book: CI installed Python and jq, not the Chromium and poppler the binder
needs. A `build-book.py` regression merged with a passing fixtures check.

This branch installs the binder's toolchain in the fixtures workflow, through the same
`install.sh` a person runs, and adds `makebook/fixtures/bind/run.sh`, which binds real books on
every suite run and asserts on what the binder writes: both formats, the cover fitting on page 1,
the EPUB's cover art, one bind stamp across both formats, and a regression book for each of the
two binder fixes that PR #39 landed. The fixture runs inside `test-fixtures.sh`, so a contributor with the
toolchain catches a binder break before pushing; without it the fixture skips, and CI fails the
skip.

## Key changes

- **`.github/workflows/fixtures.yml`**: installs poppler, runs `plugins/bookcraft/scripts/install.sh`,
  installs Chromium's system libraries on Linux (`playwright install-deps chromium`), and asserts
  the toolchain runs with a bind in miniature. Adds `install.sh` and `bookcraft-python` to the
  executable-bit check. The header explains the bind and why its Linux leg stays advisory.
- **`plugins/bookcraft/skills/makebook/fixtures/bind/run.sh`** (new): skips without the venv or
  `pdftotext`; otherwise binds copies of three books, the guide twice, and runs twelve checks.
  - `createbook/fixtures/guide` as declared: both formats written, page 2 is Contents, and the
    EPUB's cover art is a real PNG rasterised from the PDF cover.
  - The same book with a `cover_image` added: PDF page 1 and `EPUB/cover.xhtml` carry the same
    `Created:` stamp, in `bind_stamp`'s form.
  - `bind/appendix-slug/`: Contents lists 1, 2 and one A1, so a chapter whose name only looks
    like an appendix's stays a chapter (#35).
  - `bind/appendix-table/`: the appendix's table prints its three long words whole on its page,
    and the bind does not warn of a word broken mid-word (#20).
- **`bind/appendix-slug/*.md`, `bind/appendix-table/*.md`** (new): the two regression books,
  copied from #37's own reproductions.
- **`makebook/fixtures/display-names/run.sh`**: header only; it no longer says the suite cannot
  bind.
- **`plugins/bookcraft/README.md`**, **`README.md`**, **`createbook/NOTES.md`**: say the suite binds,
  what the bind checks, when it skips, and that seven fixtures are scripts.

## Code examples

The workflow asserts the toolchain runs rather than that it exists, by doing what a bind does in
miniature (`.github/workflows/fixtures.yml`):

```bash
if ! plugins/bookcraft/scripts/bookcraft-python - "$probe" <<'EOF'
import sys
from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    print(f"chromium {browser.version}")
    page = browser.new_page()
    page.set_content("<p>bookcraft toolchain probe</p>")
    page.pdf(path=sys.argv[1])
    browser.close()
EOF
then
  echo "the binder's venv cannot launch Playwright's Chromium and print a PDF;"
  echo "the error above says which of the two is missing"; exit 1
fi
text=$(pdftotext "$probe" -) || {
  echo "pdftotext is on PATH at $(command -v pdftotext) but will not run"; exit 1; }
```

An absent toolchain is a skip, and everything else is a failure
(`makebook/fixtures/bind/run.sh`):

```bash
py="${XDG_CACHE_HOME:-$HOME/.cache}/bookcraft/venv/bin/python"
if [ ! -x "$py" ]; then
  echo "skip  no binder venv at $py; run scripts/install.sh to bind"
  exit 0
fi
```

The appendix-table check reads the words back off the page, because the binder's warning and its
repair hang off one detector and would go quiet together (`makebook/fixtures/bind/run.sh`):

```bash
a1=$(pdftotext -f 2 -l 2 -layout "$pdf" - 2>/dev/null \
  | sed -n -E 's/^ *A1 +The Squeezed Table +([0-9]+)$/\1/p')
page=$(pdftotext -f "$a1" -l "$a1" "$pdf" - 2>&1)
for w in Denormalization Characteristically Referential; do
  printf '%s\n' "$page" | grep -qw "$w" || broken="$broken $w"
done
```

## Plan alignment

All six phases are done.

- **Phase 1, the toolchain in CI**: as planned, through `install.sh`. The Linux leg also installs
  Chromium's system libraries, which `install.sh` leaves to the caller; whether Linux needs them
  was not measured.
- **Phase 2, the bind fixture**: a `run.sh`, per the operator, over a separate workflow step. It
  binds a **copy**, because the binder writes its render HTML into the source folder.
- **Phase 3, the assertions**: all three as planned, plus one. **Deviation:** the fixture binds
  the guide book twice. PR #39 stopped building `EPUB/cover.xhtml` when the cover art is
  generated, which would have broken the stamp check whichever branch merged second; per the
  operator, the stamp is compared on a second bind that declares a `cover_image`, where #39 keeps
  that page. The first bind gained a cover-art check, because the rasterising path it still runs
  swallows its own failure.
- **Phase 4, the Linux leg**: advisory, per the operator, decided after the first Linux bind
  passed, since the checks lean on font metrics. The reason is in the workflow header.
- **Phase 5, false comments and docs**: done, and CI was green with the bind in it.
- **Phase 6, #37's two regression books**: **added by the operator** from #37's comment on #32,
  after #39 merged and `main` was synced in.

Settled along the way: no Playwright cache (a cold install costs 16 to 19s in CI), and
`install.sh` runs unattended on a runner.

The pre-test review returned APPROVE; its one Important finding, the appendix-table check trusting
the binder's own warning, and two suggestions were fixed (`pr-review-2026-09-25.md`).

## Testing

**By hand:** with the toolchain installed (`plugins/bookcraft/scripts/install.sh`), run
`plugins/bookcraft/scripts/test-fixtures.sh`; it should report `ok    makebook/bind/run.sh`
among 16 passes. `plugins/bookcraft/skills/makebook/fixtures/bind/run.sh` alone prints all twelve
checks. Without the venv the suite reports one skip and passes; with `--strict` it fails.

**Every check was shown to fail against the break it targets**, by binding with a mutated copy
of the binder:

- a cover that spills onto page 2; an EPUB stamp that differs; a stamp in the wrong form; no EPUB
  written; no cover art rasterised
- a broken-word detector that records nothing, which the whole-word check catches and the warning
  check alone did not
- no `cover.xhtml`, which now fails with its traceback; a failed `book.json` edit, which reports
  a fault in the fixture
- the pre-#39 binder, which fails both regression checks

**On CI:** green on both legs with the bind (runs 36134364045, 36136578845, and PR #41's run
36141508797). Two throwaway branches carrying the pre-#39 binder (runs 36137670848 and
36141024240, both branches deleted) failed the regression checks on macOS **and** Linux, so the
table squeeze reproduces on Linux (the column 51pt short on macOS, 43pt on Linux) and the checks
test the fixes on both legs. `/bin/bash` 3.2 runs the fixture.

**Edge cases considered:** the binder's temp HTML landing in a tracked fixture (a copy is bound);
a word printed whole in an index passing the table check (only the appendix's page is read); a
fixture fault reported as a binder fault (guarded); the fixture folders' coverage rule (the
regression books sit one level down, out of its reach).

## Impact assessment

- **15 files changed, 704 insertions, 12 deletions** before the close artifacts (this summary,
  the close review and the commit message), most of it the new fixture and this branch's plan
  folder.
- **Dependencies:** none added to the plugin. CI now installs poppler, the packages in
  `makebook/requirements.txt` and Playwright's Chromium, plus Chromium's system libraries on Linux.
- **CI time:** the toolchain steps add about 20s on macOS and about 50s on Linux, measured on run
  36134364045. The suite's four binds took it from 8s to 16s on macOS and from 4s to 16s on Linux
  (runs 36050896464 and 36136578845).
- **Local suite:** about 9s slower where the toolchain is installed; unchanged where it is not.
- **Breaking changes:** none. No skill's behavior changes, so bookcraft's version is not bumped.

## Deferred work

- **The binder's hidden page markers are still checked by nothing.** `createbook/NOTES.md` names
  a bind test as the gap to close for them; this branch's assertions do not include one. A check
  would bind the guide fixture and require the finished PDF's text layer to carry none of the
  markers.
