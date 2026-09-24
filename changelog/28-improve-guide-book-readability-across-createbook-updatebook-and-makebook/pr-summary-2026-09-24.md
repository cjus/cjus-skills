# Improve guide-book readability across createbook, updatebook and makebook

## Overview

A reread of the reference teaching guide found its sentences mostly sound and its structure
hard to read, and traced each structural cause to a rule in the book skills. This PR changes
those rules so the next guide book reads the way a guide is used, one chapter at a time when
it is needed, and so revising a finished chapter no longer wears it down.

It gives the `guide` profile a rule file of its own, takes the narration handoff chain out of
the guide path, makes `## In short` the chapter's one summary, and has `check-book.sh` hold a
guide to the 90-word paragraph stop and report six other readability signals. `/updatebook`
can now add a paragraph without renumbering any tag, and says when a chapter or the whole book
should be rewritten instead of edited. `/makebook` hands a guide's reader the reading edition,
prints display names where the header named repo paths, and keeps its page markers out of the
PDF's text layer. The blind reader comparison planned as Phase 7 moved to #34.

## Key changes

**Rule files** (`plugins/bookcraft/skills/createbook/reference/`)
- `chapter-prose.md` is now the core every chapter follows, rewritten in the plain style it
  asks for, with its reasoning moved to `NOTES.md`. "Rather than" fell from 63 uses to 1 and
  forms of "carry" from 62 to 12, and every paragraph and sentence keeps the stops.
