# bookcraft: a reader test and revision loop held to a book-level budget

## Overview

Every check `/createbook` ran was a compliance check, and nothing tested whether a reader comes away able to do what the book promised. This PR adds a reader test after drafting, a revision pass driven by it, and a book-level reading budget that the revision is held to.

The shape comes from a hand-built trial primer.

- **The first reader** answered all nine comprehension questions. It also found what no checker could: chapters that listed instead of teaching, output shown before it was explained, and recap openings in seven of eight chapters.
- **The revision** fixed those and grew the book from about 70 to about 99 minutes against a 90-minute budget, every chapter near its ceiling.
- **A second, unanchored reader** then found two factual errors.

`NOTES.md § The reader test, 2026-11-18` has the detail.

**This branch is stacked on the #127 branch**, the top of a stack: #130, then #128, then #127, then this. Its PR targets the #127 branch and should merge last.

## Key changes

- `skills/createbook/reference/reader-test.md` (new): the procedure.
- `skills/createbook/scripts/check-book.sh`, `scripts/book_model.py`: `reading_budget`, the `read time:` line, and the over-budget report.
- `skills/createbook/SKILL.md`: step 8b; `reading_budget` in the primer template and § Under the primer profile; step 9's report.
- `skills/updatebook/SKILL.md`: the read-time line in its report, and a suggested re-test after a large primer edit.
- `fixtures/primer` (budget declared and exceeded) and `fixtures/research` (none declared), with manifest strings.
- README, NOTES.md, plugin 1.20.0.

## Code examples

`plugins/bookcraft/skills/createbook/scripts/check-book.sh`:

```bash
if [ "$profile" = primer ] || [ -n "$declared_budget" ]; then
  read_min=$(((total_words + total_struct + 87) / 175))
  if [ -n "$declared_budget" ]; then
    echo "read time: about $read_min minutes at 175 words a minute    budget: $declared_budget minutes"
    if [ "$read_min" -gt "$declared_budget" ]; then
      report "the book reads in about $read_min minutes, past its reading budget of $declared_budget; ..."
    fi
  ...
```

The stop conditions, `reference/reader-test.md`:

```text
Stop when all of these hold:
- every question is answered correctly from the book alone;
- no stumble remains that blocks understanding of a taught concept;
- the book is within its reading budget.
Two rounds at most.
```

## Plan alignment

Every checklist item in the ticket is done.

- **The open item, when the loop stops:** settled as four conditions the notes and the checker can decide: every question answered, no blocking stumble, no remaining factual error, and within budget where one is declared. Two rounds at most, the second ending with one more revision and a report to the operator if needed, and the rating reported but never gated on.
- **The reader test's place:** step 8b, required under `primer` and optional for the handbook profiles.
- **The budget:** checked mechanically. `check-book.sh` reads `reading_budget` and reports a book past it, using the same 175-words-a-minute rate as the rest of the skill. The reader test is judgement, and the budget is the one part of it a script can hold.

## Testing

- `plugins/bookcraft/scripts/test-fixtures.sh --strict`: 27 passed, 0 failed, 0 skipped.
- `fixtures/primer-bad-budget` exits 2 on a `reading_budget` written as a word. By hand, `"00"` is refused too.
- `fixtures/primer` row asserts the `read time: about 6 minutes ... budget: 3 minutes` line, the over-budget report, and three reports in all.
- `fixtures/research` row asserts `budget: none declared` and no budget report.
- A guide fixture with no budget prints no read-time line.
- The reader test itself is a procedure an agent follows, not a script. It was exercised by hand twice on the trial book, which is where the stop conditions and the "adds nothing net" rule came from.

## Impact assessment

Ten files, about 165 lines added and 10 removed, before this plan folder. No dependencies change.

- A primer now prints a `read time:` line on every `check-book.sh` run.
- A book declaring `reading_budget` gets the same line, and a report when it runs past.
- A handbook book without a budget sees no change.

## Deferred work

None.
