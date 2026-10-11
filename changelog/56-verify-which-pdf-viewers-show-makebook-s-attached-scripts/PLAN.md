# Verify which PDF viewers show makebook's attached scripts

Start date: 2026-10-08 13:58:04 MDT

Ticket: #56 (status:todo -> status:in-progress)

## Overview

A bound book attaches every script the reader is asked to save, twice: as a
FileAttachment annotation over the note printed under the block, and in the document's
EmbeddedFiles list. Only poppler's `pdfdetach` and PDFKit's annotation parsing have been
checked. Whether a reader can actually find and save an attachment in the viewers readers
use has not been.

The objective is to record, for each common viewer, whether it offers the attached scripts
to a reader, and to make makebook's documentation and the printed note match what was found.
In full:

1. Each viewer is recorded as shows or does not show, with the attachments panel and a
   double-click on the note's filename recorded separately: Adobe Acrobat Reader, Firefox's
   built-in viewer, Chrome's built-in viewer and Edge's, macOS Preview, and Safari.
2. `plugins/bookcraft/skills/makebook/SKILL.md` § Code the reader is asked to save states
   the result.
3. The note under each block is reworded if it promises something a common viewer does not
   do.

Acceptance: every viewer above has a recorded result for both surfaces, taken from a book
bound from `plugins/bookcraft/skills/makebook/fixtures/save-scripts/book` with
`build-book.py`, and the SKILL.md section and the printed note agree with those results.

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred`, never as new scope.

## Plan

- [x] Phase 1: Bind `fixtures/save-scripts/book` with `build-book.py` and confirm, with
      `pdfdetach`, that both attachment surfaces are present in the PDF under test.
      Done 2026-10-11 against `main` @ `142c189`: 7 scripts in the EmbeddedFiles name
      tree, 7 FileAttachment annotations (pp. 3-6, `/Paperclip`, print flag), 14 listed
      by `pdfdetach`; `fixtures/save-scripts/run.sh` passes all ten checks. The catalog
      sets no `/PageMode`, so no viewer is told to open its attachments panel on load.
- [x] Phase 2: Open that PDF in each viewer and record the attachments panel and the
      double-click on the note's filename separately. All operator-run on macOS 27.0,
      2026-10-11; synthetic clicks from the browser extension do not reach Chrome's PDF
      viewer, and the other five are desktop apps.
  - [x] Adobe Acrobat Reader
        Acrobat Reader 26.001.21662: panel **not determined**; double-click **refused**,
        Acrobat does not allow a `.py` file out. The operator accepted the panel as
        unrecorded rather than chase it, since it would change the note by one clause.
  - [x] Firefox's built-in viewer
        Firefox 157.0.1: panel **shows**; double-click **shows**.
  - [x] Chrome's built-in viewer, and Edge's
        Chrome 154.0.8037.98: panel **does not show** (sidebar has only Thumbnails and
        Outline, nothing in the ⋮ menu); double-click **does not show**.
        Edge 155.0.4283.45: panel **does not show**; double-click **does not show**.
  - [x] macOS Preview
        Preview 11.0 on macOS 27.0, 2026-10-11: panel **does not show**; double-click
        **does not show**. Operator-run.
  - [x] Safari
        Safari 27.0 on macOS 27.0, 2026-10-11: panel **does not show**; double-click
        **does not show**. Operator-run.
- [x] Phase 3: State the result in `makebook/SKILL.md` § Code the reader is asked to save,
      replacing the "Not checked" sentence. Done: a six-row table of both surfaces, with
      versions, and a line telling the book's maker to hand the scripts out beside the
      book when readers may not use Firefox.
- [x] Phase 4: Reword the note under each attached block if it promises something a common
      viewer does not do. Done in `build-book.py:script_notes`: the note now names Firefox
      and the four viewers that show nothing, and promises neither route generally.
      `attach_scripts`'s docstring points at the result. bookcraft 1.12.0 -> 1.12.1.
      `test-fixtures.sh` passes 18 of 18; `check-citations.py` resolves 219.

## Open Questions

- Which of these viewers are installed on this machine? Acrobat Reader, Firefox and Edge
  may not be, and a double-click on an annotation inside a viewer is a hands-on check, so
  part of Phase 2 is the operator's to run and report.
  Partly answered 2026-10-11: Chrome, Safari and Preview are installed and checked;
  Acrobat Reader, Firefox and Edge are not installed. The operator ruled: install them
  on this Mac and run the same two checks. Answered: all six checked; see Phase 2.
- The occasion was the first guide that asks readers to save scripts reaching students the
  week of October 5, 2026. If it has already gone out and a common viewer turns out not to
  offer the scripts, readers need word through a channel outside this repo.
  2026-10-11: Preview, Safari and Chrome do not offer them. The operator is not sure
  whether the guide went out; that needs checking outside this repo.

## About Ticket

**#56: Verify which PDF viewers show makebook's attached scripts** ·
https://github.com/cjus/cjus-skills/issues/56 · priority:high

Bound books now carry every script a reader is asked to save as a PDF attachment, because code copied off the page loses its indentation. Each script is attached twice: as a FileAttachment annotation over the note printed under its block, and in the document-level EmbeddedFiles list.

Only two things were checked: poppler's `pdfdetach` lists and extracts both, and PDFKit parses the annotations. Whether a reader can actually find and save an attachment in the viewers they use was not checked.

**Symptom if a common viewer hides them:** a reader following "Save the script below as `x.py`" has no working way to get the script.

**Occasion:** before the first guide book that asks readers to save scripts goes to students, the week of October 5, 2026.

**Done when:**

- [ ] Each viewer below is recorded as shows or does not show, with the attachments panel and a double-click on the note's filename recorded separately:
  - [ ] Adobe Acrobat Reader
  - [ ] Firefox's built-in viewer
  - [ ] Chrome's built-in viewer, and Edge's
  - [ ] macOS Preview
  - [ ] Safari
- [ ] `plugins/bookcraft/skills/makebook/SKILL.md` § Code the reader is asked to save states the result.
- [ ] The note under each block is reworded if it promises something a common viewer does not do.

**Test input:** bind `plugins/bookcraft/skills/makebook/fixtures/save-scripts/book` with `build-book.py`.

Triage stamp, 2026-10-08 against `main` @ `2231a04`: still valid. `makebook/SKILL.md:453`
still records Acrobat Reader, Firefox, Chrome's built-in viewer and Preview as not checked.

## Deferred

- 2026-10-11: Of six viewers, only Firefox offers the attached scripts. Preview, Safari,
  Chrome and Edge show neither surface, and Acrobat Reader refuses a `.py` file on a
  double-click. Rewording the note (Phase 4) makes it truthful but gives readers in those
  viewers no way to get the scripts. Getting the code to them some other way is new work:
  a link to a hosted copy of each script works in every viewer, and files shipped beside
  the PDF work wherever the book is handed out as a folder or archive. The operator
  accepted the attachments as a partial route on 2026-10-11.
