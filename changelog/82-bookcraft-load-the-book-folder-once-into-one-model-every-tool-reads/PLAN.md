# bookcraft: load the book folder once, into one model every tool reads

Start date: 2026-10-12 10:47:01 MDT

Ticket: #82 (status:todo -> status:in-progress)

## Overview

Every bookcraft tool reads the book folder on its own. Each one has its own copy, in bash or in
Python, of the rules that say what a file is: chapter discovery and order, the skip list, the
appendix name and the chapter number. The copies have drifted. The appendix filename rule
exists four times and the copies disagree, so the binder can bind a file as a chapter that
the checkers grade as an appendix. That has shipped before.

The objective is one stdlib-only `book_model.py` that reads `book.json` and the folder once
and emits the book as JSON. `build-book.py`, `check-provenance.sh`, `check-references.sh`,
`render-report.py` and `check-book.sh` all classify files from its output instead of their own
rules. A fixture hands every tool the same filenames and proves they classify each one the
same way.

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred`, never as new scope.

## About Ticket

The body of #82 as of the branch start. It has no comments. Its action items are tracked under
`## Plan`.

Every bookcraft tool reads the book folder on its own. The rules that say what a file *is*
(chapter discovery and order, the skip list, the appendix name, the chapter number) are
written once per tool, in bash and in Python, across `makebook/scripts/build-book.py`,
`createbook/scripts/check-book.sh`, `check-provenance.sh` and `check-references.sh`.

The appendix filename rule shows what that costs. It exists four times, and the copies no
longer agree:

| Where | Pattern |
|---|---|
| `build-book.py`, `APPENDIX_FILE_RE` | `^[a-z]+(?:-[a-z]+)*-appendix-(\d+)-[a-z0-9-]+\.md$` |
| `check-book.sh`, the guide-profile filename check | `^[a-z]+(-[a-z]+)*-appendix-[0-9]+-[a-z0-9]+(-[a-z0-9]+)*\.md$` |
| `check-provenance.sh`, `APPENDIX_FILE` | `^[a-z]+(?:-[a-z]+)*-appendix-(\d+)-` (prefix only) |
| `check-references.sh`, `APPENDIX_FILE` | `^[a-z]+(?:-[a-z]+)*-appendix-(\d+)-` (prefix only) |

Run against the same names:

| Filename | binder | provenance / references | check-book |
|---|---|---|---|
| `bk-appendix-1-answer-key.md` | appendix | appendix | appendix |
| `bk-appendix-1-Answer-Key.md` | chapter | appendix | not an appendix |
| `bk-appendix-1-answer--key.md` | appendix | appendix | not an appendix |
| `bk-appendix-1-answer_key.md` | chapter | appendix | not an appendix |

`check-book.sh` fails all three odd names on its filename rule, so a book that passed it
carries none of them today. But `/makebook` binds any folder and `check-provenance.sh` runs
without `check-book.sh`, and the disagreement has shipped before. The comment on
`APPENDIX_FILE_RE` records `sql-02-appendix-1-of-the-standard.md` binding as Appendix 1 while
every checker read it as chapter 2. #21 is the same class of fault: the worklist emitter
numbered appendices from the filename's first digit run, so they collided with chapters 1 to N.

**Proposal** (tracked under `## Plan`):

- A stdlib-only `book_model.py`, needing no venv so every checker can use it, that reads
  `book.json` and the folder once and emits the book as JSON. That covers each file's kind
  (chapter, appendix, front matter, glossary, excluded), its number and display label, its
  title, its `sections` group, and, in a tagged book, each paragraph's tag and mark.
- Move `build-book.py`, `check-provenance.sh`, `check-references.sh` and `render-report.py`
  onto it, and have `check-book.sh` read its output.
- A fixture that hands every tool the same set of filenames and asserts they classify each one
  the same way, including the four above and `sql-02-appendix-1-of-the-standard.md`.

Where `check-book.sh` reads `book.json` through `jq` today, the model could hand it the
resolved values instead, which would retire the degraded no-`jq` grading that
`fixtures/jq-unrunnable/` exists to guard.

**Cost of leaving it:** every new rule about what a file is has to be written once per tool,
and a missed copy ships a book the checkers grade differently from how it binds.

**Occasion:** before the next rule that classifies files lands. #21's fix is one, and so is
#72, which reworks `units_of()` in `check-provenance.sh`.

## Plan

### Inventory the rules

