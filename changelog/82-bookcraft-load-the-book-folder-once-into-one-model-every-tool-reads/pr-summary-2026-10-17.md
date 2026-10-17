# bookcraft: load the book folder once, into one model every tool reads

## Overview

Every bookcraft tool used to read the book folder on its own. Each carried its own copy of the
rules that say what a file is, and the copies had drifted. The appendix filename rule existed
four times and no two agreed: `bk-appendix-1-Answer-Key.md` bound as a chapter while two
checkers graded it as an appendix and `check-book.sh` rejected it. An inventory on `498a68a`
found six more disagreements:
- four ways of reading a chapter's number
- four different skip lists
- an appendix `check-book.sh` graded as chapter 10 under the narration profile
- a `sections` range that put an appendix inside a part on the binder's contents page but not
  on the appendix's own page
- `ch. N` and glossary `(ch. N)` bounds that counted appendices as chapters
- paragraph-level differences in marks and fences

This branch adds one stdlib-only module, `plugins/bookcraft/scripts/book_model.py`, that
decides what each file is. The binder, `check-provenance.sh` and `check-references.sh` load it
by path. `check-book.sh` runs it under `python3` and reads tab-separated rows, which retires
every `jq` read and the degraded no-`jq` grading. A new fixture hands every tool the same
filenames and fails if any of them classifies a file differently from the model.

The operator ruled on all ten recommendations, R1 to R10, on 2026-10-15. They are recorded in
the branch's `CHANGELOG.md`, and this branch implements them as written.

## Key changes

- **`plugins/bookcraft/scripts/book_model.py`** (new). Python 3.9 compatible, standard library
  only.
  - **`classify(names, cfg)`** is pure and touches no file. `check-references.sh` classifies a
    baseline commit's `git ls-tree` names with it, and the agreement fixture classifies names a
    case-insensitive disk could not hold side by side.
  - **`read(folder)`** adds `book.json` and each chapter-kind file's title and H1 line.
  - **Each chapter-kind file** carries its kind, number, name number, position, conformance,
    label (`Appendix 1`), unit (`A1`), part and title.
  - **`problems`** words name, leading-zero and position faults the way `check-book.sh` worded
    them.
  - **`--tsv`** gives `check-book.sh` its rows, and `--json` prints the whole model.
- **The rules it settles.**
  - **Kind and number (R1).** The opening of a name decides them, `<book-slug>-appendix-<N>-`
    tried first and then `<book-slug>-<NN>-`. The whole name decides only whether it conforms.
  - **Chapter numbers (R2).** The number is the one in the name, or the chapter's position when
    the name carries none. Numbers count within each kind, and the reading order is chapters,
    then appendices.
  - **The skip list (R3)** is the union of the four old lists: `OUTLINE.md`,
    `description_file`, `glossary_file`, `front_matter_file` and `exclude`.
  - **Appendices are profile-independent (R4).** An appendix is an appendix whatever the profile
    says.
  - **No appendix is in a `sections` part (R5),** and **no `ch. N` or `(ch. N)` names one
    (R6).**
  - **The title (R10)** is the first line once whole-line provenance marks are set aside.
- **`plugins/bookcraft/skills/makebook/scripts/build-book.py`.**
  - `prettify`, `load_config`, `APPENDIX_FILE_RE` and `group_for` are gone, and
    `PROVENANCE_RE` is the model's `MARK_LINE`.
  - `load_chapters` walks the model's reading order and takes kind, number, label, unit, part
    and title from it. The running `num` stays internal, for ids, probes and page lookups.
  - A misnamed or misplaced file binds as what its name says and warns, but only where its name
    claimed a place in a `/createbook` book. A plain folder of notes draws no warning.
  - A glossary `(ch. N)` must name a chapter, and the EPUB's glossary links resolve by chapter
    number.
  - **Two binder disagreements fixed in passing.** The EPUB numbered an appendix's figures `3.1`
    where the PDF printed `A1.1`, and its index printed the binder's running sequence as a
    chapter number. Both now use the model's unit.
- **`plugins/bookcraft/skills/createbook/scripts/check-provenance.sh`.**
  - It borrows the model with its own `_borrow`. `APPENDIX_FILE` and `chapter_id` are gone.
  - `--chapters` and the worklist index `render-report.py` reads take each file's
    `(kind, number)` from the model.
  - A mark's `ch. N` must name a chapter the book has.
- **`plugins/bookcraft/skills/createbook/scripts/check-references.sh`.**
  - `APPENDIX_FILE`, `CHAPTER_FILE` and `unit_of` are gone. `units_of(model)` maps each unit to
    its file and prints a note when two files claim one, where a dict key once dropped the first.
  - The baseline is classified by the same model from its `git ls-tree` names.
