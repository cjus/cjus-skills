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
- [x] Settle the canonical rule for each disagreement (see `## Open Questions`) before
  writing the model. Done 2026-10-15: the operator accepted R1 to R10 as written in
  `CHANGELOG.md § recommendations for every open question`.

### One model

- [x] A stdlib-only `book_model.py` that reads `book.json` and the folder once and emits the
  book as JSON: each file's kind (chapter, appendix, front matter, glossary, excluded), its
  number and display label, its title, its `sections` group, and, in a tagged book, each
  paragraph's tag and mark. It needs no venv, so every checker can call it. Ruled 2026-10-15:
  it lives at the plugin level as `scripts/book_model.py` and runs on Python 3.9 (R7). The
  paragraph half moved to `## Deferred` for #72 (R9), so the model is file-level only.
  Done 2026-10-15: `scripts/book_model.py`, `classify` from names and `read` from a folder, with
  `--tsv` and `--json`.

### Every tool reads it

- [x] `build-book.py` classifies files from the model, and `APPENDIX_FILE_RE` and its siblings
  go.
  Done 2026-10-15: `APPENDIX_FILE_RE`, `prettify`, `load_config` and `group_for` are gone.
- [x] `check-provenance.sh` and `check-references.sh` classify from the model, and their
  `APPENDIX_FILE` copies go.
  Done 2026-10-15: both `APPENDIX_FILE` copies, `chapter_id`, `CHAPTER_FILE` and `unit_of` are
  gone.
- [x] `render-report.py` takes chapter and appendix numbers from the model, so they cannot
  collide the way #21 describes. Status: `render-report.py` never reads the book folder. It
  takes `(kind, number)` from the index that `check-provenance.sh --emit-worklist` writes, so
  this item is done once that emitter reads the model. #21's collision is already fixed on main
  (#17), and `check-claims/fixtures/appendix/run.sh` reproduces it and passes.
  Done 2026-10-15, through the emitter: `check-provenance.sh --emit-worklist` writes each file's
  kind and number from the model.
- [x] `check-book.sh` reads the model's output for what a file is, in place of its own
  filename rule. Ruled 2026-10-15 (R8): it reads tab-separated lines through `python3` and
  `jq` goes. The model also hands back the `book.json` declarations, and
  `fixtures/jq-unrunnable/` becomes a missing-or-broken `python3` test.
  Done 2026-10-15: no `jq` read and no filename rule remains, and `fixtures/python-unrunnable/`
  replaced `fixtures/jq-unrunnable/`.

### Prove they agree

- [x] A fixture hands every tool the same filenames and asserts each one classifies every file
  the same way. It covers `bk-appendix-1-answer-key.md`, `bk-appendix-1-Answer-Key.md`,
  `bk-appendix-1-answer--key.md`, `bk-appendix-1-answer_key.md` and
  `sql-02-appendix-1-of-the-standard.md`.
  Done 2026-10-15: `createbook/fixtures/book-model/run.sh`, 75 checks, and two deliberate
  mutations each fail it.
- [x] The existing fixture suite passes unchanged, apart from any expectation a settled
  canonical rule deliberately changes, each named in the changelog.
  Done 2026-10-15: 19 of 19. The deliberate changes, each named in the changelog:
  `guide-under-narration`'s expected message (R4), `jq-unrunnable` rewritten for `python3` (R8),
  the appendix fixture's fifth test reading the model, and two fixtures loading
  `check-provenance.sh` where it sits.

### Release

- [x] Bump bookcraft's version in `plugin.json` (currently 1.14.0), and run the fixture checks
  CI runs. Ruled 2026-10-15 (R7): CI gains a leg that runs the checkers under Python 3.9.
  Done 2026-10-15: 1.14.0 to 1.15.0. The suite passes 19 of 19, and a local run of the floor job
  under 3.9.6 passes with its three expected skips. CI passes all six jobs on `9ee270a`, the 3.9
  `checkers` job among them.

## Open Questions

All settled 2026-10-15: the operator accepted R1 to R10 (`CHANGELOG.md § recommendations for
every open question`).

- Where `book_model.py` lives: plugin-level `scripts/`, Python 3.9 floor (R7).
- The appendix rule: the name's opening decides kind and number, and the whole name decides
  whether it conforms. The binder binds a malformed appendix and warns (R1).
- Whether `check-book.sh`'s `jq` reads retire: yes, all of them (R8).
- How `check-book.sh` reads the model: tab-separated lines through `python3` (R8).
- Whether #21 or #72 is in flight elsewhere: neither is.
- Where a chapter's number comes from: its name, or its position when the name carries none (R2).
- The skip list: the union of the four (R3).
- Appendices under narration: the kind is profile-independent, and `check-book.sh` fails one
  under narration with its own message (R4).
- `sections` and appendices: an appendix is never in a part (R5).
- `ch. N` and `(ch. N)`: chapters only (R6).
- The paragraph rules: deferred with the paragraph half, for #72 (R9).
- The title: the binder's rule (R10).

## Deferred

- The paragraph half of the model: each paragraph's tag, mark and fence, by ruling R9. It goes
  to #72, with the rules recorded in R9. No consumer in this plan reads it. Triaged 2026-10-17:
  R9's rules posted to #72 as a comment, by the operator's approval.
- The appendix-number collision ticket, #21. It was repaired by #17 before it was filed, and
  `check-claims/fixtures/appendix/run.sh` reproduces it and passes on main. Triaged 2026-10-17:
  closed by hand, with that evidence, by the operator's approval.

Triaged at the close, 2026-10-17: the two items above survived and acted on existing issues, so
no follow-up issue was filed. Six were dropped:
- non-ASCII names missing from the `check-references.sh` baseline, which predates this branch
- the binder's internal number in an operator-only message, which predates it
- an empty mark above the H1, which the binder strips
- old Mac line endings in `title_line`
- fixture rows for the two `9ee270a` fixes
- two omissions from the summary
