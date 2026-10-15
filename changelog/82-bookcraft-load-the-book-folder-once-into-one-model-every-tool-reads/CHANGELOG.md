# bookcraft: load the book folder once, into one model every tool reads

Start date: 2026-10-12 10:47:01 MDT

Every bookcraft tool reads the book folder on its own, with its own copy of the rules that say
what a file is, and the copies have drifted. The appendix filename rule exists four times and
the copies disagree. This branch adds one stdlib-only `book_model.py` that reads the folder
once, moves the binder and every checker onto it, and adds a fixture proving they classify each
file the same way.

## Changes

### 2026-10-12 10:57:05 MDT: the rules inventory

Line numbers are on `498a68a`. "binder" is `makebook/scripts/build-book.py`, and the three
checkers are in `createbook/scripts/`.

**`render-report.py` has no rule of its own.** It never reads the book folder. It takes each
file's `(kind, number)` from `index.json` and the findings files, both written by
`check-provenance.sh --emit-worklist` (:1416-1430), so the model reaches it only through that
emitter. #21's collision was fixed in the emitter by #17, merged 2026-09-21, the day before #21
was filed. `check-claims/fixtures/appendix/run.sh` reproduces #21 and passes 17 of 17 on main.

| Rule | binder | `check-book.sh` | `check-provenance.sh` | `check-references.sh` |
|---|---|---|---|---|
| Discovery, order | `sorted(glob("*.md"))` :901 | `find -maxdepth 1 \| sort`, `LC_ALL=C` :282, :25 | `sorted(glob("*.md"))` :1755 | `sorted(glob("*.md"))` :526 |
| Skip list | `description_file`, `exclude`, `glossary_file`, `front_matter_file` :3994-4010 | `OUTLINE.md`, `exclude`, `glossary_file`, `front_matter_file` :87, :164-180 (jq only) | `OUTLINE.md`, `glossary.md`, `about-this-book.md` hard-coded, `exclude` :1753 | `exclude`, `glossary_file` :516; any file without `-NN-` is ignored :529 |
| Chapter number | position in sort order, never the filename :950 | `-NN-` (two or more digits), the first digit run, must equal position :364, :377 | first digit run anywhere, `\d+` :1238 | first `-(\d{2,})-` anywhere :87 |
| Appendix | `APPENDIX_FILE_RE`, any profile :773 | guide profile only :334 | prefix only :1217 | prefix only :86 |
| Title | line 1 after marks are stripped, else `prettify(stem)` :908-915 | raw line 1 must start `# ` :384 | not read | not read |
| `sections` group | sequential number, appendices included in some places | not checked | not read | not read |
| Paragraph tag | `^\[A?\d+-\d+[a-z]?\] ` :755 | same, with `[0-9]` :147 | same :295 | same :69 |
| Mark | whole line only, stripped :744 | whole line only; any other comment fails :1227 | anywhere on a line, `MARK.search` :706 | n/a |
| Fence | markdown-it: backtick and `~~~` fences | backtick fences only :764 | backtick fences only :698 | backtick fences only :325 |

**Disagreements beyond the appendix pattern.** Each row in the first table below came from
running the tools' own code on the name: the real `load_chapters`, `chapter_id` and `unit_of`,
and `check-book.sh`'s grep and sed patterns.

1. **Chapter number has four rules.** The binder's number is a position. Every checker reads one
   from the filename, and no two of them read it the same way:

   | Filename | binder | provenance | references | check-book |
   |---|---|---|---|---|
   | `bk2-07-slug-digit.md` | chapter (position) | chapter 2 | chapter 7 | rejected |
   | `notes-v2.md` | chapter (position) | chapter 2 | ignored | rejected |
   | `bk-1-one-digit.md` | chapter (position) | chapter 1 | ignored | rejected |
   | `01-intro.md` | chapter 1 | chapter 1 | ignored | rejected |

   In a book with a gap (`-01-`, `-03-`), the binder prints "Chapter 2" over the file every
   checker calls chapter 3. `check-book.sh` fails the gap, but the binder runs without it.