- **`plugins/bookcraft/skills/createbook/scripts/check-book.sh`.**
  - The `jq` block, the `find | sort` walk and its own appendix, chapter-number and position
    rules are gone. Everything it knows about a file comes from the model's `--tsv` rows.
  - It needs `python3` 3.9 or newer, and stops with exit 2, naming the problem, when `python3` is
    missing or will not run.
  - Under narration, an appendix fails as an appendix instead of being graded as a chapter (R4).
  - A glossary `(ch. N)` must name a chapter number the book has (R6).
  - The body starts below the H1 wherever a mark above it put it (R10).
- **Fixtures.**
  - **`createbook/fixtures/book-model/run.sh`** (new). It holds 75 checks across the model's
    table, every tool on the same names, and a guard against any tool regaining a filename rule.
  - **`createbook/fixtures/jq-unrunnable/`** became **`python-unrunnable/`**. It covers a
    working `python3`, one that exits 126, and none at all, which now expects a stop.
  - **`test-fixtures.sh`** drops its `jq` gate. Its `guide-under-narration` row expects the new
    narration message.
  - **`check-claims/fixtures/appendix/run.sh`** and **`createbook/fixtures/ledger/run.sh`** load
    `check-provenance.sh` where it sits, so what it borrows by path resolves. The appendix
    fixture's fifth test checks the model's classification.
  - **`createbook/fixtures/assertions/run.sh`** drops its `jq` skip.
- **`.github/workflows/fixtures.yml`.**
  - It asserts that `python3` runs, where it used to install and assert `jq`.
  - A new `checkers-floor` job runs the suite under the runner's own `/usr/bin/python3`, and
    asserts the version is 3.9.
- **Docs.**
  - **Root `README.md`:** requirements, the broken-tool paragraph, and the CI notes.
  - **bookcraft `README.md`:** the 3.9 floor, the fixture list and count, and the tree.
  - **`createbook/SKILL.md`:** § Filenames, the `overview` and undeclared-book passages, and the
    checker's requirements.
  - **`makebook/SKILL.md`:** front matter, `sections`, `exclude`, glossary references and
    § Appendices.
  - **`createbook/NOTES.md`:** § One book model for every tool, 2026-10-15.
- **`plugins/bookcraft/.claude-plugin/plugin.json`.** 1.14.0 to 1.15.0.

## Code examples

The rule every tool now shares (`plugins/bookcraft/scripts/book_model.py`, `classify`):

```python
m = APPENDIX_OPENING.match(name)
kind = "appendix" if m else "chapter"
if not m:
    m = CHAPTER_OPENING.match(name)
...
named = int(digits) if digits is not None else None
number = pos if named is None else named
rec.update({
    "number": number,
    "name_number": named,
    "position": pos,
    "conforms": bool(whole.fullmatch(name)),
    ...
})
```

The binder before and after (`plugins/bookcraft/skills/makebook/scripts/build-book.py`,
`load_chapters`). Before, it had its own appendix pattern, and the label counted every file
bound so far, appendices included:

```python
for path in sorted(src.glob("*.md")):
    if path.name in skip:
        continue
    ...
    am = APPENDIX_FILE_RE.search(path.name)
    chapters.append({
        "appendix": bool(am),
        "label_num": int(am.group(1)) if am else len(chapters) + 1,
```

After, the kind, the label and the part come from the model, and `num` stays the binder's own
running sequence:

```python
for rec in book_model.chapters(book):
    ...
    chapters.append({
        "appendix": rec["kind"] == "appendix",
        "label_num": rec["number"],
        "label": rec["label"],
        "unit": rec["unit"],
        "part": rec["part"],
        "num": len(chapters) + 1,
```

`check-book.sh` reading the model (`plugins/bookcraft/skills/createbook/scripts/check-book.sh`),
in place of eleven `jq` reads and its own filename rules:

```bash
model_rows=$(python3 "$model" --tsv "$dir") || exit 2
while IFS=$'\t' read -r row f1 f2 f3 f4 f5 f6 f7 f8; do
  case "$row" in
    decl) ... ;;
    file)
      chapters+=("$dir/$f7")
      file_kind+=("$f1")
      file_num+=("$f2")
      ...
```

## Plan alignment

**Delivered as planned.**
- The inventory of every rule, by tool and line.
- The rulings, settled before the model was written.
- One stdlib model.
- The binder, both Python checkers and `check-book.sh` reading it.
- The agreement fixture, covering the ticket's five names.
- The version bump.

