# bookcraft: a reader test and revision loop held to a book-level budget

Start date: 2026-11-18 22:51:22 MST

Issue: https://github.com/cjus/cjus-skills/issues/129

## Overview

Add a reader test after drafting, a revision pass driven by it, and a book-level reading budget that revision is held to.

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred`, never as new scope.

**Stacked branch.** This branch starts from the #127 branch, the last of a stack (#130, #128, #127), because the reader test belongs to the primer flow those branches build. Its PR targets the #127 branch and should merge after it.

## About Ticket

### The reader test
- [x] A fresh agent reads only the finished chapters as the persona, with nothing else open; an unexplained term counts as unknown.
- [x] Notes per chapter: stumbles, unanswered questions, repeats and contradictions, too much, formulaic passages, recurring habits, what worked.
- [x] Comprehension questions from the coverage ledger, from memory then checked, each saying whether the book alone equipped the reader.
- [x] A rating for how well the book got the reader up to speed in the budget.
- [x] Notes in the book folder, never bound.

### Revision
- [x] Notes become a revision brief first: book-wide conventions and per-chapter changes.
- [x] Revisers grouped by dependency.
- [x] Every added fact meets the first draft's sourcing rules.

### A budget revision is held to
- [x] The reading budget binds the whole book, and the read time is reported before and after.
- [x] A fix adds nothing net, paid for with cuts from what the reader marked unneeded.

### Confirming
- [x] A second, unanchored reader after revision.
- [x] When the loop stops: every question answered, no blocking stumble, within budget; two rounds at most.

## Plan

- [x] `reference/reader-test.md`: the reader's prompt, the questions, the revision brief, revising, confirming and stopping.
- [x] `check-book.sh` and `book_model.py`: `reading_budget` declared, validated, and the read time printed for a primer or a budgeted book, reported when past the budget.
- [x] `createbook/SKILL.md`: step 8b, `reading_budget` in the primer template and § Under the primer profile, step 9 reports the budget and the reader test.
- [x] `updatebook/SKILL.md`: report the read time, and suggest a re-test after a large primer edit.
- [x] `fixtures/primer` declares a budget it runs past; `fixtures/research` shows "none declared"; README; NOTES.md; plugin 1.20.0.

## Status

Done. `scripts/test-fixtures.sh --strict` passes 27 of 27. The review approved (pr-review-2026-11-18.md), and its four important wording gaps were fixed:

- A round is defined, with what follows the second reader. A factual error a reader found is a stop condition.
- A book with no budget has no budget item or condition, and no chapter is handed a word target.
- updatebook suggests a re-test of the whole book.
- Step 9 reports the read time before and after the revision.

From its suggestions, `reading_budget` must be 1 to 9999 with no leading zeros, and the new `fixtures/primer-bad-budget` covers a malformed one.

## Deferred

- None.