2. **Three skip lists.**
   - Only the binder skips `description_file`.
   - The binder skips `OUTLINE.md` only because `createbook/SKILL.md:419` writes it into
     `exclude`.
   - `check-provenance.sh` hard-codes the default glossary and front-matter names, so a renamed
     one is a chapter to it: scanned for marks, and counted in `n_chapters`.
   - No fixture sets `description_file`, `glossary_file` or `front_matter_file`.
3. **Appendices under the narration profile.**
   - `check-book.sh` recognises an appendix only under the guide profile. The other three
     recognise one under any profile.
   - Its comment says a narration appendix "falls through to the chapter rule and fails there by
     name". That holds only for a one-digit number. Under narration, `bk-appendix-10-x.md` passes
     the chapter rule as chapter 10, and `bk-appendix-01-x.md` passes as chapter 1.
4. **`sections` disagrees within the binder itself.**
   - The chapter eyebrows leave appendices out of a part (:2278, :3815).
   - The contents (:1651), the PDF outline (:3246) and the EPUB nav (:3748) group appendices by
     their sequential number. So a range that spans an appendix's number nests it under a part
     its own page does not name.
5. **Numbers that count appendices as chapters.**
   - `check-provenance.sh` bounds a mark's `ch. N` by `n_chapters`, which counts every file it
     did not skip, appendices included (:1772, :1884).
   - The glossary's `(ch. N)` is bounded the same way by the binder (:4057) and by
     `check-book.sh` (:1325). Both accept a `(ch. N)` past the last chapter, and the binder then
     resolves it to an appendix.
6. **Paragraph rules, which matter only where `check-book.sh` has not run.**
   - Line 1 that is a mark above the H1: the binder finds the title, `check-book.sh` fails it.
     Its comment cites `build-book.py:406`; the rule is now at :910.
   - A mark that does not fill its line: provenance reads it, the binder leaves it in the page.
   - A `~~~` fence: the binder renders it as code, the checkers read its contents as prose.
   - Python's `\d` matches non-ASCII digits, where `check-book.sh`'s `[0-9]` does not.

**For the agreement fixture.** On a case-insensitive disk (macOS's default),
`bk-appendix-1-answer-key.md` and `bk-appendix-1-Answer-Key.md` are one file, so the probe lost
one of them. The ticket's four names cannot share a folder, so the fixture needs one folder
per name, or it must classify names without creating the files.

### 2026-10-12 11:27:13 MDT: recommendations for every open question, awaiting the operator

These are proposals. None is settled until the operator rules. Each one was checked against the
specs and the fixtures, and the less obvious findings were confirmed by running the tools' own
code.

**Confirmed since the inventory:**
- **The `sections` mismatch.** In a folder with two chapters and an appendix, and `sections`
  covering 1 to 3, `build_toc` lists `A1` under "Part One" while `build_chapters` heads it
  "Appendix 1" with no part.
- **The narration-profile appendix.** On a narration book, `check-book.sh` reports
  `bk-appendix-10-key.md: is chapter 10 but sits at position 2`, then checks its content under
  the chapter rules.

**New findings:**
- **An appendix that sorts ahead of the chapters shifts every chapter label.** The binder
  counts appendices in a chapter's label (`len(chapters) + 1`, :950). So with
  `aa-appendix-1-key.md` before `bk-01-one.md`, the binder prints "Chapter 2" over the file
  every checker calls chapter 1.
- **`check-references.sh` silently drops one of two files that share a chapter number.** It
  keys chapters by number in a dict (:534), so the second file overwrites the first.
- **A glossary `(ch. N)` past the last chapter prints wrong.** The binder prints "ch. 19" over a
  link to Appendix 1 (:2363, :3693).
- **Untested areas.** No fixture sets `sections`, `description_file`, `glossary_file` or
  `front_matter_file`. No fixture glossary points past its chapters.
- **The checkers' Python version isn't tested.** They run under macOS's `/usr/bin/python3`
  (3.9.6, verified), but bookcraft's CI tests only 3.12 (`fixtures.yml:60`).

**R1. The appendix rule: the name's opening decides kind and number, the whole name decides
whether it conforms.**
- The opening part is `<book-slug>-appendix-<N>-` for an appendix, tested first as every tool
  tests it today, then `<book-slug>-<NN>-` for a chapter. The book slug is ASCII lowercase
  letters and dashes. This is the `check-provenance.sh` and `check-references.sh` rule.
- Conformance is the full pattern from `check-book.sh`, plus no leading zero in an appendix
  number.
- All four `bk-appendix-1-…` names are appendix 1, and three of them do not conform.
  `sql-02-appendix-1-of-the-standard.md` is chapter 2 and conforms.
- `check-book.sh` fails a non-conforming name, as it does today. The binder binds it as an
  appendix and warns, and never refuses: it "binds any folder of markdown, including folders
  `/createbook` never wrote" (`makebook/SKILL.md:600`).
- **Why appendix rather than chapter or rejected.** The name says what it was meant to be.
  Binding it as "Chapter 5" is the failure that has already shipped, and "rejected" is not
  something the binder can do with a file.
- **What changes:** the binder, for `…Answer-Key.md` and `…answer_key.md`.

**R2. A chapter's number is the one in its name, or its position when the name carries none.**
- **Why the name, not the position.** The filename number is what the book's addressing uses:
  - the tag's chapter half
  - a mark's `ch. N`
  - `chapter N` in a referring file
  - `--chapters 2`
  - a glossary's `(ch. N)`

  Renumbering a chapter means renaming the file and retagging it (`createbook/SKILL.md:664`).
  Four of the five tools already read the filename number, and the binder already does for
  appendices.
- **No book that passes today changes.** `check-book.sh` requires the number to equal the
  position, so for every book it passes the two are the same.
- **What changes.**
  - A book with a gap or a duplicate. The binder prints the names' numbers ("Chapter 1",
    "Chapter 3"), which match the tags printed on the page, and warns. The model reports the gap
    or duplicate, and `check-book.sh` fails it as it does now.
  - `check-provenance.sh` stops reading `bk2-07-…` as chapter 2.
  - `check-references.sh` stops ignoring a file whose name carries no number.
  - The binder keeps its own running sequence for page ids and probes, separate from the label.
