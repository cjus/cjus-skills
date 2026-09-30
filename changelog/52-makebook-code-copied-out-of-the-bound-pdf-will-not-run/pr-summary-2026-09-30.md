# makebook: code copied out of the bound PDF will not run

## Overview

A reader who copies a fenced code block out of a `/makebook` PDF gets text Python cannot run. The ticket traced this to two causes, and this branch handles each one where it can actually be handled.

**The `_` split is fixed at its source.** It turned out to be the font size, not a style rule. Off a quarter pixel, Chromium writes each glyph of a code line into the PDF as its own text run. PDFKit (Preview, Safari) rebuilds lines from those runs, and because an underscore's glyph sits wholly below the baseline, each `_` lands on a line of its own: `for` / `_` / `in range(7):`. Every code size in the stylesheet is now rounded to a quarter pixel, and Chromium then writes each line as one run.

**The indentation cannot be fixed on the page, so the PDF now carries the scripts as files.** PDFKit drops every leading indent from the text layer whatever the font or size. The operator confirmed that only the PDF is handed out, so every block the book asks the reader to save is attached to the PDF as the file it names. A note printed under each block tells the reader to save the attachment rather than copy the text. `/makebook` warns about any save instruction it cannot tie to a block and a filename.

## Key changes

- **`plugins/bookcraft/skills/makebook/scripts/build-book.py`**
  - CSS: `.mono`, `code`, `pre`, `.chapter code`, `.chapter pre` and the note's filename are rounded with `round(nearest, ..., 0.25px)`. New `code_pt()` mirrors the rounding for the fenced-line width warning, whose thresholds (79, 67, 54) come out unchanged.
  - `find_scripts()`: walks markdown-it's tokens and pairs each save instruction with its block. Recognises `file=NAME` on the fence, or a save sentence in the adjacent paragraph. Returns the scripts, plus a gap for every save it cannot cover. `load_chapters` now parses and renders in two steps so the script fences can be marked with `data-script`.
  - `script_notes()`: PDF only. Prints the attachment note under each script block. The note's filename links to a reserved `https://bookcraft.invalid/attach/<ch>/<n>` marker.
  - `attach_scripts()`: runs after the final render. It uses `pypdf` to replace each marker link annotation with a FileAttachment annotation at the same rect, with an empty appearance so the printed filename shows through. It also adds every script to the document-level EmbeddedFiles name tree. A missing or leftover marker fails the bind.
  - `main`: prints `scripts: N attached to the PDF: name (p. N), ...`, and warns once per uncovered save instruction.
  - The EPUB strips the `data-script` marker and carries no note.
- **`plugins/bookcraft/skills/makebook/fixtures/save-scripts/`**: new fixture. It binds a two-chapter book that exercises every save case and checks the attachments, their contents, the warnings, text runs, PDFKit's copy, leftover markers, and the EPUB.
- **`plugins/bookcraft/skills/makebook/requirements.txt`**: adds `pypdf>=6.0`.
- **`plugins/bookcraft/skills/makebook/SKILL.md`**: new section *Code the reader is asked to save*. The Procedure's report step now includes scripts and gaps.
- **`plugins/bookcraft/README.md`**: lists the new fixture.
- **`.github/workflows/fixtures.yml`**: the comment now names both binding fixtures and `pdfdetach`.
- **`plugins/bookcraft/.claude-plugin/plugin.json`**: 1.8.0 → 1.9.0.

## Code examples

The rounding (`build-book.py`, `CSS_TEMPLATE`):

```css
.mono, code, pre { font-size: round(nearest, 1em, 0.25px); }
.chapter code { font-size: round(nearest, 0.86em, 0.25px); ... }
.chapter pre  { ... font-size: round(nearest, ${pre}pt, 0.25px); line-height: 1.42; ... }
```

