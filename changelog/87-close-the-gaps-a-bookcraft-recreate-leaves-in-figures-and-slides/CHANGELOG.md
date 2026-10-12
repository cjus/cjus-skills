# Close the gaps a bookcraft recreate leaves in figures and slides

Start date: 2026-10-11 10:31:26 MDT

A `/createbook --recreate` counted every figure the old chapters placed, but `/makebook`'s
figure pass took only the old `diagrams/README.md` as its candidates, so a figure the README
never recorded could leave the book by drift. The recreate also copied the slide folder, but
nothing placed the copied slides, so the new book bound without them. This branch closes both
gaps.

## Changes

### 2026-10-11 11:00:32 MDT: the open questions are settled

The operator ruled on all four:
- The operator places slides through `/updatebook`, where the new lesson needs each one.
- The bind gets no warning for unplaced slides.
- No candidate list is recorded in the new folder.

### 2026-10-11 11:00:51 MDT: the figure pass takes every figure the old book placed

The candidates are the old README's placed figures plus every figure the old chapters place,
counted once each (`makebook § Deciding where a figure helps`). A candidate the README never
recorded is named by its old file name or `<title>`. The recreate's gate counts the same set and
names each figure only one record holds. Step 9, the candidates paragraph and § Notes point at
the old folder, and the binder's missing-README warning names both records. `NOTES.md` gains a
dated section. 18 of 18 fixtures, 221 citations.

### 2026-10-11 11:07:49 MDT: the operator places a recreate's slides through /updatebook

- **The recreate.** Step 9 lists the copied slides as not yet placed. The gate says the new
  chapters will place none, and a paragraph explains why.
- **`/updatebook`.** Gains a "Places a slide" row and § Placing slides.
- **Elsewhere.** The README's `--recreate` row is updated, `NOTES.md` records the three options
  weighed, and bookcraft goes from 1.12.1 to 1.13.0.

18 of 18 fixtures, 225 citations.

### 2026-10-12 09:25:42 MDT: the pre-test review's six findings, applied

The review approved, and the operator chose option A on finding 2.
- A slide goes before the paragraph that explains it, which is the paragraph its floating row
  prints beside. The first text had carried the figure rule across.
- Paragraphs added for slides are exempt from the several-at-once rewrite.
- The explanation is said to the reader, never as what to say over the slide.
- Slides are placed before outside citations are repointed.
- The bind's `slides:` line is described as a running total.
- The slide folder is left out of both candidate records.

`NOTES.md` records the correction and the ruling. A chapter rewrite dropping its figures and
slides, which was already true on `main`, went to Deferred. 18 of 18 fixtures, 227 citations.

### 2026-10-12 09:37:48 MDT: the close review's suggestions, applied

The close review approved. Recreate step order now repoints outside citations only once the
slides are placed. The unplaced-slide sentence names both reports. The summary's CI line and
diff size are corrected. Two items went to Deferred: the exemption not reaching the
accumulated-lettered-tags trigger, and which provenance mark a slide's explanation carries.
18 of 18 fixtures, 227 citations.
