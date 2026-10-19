# bookcraft checkers: close the provenance blind spots and scope check-references.sh's attributions

## Overview

Five places where a bookcraft check reported a pass without doing the work behind it now either
do the work or say what they skipped. `check-provenance.sh` now checks the quotations of a
paragraph whose mark sits after a blank line, and a bare `§ 1` no longer resolves against
`## 10.`. `check-references.sh` reads each citation in a file that cites two books against the
book it names, reads a quotation sourced to a named file against that file, and reads fences by
CommonMark's rule through one tracker shared with `check-provenance.sh`.

This consolidates #51 and #65. The rulings that settled the open design questions are D1 to D5
in the branch's `CHANGELOG.md`, accepted by the operator on 2026-10-18; the measurements behind
D3 were taken on a teaching guide's course material and are described there without its paths.
The first fix lands first for its occasion: a second teaching guide with 58 marks after a blank
line, serving a course that starts November 9.

## Key changes

- **`plugins/bookcraft/scripts/book_model.py`**: `Fence`, the CommonMark fence tracker every
  fence reader in both checkers now calls (D1). It records the line that opened an unclosed
  fence. The module docstring now says the model owns the fence and whole-line-mark rules.
- **`skills/createbook/scripts/check-provenance.sh`**
  - `units_of()`: a blank line closes a unit without emptying it, so a mark after it still
    covers the paragraph above. A mark is a mark only when it fills its line (`MARK_LINE`).
  - `heading_hit`: a bare-number locator must equal a heading's leading number, or be the
    section a dotted heading extends (`§ 2` against `2.1`). Word locators keep prefix matching.
  - The book's tag definitions are read through `check-references.sh`'s fence-aware
    `tag_paragraphs`, so the two checkers agree on what a tag is.
- **`skills/createbook/scripts/check-references.sh`**
  - `declarations()`, `Attribution`, `attribution()`: a referring file may declare the books it
    cites, one `<!-- cites: NAME -->` line each with one marked `(default)`, matched against the
    new `book.json` key `cited_as`. A declaration the run cannot read fails the file unread.
  - Check 1 reads `blocks()` instead of lines, and gives each chapter reference the book named
    nearest it in its block: FAIL when that name shares the reference's sentence, REVIEW when it
    is only elsewhere in the block.
  - Checks 3 and 4 skip a declared file whose default book is another, and count its tags.
  - Check 2 scopes a chapter-attributed quotation by its reference's book, and reads a
    file-sourced quotation against every visible file of that name except the quoting file
    itself (D4). A misquote fails in a key row and reviews in prose.
  - `blocks()`, `tag_paragraphs()` and `tag_citations()` read fences through `Fence`;
    `blocks()` yields nothing for a fence and a fence clears `lead`.
  - An unclosed fence in a referring file is a REVIEW. `REF` and `FILEREF` take ASCII digits.
  - `bj` is defined again: its use in the `"tags": true` error had raised a NameError since #82.
- **Fixtures**: `fixtures/provenance` gains `§ 10`, `§ 20`, `§ 1` and the blank-line case;
  `fixtures/attribution/run.sh` is check 2's first fixture, with twelve cases.
- **Docs**: `createbook/SKILL.md` (the chapter example, `cited_as`, the declaration, file-sourced
  quotations), `updatebook/SKILL.md` step 5, `plugins/bookcraft/README.md`, and a
  `createbook/NOTES.md` entry. bookcraft is 1.16.0.

## Code examples

A mark after a blank line, `plugins/bookcraft/skills/createbook/scripts/check-provenance.sh`
`units_of()`. Before, the blank emptied the buffer and the mark was handed an empty unit:

```python
        elif line.strip() == "" or line.lstrip().startswith("#"):
            buf = []
```

After, the blank only closes the unit, and the next unit's first line discards it:

```python
        elif line.strip() == "":
            closed = True
        elif line.lstrip().startswith("#"):
            buf, closed = [], False
        else:
            if closed:
                buf, closed = [], False
            buf.append(line)
```

The fence rule every reader shares, `plugins/bookcraft/scripts/book_model.py`:

```python
    def step(self, line: str) -> bool:
        """Read the next line; True when it opens, closes or sits inside a fence."""
        self.line += 1
        if self.opening is not None:
            run = line.strip()
            if len(run) >= len(self.opening) and not run.strip(self.opening[0]):
                self.opening = None
            return True
        m = FENCE_OPENING.fullmatch(line.rstrip("\r\n"))
        if m and not (m.group(1)[0] == "`" and "`" in m.group(2)):
            self.opening, self.opened_at = m.group(1), self.line
            return True
        return False
```

A referring file that cites two books, as `fixtures/attribution/referring/two-books.md` does:

