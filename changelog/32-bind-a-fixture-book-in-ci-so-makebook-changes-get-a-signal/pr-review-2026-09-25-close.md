# PR review: Bind a fixture book in CI so makebook changes get a signal

Review date: 2026-09-25, by `/pr:close`, over `origin/main...HEAD` at `8698e74` (PR #41). A
re-review: the pre-test review (`pr-review-2026-09-25.md`, APPROVE at `8bb3b93`) covered the
branch through that commit. This one reviews its delta, commit `8698e74`, plus the PR summary
that becomes the body, and the repo's CLAUDE.md rules across the whole branch. Changes that came
with the merge of `main` @ `5a4d741` (#39) are not this branch's work.

## Summary

The fixtures workflow installs the binder's toolchain through `install.sh`, adds poppler, and
asserts that Chromium can print a PDF and `pdftotext` can read it back.
`makebook/fixtures/bind/run.sh` runs inside `test-fixtures.sh` and binds the guide fixture twice,
plus two regression books for #39's fixes. It makes twelve assertions on what the binder writes.
The objective in `PLAN.md` is delivered: every run binds a book, and a binder regression now fails
the suite.

## What is working well

- **The whole-word fix closes the gap the pre-test review named, and it cannot pass vacuously.**
  It finds the appendix's page from the Contents line and reads only that page. The three long
  words appear nowhere else in the book. A wrong page lookup therefore fails the check rather than
  passing it. CI run 36141024240, with the pre-#39 binder, failed it on both legs, naming all
  three words.
- **Fixture faults now surface as fixture faults.** The `book.json` edit uses the
  `if ! out=$(... <<'EOF' ... EOF); then` shape, so the command substitution's status drives the
  branch. The EPUB read is captured whole, and the traceback prints only in the branch that needs
  it.
- **The two binds rest on the binder's real behaviour.** `build-book.py:3104-3134` confirms both
  claims in the header. With no `cover_image`, the only source of a PNG cover is
  `render_cover_png`, which returns `None` on failure, so the magic-byte check is what catches a
  swallowed rasterising failure. `cover.xhtml` is built only when the art is not generated. A
  declared `cover_image` that is missing exits the bind, so it cannot quietly drop the stamp page.
- **The failure messages name the cause.** Each FAIL says what broke, and the bind's output is
  indented under it.

Checked by this reviewer:

- `/bin/bash` 3.2 runs `bind/run.sh`: 12 of 12 in 10.3s, and `git status` is unchanged afterwards.
- The full suite passes 16 of 16.
- With `XDG_CACHE_HOME` pointed at an empty directory, the suite reports one skip and passes.
  Under `--strict` it fails with the fixture's own skip line.
- The branch is one commit behind `main` (`33a3b6f`, #38, pr plugin only). `git merge-tree`
  merges it clean.

## Verification of the pre-test review's three fixes

1. **Appendix-table check trusting the binder's warning: fixed correctly and completely.**
   `run.sh:198-215` adds the page read beside the unchanged warning check. The header
   (`run.sh:34-39`) and the bookcraft README describe both checks.
2. **Helper steps hiding their errors: fixed.** The `book.json` edit is guarded at `run.sh:136-148`.
   The EPUB read is kept whole at `run.sh:157-170`.
3. **Doc phrasings: fixed.** The `fixtures.yml` header, the root README and the bookcraft README
   now say it skips without the venv or `pdftotext`, fails when Chromium will not launch, and
   binds three books, the guide twice. All three match `run.sh`'s skip conditions.

## Settled decisions, checked for implementation only

- **A `run.sh` in the suite.** It is found by `test-fixtures.sh`'s `fixtures/*/run.sh` glob, with
  mode 100755.
- **Two binds of the guide.** One as declared, one with `cover_image` added to the copy.
- **The Linux leg is advisory.** The existing `continue-on-error: matrix.blocking == false` does
  it, and the reason is recorded in the header beside the macOS rationale.
- **No Playwright cache.** There is no cache step.
- **Regression books inside `bind/`.** They sit one level below `fixtures/*/`, out of the coverage
  loop's reach, and the suite reports no "asserted by nothing" failure.
- **No version bump.** No `plugin.json`, `SKILL.md` or script changes.

## CLAUDE.md audit

- **Commits.** All seven are authored and committed as the repo owner, with no trailers, sign-offs
  or emoji markers.
- **Banned terms.** The repo's cross-project audit pattern returns nothing across the diff, the commit messages (authors included), all four changelog files (including the
  untracked summary), and a tree-wide `git grep`.
- **Attribution.** The attribution pattern returns nothing across the added lines, the commits and
  the changelog folder.
- **Cross-repo references.** There are no `org/repo#N` or `github.com/org/repo` strings in the
  added lines or the changelog folder.

## Summary claims against the code and the git log

Almost every claim checks out:

- **Counts.** Twelve checks, 16 passes and "seven fixtures are scripts".
- **CI runs.** All six cited runs exist on the stated SHAs and branches with the stated outcomes.
  Both experiment branches are deleted.
- **Timings.** The toolchain steps take 20s on macOS and 48s on Linux in run 36134364045. The
  suite went from 8s to 16s on macOS and from 4s to 16s on Linux across runs 36050896464 and
  36136578845.
- **Code excerpts.** The three code excerpts match the files.

The exceptions follow.

## Issues found

### Critical

None.

### Important

**1. The summary's "binder fixes #37 landed" is a live closing keyword, and it names the wrong
number.**

Location: `changelog/32-.../pr-summary-2026-09-25.md:13-14`

What I see: "...and two regression books for the binder fixes #37 landed."

The risk: this summary becomes PR #41's body, and the phrase is in prose, not code, so GitHub
resolves `fixes #37` as a closing reference. PR #41 would then list #37 in its
`closingIssuesReferences` and show in #37's sidebar as a PR that closes it. #37 is already closed,
by #39, so its state does not change. The link is still wrong, and it sits in public metadata.
The rule against this is in `main`'s close skill since #38: "keep literal closing keywords with an
issue number out of the summary". The installed 0.2.3 close skill predates it, so nothing in this
run's gate would catch it. The sentence is also wrong on the facts: #37 is the issue, and PR #39
landed the fixes.

Suggested fix: write around the keyword, for example "...and two regression books, one for each
binder fix in #39." Then confirm that `closingIssuesReferences` lists only #32 after the body is
written.

Learning note: GitHub reads closing keywords anywhere in a PR body's prose, mid-sentence included.
Wherever an issue number follows "fix", "close" or "resolve", reword it before it reaches a body.

This does not block. It is not a regression against the objective, and it takes one line to fix
before close publishes the body.

### Suggestions

**2. Three summary phrasings are off.**

- Key changes: "binds copies of four books". It is three books, one of them bound twice. The
  pre-test review corrected this same phrasing in the bookcraft README.
- Plan alignment, Phase 1: "Linux also needed Chromium's system libraries ... whether Linux
  strictly needs them was not measured." The sentence contradicts itself. "Linux also gets" says
  what is known.
- Impact: "15 files changed, 704 insertions, 12 deletions" leaves out the summary itself and any
  close-time edits to `PLAN.md` or `CHANGELOG.md`. Refresh the figures after the final commit.

**3. `PLAN.md`'s status line says "pushed at `8bb3b93`".** The fixes are at `8698e74`. Close's
status refresh will cover this.

### Deferred to follow-up

None new. The page-marker assertion is already parked under `## Deferred` in `PLAN.md` and in the
summary's "Deferred work".

### Dropped

- If the appendix's table ever spilled onto a second page, the whole-word check would report the
  missing words as "broken mid-word". It is a three-row table on a fresh page, so this is arguable.
- The summary's "every check was shown to fail" has no listed mutant for the "binds" and "PDF is
  written" checks. A bind that writes no PDF fails loudly anyway, so this is arguable.
- `createbook/NOTES.md` says "on every run", which means every run with the toolchain installed.
  This is arguable.

## Questions

- Phase 6 says the checkboxes in #37's comment on #32 (comment 5832105522) are ticked at close.
  Both are still unticked. The fixture asserts exactly what each one asks for: 1, 2 and A1 in
  Contents, and no table warning.

## Verdict

VERDICT: APPROVE

Fix the "binder fixes #37 landed" phrasing in the summary before it becomes the PR body, then tick
Phase 6's checkboxes on #32 as part of the close.
