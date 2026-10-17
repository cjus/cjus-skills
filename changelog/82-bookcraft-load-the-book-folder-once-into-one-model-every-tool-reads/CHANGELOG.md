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
checkers are in `createbook/scripts/`. `render-report.py` has no rule of its own: it reads the
worklist index `check-provenance.sh --emit-worklist` writes. #21's collision was already
repaired in that emitter by #17, a day before #21 was filed, and
`check-claims/fixtures/appendix/run.sh` reproduces it and passes on main.

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

Six disagreements beyond the appendix pattern, each confirmed by running the tools' own code:
1. **Chapter numbers, four ways.** The binder's number is a position. Each checker reads the
   filename differently: `bk2-07-slug-digit.md` is chapter 2 to provenance, chapter 7 to
   references, and rejected by `check-book.sh`.
2. **Skip lists, four ways.** Only the binder skipped `description_file`, and only through
   `exclude` did it skip `OUTLINE.md`. `check-provenance.sh` hard-coded the default glossary and
   front-matter names.
3. **Appendices under narration.** `check-book.sh` recognised them only under guide, and graded
   `bk-appendix-10-x.md` as chapter 10 there.
4. **`sections` within the binder.** The chapter pages left appendices out of a part. The
   contents, outline and EPUB nav put them in.
5. **Bounds that counted appendices as chapters.** Provenance's `ch. N`, and the glossary's
   `(ch. N)` in the binder and in `check-book.sh`.
6. **Paragraph rules.** A mark above the H1, a mark mid-line, `~~~` fences, non-ASCII digits.

A case-insensitive disk cannot hold `bk-appendix-1-answer-key.md` and
`bk-appendix-1-Answer-Key.md` side by side, so the agreement fixture classifies names without
creating them.

### 2026-10-12 11:27:13 MDT: recommendations for every open question, awaiting the operator

The investigation confirmed findings 3 and 4 by running the tools. It also found:
- an appendix sorting ahead of the chapters shifted every chapter label in the binder
- `check-references.sh` silently dropped one of two files sharing a number
- a glossary `(ch. N)` past the last chapter printed "ch. 19" over Appendix 1
- no fixture covered `sections` or the three filename keys
- CI tested only Python 3.12 while the checkers run on macOS's 3.9.6

The recommendations:
- **R1.** The name's opening, `<book-slug>-appendix-<N>-` tried first, then `<book-slug>-<NN>-`,
  decides kind and number. The whole name decides conformance, plus no leading zero on an
  appendix. `check-book.sh` fails a malformed name. The binder binds it as what it says and
  warns, never refusing.
- **R2.** A chapter's number is the one in its name, or its position when the name carries none.
  The filename number is what tags, marks, citations and `--chapters` address. Numbers count
  within each kind, and the reading order is chapters, then appendices.
- **R3.** One skip list, the union of all four: `OUTLINE.md`, `description_file`,
  `glossary_file`, `front_matter_file` and `exclude`.
- **R4.** An appendix is an appendix under either profile. `check-book.sh` fails one under
  narration with its own message.
- **R5.** No appendix is in a `sections` part. Parts list chapter numbers.
- **R6.** A mark's `ch. N` and a glossary's `(ch. N)` name chapters only, since an appendix never
  teaches (`guide.md:187`).
- **R7.** The model lives at plugin-level `scripts/book_model.py` with a Python 3.9 floor, and CI
  gains a 3.9 job.
- **R8.** `check-book.sh` reads the model through `python3` as tab-separated rows. Every `jq`
  read goes, there is no degraded mode, and `fixtures/jq-unrunnable/` becomes a `python3` test.
- **R9.** The paragraph half of the model moves to `## Deferred`, for #72, which already rewrites
  `units_of()`. Its rules for when it lands:
  - A mark fills its line.
  - A fence follows CommonMark: three or more backticks or tildes, closed by the same character
    at least as many times.
  - A mark after a blank line covers the unit above it, as `check-book.sh` already treats it
    (:931) and as #72 proposes.
  - Digits are ASCII only.
- **R10.** The title is the first line once whole-line marks are stripped, when that line is an
  H1, and otherwise comes from the filename.

For books `check-book.sh` passes today, only R5's parts, R6's bounds and R8's `python3`
requirement change anything.

### 2026-10-15 12:17:49 MDT: the open questions are settled

The operator accepted R1 to R10 as written. Three change the plan's scope: R8 removes `jq`
entirely, R9 defers the paragraph half to #72, and R7 adds a Python 3.9 CI leg.

### 2026-10-15 12:24:23 MDT: the book model, and the binder reads it

- **`scripts/book_model.py`.** It runs under 3.9.6 and 3.14.
  - `classify(names, cfg)` is pure, and `read(folder)` adds titles.
  - Each chapter-kind file carries its kind, number, name number, position, conformance, label,
    unit, part and title.
  - `problems` words faults as `check-book.sh` did, and `--tsv` and `--json` print the model.
