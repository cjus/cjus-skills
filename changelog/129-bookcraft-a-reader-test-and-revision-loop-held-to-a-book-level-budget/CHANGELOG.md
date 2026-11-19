# bookcraft: a reader test and revision loop held to a book-level budget

Start date: 2026-11-18 22:51:22 MST

Issue: https://github.com/cjus/cjus-skills/issues/129

## Changes

- **`reference/reader-test.md`**, new.
  - The reader: a fresh agent given only the chapters, never a writer of them, with a prompt that
    names the persona, what to note per chapter, and the reply's shape.
  - The questions: written from the coverage ledger, plus one end-to-end explanation and one
    "where next", never one whose answer the outline left out.
  - The revision brief, written to `reader/revision-brief-<N>.md` before any chapter is touched.
  - Revising by dependency group, with a fix adding nothing net.
  - A second, unanchored reader, and the stop conditions: every question answered, no blocking
    stumble, within budget, two rounds at most.
- **`check-book.sh` and `book_model.py`.**
  - `reading_budget` is declared and must be a whole number of minutes.
  - A primer, or a book with a budget, gets a `read time:` line, and a book past its budget gets
    a report, never a failure.
- **`createbook/SKILL.md`.**
  - New step 8b: the reader test, required under primer and optional otherwise.
  - `reading_budget` is in the primer template and § Under the primer profile.
  - Step 9 reports the read time against the budget and the reader test's outcome.
- **`updatebook/SKILL.md`:** the report carries the read-time line, and a large primer edit
  suggests a re-test.
- **Fixtures.** `fixtures/primer` declares a 3-minute budget, runs about 6, and draws the report.
  `fixtures/research` prints "budget: none declared".
- **After the review.** Rounds are defined, with what follows the second reader. A remaining
  factual error blocks the stop, and a book with no budget has no budget condition. Revisers get no
  per-chapter word target. updatebook suggests a whole-book re-test, and step 9 reports the read
  time before and after. `reading_budget` must be 1 to 9999, and `fixtures/primer-bad-budget` is new.
- README, NOTES.md "The reader test, 2026-11-18", plugin 1.20.0.