- **Numbers count within each kind**, which fixes the label shift above. The reading order is
  the chapters, then the appendices, so "bound after the chapters" (`guide.md:181`) holds by
  construction.

**R3. One skip list, the union of the four.**
- `OUTLINE.md` always, `description_file`, `glossary_file` (default `glossary.md`),
  `front_matter_file` (default `about-this-book.md`), and `exclude`.
- **Why `OUTLINE.md` is skipped unconditionally.** The binder's own reason for skipping the
  glossary and front matter applies to it: a forgotten `exclude` line would bind the file as a
  chapter (:3999-4010).
- **What changes:**
  - A plain folder's `OUTLINE.md` no longer binds.
  - The checkers skip `description_file`, so `check-book.sh` stops failing a book that uses one.
  - The checkers skip a renamed glossary or front matter.
- Add fixture coverage for the three filename keys.

**R4. An appendix is an appendix under either profile, and the profile decides whether one is
allowed.**
- The model classifies by name alone. The binder never reads `profile`.
- Under narration, `check-book.sh` fails an appendix with its own message instead of grading it
  under the chapter rules. This fixes the `bk-appendix-10-…` case.
- **What changes:** one deliberate fixture change.
  `createbook/guide-under-narration`'s expected string `filename does not match`
  (`test-fixtures.sh:99`) becomes the new message.

**R5. No appendix is ever in a `sections` part.**
- `guide.md:185` gives an appendix "No parts", and the chapter pages already follow that.
- The model gives each file its part (none for an appendix), and the contents page, outline and
  EPUB nav read it.
- `sections.chapters` lists chapter numbers in R2's sense. `makebook/SKILL.md:322` changes
  accordingly, since today it says "1-based position in sort order".
- **What changes:** the binder, for a `sections` range that reaches past the last chapter.

**R6. A mark's `ch. N` and a glossary's `(ch. N)` can name chapters only.**
- `guide.md:187`: "An appendix never teaches", so no glossary term can be taught in one.
- The bound becomes the set of chapter numbers, not a count of files. `check-references.sh`
  already leaves appendices out, and an appendix paragraph is cited by its `[A1-3]` tag.