- [x] For each of the five tools, list every rule that decides what a file is: discovery and
  order, the skip list, front matter, glossary, appendix name and number, chapter number,
  display label, title, `sections` group, and paragraph tag and mark. Record where the copies
  disagree beyond the appendix pattern. Done 2026-10-12: `CHANGELOG.md § the rules inventory`.
  It found six more disagreements, which are now listed under `## Open Questions`.
- [ ] Settle the canonical rule for each disagreement (see `## Open Questions`) before
  writing the model.

### One model

- [ ] A stdlib-only `book_model.py` that reads `book.json` and the folder once and emits the
  book as JSON: each file's kind (chapter, appendix, front matter, glossary, excluded), its
  number and display label, its title, its `sections` group, and, in a tagged book, each
  paragraph's tag and mark. It needs no venv, so every checker can call it.

### Every tool reads it

- [ ] `build-book.py` classifies files from the model, and `APPENDIX_FILE_RE` and its siblings
  go.
- [ ] `check-provenance.sh` and `check-references.sh` classify from the model, and their
  `APPENDIX_FILE` copies go.
- [ ] `render-report.py` takes chapter and appendix numbers from the model, so they cannot
  collide the way #21 describes. Status: `render-report.py` never reads the book folder. It
  takes `(kind, number)` from the index that `check-provenance.sh --emit-worklist` writes, so
  this item is done once that emitter reads the model. #21's collision is already fixed on main
  (#17), and `check-claims/fixtures/appendix/run.sh` reproduces it and passes.
- [ ] `check-book.sh` reads the model's output for what a file is, in place of its own
  filename rule.

### Prove they agree

- [ ] A fixture hands every tool the same filenames and asserts each one classifies every file
  the same way. It covers `bk-appendix-1-answer-key.md`, `bk-appendix-1-Answer-Key.md`,
  `bk-appendix-1-answer--key.md`, `bk-appendix-1-answer_key.md` and
  `sql-02-appendix-1-of-the-standard.md`.
- [ ] The existing fixture suite passes unchanged, apart from any expectation a settled
  canonical rule deliberately changes, each named in the changelog.

### Release

- [ ] Bump bookcraft's version in `plugin.json` (currently 1.14.0), and run the fixture checks
  CI runs.

## Open Questions

- Where does `book_model.py` live? The five tools sit in three skills
  (`makebook/scripts/`, `createbook/scripts/`, `check-claims/scripts/`), so the model needs a
  path each can reach once the plugin is installed. Candidates: the plugin-level `scripts/`
  beside `install.sh`, or one skill's `scripts/` that the others call by relative path.
- What is the canonical appendix rule? The model has to give each of the four odd names
  above a single answer: appendix, chapter, or rejected as malformed. Should the binder,
  which today binds any folder, refuse a name the checkers would reject, or bind it and warn?
- Is retiring `check-book.sh`'s `jq` reads in scope? The ticket says the model *could* hand it
  the resolved values, which would retire `fixtures/jq-unrunnable/`. The objective only
  requires that `check-book.sh` read the model for what a file is. Its other `book.json` reads
  could move too, or be deferred.
- How do the bash checkers consume the JSON: through `python3` directly, through `jq`, or
  through a flat form the model also emits? Whichever is picked, a checker must not need a
  tool the checker did not already need.
- #21 and #72 are both open and both land on this model. Confirm neither is in flight on
  another branch that would conflict. Resolved 2026-10-12: both are `status:todo`, with no
  branch, worktree or PR.

The inventory (`CHANGELOG.md § the rules inventory`) adds these, each needing a canonical rule:

- Where does a chapter's number come from: its sort position (the binder), or the filename's
  `-NN-`? If the filename, which reading? Only `check-book.sh`'s strict reading rejects
  `bk2-07-slug-digit.md` rather than reading it as chapter 2 or chapter 7.
- What is the skip list? The four tools skip four different sets. The union is `OUTLINE.md`,
  `description_file`, `glossary_file`, `front_matter_file` and `exclude`.
- Is an appendix an appendix under the narration profile? The binder and two checkers say yes;
  `check-book.sh` says no, and it reads `bk-appendix-10-x.md` as chapter 10 there.
- Does a `sections` range ever take in an appendix? The binder's chapter eyebrows say no, while
  its contents page, PDF outline and EPUB nav say yes.
- Can a `ch. N` in a mark, or a glossary's `(ch. N)`, point at an appendix? Today all three
  bounds count appendices as chapters.
- Paragraph rules for the tagged-book half of the model: does a mark have to fill its line, and
  is `~~~` a fence?

## Deferred

- None yet.
