# bookcraft: a primer profile, subject first, selected and sized to a reading budget

Start date: 2026-11-18 22:01:28 MST

Issue: https://github.com/cjus/cjus-skills/issues/128

## Changes

- **`reference/primer.md`**, a standalone rule file for a primer chapter, read instead of
  `chapter-prose.md` and borrowing only its mark and tag grammar.
  - Teach, mention or leave, as the outline decides. Teach or point, never list.
  - Problem first, the device chosen per concept, terms defined once, shown output made readable.
  - Facts from the context or marked `fill`; nothing invented; a number keeps its scope.
  - Ceilings, never bands: a chapter of about 2,000 words of prose at most, paragraphs rarely
    over 100, sentences past 35 split.
  - The assigned opening, no recap, `## Sources and further reading` last.
  - A voice list built from the habits two test readers found in a trial book.
- **`check-book.sh` reads `primer`.**
  - Its closing section is `## Sources and further reading`.
  - It allows any number of `##` sections, an `###` inside one, and appendices.
  - A paragraph past 100 words is reported, never failed.
  - A new clustering report, under every profile, names a chapter of eight or more paragraphs
    where 40% or more reach 85% of the paragraph limit.
- **`check-provenance.sh`** stops its walk at the primer's closing section as it does at
  `## Suggested reading`.
- **`createbook/SKILL.md`.**
  - `primer` is the default a new book gets, and the profile table has three rows.
  - A new § Under the primer profile covers the reading budget and selection, a learner's order,
    and the primer outline row with its assigned opening and Try it decision. It also covers
    book-wide conventions, numbering for a book drawn from a larger one, `book.json`, the agent
    prompt, step 6, what `check-book.sh` does, and reading the openings side by side.
  - Prompt items 1, 3 and 6, the file format, the tagging default and the gate's profile line
    name the primer.
- **`updatebook/SKILL.md`** holds a primer edit to `primer.md` alone.
- **`fixtures/primer`**, two chapters.
  - Chapter 1 has four sections, an H3, no header table and one 102-word paragraph, reported.
  - Chapter 2 has six of eight paragraphs at 85 words or more, which the clustering report names.
  - Its manifest row asserts both reports, and that chapter 1 draws no clustering report.
- README "Three profiles", NOTES.md "The primer profile, 2026-11-18", plugin 1.18.0.
- **After the first review.** Step 4's template, sizing, read-time and prompt items 2 and 5
  carry the primer, and the primer outline row gains Carries, Fills in and Stops short of.
  `primer.md` states the bulleted closing list, the block-quote and italics ban, and marks above
  the first paragraph. `check-book.sh` requires that mark under primer. `updatebook/SKILL.md`
  qualifies its handbook-only rules. `fixtures/primer` gains an appendix and an eight-paragraph
  chapter 1, and `fixtures/primer-failures` is new.
