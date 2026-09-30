# makebook: code copied out of the bound PDF will not run

Start date: 2026-09-30 11:49:24 MDT

Ticket: #52 (status:todo -> status:in-progress)

## Overview

Guide books tell readers to save scripts from the page, but a fenced code block copied out of
a `/makebook` PDF does not run. The failure has two separate causes. The first is Chromium:
its PDF text layer drops leading indentation under PDFKit whatever font is used, so no
stylesheet change can restore it. The second is the binder: the book page's code styling
splits the text run so that each `_` lands on a line of its own, which a bare `<pre><code>`
page does not do.

The objective is to finish the three items under the ticket's "Done when":

1. Find and fix the underscore split, so that a copied block keeps every `_` inline.
2. Give a bound book a working way for the reader to get each script it asks them to save,
   since the PDF's text layer cannot carry indentation.
3. Make `/makebook` warn when a book asks the reader to save a code block as a file and no
   working route covers it, so the gap is reported rather than shipped.

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred`, never as new scope.

## About Ticket

**#52: makebook: code copied out of the bound PDF will not run**

Labels at start: `bug`, `status:todo`, `priority:high`.

> A reader who copies a fenced code block out of a `/makebook` PDF gets text Python cannot run.
> Guide books tell readers to save scripts from the page ("Save the script below as
> `time_species.py`"), so every such step fails for anyone who copies instead of typing.
>
> **What comes out.** Measured 2026-09-27 on bookcraft 1.8.0, bound at 14pt with Playwright's
> Chromium 151.
>
> | Reader engine | Result |
> |---|---|
> | PDFKit (macOS Preview), one selection across the block | Every leading indent and every blank line is dropped, and each `_` lands on a line of its own: `for` / `_` / `in range(7):`, `time.perf` / `counter()` |
> | poppler, `pdftotext -layout` | Line breaks survive, but the indentation drifts with column position; a 205-line script failed with `IndentationError` |
>
> Chrome's built-in viewer, Acrobat, and copying from the EPUB in a reader app were not tested.
>
> **Two causes, and they separate.**
>
> - **Indentation is Chromium's.** A bare page holding one `<pre><code>` block, printed with
>   `page.pdf()`, loses its leading indentation under PDFKit in all four fonts tried: the
>   binder's own stack (`"SF Mono", Menlo, Consolas, "Liberation Mono", monospace`), Menlo,
>   Courier and Courier New. No stylesheet change in the binder can restore it.
> - **The underscore split is the binder's.** The same bare page keeps every `_` inline in all
>   four fonts, so something in the book page's code styling splits the text run. The
>   `.chapter pre` and `.chapter code` rules are the likely place; it is not isolated yet.
>
> **Reproduce.** Bind any book with a fenced Python block that has an indented body, then run
> this against the PDF:
>
> ```swift
> // swift pdfkit_text.swift book.pdf <first-page> <last-page>
> import Foundation
> import PDFKit
> let a = CommandLine.arguments
> let doc = PDFDocument(url: URL(fileURLWithPath: a[1]))!
> let s = doc.page(at: Int(a[2])! - 1)!, e = doc.page(at: Int(a[3])! - 1)!
> print(doc.selection(from: s, atCharacterIndex: 0,
>                     to: e, atCharacterIndex: e.numberOfCharacters - 1)!.string ?? "")
> ```
>
> **Done when:**
>
> - [ ] The underscore split is found and fixed, and a copied block keeps every `_` inline.
> - [ ] A bound book gives the reader a working way to get each script it asks them to save,
>   since the PDF's text layer cannot carry indentation. Options worth weighing: attach the
>   scripts to the PDF as embedded files, write them beside the book, or verify copying from
>   the EPUB and say so in the book.
> - [ ] Until then, `/makebook` warns when a book asks the reader to save a code block as a
>   file, so the gap is reported rather than shipped.
>
> **Occasion:** before the next guide book that tells readers to save a script from the page
> is handed out. The first is a course guide going to students the week of October 5, 2026.

## Plan

- [x] Phase 1: Reproduce. Bind a small fixture book with an indented Python block containing
  `_` identifiers, and capture the PDFKit and `pdftotext -layout` text for it as the baseline.
  *PDFKit: every indent and blank line dropped, and every `_` on a line of its own, in inline
  code in the prose as well as in the fence. poppler `-layout`: indents intact on a 10-line
  block.*
- [x] Phase 2: Isolate the underscore split by bisecting the code styling in
  `plugins/bookcraft/skills/makebook/scripts/build-book.py` (`.chapter code`, `.chapter pre`,
  `.chapter pre code`, and anything else that reaches a code run: hyphenation, `word-break`,
  `overflow-wrap`, letter-spacing, font features). Fix it, and confirm every `_` stays inline.
  *No style rule causes it: the font size does. Off a quarter pixel, Chromium writes each glyph
  of a code line as its own text run (`Tj` + `Td` per glyph), and PDFKit puts each `_` on its
  own line. Every quarter-pixel size 7-40px in five font stacks writes one run. Fixed by
  rounding every code size with `round(nearest, ..., 0.25px)` (`.mono`, `code`, `pre`,
  `.chapter code`, `.chapter pre`, the note's filename).*
- [x] Phase 3: Weigh the delivery options (embedded PDF attachments, files written beside the
  book, verified EPUB copying) against what readers can actually open. Pick one and implement it.
  *Embedded attachments (only the PDF is handed out). `attach_scripts` swaps a marker link under
  each block for a FileAttachment annotation and adds the document-level EmbeddedFiles list,
  via `pypdf` (new dependency).*
- [x] Phase 4: Detect the "save this as a file" instruction in a book's source, and warn from
  `/makebook` wherever phase 3's route does not cover the block.
  *`find_scripts`: `file=` on the fence, or a save sentence in the adjacent paragraph. Warns
  for a save that names no file and for a named file with no block beside it.*
- [x] Phase 5: Add a fixture or test that fails on the split and on a missing script, update
  `plugins/bookcraft/skills/makebook/SKILL.md`, and bump the bookcraft plugin version.
  *`makebook/fixtures/save-scripts/`; confirmed to fail with the rounding reverted. SKILL.md
  § Code the reader is asked to save; bookcraft 1.9.0.*

## Status

2026-09-30: all five phases done locally; `test-fixtures.sh --strict` passes 18 of 18 on macOS.
Not yet pushed through CI, so the Linux leg's fonts are unmeasured.

## Open Questions

All four answered by the operator on 2026-09-30:

- ~~Which delivery route do the readers of a course guide actually reach?~~ Only the PDF is
  handed out, so the scripts are embedded in it.
- ~~How does the binder recognise a save instruction?~~ Both: `file=` on the fence is exact,
  and a save sentence in the adjacent paragraph covers books already written.
- ~~Does the warning retire once phase 3 lands?~~ No: it stays for every save the attachments
  cannot cover.
- ~~Does the EPUB preserve indentation when copied?~~ Out of scope.

## Deferred

- Viewer support for the attachments is unverified by hand: Adobe Acrobat Reader, Firefox,
  Chrome's built-in viewer and macOS Preview. Only poppler (`pdfdetach`) and PDFKit's parsing
  were checked. The Chrome extension cannot see inside Chrome's PDF viewer.
- A panel that lists both the annotation and the EmbeddedFiles entry shows each script twice
  (`pdfdetach` does).
- `/createbook`'s guide profile could write `file=` on the fences of scripts it asks readers
  to save, rather than relying on the prose sentence.
- The quarter-pixel rule was measured on macOS fonts only; the Linux CI leg is the first
  measurement of Liberation Mono / DejaVu Sans Mono.
