# Verify which PDF viewers show makebook's attached scripts

Start date: 2026-10-08 13:58:04 MDT

Record which common PDF viewers offer makebook's attached scripts to a reader, through the
attachments panel and through a double-click on the note's filename, and make
`makebook/SKILL.md` and the printed note match the results.

## Changes

### 2026-10-11 09:37:05 MDT: no Mac viewer checked so far offers the scripts

The fixture binds with every script attached in both places (`pdfdetach` lists 14, `run.sh`
passes). Opened by the operator in Preview 11.0, Safari 27.0 and Chrome 154 on macOS 27.0, none
offers the scripts through either route, though the printed note promises both.

### 2026-10-11 10:00:37 MDT: only Firefox hands the reader the file; the note now says so

The operator installed and checked the other three. Firefox 157 offers the scripts both ways;
Edge 155 shows neither; Acrobat Reader 26.001 refuses a `.py` file on a double-click, its panel
left undetermined by the operator's choice. The operator accepted the attachments as a partial
route rather than a fix.

- **`build-book.py:script_notes`.** The note names Firefox as the way to save the script and
  the four viewers that show no attachments.
- **`makebook/SKILL.md § Code the reader is asked to save`.** A six-row table of both routes,
  with versions, replaces the "Not checked" sentence.
- **bookcraft 1.12.1.** Getting scripts to readers in other viewers is under Deferred.

### 2026-10-11 10:09:21 MDT: pre-test review, APPROVE; the summary no longer outruns the table

Draft PR #89 opened; CI green on all five jobs. Both review items applied: the prose under the
table now names only the four viewers measured to show nothing and says Acrobat's panel was not
checked, and the heading reads "was seen to". The docstring only points at SKILL.md, so a
re-measure updates one place. The hand-out advice gained a `pdfdetach` command.

### 2026-10-11 10:18:40 MDT: close review, APPROVE; the hand-out advice handles a repeated name

The close review found `pdfdetach -saveall` keeps only the later chapter's file when two
chapters save a file of the same name, which the binder allows on purpose. SKILL.md now says so,
gives `pdfdetach -save <n>`, and creates the folder first (a missing one exits 2); both checked
on this branch's bind. Three inexact summary claims were corrected.