- **What changes:** a book that cites past its last chapter fails, which is correct.

**R7. Put the model at the plugin level: `scripts/book_model.py`.**
- **Why there.** That folder already holds the plugin-wide tools (`install.sh`,
  `bookcraft-python`, `test-fixtures.sh`). It installs beside `skills/`, which the installed
  plugin cache shows.
- **Why not `createbook/scripts/`.** The binder binds folders `/createbook` never wrote, so it
  should not depend on that skill's folder.
- **How each tool reaches it.**
  - The Python tools load it by path, three levels up, with the `_borrow` loader
    `check-provenance.sh` already uses (:251).
  - `check-book.sh` runs `python3` on it.
- **Version floor: Python 3.9**, the version on a stock Mac. Add a 3.9 CI leg, as `iac.yml`
  already has for its own floor (:9-10), or nothing stops the model from breaking the checkers
  there.

**R8. `check-book.sh` reads the model through `python3`, and `jq` goes (this answers both the
`jq` question and the format question).**
- **`python3` is already required.** `/createbook` needs it for `check-provenance.sh`,
  `check-references.sh` and `assertions.sh`, and the README says the three non-binder skills
  "use the Python standard library and bash" (`README.md:37`).
- **Why `jq` should go too.** Keeping it for the remaining `book.json` reads would mean two
  required tools and two degraded modes. The model reads `book.json` anyway, so it hands back
  the declarations as well.
  - The three skip-list reads have to move under the plan as written.
  - The other eight are the recommendation.
  - Raw values keep the existing validation `case` blocks unchanged.
- **The output format.**
  - Tab-separated lines for bash: one `file` row per file, plus `decl` and `source` rows. The
    model refuses a filename that holds a tab or a newline.
  - `--json` for people and the fixture.
  - The Python tools import the module directly.
- **No `python3` means exit 2 with a message, and no degraded mode.** This follows the code's
  own stance that degraded grading "reads as absent" while `book.json` declares otherwise
  (`check-book.sh:151-158`).
- **What changes:**
  - `fixtures/jq-unrunnable/` becomes a test for a missing or broken `python3`, with the same
    three cases; the absent case now expects a stop rather than a fallback.
  - `test-fixtures.sh` drops its `jq` gate.
  - The no-`jq` notes in the docs go.

**R9. Move the paragraph half of the model to `## Deferred`, for #72, and record its rules now.**
- **Why defer.** Every consumer step in the plan is file-level ("classify files from the
  model"), and none reads paragraph data. Emitting it with no reader would be a fifth copy of
  the rules, which is the drift this ticket exists to remove.
- **Why #72.** It already rewrites `units_of()` (blind spot 1, a mark after a blank line yields
  an empty unit), and asks to "confirm the three functions agree on what a fence is".
- **The rules for when it lands:**
  - A mark fills its line.
  - A fence follows CommonMark: three or more backticks or tildes, closed by the same character
    at least as many times. That is how the binder renders one.
  - A mark after a blank line covers the unit above it, as `check-book.sh` already treats it
    (:931) and as #72 proposes.
  - Digits are ASCII only.
- The objective names only file classification, so it is unaffected.

**R10. The title comes from the binder's rule.**
- The title is line 1 once whole-line marks are stripped, when that line is an H1. Otherwise it
  comes from the filename.
- `check-book.sh` fails only the filename case, which is what its message already says. That
  ends the false failure on a mark above the H1.

**For books that pass `check-book.sh` today, only three things change.**
- R5 changes the binder's contents page, outline and nav where a part's range reaches an
  appendix.
- R6 fails a citation past the last chapter.
- R8 adds `python3` as a requirement of `check-book.sh`.

**Outside the plan:** #21 can be closed, with `check-claims/fixtures/appendix/run.sh` as the
evidence. That is the operator's call.

### 2026-10-15 12:17:49 MDT: the open questions are settled

The operator accepted all ten recommendations, R1 to R10, as written above. Three of them change
the plan's scope:
- **R8:** `jq` leaves `check-book.sh` entirely, not only for the skip-list reads.
- **R9:** the paragraph half of the model moves to `## Deferred`, for #72.
- **R7:** CI gains a Python 3.9 leg.
