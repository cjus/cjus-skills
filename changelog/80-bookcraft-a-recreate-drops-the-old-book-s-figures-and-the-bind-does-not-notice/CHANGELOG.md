# bookcraft: a recreate drops the old book's figures, and the bind does not notice

Start date: 2026-10-10 19:40:16 MDT

A `/createbook --recreate` leaves the old book's figures, and the `diagrams/README.md` recording
them, behind in the old folder, and `/makebook` binds the new book without noticing. This
branch makes a recreate account for the old figures and the slide folder, and makes the bind
warn when a book's figure decisions were never recorded.

## Changes

### 2026-10-10 19:55:18 MDT: figures are redrawn, never carried

The operator settled the first open question (`PLAN.md § Open Questions`). A recreate copies no
figure and no `diagrams/README.md`. `/makebook`'s figure pass redraws every figure against the
new prose, with the old README as its candidates, and records each one as drawn again or passed
over. This is the same rule the recreate already applies to the old chapters, and a copied README
would silence the bind warning before the figure pass had run. Slides are copied, because they
are source material rather than figures drawn from the prose.

The CI fixture question was answered from the code, wrongly at first: see the 20:07 entry.

### 2026-10-10 19:57:07 MDT: the recreate accounts for the old figures

- `createbook/SKILL.md § Recreating a book`: step 4 copies the `slide_figures` folder, and a new
  step 9 row names `/makebook`'s figure pass as due. The gate grows from three items to five,
  adding how many figures the old book placed (with what its README records) and how many
  slides will be copied. Two new paragraphs say why a recreate carries no figure, and that the
  old README goes to the figure pass as candidates.
- `createbook/SKILL.md § Notes`: the line saying figures land in `diagrams/` only when
  `/makebook` runs now covers the recreate case.
- `makebook/SKILL.md § Deciding where a figure helps`: a book replacing an earlier edition reads
  the old README as candidates, records each as placed again or passed over, and redraws every
  figure it places again.
- `createbook/NOTES.md` gains § Figures across a recreate, 2026-10-10.

The prose already names the bind warning, which `build-book.py` gets next. Verified:
`check-citations.py` reports 216 citations resolving, and no added line carries an em dash.

### 2026-10-10 20:07:42 MDT: the bind warns when a book's figure decisions were never recorded

- `build-book.py`: `figure_record_missing` is true when a folder set up as a book (a `book.json`
  or an `assertions.json`) has no `diagrams/README.md`. The bind report then warns that the
  figure decisions were never recorded, with the figure count, and points at the figure pass.
  A plain folder of markdown is never asked for one.
- `makebook/SKILL.md § Deciding where a figure helps`: a book that rightly has no figures writes
  the README too, and the paragraph names the warning.
- **Correction.** The CI fixture question was first answered from three books, all with no
  `book.json`. `bind/run.sh` also binds `createbook/fixtures/guide` twice, and that book has a
  `book.json` and a figure, so the warning would have fired on both binds. It now carries
  `diagrams/README.md`, recording its one figure and the two places passed over.
- `bind/run.sh`: the first guide bind must not warn, the second removes the README and must warn
  with a count of 1 figure, and `appendix-slug`, a folder with no `book.json`, must not warn.
  Two mutations of the binder each fail exactly one of these: a warning that never fires, and
  a warning with no scoping.

Verified: `test-fixtures.sh --strict` passes 18 of 18, with `bind/run.sh` adding three checks,
and `check-citations.py` reports 217 citations resolving.

### 2026-10-10 20:18:47 MDT: no checker line for a forgotten candidate

The operator settled the last open question: the `check-book.sh` REVIEW line is not built, and
neither input (a flag or a `book.json` field) is added. `check-book.sh` runs before the figure
pass, so it would name every old figure on every recreate. Either input would point outside
the book folder at a folder the operator later deletes. The bind warning already catches the
measured failure.

- `makebook/SKILL.md`: the report gives the candidates placed again and passed over, which must
  add up to the candidate count. Procedure step 7 names both counts.
- `createbook/NOTES.md § Figures across a recreate` records the ruling, and what a later check
  would look like if a recreate ever shows a candidate dropped without a reason.
- The review on #80 said `check-book.sh` reads `diagrams/README.md`. It does not.
  `check-provenance.sh` does.

Verified: `check-citations.py` reports 218 citations resolving.

### 2026-10-11 08:21:21 MDT: release

- `plugin.json`: bookcraft 1.11.0 to 1.12.0.
- `plugins/bookcraft/README.md`: the folder layout lists `diagrams/README.md`, and the
  `--recreate` row says slides are copied and figures redrawn. The Figures section explains the
  record and the warning, and the troubleshooting table gains a row for the warning.

Verified: `test-fixtures.sh --strict` passes 18 of 18, `bind/run.sh` passes 22 of 22,
`check-citations.py` reports 218 citations resolving, and no added line carries an em dash.
