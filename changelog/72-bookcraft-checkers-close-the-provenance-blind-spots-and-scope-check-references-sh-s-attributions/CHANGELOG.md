# bookcraft checkers: close the provenance blind spots and scope check-references.sh's attributions

Start date: 2026-10-17 14:24:16 MDT

Three of bookcraft's checks pass without doing the work they report, and check 2 of
`check-references.sh` has two more gaps. `check-provenance.sh` checks no quotation in a unit
whose mark follows a blank line, and it matches a bare-number `§ N` locator by prefix.
`check-references.sh` resolves another book's citations against the book it was given, never
reads the file a file-sourced quotation names, and reads fenced examples as prose. This branch
makes each check either do that work or say what it skipped, following the paragraph rules the
operator settled for #82 as R9.

## Changes

### 2026-10-18 20:01:30 MDT: rulings D1 to D5

The operator accepted these on 2026-10-18, answering the branch's five open questions. The
measurements behind D3 were taken on the second teaching guide's course material by a session
with access to it, and are described here without its paths.

- **D1.** The book model's paragraph half stays deferred. Its fence rule lands as
  `book_model.Fence`, which every fence reader in both checkers calls, and its whole-line mark
  test is the existing `MARK_LINE`. #98 will call the fence tracker as well.
- **D2.** R9's mark and digit rules apply where a fix already touches the line: `units_of()`'s
  mark test, `heading_hit`'s number test, `REF`, and `FILEREF`'s line number. The fence rule
  applies at every fence reader in both checkers.
- **D3.** Attribution follows what each kind of citation needs.
  - `book.json` `cited_as` lists the names other files use for the book, matched
    case-insensitively as a phrase.
  - A referring file may declare the books it cites, one whole-line comment each, one marked as
    the default. Undeclared, a file reads exactly as before.
  - Tags belong to the declared default book and nothing else; a name beside a tag never moves
    it. Measured: nearest-name attribution misread 27 tags on 20 lines where the companion
    SQLite guide was mentioned as a resource, and about 3,000 tags are written bare.
  - Chapter references belong to the book named nearest in their block, else the default. All
    8 references in blocks naming the SQLite guide meant it, and only 3 named it beside the
    reference. FAIL when the name shares the reference's sentence, REVIEW when it is only
    elsewhere in the block. In the same material's changelog notes about 47 of 102 such
    references mean the other book; nothing checks those notes, and the fixture pins the shape
    at REVIEW.
  - Check 2 scopes a chapter-attributed quotation the same way.
- **D4.** A quotation sourced to a named file is checked against it: FAIL in a key row, REVIEW
  in prose, as for a chapter. The `:NN` line is not checked; every file carrying the name is
  read, and the report says when more than one did.
- **D5.** `check-book.sh`'s fences stay with #73.

### 2026-10-18 20:01:30 MDT: a mark after a blank line, and a bare-number locator

- **`units_of()`** (`check-provenance.sh`) closes a unit at a blank line instead of emptying
  it, so a mark separated from its paragraph by a blank still covers it. A mark is one only
  when it fills its line, by `MARK_LINE`, and fences come from `book_model.Fence`.
- **`heading_hit`**: a locator that is only a number (`§ 1`, `§ 1.2`) must equal a heading's
  leading number. Word locators keep prefix matching.
- **`SKILL.md § Chapter file format`** writes every mark on the line under its paragraph.
- **Fixture.** `fixtures/provenance` gains `§ 10` (resolves), `§ 1` against a handbook with
  `## 10.` and no `## 1.` (fails), and a misquoting paragraph a blank line separates from its
  mark (reviews). Under `main`'s script both new failing cases pass silently: 6 failures and 3
  quotations checked, against 7 and 4 on the branch.

### 2026-10-18 20:17:14 MDT: which book a citation cites, file-sourced quotations, and fences

- **`book_model.Fence`** is now every fence reader in `check-references.sh`: `blocks()`,
  `tag_paragraphs()` and `tag_citations()`. `blocks()` yields nothing for a fence, and a fence
  clears `lead`.
