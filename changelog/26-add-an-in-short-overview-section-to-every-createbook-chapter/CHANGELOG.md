# Add an `## In short` overview section to every createbook chapter

Start date: 2026-09-20 07:37:04 MDT

Give every createbook chapter a short overview directly after the chapter header table, for a
reader who has not read it or who read the ones before it a month ago. It holds a **carried-in
line** naming the concepts the chapter reintroduces from earlier ones, worded from the glossary
and cited `(ch. N)`, and then the **walk** through what the chapter argues. Opt-in through
`"overview": true`, absent by default.

## Changes

- 2026-09-20 — Objective refreshed from the updated ticket, before any work landed. The section
  gained its carried-in half, the no-glossed-term rule gained a carried-term exemption, and the
  checker work grew from four changes to five.

- 2026-09-20 — **Decision: the carried-in line requires the literal `Carried in: ` prefix.** The
  checker finds the line by that prefix and nothing else. Inferring it from its first
  `**term** (ch. N)` was rejected because both failure modes read as passes: a walk opening on a
  glossed term gets swallowed, and a line whose first term lost its bold gets skipped.

- 2026-09-20 — **Decision: the walk's no-glossed-term rule is written and reviewed, not checked.**
  The record it would check against is `OUTLINE.md`, which the checker does not read, and the
  comparison does not survive scripting (`SKILL.md:215` records a substring match calling "the
  query plan" glossed by "query planner"). Holds the checker to `book.json` as its only config
  source and keeps phases 3 to 5 at their scoped size.

- 2026-09-20 — **Decision: the at-most-three ceiling is checked.** A hard failure above three,
  counting bolded terms, gated on `overview` alone since counting needs no definitions. Checked
  where the walk's rule is not, because the line is found by a fixed prefix and a count has
  nothing to compare.

- 2026-09-20 — Merged `main` (fast-forward, no conflicts; its four commits touched only READMEs).

- 2026-09-20 — **Phase 1 landed.** `chapter-prose.md` gains `### In short` between
  `### The chapter header` and `### Paragraph tags`. Two edits beyond the new section: `§ Headings`
  said only one H2 is not a part and there are two now, and `§ Before sending` grew a fifth
  bullet, which is where the walk's rule is actually enforced given it is not scripted.

- 2026-09-20 — **Phases 2 to 7 landed.** `SKILL.md` carries the section through the file format
  example, step 4's `book.json`, the step 5 prompt and a new step 6 pass; `check-book.sh` gains
  eight changes; `fixtures/overview/` is a new control; `NOTES.md` records the decisions and
  bookcraft goes to 1.1.0. **Step 6 writes the section, not step 5**: the carried-in line takes
  its words from a glossary that does not exist while chapters are being drafted. Two silent bugs
  found by the fixture: the carried-in line is a paragraph rather than a physical line, and the
  section has no end marker, so the sweeps end it at the first tag, failing that the first marked
  paragraph, failing that the next part heading.

- 2026-09-20 — **`check-book.sh` now stops on a jq that is present but will not run.**
  `/usr/local/bin/jq` here is an x86_64 binary from 2022 failing on arm64 and shadowing a working
  `/usr/bin/jq`; every jq call is `2>/dev/null`, so each declaration read as absent and every book
  had been checked in the weakest mode while `book.json` declared otherwise. Confirmed
  pre-existing against `fixtures/fence`. jq missing stays supported; jq broken is now exit 2.
  Exposed `declared_ovw` unbound under `set -u` on the no-jq path, fixed.

- 2026-09-20 — **Round-one review: REQUEST_CHANGES, three real defects, all fixed.** Blocking: the
  glossary cross-check aborted the whole run on a book where no chapter carries a term in, since
  bash 3.2 expands `"${arr[@]}"` on an empty array to an unbound variable under `set -u`. Every
  single-chapter book has that shape; `fixtures/overview-nothing-carried/` now holds it and
  reproduces the abort pre-fix. Also: rules gated on the heading being present rather than on the
  declaration, and a section-end range that ran to EOF and swallowed the chapter.

- 2026-09-20 — **Round-two review: APPROVE, with two regressions the fixes introduced, both
  fixed.** Gating recognition on the declaration broke the no-jq fallback, so a declared book
  failed where an undeclared one passed; recognition is now structural (first H2 with the header
  table immediately before it) and only the checks need the declaration. And the trailing space
  made `Carried in:` silently unchecked, so a typo switched off both the ceiling and the
  cross-check; the prefix is matched loosely to find the line and exactly to validate it.
  Correction: the earlier section-extent fix corrected the disclosure, not the extent.
