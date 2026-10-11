# Verify which PDF viewers show makebook's attached scripts

## Overview

A bound book attaches every script it asks the reader to save in two places: as a
file-attachment annotation over the note printed under the block, and in the document's
list of embedded files. Until now, the only checks were that poppler's `pdfdetach` and
PDFKit could read them. The printed note told every reader to "double-click its name here,
or open your viewer's list of attachments", and `makebook/SKILL.md` said that no common
viewer had been checked.

This branch checks six viewers by hand and records the attachments panel and the
double-click separately for each. Only Firefox gives the reader the file. Preview, Safari,
Chrome and Edge show neither route. Acrobat Reader refuses a `.py` file on a double-click,
and its panel was left undetermined by the operator's choice. The note now tells readers to
open the PDF in Firefox and names the four viewers that show nothing. SKILL.md carries the
results as a table with each viewer's version, and tells a book's maker how to hand the
scripts out beside the book when readers may not use Firefox.

## Key changes

- **`plugins/bookcraft/skills/makebook/scripts/build-book.py:script_notes`.** The note under
  each attached block no longer promises the double-click or an attachments list in general.
  It names Firefox and the four viewers that show no attachments.
- **`plugins/bookcraft/skills/makebook/scripts/build-book.py:attach_scripts`.** The docstring
  now says SKILL.md records which common viewers do what. The result itself is written only
  in SKILL.md, so a re-measure updates one place.
- **`plugins/bookcraft/skills/makebook/SKILL.md` § Code the reader is asked to save.** The
  "Not checked" sentence is replaced by a six-row table of both routes with versions, and a
  paragraph naming who has no way to get a script out and what is undetermined. It also
  gives the commands for handing the scripts out: `mkdir <folder> && pdfdetach -saveall -o
  <folder> <book>.pdf` writes each script once, and `pdfdetach -save <n>` writes one at a
  time when two chapters save a file of the same name, since `-saveall` keeps only the later
  one.
- **`plugins/bookcraft/.claude-plugin/plugin.json`.** bookcraft 1.12.0 to 1.12.1. The change
  rewords output and docs and adds no capability, which matches earlier patch bumps.

## Code examples

The printed note, `plugins/bookcraft/skills/makebook/scripts/build-book.py:script_notes`.
Before:

```python
                f"{name}</a> is attached to this PDF. Copying the code off the "
                "page loses its indentation, so save the attachment instead: "
                "double-click its name here, or open your viewer's list of "
                "attachments.</p>")
```

After:

```python
                f"{name}</a> is attached to this PDF, because code copied off "
                "the page loses its indentation. To save it, open this PDF in "
                "Firefox and double-click the name here. Preview, Safari, "
                "Chrome and Edge do not show attachments.</p>")
```

The recorded results, `plugins/bookcraft/skills/makebook/SKILL.md`:

```markdown
| Viewer | Attachments panel | Double-click on the note's filename |
|---|---|---|
| Firefox 157.0.1 | offers the scripts | offers the script |
| Adobe Acrobat Reader 26.001 | not determined | refused: Acrobat does not allow a `.py` file out |
| Chrome 154 | none | nothing |
| Microsoft Edge 155 | none | nothing |
| Preview 11.0 | none | nothing |
| Safari 27.0 | none | nothing |
```

## Plan alignment

- **Phase 1, done as planned.** The fixture `fixtures/save-scripts/book` was bound with
  `build-book.py` against `main` at `142c189`. It carries seven scripts in the embedded-files
  list and seven file-attachment annotations, and `pdfdetach` lists 14. The fixture's
  `run.sh` passes all ten checks. The catalog sets no `/PageMode`, so no viewer is told to
  open its attachments panel on load. That is recorded, not changed.
- **Phase 2, done, with one cell undetermined.** All six viewers were checked by the operator
  on macOS 27.0 on 2026-10-11. Firefox, Acrobat Reader and Edge were installed for the
  purpose. Synthetic clicks from the browser extension did not reach Chrome's PDF viewer,
  so Chrome was checked by hand like the desktop apps. Acrobat Reader's attachments panel
  was left undetermined: the operator judged that it would change the note by one clause at
  most. The acceptance bar asks for both routes on every viewer, so that one cell is a
  stated deviation.
- **Phase 3, done.** The SKILL.md section states the result. The pre-test review found the
  first version's summary sentence claimed a negative for Acrobat's undetermined panel and
  for viewers nobody tried, and it was narrowed to the four measured ones.
- **Phase 4, done.** The note promised two routes. Both fail in Preview, Safari, Chrome and
  Edge, and Acrobat Reader refuses the double-click, so it was reworded.

## Testing

**By hand.** Bind any book that asks the reader to save a script, for example
`fixtures/save-scripts/book`, and open the PDF in Firefox. Double-click a filename in the
note under a block and confirm Firefox offers the file. Its attachments sidebar should list
the scripts too. Read the note on the page to confirm it reads well.

**Automated.** No test was added or changed: the change is a string and documentation, and
the viewer results cannot be measured headlessly. `plugins/bookcraft/scripts/test-fixtures.sh`
passes 18 of 18, including `makebook/save-scripts/run.sh`, which still finds seven attached
scripts, byte-identical blocks, and the note's annotation on each. `scripts/check-citations.py`
resolves 219 references. CI passed on all five jobs for both commits before the close.

**Edge cases considered.** The note still prints under all seven blocks in the fixture,
including the one inside a list item and the indented block. `pdfdetach -saveall -o` was run
on this branch's bind and wrote seven files, one per script, despite each script being listed
twice. The close review found the case the hand-out advice first missed: two chapters that
save a file of the same name, which the binder allows on purpose. `-saveall` then keeps only
the later chapter's file, so SKILL.md now says so and gives `pdfdetach -save <n>`, checked on
this branch's bind. `-saveall` into a folder that does not exist fails with exit 2, so the
command creates it first.

## Impact assessment

- **Files changed:** 3 in the plugin (`build-book.py`, `makebook/SKILL.md`, `plugin.json`), plus
  the plan folder.
- **Lines:** in the plugin, 21 added and 8 removed.
- **Dependencies:** none added or changed.
- **Breaking changes:** none. Every PDF bound from now on prints the new note. A PDF already
  bound keeps the old note until it is rebound.

## Deferred work

Of the six viewers checked, only Firefox gives the reader an attached script. Rewording the
note makes it truthful, but a reader in Preview, Safari, Chrome or Edge still has no way to
get the scripts out of the PDF, and that is the problem the attachments were added to
solve. Getting the code to those readers another way is new work: a link to a hosted copy of
each script works in every viewer, and files shipped beside the PDF work wherever the book is
handed out as a folder or an archive. The operator accepted the attachments as a partial route
on 2026-10-11.

Whether the first guide asking students to save scripts has already gone out is unknown. If it
has, its readers on those viewers need word through a channel outside this repo.