**Deviations, each settled by the operator on 2026-10-15.**
- **R9: the paragraph half moved to `## Deferred`.** That was each paragraph's tag and mark. No
  consumer in the plan reads paragraph data, so emitting it would have been a fifth copy of the
  rules. Its rules are recorded in R9 for #72, which already rewrites `units_of()`.
- **R8: `jq` leaves `check-book.sh` entirely.** The objective required only the reads that
  decide what a file is. Keeping `jq` for the rest would have meant two required tools and two
  degraded modes.
- **R7: CI gains a Python 3.9 job.** The checkers run under whatever `python3` is on PATH, and
  bookcraft's CI tested only 3.12.

**`render-report.py` needed no change.** It never reads the book folder. It takes each file's
kind and number from the worklist index `check-provenance.sh --emit-worklist` writes, so it
reaches the model through that emitter.

## Testing

**Automated.**
- **The suite passes 19 of 19.** With Python 3.9.6 first on PATH and no binder venv, it passes
  16, and the three binder checks skip as designed.
- **CI passes all six jobs on `9ee270a`,** including `checkers (macos-latest, python system)`.
- **`book-model/run.sh` fails on drift.** Two deliberate mutations of a copy of the plugin each
  failed it:
  - `check-references.sh` dropping the appendix `A` failed five appendix checks.
  - The binder labelling by position failed `bk-appendix-10-ten.md`.
- **The pre-test review approved.** It ran its own cases, including filenames with spaces, an
  empty title and a CRLF file with a mark above the H1.

**By hand.**
1. Bind a real `/createbook` book that has appendices and `sections` with `/bookcraft:makebook`.
   The contents page, PDF outline and EPUB should label chapters and appendices as before, and
   no appendix should sit inside a part.
2. Run `check-book.sh` on that book. It should pass as it did on `main`.
3. Bind a plain folder of notes whose names carry no numbers. It should bind as Chapters 1 to N
   in filename order, with no new warnings.

**Edge cases considered.**
- The ticket's four malformed appendix names, and `sql-02-appendix-1-of-the-standard.md`.
- A two-digit appendix, and a leading zero.
- Names numbered by position: a digit in the book slug, no book slug, a one-digit number, no
  number at all.
- A chapter-number gap, and an appendix sorting ahead of the chapters.
- A renamed glossary and front matter, a `description_file`, and an un-excluded `OUTLINE.md`.
- An appendix under narration, and a mark above the H1.
- A file that is not UTF-8, a tab in a filename, and `"profile": 0`.

## Impact assessment

- **Size.** 26 files changed, 2,259 lines added and 699 removed. About 820 of the added lines
  are this branch's own plan, changelog and review.
- **Dependencies.** `check-book.sh` now needs `python3` 3.9 or newer, which `/createbook`
  already needed for `check-provenance.sh`, `check-references.sh` and `assertions.sh`. It no
  longer reads `jq`. No package is added.
- **Behavior a book can notice.** For every book `check-book.sh` passes today, only three
  things change:
  - A `sections` range that reaches past the last chapter no longer nests an appendix in the
    binder's contents page, outline and nav.
  - A `ch. N` or `(ch. N)` past the last chapter now fails.
  - `check-book.sh` needs `python3`.
- **Behavior on odd names.**
  - A malformed appendix name binds as an appendix, with a warning.
  - A gap binds as its names say.
  - Under narration, an appendix fails by name.
  - A file that is not UTF-8 now fails `check-book.sh`, as the binder already refused it.
- **Breaking.** The no-`jq` fallback is gone, by ruling R8. A machine without `python3` can no
  longer run `check-book.sh` at all, where it used to grade in the weakest mode.

## Deferred work

- **The paragraph half of the model,** each paragraph's tag, mark and fence, deferred to #72 by
  ruling R9. Its rules for when it lands are recorded in the branch's `CHANGELOG.md`:
  - a mark fills its line
  - a fence follows CommonMark
  - a mark after a blank line covers the unit above it
  - digits are ASCII only

  Those rules are also posted to #72 as a comment, so its work inherits them.
- **The appendix-number collision ticket, #21, was closed by hand at the close.** #17 repaired
  the collision on 2026-09-21, the day before #21 was filed, and
  `check-claims/fixtures/appendix/run.sh` reproduces it and passes on `main`.
- **From the review, recorded and dropped.** Non-ASCII chapter names are left out of
  `check-references.sh`'s baseline, which predates the branch. The binder's "could not locate
  chapters" message prints its internal sequence number, which only the operator sees.