The two ways a block is marked (`SKILL.md`, and the fixture's `save-01`):

````markdown
Save the script below as `time_species.py`.

```python
...
```

```python file=count_rounds.py
...
```
````

What the bind prints for the fixture book (`save-scripts/run.sh` asserts on it):

```
scripts: 4 attached to the PDF: time_species.py (p. 3), count_rounds.py (p. 3), in_a_list.py (p. 4), after.py (p. 5)
  warning: 2 instruction(s) to save code as a file have nothing attached, ...
    ch 2: "Save this script so you can run it again tomorrow:" names no file to save the block as; put the name on its fence: ```python file=NAME
    ch 2: "Save the script as `later.py` once you have written it." has no code block beside it
```

## Plan alignment

All five phases were completed as planned.

- **Phase 1, reproduce:** done. PDFKit dropped all indentation and split every `_`, in inline code as well as fences. poppler `-layout` kept the indents on a short block.
- **Phase 2, isolate the split:** done. The plan expected a style rule in `.chapter code` or `.chapter pre`, but bisection found none. The trigger is any font size that is not a quarter pixel. A sweep of 7 to 40px in five font stacks showed every quarter-pixel size writing one run. The fix is therefore a rounding rule rather than the removal of a rule. The cover's `.mono` folder name was a second place with the same problem, caught by the fixture.
- **Phase 3, delivery route:** embedded attachments, chosen after the operator confirmed only the PDF is handed out. EPUB copying was declared out of scope.
- **Phase 4, detection and warning:** done. The recognition rule is both `file=` and prose, per the operator. The warning stays for uncovered saves, also per the operator.
- **Phase 5, fixture, docs, version:** done.

**One deviation:** the ticket asked for a way to get each script "that works for the reader". Which common viewers actually offer an embedded file to a reader was not verified. See Testing and Deferred work.

## Testing

**Automated.** `plugins/bookcraft/scripts/test-fixtures.sh --strict` passes 18 of 18 on macOS, including the new `makebook/save-scripts/run.sh`, which checks that:

- `pdfdetach` lists exactly the four scripts, and not `later.py`;
- `time_species.py` and `in_a_list.py` match their blocks byte for byte, and every attached `.py` parses;
- the bind warns for the two uncovered saves and nothing else;
- every monospace text object in the PDF is written as one run;
- on macOS, PDFKit's copy of the whole book has `for _ in range(7):` intact and no lone `_` line;
- no marker link survives, and four FileAttachment annotations exist;
- the EPUB carries neither the note nor the marker.

**Revert check.** With the four `round()` rules stripped, the fixture fails twice: code lines are written in 15 to 31 runs, and PDFKit's copy reads `time` / `_` / `species.py`.

**By hand.**

- Bound the fixture book at 11.8, 14 and 17pt; PDFKit showed no lone `_` at any size.
- Extracted the attachments with `pdfdetach -saveall` and ran `time_species.py`.
- Looked at the rendered chapter page: the note sits under its block, set like a figure caption.
- `epubcheck` on the EPUB reported 0 errors and 0 warnings.
- A small harness confirmed each phrasing the docs promise, and that "save time with this loop", "save your work as you go" and "save the output as" attach nothing.

**Not verified.** Whether Adobe Acrobat Reader, Firefox, Chrome's built-in viewer or macOS Preview show the attachments to a reader. The browser extension cannot see inside Chrome's PDF viewer. PDFKit parses the annotations, but that says nothing about Preview's UI. The SKILL.md says this and tells the author to check the viewer their readers use.

## Impact assessment

11 files changed, 928 insertions, 12 deletions. About a third of the insertions are the plan folder.

- **New runtime dependency: `pypdf>=6.0`.** Anyone updating from 1.8.0 has to re-run `install.sh` once. Until they do, the binder stops at start-up, naming the missing package and the command. CI runs `install.sh`, so it picks up the dependency automatically.
- **Every bound book changes slightly.** Code prints at most 0.125px (under 0.1pt) off its previous size: at 14pt body, fenced code moves from 10.4pt to 10.3125pt. Page counts can shift where a code block sat on a page boundary.
- **Books with save instructions** gain a note under each saved block and grow by the size of the attached files.
- **A book with no save instructions** gets no note and no attachment, and the PDF is not rewritten.
- `attach_scripts` uses `PdfWriter._add_object`, the only way pypdf offers to make an object indirect. It is underscored, so a future pypdf could move it.
- No breaking change to the CLI or to `book.json`.

## Deferred work

The branch leaves these for later, as parked in `PLAN.md`:

- **Viewer support is unverified by hand.** Nobody has checked which of Acrobat Reader, Firefox, Chrome's viewer and Preview actually show the reader an attachment.
- **Duplicate listings.** A viewer panel that lists both the annotation and the EmbeddedFiles entry shows each script twice, as `pdfdetach` does.
- **`/createbook` could mark scripts itself.** Its guide profile could write `file=` on the fences of scripts it asks readers to save, instead of relying on the sentence.
- **Linux fonts are unmeasured.** The quarter-pixel rule was measured only on macOS fonts. The Linux CI leg will be the first measurement for Liberation Mono and DejaVu Sans Mono.
