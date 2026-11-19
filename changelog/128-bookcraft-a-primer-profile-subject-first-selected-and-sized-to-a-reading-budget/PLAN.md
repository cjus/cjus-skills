# bookcraft: a primer profile, subject first, selected and sized to a reading budget

Start date: 2026-11-18 22:01:28 MST

Issue: https://github.com/cjus/cjus-skills/issues/128

## Overview

Add a `primer` profile to `/createbook` for its commonest goal, a small book that gets a reader up to speed on a subject from the context given at creation time, and make it the default for new books. `guide` and `narration` stay as the handbook modes.

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred`, never as new scope.

**Stacked branch.** This branch starts from the #130 branch, not from main, because both change `check-book.sh`, `createbook/SKILL.md` and the plugin version. Its PR targets the #130 branch and should merge after it.

## About Ticket

### Selection and size
- [x] The outline sorts the context into teach, mention and leave to the source; the gate shows the cut list and why.
- [x] A reading budget is set at the gate, defaulting to 60 to 90 minutes; chapter count follows from it.
- [x] Chapters are ordered by what the learner must understand first.

### Length: ceilings, never bands
- [x] A chapter ceiling of about 2,000 words of prose, no floor and no target.
- [x] A paragraph rarely over 100 words; a sentence past about 35 is probably two.
- [x] `check-book.sh` reports a chapter whose paragraphs cluster near a limit.

### How a chapter explains
- [x] Problem first, using the context's own demonstration where it has one.
- [x] The device chosen per concept; the four steps and the part skeleton become habits, not a template.
- [x] Teach or point, never list.

### What the outline decides for the whole book
- [x] Each chapter's opening move and shape, differing from its neighbours'.
- [x] Book-wide conventions, each explained once in a named chapter.
- [x] How a primer drawn from a larger book tells the two books' numbering apart.
- [x] Only the chapter that owns a measured result states it.

## Plan

- [x] `reference/primer.md`, the standalone rule file.
- [x] `check-book.sh`: accept `primer`; closing section `## Sources and further reading`; any number of sections, H3 allowed, H4 not; appendices allowed; paragraph past 100 reported, never failed; clustering report under every profile.
- [x] `check-provenance.sh` stops its walk at the primer's closing section too.
- [x] `createbook/SKILL.md`: profile table and default, § Under the primer profile, prompt items 1, 3 and 6, file format, tagging default, gate line.
- [x] `updatebook/SKILL.md`: the primer rule set.
- [x] `fixtures/primer` with a manifest row; README; NOTES.md; plugin 1.18.0.

## Status

Done. `scripts/test-fixtures.sh --strict` passes 23 of 23. The first review requested changes (pr-review-2026-11-18-first.md), and every finding was fixed:

- Step 4 now writes a primer `book.json` template first, and its profile paragraph names three rule sets.
- The sizing row, the read-time arithmetic and prompt items 2 and 5 carry the primer. The primer outline row gains Carries, Fills in and Stops short of, which prompt items 9 to 11 read.
- `primer.md` says the closing section is a bulleted list, bans block quotes and italics, and marks a unit above the first paragraph. `check-book.sh` now requires that mark under primer, where there is no header table to exempt.
- `updatebook/SKILL.md` qualifies the length rule, the anchor and term budgets, the header rows and the closing section for primers.
- `fixtures/primer` gains an appendix and an eight-paragraph chapter 1, so its no-clustering assertion can fire. The new `fixtures/primer-failures` fails on an H4, an unmarked block above the first paragraph, and a closing section with no list.

## Deferred

- None.
