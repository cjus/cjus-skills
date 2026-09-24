# Stamp the bind date and time under the title page byline

Start date: 2026-09-24 06:14:10 MDT

Add the date and time a book was bound under the author name on the title page of the PDF and
EPUB `/makebook` produces, so the stamp serves as the bound book's version marker.

## Changes

### 2026-09-24

- Settled the open questions with the operator. The stamp is local time with the zone
  abbreviation, labelled `Created: `, set in the byline's type, and printed with or without a
  byline. There is no reproducibility override, and a supplied `cover_image` is left alone.
- Added `bind_stamp()` to `build-book.py` and read it once per run, so every settling pass, the
  EPUB cover page and the generated EPUB cover art all print the PDF's stamp. The stamp is a
  required argument all the way down, for the same reason `css` is: a cover that read the clock
  itself would disagree with its own EPUB.
- Flushed the EPUB cover's byline left. It picked up `p`'s 1.2em indent whenever a subtitle
  preceded it, and the stamp beneath it would have been indented only some of the time.
- Measured the cost on the PDF cover: 21pt at every `--type-size`, since the stamp's type and
  margins are fixed.
