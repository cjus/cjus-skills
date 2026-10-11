# Verify which PDF viewers show makebook's attached scripts

Start date: 2026-10-08 13:58:04 MDT

Record which common PDF viewers offer makebook's attached scripts to a reader, through the
attachments panel and through a double-click on the note's filename, and make
`makebook/SKILL.md` and the printed note match the results.

## Changes

### 2026-10-11 09:37:05 MDT: no Mac viewer checked so far offers the scripts

The fixture binds with every script attached in both places (`pdfdetach` lists 14, `run.sh`
passes). The operator then opened it in Preview 11.0, Safari 27.0 and Chrome 154 on macOS
27.0, and none of the three offers the scripts, either in an attachments panel or on a
double-click on the note's filename. The printed note promises both. Acrobat Reader, Firefox
and Edge are not installed here and remain unchecked.

### 2026-10-11 10:00:37 MDT: only Firefox hands the reader the file; the note now says so

The operator installed the other three and checked them. Firefox 157 offers the scripts both
ways. Edge 155 shows neither. Acrobat Reader 26.001 refuses a `.py` file on a double-click;
its panel was left undetermined, by the operator's choice, since it would change the note by
one clause. The operator accepted the attachments as a partial route rather than a fix.

- **`build-book.py:script_notes`.** The note names Firefox as the way to save the script, and
  names Preview, Safari, Chrome and Edge as showing no attachments. It no longer tells every
  reader to double-click or open a list of attachments.
- **`makebook/SKILL.md § Code the reader is asked to save`.** The "Not checked" sentence is
  replaced by a six-row table of both surfaces, with versions, and advice to hand the scripts
  out beside the book when readers may not use Firefox.
- **bookcraft 1.12.1.**

Getting scripts to readers in the other viewers is under Deferred, for a follow-up ticket.

### 2026-10-11 10:09:21 MDT: pre-test review, APPROVE; the summary no longer outruns the table

Draft PR #89 opened; CI passes on all five jobs. The review (`pr-review-2026-10-11.md`)
approved with one Important finding and one suggestion, both applied:

- **The prose under the table claimed a negative the table left open.** "A reader in any other
  viewer has no way to get a script out" covered Acrobat's undetermined panel and every viewer
  nobody tried. It now names the four that show nothing, says Acrobat refuses the double-click,
  and says its panel was not checked. The heading reads "was seen to". The result is dropped
  from `attach_scripts`'s docstring, which now only points at SKILL.md, so a re-measure
  updates one place.
- **"Hand the scripts out beside the book" now says how:** `pdfdetach -saveall -o <folder>
  <book>.pdf` writes each script once. Checked on this branch's bind: seven files.
