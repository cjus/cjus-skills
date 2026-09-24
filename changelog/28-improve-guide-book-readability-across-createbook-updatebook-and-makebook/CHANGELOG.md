# Improve guide-book readability across createbook, updatebook and makebook

Start date: 2026-09-24 07:44:16 MDT

Change the book skills so a guide book reads the way a guide is used, one chapter at a time
when it is needed, and so revising a finished chapter does not wear it down. The changes cover
the `createbook` prose spec and procedure, `check-book.sh`, `/updatebook`'s edit rules and
`/makebook`'s bind. Ticket #28.

## Changes

### 2026-09-24 — Rewrite or recreate, and the reference guide

**The reference teaching guide will be recreated under the new rules, not patched**: its
defects come from the rules, so they are in every chapter, and splitting its 46 long
paragraphs would renumber tags throughout chapters 1 to 4 anyway. **Phase 5 gained a three-level
rule**, edit, rewrite one chapter, or recreate the book, with revision facts moved into
`OUTLINE.md` before any rewrite. That decision settled the paragraph stop (fail a guide) and
the renumber trigger for lettered tags (a chapter rewrite).

### 2026-09-24 — The open questions, settled

All settled by the operator: the core keeps the name `chapter-prose.md`, beside `guide.md` and
`narration.md`; tags take a letter suffix, `[1-2a]`, over a decimal one or always
renumbering; a guide declares `"edition": "reading"` in `book.json`, keeping `/makebook`'s
two-file contract; `This chapter` merges into `## In short` under `guide`; and Phase 7 is a
blind read by the operator, run in the source repo.

### 2026-09-24 — Phases 1 to 4: the rule files, the guide path, the summary and the checks

**Phase 1.** The split, with reasoning moved to `NOTES.md` and the core and `guide.md` written
in the style they ask for ("rather than" 63 uses to 1, "carry" 62 to 12). `narration.md` moved
unchanged; `guide.md` gained before-and-after examples, the heading test and "a shape, not a
script". An audit found eight lost rules, six weakened and four contradictions; all fixed but
one kept on purpose (a guide part walks a mechanism only where it explains one).

**Phase 2.** No handoff chain under `guide`: a **Scope** outline row replaces **Opens on** and
**Closes on**; the opening orients; the close lands the main point or next step.

**Phase 3.** `## In short` is a guide chapter's one summary: its own terms with a short
definition, near 120 words, no reused sentences; `This chapter` merged into it.

**Phase 4.** A paragraph over 90 words fails a guide and is reported under narration, plus six
new reports. Fixtures `guide-reports/` and `paragraph-stop/`.

### 2026-09-24 — Phases 5 and 6: revising without wear, and what the reader is handed

**Phase 5.** Lettered tags, accepted by all five programs that read a tag, which also closed
`check-references.sh`'s blindness to appendix tags. `/updatebook` reordered its edits, split
out cutting, added the premise row and `§ When to stop editing in place`. Fixture
`lettered-tags/`, which the pre-change checkers fail.

**Phase 6.** A guide binds the reading edition by default; display names replace path keys in
the header and so in the endnotes; the page markers are hidden in the finished PDF, checked
against the probed render. Verified by hand: 13 pages before and after, 9 markers to none.
bookcraft bumped to 1.6.0.

### 2026-09-24 — /pr:pre-test review fixes

The pre-test review (REQUEST_CHANGES) found the swap touching the reader's `Act on this` row;
it is scoped to `Draws on` and `Fills in` and pinned by `makebook/fixtures/display-names/`. A
second, independent review found the swap doubling articles in 34 real header rows (now
path-like keys only, keeping an existing article), check 4 missing a relettered run (now a
slide), and an unanchored appendix pattern (now anchored); each pinned by a fixture case that
fails against the earlier code. Also: the marker comparison collapses whitespace first,
leading-zero citations resolve as on `main`, and an untagged guide's opening-paragraph gap is
disclosed in the run's note. Suite 15 of 15.

### 2026-09-24 — Synced with main, and bumped to 1.7.0

Merged `main` at `ee9a8e1` (#26, #31). Clean, and checked where it overlapped: #31's bind stamp
is read once per run, so the hidden-marker render matches the probed one. #31 had also bumped
bookcraft to 1.6.0, so this branch is now **1.7.0**.

### 2026-09-24 — Phase 7 split to #34

The blind reader comparison is #34, by operator decision: it needs the operator as reader and
runs in the source repo. The rules merge first; the reference guide waits for #34.
