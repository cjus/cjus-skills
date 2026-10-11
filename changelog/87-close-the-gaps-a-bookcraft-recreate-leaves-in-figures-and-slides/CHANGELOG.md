# Close the gaps a bookcraft recreate leaves in figures and slides

Start date: 2026-10-11 10:31:26 MDT

A `/createbook --recreate` counts every figure the old chapters placed, but `/makebook`'s
figure pass takes only the old `diagrams/README.md` as its candidates, so a figure the README
never recorded can leave the book by drift. The recreate also copies the slide folder, but
nothing places the copied slides in the new chapters, so the new book binds without them. This
branch closes both gaps.

## Changes

### 2026-10-11 11:00:32 MDT: the open questions are settled

The operator ruled on all four questions.
- **Slides:** placed by the operator through `/updatebook`, wherever the new lesson needs each one.
- **Bind:** gets no warning for unplaced slides.
- **Figure candidates:** no recorded list goes into the new folder.

### 2026-10-11 11:00:51 MDT: the figure pass takes every figure the old book placed

- **`makebook/SKILL.md § Deciding where a figure helps`.** The candidates are the old README's
  placed figures plus every figure the old chapters place, outside the slide folder, with a
  figure in both counted once. A candidate the README never recorded is named in the new README
  by its old file name or `<title>`, and its old chapter.
- **`createbook/SKILL.md § Recreating a book`.** The gate counts the same set and names each
  figure only one record holds. Step 9, the candidates paragraph and the folder note in
  § Notes name the old folder, not the old README.
- **`build-book.py`.** The missing-record warning's last sentence names both records. No
  fixture asserts that sentence.
- **`createbook/NOTES.md`.** Gains § Figure candidates across a recreate, 2026-10-11.

The suite passes 18 of 18, and 221 citations resolve.

### 2026-10-11 11:07:49 MDT: the operator places a recreate's slides through /updatebook

- **`createbook/SKILL.md § Recreating a book`.** Step 9's report lists every copied slide as not
  yet placed, and names `/updatebook` to place them. The gate's slide count says the new chapters
  will place none. A new paragraph explains why drafting places no slide, and why placing one
  later moves no tag. § Notes covers it too.
- **`updatebook/SKILL.md`.** Gains a "Places a slide" row in step 2's table, and § Placing
  slides: where the lesson needs it, the slide folder's path prefix, the paragraph beside it as
  its notes, a slide left unplaced with a reason, and what to report.
- **`README.md`.** The `--recreate` row says how slides get placed.
- **`createbook/NOTES.md`.** Gains § Slides across a recreate, 2026-10-11, with the three
  options weighed.
- **`plugin.json`.** 1.12.1 to 1.13.0.

The suite passes 18 of 18, and 225 citations resolve.
