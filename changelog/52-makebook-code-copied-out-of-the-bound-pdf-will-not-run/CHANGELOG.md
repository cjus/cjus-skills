# makebook: code copied out of the bound PDF will not run

Start date: 2026-09-30 11:49:24 MDT

A reader who copies a fenced code block out of a `/makebook` PDF gets text Python cannot run.
This branch fixes the binder's own contribution, the `_` split, and gives the reader a working
way to get each script the book asks them to save. It also makes `/makebook` report the gap
wherever it remains, so the book is not shipped with it silently.

## Changes

### 2026-09-30

- **The `_` split was a font size, not a style rule.** Bisecting the code styling on a bare page
  found no rule that splits; changing the font size alone did. Off a quarter pixel, Chromium
  writes each glyph of a code line as its own text run, and PDFKit rebuilds lines from runs, so
  an underscore, whose glyph sits wholly below the baseline, lands on a line of its own. Every
  code size (`.mono`, `code`, `pre`, `.chapter code`, `.chapter pre`, the note's filename) is now
  rounded with CSS `round(nearest, ..., 0.25px)`. `code_pt` mirrors the rounding for the
  fenced-line width warning, whose thresholds (79, 67, 54) are unchanged.
- **Scripts travel inside the PDF.** The operator confirmed only the PDF is handed out, so every
  block the book asks the reader to save is attached as the file it names: a FileAttachment
  annotation over a note printed under the block, and an EmbeddedFiles entry for attachments
  panels. The note's filename is a link to a reserved `.invalid` URI; Chromium draws the link
  annotation exactly over it, and `attach_scripts` swaps it for the attachment, so nothing
  measures the page. A link left over, or a script with no link, fails the bind. Adds `pypdf`.
- **A save is found two ways.** `file=NAME` on the fence is exact. A save sentence in the
  paragraph beside the block ("Save the script below as `x.py`", "... above as ...", "Create a
  file named `x.py`") covers books already written. "Save the output as" is read as being about
  the output. The bind warns for a save that names no file and for a named file with no block
  beside it, and a block one sentence asked about cannot be claimed by the next.
- **Tested by `makebook/fixtures/save-scripts/`**, which binds a book covering each case and
  checks the attachments byte for byte, the warnings, one text run per code line, PDFKit's copy
  on macOS, no leftover marker link, and an EPUB without the note. Reverting the rounding fails
  it. bookcraft 1.8.0 -> 1.9.0; updating needs one more `install.sh` run.
- **Not verified:** which common viewers offer the attachments to a reader. Only `pdfdetach` and
  PDFKit's parsing were checked; Chrome's PDF viewer was out of reach of the browser extension.