```markdown
<!-- cites: The Field Guide (default) -->
<!-- cites: The Companion Guide -->

The Companion Guide's chapter 9 covers the install.     <- left to the companion's check
The Field Guide's chapter 8 does not exist.             <- FAIL: named in its own sentence
The field book comes up again later. The install steps are in chapter 9.   <- REVIEW
```

## Plan alignment

Every action item in `PLAN.md § Plan` is done.

- **Step 1** (blank line before a mark): as planned, with the `SKILL.md` example rewritten and a
  fixture that passes under `main` and reviews on the branch.
- **Step 2** (bare-number locator): as planned. Deviation: a dotted heading counts as inside its
  section, so `§ 2` still resolves against a source that heads only `2.1` and `2.2`, as it did
  on `main`. The review asked whether stricter matching was intended; the conservative answer
  keeps every new FAIL to the defect #51 named.
- **Step 3** (which book a citation cites): settled as D3 rather than the plan's single "nearest
  attribution" rule, because the measurements showed tags and chapter references need different
  rules. Check 2's chapter-attributed quotations take the same scoping, which the plan did not
  list but the objective's "every citation" covers.
- **Step 4** (file-sourced quotations): as planned. Severity follows the chapter rule (D4); the
  `:NN` line is not checked, and the report says why.
- **Step 5** (fences): as planned, with the fence rule in `book_model.py` (D1) so the readers
  agree by construction.
- **Step 6** (fixtures and release): every fix has a fixture case `main`'s scripts fail; version
  1.16.0; `NOTES.md` entry.
- **Beyond the plan, each small and in a file already being rewritten**: the `bj` NameError, the
  unclosed-fence REVIEW, and `check-provenance.sh`'s tag definitions read through the
  fence-aware reader.
- **Not done here**: the book model's paragraph half (D1), and `check-book.sh`'s fences (D5,
  left to #73).

## Testing

- `plugins/bookcraft/scripts/test-fixtures.sh`: 20 of 20 pass, and again with `/usr/bin/python3`
  3.9.6 first on PATH, the floor CI holds the checkers to.
- `fixtures/attribution/run.sh`: twelve cases. Copied into a tree of `main`'s scripts, eleven
  fail; the twelfth guards that an undeclared file reads as it did, and passes on both.
- `fixtures/provenance`: under `main`'s script the new failing case passes and the blank-line
  quotation goes unchecked (6 failures, 3 quotations checked); on the branch 7 and 4.
- `fixtures/lettered-tags/run.sh`: a mark citing a tag that only a fenced example defines now
  fails `check-provenance.sh`, and passes under `main`.
- Differential: `main`'s and the branch's `check-references.sh` over every createbook fixture
  book, with the plugin's own docs as referring files. The only differences are 12 `ch. N`
  references and one quotation that sit inside fenced examples, all verified to be inside a
  fence, plus the reworded REVIEW paragraph.
- A review pass (`pr-review-2026-10-18.md`) asked for changes; every finding was addressed in
  `a880213`, each with a fixture case.

To verify by hand:

```bash
cd plugins/bookcraft/skills/createbook
./fixtures/attribution/run.sh
./scripts/check-provenance.sh fixtures/provenance      # exits 1, seven failures by design
```

## Impact assessment

33 files, 1,523 lines added and 92 removed, most of it the new fixture and the branch's notes.
No dependency changes; everything stays standard-library Python 3.9.

Behaviour changes a user can see:

- A book whose marks sit after a blank line now has those paragraphs' quotations checked, so
  quotations that were never examined can now report REVIEW.
- A `§ N` mark that resolved against a different number by prefix now fails.
- Check 1 no longer counts `ch. N` inside a fence, and now counts a reference wrapped across a
  line break, for every referring file.
- A quotation attributed to a named file can now fail a key row or review in prose, where it was
  only listed before; when the file is found, the run no longer prints `OK*` for it.
- New, opt-in: the `<!-- cites: ... -->` declaration and `book.json` `cited_as`. A file without
  a declaration reads as before. `cited_as` will need a place in #84's list of known keys.

No breaking change to any command line.

## Deferred work

These sit under `PLAN.md § Deferred` for the close to triage. The book model's paragraph half,
each paragraph's tag and mark read once for every tool, waits for a consumer that needs the
structure (D1). A word locator ending in a number still matches by prefix, so
`§ Worked Reasoning 1` written with its hash sign resolves against item ten's heading after
item one is gone. A list with blank lines between its items has only its last item covered by
a mark after the list, while `check-book.sh` reads the whole list as one unit. The binder's
`fenced_lines` in `build-book.py`, used to attach a chapter's scripts, still toggles on a
backtick line; its markdown-it pass already reads fences by CommonMark. The review also noted
`check-provenance.sh`'s tag-definition reader ignoring fences, which this branch folded in.
