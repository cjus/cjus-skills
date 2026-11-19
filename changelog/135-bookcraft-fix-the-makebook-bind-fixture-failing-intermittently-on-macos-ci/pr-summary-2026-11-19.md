# bookcraft: stop a ligature from keeping the page markers in a bound PDF

## Overview

The `makebook/bind` fixture had been failing intermittently in `fixtures (macos-latest)` since
2026-11-19. Its two failure forms, "page 2 opens on 'ZQTOCSTARTQZ', not Contents: the cover
spilled onto a second page" and "a link on the Contents, Figures and Index pages opens a page
other than the one it prints", read like pagination drift. Neither was. Both come from the
binder's markers fallback misfiring.

After the page numbers settle, `build-book.py` renders the book once more with its white 5pt
probes hidden. It keeps that clean render only if its text matches the probed render page for
page; otherwise it ships the probed PDF and warns. Chromium 159 writes the "fi" in the guide
fixture slide's "profiles" into the text layer as two letters on one render and as the ligature
U+FB01 on the next, with nothing on the page moved. That one character failed the comparison, the
probed PDF shipped, and its page 2 opened on the `ZQTOCSTARTQZ` probe instead of "Contents", which
is what both fixture checks then tripped over. The comparison now folds both renders to NFKC
first, so a respelled glyph no longer counts as a changed page.

CI picked up Chromium 159 through Playwright 1.65.2, which `playwright>=1.44` in
`makebook/requirements.txt` allows; no commit in this repo changed the layout.

## Key changes

- `plugins/bookcraft/skills/makebook/scripts/build-book.py`: `flat()`, the helper that strips
  whitespace and probes before the clean and probed renders are compared, now normalizes to NFKC
  first, with a comment recording the measurement behind it.
- `plugins/bookcraft/.claude-plugin/plugin.json`: 1.20.0 to 1.20.1, so installs pick the fix up.
- `changelog/135-…/PLAN.md` and `CHANGELOG.md`: the investigation, its evidence and the decision.

## Code example

`plugins/bookcraft/skills/makebook/scripts/build-book.py`, before:

```python
    def flat(page: str) -> str:
        return PROBE_RE.sub("", re.sub(r"\s+", "", page))
```

After:

```python
    def flat(page: str) -> str:
        return PROBE_RE.sub(
            "", re.sub(r"\s+", "", unicodedata.normalize("NFKC", page)))
```

`bare()` in the same file already compares index terms in NFKC for the same reason, so the binder
now treats the text layer one way in both places.

## Plan alignment

All four plan items completed as planned.

1. **Runner and renderer versions compared.** 18 macOS job logs since 2026-11-02. Every 2026-11-19
   job, passing or failing, ran Playwright 1.65.2 / Chromium 159.0.8154.6; the last all-green runs
   (2026-11-02) ran 1.64.1 / Chromium 156.0.8078.4. Runner image 20261102.0473 and poppler 26.10
   and 26.11 appear on both sides, so they do not explain it.
2. **Cause found.** As above. The "cover spilled" message was a misdiagnosis by the fixture: the
   cover never moved.
3. **Bind made deterministic.** The plan allowed either a binder fix or a more tolerant fixture.
   The binder was the right place, because the same false fallback leaves `ZQ…QZ` strings in the
   text layer of real books, where a screen reader reads them aloud. Pinning Chromium was also
   rejected: it would hide the comparison's fragility rather than remove it.
4. **Proven in CI.** See Testing.

The plan's open question, whether the failure reproduces locally, is resolved: it does, once the
venv runs Chromium 159. The local `install.sh` venv was still on Chromium 151, which never failed.

## Testing

Local, macOS, in a scratch venv on Playwright 1.65.2 / Chromium 159.0.8154.6:

| | before | after |
|---|---|---|
| guide binds that kept their markers | 6 of 40 | 0 of 40 |
| `makebook/bind/run.sh` runs | | 15 of 15 pass |

Every one of the six failing binds differed from its clean render only by `fi` against U+FB01, and
matched exactly after NFKC. On the local Chromium 151 venv the fixture passed 20 of 20 before the
change, and the full suite passes 27 of 27 with `test-fixtures.sh --strict` after it.

CI, this PR's `fixtures` run 44557860724 at 27d10f7: `fixtures (macos-latest)` passed on attempts 1
through 5, each on Chromium 159.0.8154.6, with `makebook/bind` ok and 27 passed, 0 failed. At the
measured rate (about one fixture run in four failing), five clean runs by chance is roughly a 1 in
4 outcome, so the local 40-bind result is the stronger evidence and CI confirms it.

To reproduce the original failure, bind `createbook/fixtures/guide` repeatedly under Chromium 159
with this change reverted and watch for "hiding the page markers changed the layout".

No fixture was added: the existing `makebook/bind` fixture already fails on a revert under
Chromium 159, at the rate above.

Edge case considered: NFKC also folds other compatibility characters (full-width forms, superscript
digits). That can only make two renders compare equal when their per-page text differs in glyph
form alone; a real reflow moves words between pages and still fails the comparison.

## Impact assessment

One line of behavior in one file (`build-book.py`, 11 added, 1 removed, mostly comment), a patch
version bump of bookcraft to 1.20.1, and the branch's plan folder. No dependency changes, no
interface changes, nothing breaking. Books bound on
Chromium 159 now keep their markers out of the text layer instead of keeping them in about one bind
in seven.

## Deferred work

The fixture blames "the cover spilled onto a second page" for any page 2 that does not open on
Contents, including one that opens on a leftover probe. Its message could tell the two apart.
