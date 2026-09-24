## PR review: stamp the bind date and time under the title page byline

Close-gate review of PR #31 (issue #27, "Stamp the bind date and time under the title page
byline"). Covers commit `13951d0` plus the uncommitted working tree that this close will commit.

### Summary

`/makebook` now prints `Created: <local time> <zone>` under the byline on the PDF cover, the EPUB
cover page and the generated EPUB cover art. The stamp is read once per run and threaded through
as a required argument, so one binding carries one stamp. The pre-test review approved `13951d0`.
Since then only docs and plan notes changed: the `bind_stamp` docstring and one SKILL.md sentence
("otherwise look the same to a reader", plus the `%Z` UTC-offset fallback), the corrected
cover-cost numbers in PLAN.md and CHANGELOG.md, and two Deferred entries.

This is a re-review, so it focuses on that delta, and it checks the PR body
(`pr-summary-2026-09-24.md`) against the code.

### What is working well

- **One read of the clock, enforced by the signatures.** `stamp` is a required parameter with no
  default at every level (`assemble`, `build_cover`, `render_cover_png`, `epub_cover_body`,
  `build_epub`). A cover cannot quietly read its own time and disagree with the EPUB. This follows
  the precedent `assemble` already set for `css`.
- **The corrected measurements are right.** I bound the `guide` fixture again with main's
  `build-book.py` and the branch's working-tree copy, at 14pt, with and without a byline. The
  description's first word moved 244.45 → 265.45 (+21pt) with a byline and 208.45 → 244.45
  (+36pt) without one. Those match PLAN.md, CHANGELOG.md and the summary's table exactly. Page 2
  of every build opened with the Contents probe.
- **The new docstring's claims hold.** The Chromium PDFs carry `CreationDate`/`ModDate`
  (`pdfinfo`). ebooklib 0.20 writes `dcterms:modified` from `datetime.now()` (`epub.py:957-964`).
  Under `TZ=Asia/Dubai`, `%Z` prints `+04`, so the SKILL.md sentence about the UTC-offset
  fallback is accurate.
- **The PDF and EPUB stamps match.** In both branch builds, the `pdftotext` page-1 stamp equals
  the `<p class="stamp">` in `EPUB/cover.xhtml`. The generated `cover.png` for the no-byline build
  shows the stamp in the byline's slot, in the byline's type.
- **The EPUB indent reasoning is sound.** `p:first-of-type, h1 + p, ...` resets the indent. On
  main, a byline after a subtitle picked up `p`'s 1.2em indent. The branch's explicit
  `text-indent: 0` on `.byline, .stamp` fixes that. The summary also flags the one knock-on
  effect: with neither subtitle nor byline, the description's first paragraph is no longer
  first-of-type and now indents. That is correct and stated honestly.
- **The PR body is accurate.** The +52/−16 plugin line count matches the working tree against
  the merge base. `test-fixtures.sh` passes 11/11 (re-run here). Both CI legs pass. The code
  excerpts match the source. The claim that nothing outside `build-book.py` calls the changed
  functions holds (grep).
- **The repo rules are clean.** The banned-terms regex returns nothing across PLAN.md,
  CHANGELOG.md, the pr-summary, SKILL.md and `build-book.py`. None of the changed files, the
  commit message or the PR title carries an attribution marker. The one "Claude Code" hit
  (SKILL.md:50) is pre-existing prose about the host and sits outside the diff. The only
  `github.com/...` string is this repo's own issue URL.

### Issues found

#### Critical

None.

#### Important

🟡 **bookcraft's version is not bumped, so installed copies will never receive the stamp**

📍 Location: `plugins/bookcraft/.claude-plugin/plugin.json:5` (`"version": "1.5.0"`, unchanged)

**What I see:**
The PR changes shipped plugin files, `skills/makebook/scripts/build-book.py` and
`skills/makebook/SKILL.md`, and leaves bookcraft at 1.5.0.

**The risk:**
Claude Code installs each plugin version into its own directory (SKILL.md:50 says so), and the
version is the installer's only change signal. Any machine already on 1.5.0 sees matching numbers
after merge, fetches nothing, and keeps binding books with no stamp. The objective is "the PDF
and EPUB `/makebook` produces" carry the stamp. For anyone who runs `/makebook` from an
installed plugin, that does not happen until some later PR happens to bump.

