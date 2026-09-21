# Harden the book skills: createbook's unchecked outline, check-claims' missing appendix concept, and three undocumented failure modes

Start date: 2026-09-20 19:32:45 MDT

Close four gaps in `/createbook`'s fan-out machinery — an unverified outline contract, a
sibling-read race, a page locator that resolves but is wrong, and findings lost to a truncated
return — and give `/check-claims` an appendix concept so a book with appendices can be reported
on at all.

## Changes

### 2026-09-21

- **Phase 2.** `createbook/SKILL.md` § 5 now states that no chapter is ever briefed to read
  another chapter of this book. A sibling's outline row is what the agent is given; batches draft
  in parallel, so pointing an agent at a sibling's file races the agent writing it, and the reader
  silently produces the repetition the instruction meant to prevent.
- **Phase 3.** `createbook/SKILL.md` § 7 now notes, beside the paraphrase note, that a page
  locator which resolves is not one that is right. The checker asserts the number is inside the
  PDF's page count; where printed page numbers differ from the page index, a wrong page resolves
  clean.
- **Phase 1.** `check-provenance.sh` gains `--ledger-only`, which reads `OUTLINE.md` alone and
  resolves the source ledger: every re-openable row names a file on disk, and every locator
  written into a row resolves against it. It needs no `book.json`, because step 4 has not written
  one yet. `createbook/SKILL.md` § 3 now runs it before the operator gate. New fixture at
  `fixtures/ledger/` with a 13-assertion `run.sh`.
- **Phase 4.** `createbook/SKILL.md` § 5 now gives each chapter agent a findings path,
  `<book>/outline-findings/<chapter file stem>.md`, and an eleventh prompt item carrying it.
  Findings in a return message are lost when the harness truncates the return; a path per agent
  rather than one shared file, because the batch drafts in parallel.
- **Phase 5.** `/check-claims` carries an appendix through as its own kind. `chapter_number()` in
  `check-provenance.sh` becomes `chapter_id()`, returning `(kind, number)`; the worklist, its
  `index.json` and `judgement.md`'s findings shape all carry both; `render-report.py` keys its
  `want` map and its four sorts on the pair and renders a row reading `appendix 1`; and
  `--chapters` takes `A1` beside `2,13` so a scoped re-check no longer folds in appendix 2. New
  fixture at `check-claims/fixtures/appendix/` with a 13-assertion `run.sh`.

### Notes

- Issue #16 says `render-report.py` "exits 1" on the duplicate-chapter refusal. It returns **2**
  (`render-report.py:358`). The fixture's `run.sh` asserts the real codes.
- `createbook/fixtures/provenance/` fails `check-book.sh` on its part-heading count. That predates
  this branch: neither the fixture nor `check-book.sh` is touched here.
- An appendix is a guide-profile kind, and `check-book.sh` rejects the filename under narration on
  purpose. The new fixture declares `"profile": "guide"` for that reason.

