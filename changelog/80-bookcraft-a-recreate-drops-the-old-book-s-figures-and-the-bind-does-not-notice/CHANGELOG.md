# bookcraft: a recreate drops the old book's figures, and the bind does not notice

Start date: 2026-10-10 19:40:16 MDT

A `/createbook --recreate` leaves the old book's figures, and the `diagrams/README.md` recording
them, behind in the old folder, and `/makebook` binds the new book without noticing. This
branch makes a recreate account for the old figures and the slide folder, and makes the bind
warn when a book's figure decisions were never recorded.

## Changes

### 2026-10-10 19:55:18 MDT: figures are redrawn, never carried

The operator ruled on the first open question. A recreate copies no figure and no README.
`/makebook`'s figure pass redraws every figure against the new prose, with the old README as its
candidates. Slides are copied, because they are source material. The CI fixture question was
answered here too, wrongly at first (see 20:07).

### 2026-10-10 19:57:07 MDT: the recreate accounts for the old figures

- **`createbook/SKILL.md § Recreating a book`.** Step 4 copies the slide folder, and a new step 9
  row names the figure pass as due. The gate grows from three items to five: the old figure
  count, and the slide count. Two new paragraphs explain why no figure is carried.
- **`createbook/SKILL.md § Notes`.** Covers the recreate case.
- **`makebook/SKILL.md`.** Gains the candidates paragraph.
- **`createbook/NOTES.md`.** Gains § Figures across a recreate, 2026-10-10.

Citations: 216 resolve.

### 2026-10-10 20:07:42 MDT: the bind warns when a book's figure decisions were never recorded

- **`build-book.py`.** `figure_record_missing`, and a warning, scoped to folders with a
  `book.json` or an `assertions.json`.
- **`makebook/SKILL.md`.** A book with no figures still writes the README.
- **Correction.** `bind/run.sh` also binds `createbook/fixtures/guide`, which has a `book.json`
  and a figure. It now carries `diagrams/README.md`.
- **`bind/run.sh`.** Three new assertions. Two mutations of the binder each fail exactly one of
  them.

The suite passes 18 of 18, and 217 citations resolve.

### 2026-10-10 20:18:47 MDT: no checker line for a forgotten candidate

The operator ruled that the `check-book.sh` REVIEW line is not built, and no flag or `book.json`
field is added. That checker runs before the figure pass, and either input would point at a
folder that gets deleted. `makebook/SKILL.md`'s report now gives placed-again and passed-over
counts that must add up. NOTES records the ruling. 218 citations resolve.

### 2026-10-11 08:21:21 MDT: release

bookcraft 1.11.0 to 1.12.0, and `plugins/bookcraft/README.md` is updated for the record and the
warning. The suite passes 18 of 18, and `bind/run.sh` 22 of 22. Committed as `030fead`.

### 2026-10-11 08:55:22 MDT: pre-test and close

- **Draft PR #81.** CI passes all five jobs.
- **Pre-test review (`pr-review-2026-10-11.md`).** APPROVE: four optional suggestions, not
  taken, and two deferred DROP items, now in `PLAN.md § Deferred`.
- **Close-gate review (`pr-review-2026-10-11-close.md`).** APPROVE. It corrected two lines in
  `pr-summary-2026-10-11.md`: the file counts, and the reason the guide fixture's README affects
  no other fixture.