This repo has hit and documented this exact failure before:

- `35636a4` (#12) exists only to catch up a missed bump. Its message: "The version is the only
  signal the installer has, so an update check sees matching numbers and fetches nothing".
- #17's close added "bump bookcraft to 1.5.0, which the first commit missed", and its summary
  states the rule: "installed copies do not refresh without it, and the repo bumps minor for a
  behavior change".
- #14, #15, #17 and #26 all bumped in-PR.

This is in scope because the PR introduced it: main at 1.5.0 is consistent with its own files
today, and this PR is what makes them diverge.

**Suggested fix:**
Fold it into the close commit.

```json
"version": "1.6.0",
```

The repo bumps minor for a behavior change, and every cover now gains a line. Then add a
Housekeeping line to `pr-summary-2026-09-24.md` and update its "Plugin files" count to three
files, +53/−17.

**Learning note:**
In a plugin marketplace, the version number is part of the delivery mechanism, not
bookkeeping. A change that never reaches installed copies is, for users, a change that never
shipped.

*This does not block. The default branch is no worse for it, since installed copies behave
exactly as before. It is a one-line fix that decides whether the objective actually reaches
users, so it belongs in this close rather than a ticket.*

#### Suggestions

🟢 **The docstring edit was not reflowed**

📍 Location: `plugins/bookcraft/skills/makebook/scripts/build-book.py:1208`

**What I see:**
`    but only in metadata a reader never sees. Seconds are kept because a rebind after a one-line fix can land`
This line is 109 characters. The rest of the docstring wraps at about 79.

**The risk:**
Cosmetic only. It is the longest line in the file, and it reads as an edit that was spliced in.

**Suggested fix:**
Rewrap the paragraph.

```python
    It is the bound book's version marker. Two bindings of one folder otherwise
    look the same to a reader, down to the EPUB's identifier, which is derived
    from the folder and the title so a re-send replaces the book on a device.
    The PDF's CreationDate and the EPUB's dcterms:modified do record a time,
    but only in metadata a reader never sees. Seconds are kept because a
    rebind after a one-line fix can land inside the same minute. Read once per
    run by the caller, never per cover, so the PDF, its every settling pass,
    and the EPUB all carry the same one.
```

**Learning note:**
Rewrap the whole paragraph when you edit prose in code, so the next diff shows only the words
that actually changed.

🟢 **PLAN.md cites the wrong createbook section**

📍 Location: `changelog/27-stamp-the-bind-date-and-time-under-the-title-page-byline/PLAN.md`,
second Deferred entry

**What I see:**
"(`createbook/SKILL.md § 5`)". The byline rule is at `createbook/SKILL.md:315`, under
`### 4. Write \`book.json\``. § 5 is "Draft the chapters".

**Suggested fix:**
Change it to `§ 4`. The pr-summary does not repeat the section number, so it needs no change.

#### ⏭️ Deferred to follow-up

- **No automated check binds a book.** Located at `plugins/bookcraft/scripts/test-fixtures.sh`
  and the fixtures workflow. A `build-book.py` regression would ship with CI green. This is
  already in PLAN.md's Deferred list. Symptom: a broken bind merges green. Occasion: when the
  workflow gains Chromium and poppler for another reason. theme: bookcraft CI coverage.
- **Fixture bylines name a model.** PLAN.md's Deferred list resolves this as by design, per the
  `/createbook` byline rule (`createbook/SKILL.md:315`). **DROP.** No symptom, nothing to do.
  theme: fixtures.

Dropped without a deferred entry, noted here only for findability: ebooklib stamps
`dcterms:modified` with local time and a literal `Z` suffix (`2026-09-24T08:19:18Z` from an MDT
bind). This is pre-existing library behaviour, nothing reads it, and this PR's docstring only
says a time is recorded, which is true. DROP.

### Questions

- Was leaving the version alone deliberate, for example to batch-release several bookcraft
  changes under one bump? If so, say so in the summary. Otherwise the 🟡 above is a one-line fix
  for this close.

### Verdict

VERDICT: APPROVE

The PR delivers the objective with no regression, and the post-approval delta is accurate
(measurements re-verified independently). Before merging, bump bookcraft to 1.6.0 so installed
copies pick up the stamp, and optionally apply the two 🟢 nits.