- `guide.md` (new): the guide profile as its own rule set. Opening that orients the reader, a
  contents-page heading test, callouts holding one idea, `## In short` as the only summary
  (the chapter's own terms with a short definition, about 120 words, never reusing the
  chapter's sentences), a close that lands the main point or the next step, the wrong model
  as "a shape, not a script", and before-and-after examples for each.
- `narration.md` (new): the handoff rules, moved from the old file unchanged.

**Procedure** (`createbook/SKILL.md`)
- Step 5 hands an agent the core plus the book's profile file and no third.
- A guide outline records a **Scope** row and no **Opens on** / **Closes on** nouns; step 5
  gives a guide chapter its scope and its neighbours' titles; step 8 reads guide openings and
  closes for orientation and truth instead of handoff drift.
- The `book.json` template writes `"edition": "reading"` for a guide, and step 9 names both
  bound files.

**Checkers** (`createbook/scripts/`)
- `check-book.sh`: a paragraph over 90 words fails a guide book and is reported under
  narration. New `REPORT` lines, which fail nothing: sentences over 45 words, callouts over four
  sentences, summaries over 120 words or sharing an eight-word run with the chapter, four-word
  phrases in three or more chapters, repo-path header keys with no display name, and chapters
  carrying lettered tags. Lettered tags (`[5-12a]`) are checked as a gapless sequence.
- `check-references.sh`: tag halves kept as strings, so appendix tags (`[A2-4]`, previously
  invisible to it) and lettered tags resolve; check 4 counts only plain tags for its slide test
  and treats a relettered run as a slide; a provenance mark ends a paragraph; leading zeros in
  an outside citation still resolve as before.
- `check-provenance.sh`: marks citing appendix and lettered tags resolve.

**Revision** (`updatebook/SKILL.md`)
- `§ Adding prose` puts the lettered paragraph first, lets a paragraph grow only within 90
  words, and bars new text from callouts, tables and lists; `§ Cutting prose` is its own
  section; the classify table gained adding, cutting and premise rows.
- New `§ When to stop editing in place`: edit, rewrite one chapter, or recreate the book, with
  a step that moves each revision's facts into `OUTLINE.md` before any rewrite.

**Binder** (`makebook/scripts/build-book.py`, `makebook/SKILL.md`)
- `PARA_TAG_RE` strips lettered tags from the reading edition.
- `swap_display_names` puts a display name where a `Draws on` or `Fills in` row names a
  path-like key, in both editions and so in the endnotes.
- After page numbers settle, the book renders once more with `.probe{visibility:hidden}`,
  kept only when it matches the probed render page for page.

**Fixtures** (CI's suite, 15 of 15): `guide-reports/`, `paragraph-stop/run.sh`,
`lettered-tags/run.sh`, `makebook/fixtures/display-names/run.sh`; the guide fixtures were
brought to the new rules.

## Code examples

The lettered-tag sequence, `plugins/bookcraft/skills/createbook/scripts/check-book.sh`:

```bash
if [ -z "$tag_s" ]; then
  if [ "$((10#$tag_n))" -ne "$((prev_n + 1))" ]; then
    problem "$base: paragraph $seq is tagged [$tag]; the paragraph number must count 1, 2, 3 through the chapter, so this one is [$tag_half-$((prev_n + 1))]"
  fi
  prev_n=$((10#$tag_n)); prev_s=""
else
  # a lettered tag repeats the number of the paragraph it follows, with the next letter
  ...
  lettered="$lettered${lettered:+, }[$tag]"
fi
```

A relettered run counted as a slide, `plugins/bookcraft/skills/createbook/scripts/check-references.sh`:

```python
cur_runs, base_runs = letter_runs(paras), letter_runs(base)
for (c, num), was in base_runs.items():
    if cur_runs.get((c, num), [])[:len(was)] != was and c not in shifted:
        shifted.add(c)
        renamed_reason[c] = (f"lost or relettered a paragraph added after "
                             f"[{c}-{num}]")
```

The swap is scoped to the source rows, `plugins/bookcraft/skills/makebook/scripts/build-book.py`:

```python
SOURCE_ROW_RE = re.compile(r"^[ \t]*\|[ \t]*\*\*(Draws on|Fills in)\*\*[ \t]*\|")

def row(line: str) -> str:
    if not SOURCE_ROW_RE.match(line):
        return line
    ...
```

## Plan alignment

| Phase | Status |
|---|---|
| 1. `guide` as a rule set of its own | Done as planned. One deliberate change beyond the split, recorded in `NOTES.md`: a guide part walks a mechanism only where it explains one. The teaching-chapter shape now puts its key in an appendix, since its fourth part could never pass the checker |
| 2. Handoff chain out of the guide path | Done as planned |
| 3. `## In short` rework | Done as planned; the `This chapter` row merged into it under `guide` only, per the settled question |
| 4. `check-book.sh` reports | Done. The paragraph stop fails a guide, per the settled question; everything else reports. Added one report the plan did not list: chapters carrying lettered tags |
| 5. `/updatebook`'s edit rules | Done, including the rewrite-or-recreate rule the operator added to this phase |
| 6. `/makebook`'s bind | Done |
| 7. Blind reader comparison | **Split to #34** by operator decision: it needs the operator as reader and runs in the source repo. The reference guide is not recreated until #34 has run |

All six open questions were settled by the operator on 2026-09-24 and are recorded in `PLAN.md`.

An independent audit of the split found eight rules lost, six weakened and four
contradictions, all fixed. Two independent reviews of the finished branch found five defects:
the display-name swap touching the reader's `Act on this` row and doubling articles, check 4
missing a relettered run, an unanchored appendix pattern, and the marker comparison stripping
markers before whitespace. All were fixed, and the four in behaviour each have a fixture case
that fails against the code before the fix.

## Testing

**Automated.** `plugins/bookcraft/scripts/test-fixtures.sh --strict` passes 15 of 15, locally
and in CI on macOS and Ubuntu. `scripts/check-citations.py` resolves all 180 `file § rule`
citations. `check-book.sh` gives identical output under macOS `/bin/bash` 3.2 with BSD awk, and
under gawk 5.2.1 and mawk 1.3.4.

**Measured against the two real guide books** (outside this repo): 46 and 7 paragraph-stop
failures, the 46 matching the ticket's count; spot-checked word counts exact.

**By hand, because CI cannot bind a book:** `fixtures/guide/` bound before and after, 13 pages
both times, 9 markers in the text layer before and none after, the two texts identical once
the markers were stripped; `fixtures/guide-reports/` bound in both editions after the merge
with `main`, printing #31's bind stamp, the display names in the header, endnote and EPUB, and
no markers.

**To verify:**
- Run `check-book.sh` on `createbook/fixtures/guide-reports/` and read its seven `REPORT` lines.
- Run `createbook/fixtures/lettered-tags/run.sh` and `paragraph-stop/run.sh`.
- Bind a guide book with no flags and copy text out of the PDF: no `ZQ…` strings, display names
  in the header.
- Read `createbook/reference/guide.md` as the file a chapter agent will follow.

**Edge cases considered:** an untagged book, a callout across several `>` lines, a paragraph
directly after a figure or list, a lettered tag in an appendix or before the close, a chapter
slug holding "appendix", a key that is an ordinary word, and one disclosed gap: a guide book
declaring neither tags nor provenance lets its opening paragraph escape the paragraph stop, and
the run's fallback note says so.

## Impact assessment

38 files changed, 2,445 insertions and 437 deletions against `main`. No new dependencies.
bookcraft goes to **1.7.0**, since #31 released 1.6.0.

**Behaviour changes a user will notice:**
- An existing guide book with paragraphs over 90 words now **fails** `check-book.sh`. The
  reference guide does, by 46 paragraphs, and is to be recreated under the new rules after #34.
  Narration books only gain reports and still pass.
- A new guide book binds the reading edition by default; the operator's tagged copy is
  `--no-reading-edition` with its own `--out`.
- `check-references.sh` now sees appendix tag citations, so a stale one that passed before now
  fails.

## Deferred work

- **A bind test in CI.** The suite cannot bind a book, because CI installs Python and `jq` and
  not the Chromium the binder drives. The display-name swap is covered anyway, as a pure
  function; the hidden page markers were verified by hand.
- **Merging overlapping windows in the recurring-phrase report**, a review suggestion not
  taken: one eight-word stock phrase uses several of the ten report slots. It is report-only.
- **A code-span key followed by `:` or `#`**, such as `` `CLAUDE.md:42` ``, is not swapped for
  its display name and not reported. Recorded in `createbook/NOTES.md`.
- **Phase 7**, now #34.