- **Declarations and `cited_as`** (D3). `declarations()` reads `<!-- cites: NAME -->` lines
  outside fences; `attribution()` matches them against `cited_as` and refuses, as a FAIL that
  checks nothing in the file, a declaration it cannot read: no `cited_as`, no declared name that
  is this book, or two or more books with other than one `(default)`. `Attribution.refs()` gives
  each chapter reference its book and whether the name shares its sentence. Names drop a leading
  "the", as `check-provenance.sh`'s `match_source` does.
- **Check 1** reads `blocks()` instead of lines. Against this plugin's own docs, run as
  referring files, it stopped counting 12 of 93 `ch. N` references, all 12 inside fences, and 7
  of them had been FAILs, and check 2 stopped reviewing the one quotation inside a fence. No
  other output moved for an undeclared file except the reworded REVIEW paragraph.
- **Checks 3 and 4** skip a declared file whose default book is not this one, and count its
  tags per file.
- **Check 2** scopes a chapter-attributed quotation by its nearest-before reference's book, and
  reads a file-sourced quotation against every visible file of that name (D4). Only a file
  nobody can read still leaves a quotation unchecked, and only that qualifies the banner as
  `OK*`; another book's citations are noted and the banner says it speaks for this book.
- **`REF` and `FILEREF`** take ASCII digits (D2).
- **`bj`** is defined again. #82 removed it and kept its use in the `"tags": true` error, so
  that error raised a NameError on `main`.
- **`fixtures/attribution/run.sh`**, check 2's first fixture: nine cases. Run against `main`'s
  `check-references.sh`, eight fail; the ninth is the undeclared file, which passes on both by
  design.
- **Docs.** `createbook/SKILL.md` documents the declaration, `cited_as` and the file-sourced
  read; `updatebook/SKILL.md` step 5 points at it; the plugin README's checker table and fixture
  list follow. bookcraft is 1.16.0, and `createbook/NOTES.md` records the change.

### 2026-10-18 20:34:35 MDT: the review's findings, addressed

`pr-review-2026-10-18.md` asked for changes. Every finding is addressed here, and each has a
fixture case in `fixtures/attribution` or `fixtures/provenance`:

- **Critical: the quoting file was one of its own candidates**, so a quotation of a file sharing
  its name was always "found". It is left out; when it is the only file carrying the name, the
  quotation is reported as one this run could not check, and the banner is `OK*`.
- **`ch.` and `e.g.` ended a sentence**, turning `The Field Guide's ch. 1 and ch. 8` into a
  REVIEW. Other references are removed before the sentence test, and `e.g.`, `i.e.`, `cf.` and
  `vs.` are not ends.
- **An empty `<!-- cites: -->` made "" a book.** A declaration naming nothing now fails the file.
- **An unclosed fence hid the rest of a referring file silently.** It is a REVIEW now, using the
  line `Fence.opened_at` records.
- **The "nothing quotes the book" note** is gated on another book's quotations, not on its
  chapter references.
- **Docs**: the Attribution docstring says what does change for an undeclared file, which is the
  fence and a reference wrapped across a line break; `SKILL.md` says every same-named file but
  the quoting one is read, and lists the declarations that fail.
- **The review's two questions, answered conservatively.** `§ 2` resolves against a source that
  heads only `2.1` and `2.2` again, as it did on `main`, since a subsection is inside its
  section; `§ 1` still never resolves against `10.`, and `§ 1.2` never against `1.20`. A key-row quotation resting on a
  reference whose book was read from another sentence reviews rather than fails, matching
  check 1.
- **Its deferred note, folded in**: `check-provenance.sh` read the book's tag definitions
  without skipping fences. It now reads them through `check-references.sh`'s `tag_paragraphs`,
  so the two checkers agree on what a tag is.
- Under `main`, 11 of the 12 attribution cases fail; the undeclared guard passes on both.

### 2026-10-18 20:44:36 MDT: the close-gate review approves

`pr-review-2026-10-18-r2.md`: APPROVE, with every round-one fix re-probed against a scratch copy
under Python 3.14 and 3.9. Its two minor notes are taken. A sentence in the entry above claimed
`§ 1` never resolves against `1.20`, which the subsection rule allows; it now says `§ 1.2`. And
the fence-aware tag definitions in `check-provenance.sh` gained their fixture case, in
`fixtures/lettered-tags/run.sh`: a mark citing a tag only a fenced example defines fails, and
passes under `main`. Two of this log's timestamps were written by hand rather than read from the
clock; they are corrected to the commits they describe.