- **`build-book.py`.**
  - `prettify`, `load_config`, `APPENDIX_FILE_RE` and `group_for` are gone. `PROVENANCE_RE` is
    the model's `MARK_LINE`.
  - Labels, parts and figure prefixes come from the model, and `num` stays internal.
  - A glossary `(ch. N)` must name a chapter, and a claimed-but-malformed name warns.
- **Fixed in passing:** the EPUB's appendix figure numbers and index labels, which disagreed with
  the PDF.
- **Fixtures.** The bind, display-names and save-scripts fixtures pass.

### 2026-10-15 12:27:55 MDT: check-provenance.sh and check-references.sh read the model

- **`check-provenance.sh`.** It borrows the model, and `APPENDIX_FILE` and `chapter_id` are gone.
  `--chapters` and the worklist index take `(kind, number)` from the model, and `ch. N` must name
  a chapter.
- **`check-references.sh`.** `APPENDIX_FILE`, `CHAPTER_FILE`, `unit_of` and the unused `json`
  import are gone. `units_of(model)` notes a unit two files claim, and the `git ls-tree` baseline
  is classified by `book_model.classify`.
- **Fixtures.** `createbook/fixtures/ledger` and `check-claims/fixtures/appendix` load
  `check-provenance.sh` in place rather than from a temp copy. The appendix fixture's fifth test
  checks the model in place of `chapter_id`, a deliberate change.
- 18 of 18 fixtures pass, and both checkers run under 3.9.6.

### 2026-10-15 12:39:05 MDT: check-book.sh reads the model through python3, and jq goes

- **`check-book.sh` reads `--tsv` rows (R8).**
  - All 11 `jq` reads are gone, and so are its `find | sort` walk and its own filename rules.
  - It needs `python3` 3.9 or newer, and exits 2 when it is missing or will not run.
- **Deliberate behavior changes.**
  - An appendix under narration fails by name (R4).
  - A `(ch. N)` must name a chapter (R6).
  - The body starts below the H1 (R10).
  - A file that is not UTF-8 fails.
- **The TSV rows.** No field is empty but the last, since bash's `read` collapses tabs. A
  declaration that would print empty is omitted, which reads as absent, as jq's empty output did.
- **Fixtures.**
  - `fixtures/jq-unrunnable` became `fixtures/python-unrunnable`, with a working, a broken and a
    missing `python3`; the missing case now expects a stop.
  - `test-fixtures.sh` drops its `jq` gate, and the `guide-under-narration` row expects the new
    message.
  - `assertions/run.sh` drops its `jq` skip.
- **CI.** It asserts that `python3` runs. A new `checkers-floor` job runs the suite under the
  runner's `/usr/bin/python3`, asserting 3.9. It runs without `--strict` and fails on any skip
  besides the binding fixtures.
- 18 of 18 pass, also with 3.9.6 first on PATH.

### 2026-10-15 12:44:22 MDT: the agreement fixture

`createbook/fixtures/book-model/run.sh` holds 75 checks:
- **27 on the model's own table, from names alone.** The ticket's names, `sql-02-…`, a two-digit
  appendix and a leading zero, names numbered by position, every skip rule, problems, reading
  order, parts, and the title below a mark.
- **40 that run every tool on the same names, one folder each.** The binder's records, the
  worklist index, `units_of` and `check-book.sh`'s verdicts, plus folders for the skip list,
  narration and a mark above the H1. The binder's share skips without the venv.
- **8 that guard against any tool regaining a filename rule.**

Mutating `check-references.sh` to drop the appendix `A`, or the binder to label by position, each
fails it. The floor job allows its one binder skip by exact count. 19 of 19 pass.

### 2026-10-15 12:47:31 MDT: the docs, and bookcraft 1.15.0

The docs now describe the model, the `python3` floor and the retired `jq` fallback:
- the root `README.md`
- the bookcraft `README.md`, whose script-fixture count of "Ten" corrects one already short on
  main
- `createbook/SKILL.md` and `makebook/SKILL.md`
- a dated `createbook/NOTES.md` section

bookcraft goes from 1.14.0 to 1.15.0, and every plan item is ticked. 19 of 19 pass, and 233
citations resolve.

### 2026-10-15 14:44:03 MDT: the pre-test review, and its two in-scope suggestions applied

Draft PR #96 opened, and the review (`pr-review-2026-10-15.md`) approved. Two of its four
suggestions were faults this branch introduced, and both are fixed:
- `"profile": 0` is refused again, as on main, now that the check tests by identity.
- A tab or line break in a `book.json` filename key is refused.

The other two were left: an empty mark above the H1, which the binder strips, and old Mac line
endings in `title_line`. 19 of 19 pass.
