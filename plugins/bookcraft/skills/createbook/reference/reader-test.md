# Testing a book on a reader

Under the handbook profiles the test is optional, and a book with no `reading_budget` simply has no budget condition. Every check `/createbook` runs before this one is a compliance check: a clean run says the folder is well formed and its marks resolve, and nothing about whether a reader comes away able to do what the book promised. This file is the test for that, and the revision it drives. `SKILL.md § 8b` says when it runs. `NOTES.md § The reader test, 2026-11-18` says why it has the shape it has.

## The reader

A fresh agent reads the finished chapters as the book's reader, the persona the outline names, with what that persona knows and nothing more. **It is given the chapter files and nothing else**: no outline, no rule files, no research, no sources, no earlier reader's notes, and no web search. A term the book has not explained counts as unknown to it, even where the agent happens to know it, because the real reader does not.

**The reader is never the agent that wrote or revised a chapter**, and never this session. A writer cannot feel a missing step, because they hold the step.

### Its prompt carries

1. The persona, from the outline's top line: who the reader is, what they already know, and their reading budget for the book.
2. The chapter files in reading order, by path, with the instruction to read them once, start to finish, and to ignore the `<!-- src: ... -->` lines, which a reader never sees.
3. What to note per chapter, as it reads:
   - **Stumbles:** a term used before it was explained, a step it could not follow, a sentence it had to read twice. The words quoted, and what was missing.
   - **Unanswered questions:** something the chapter made it want to know and then did not tell it.
   - **Repeats and contradictions:** something explained twice, two chapters that disagree, one thing with two names.
   - **Too much:** passages it could have done without, given its budget.
   - **Formulaic passages:** prose that sounds machine-written or padded, quoted, and any habit that recurs across chapters, such as the same opening move or the same closing line.
   - **What worked:** the passages that made an idea click, so a revision keeps them.
4. The comprehension questions (below), to answer **after** reading, from memory first and then checked against the chapters. For each: could it answer from the book alone, was the answer right when checked, and if not, what the book failed to give it.
5. A rating from 1 to 10 for how well the book got it up to speed within the budget, and two sentences on what would most raise it.
6. The output path, `<book>/reader/reading-notes-<N>.md`, where `<N>` is the round (below), and the instruction to reply with a short summary only: the rating, the three most serious problems, how many questions it could answer, and any recurring habit, in 300 words at most.

### The questions

**Write them from the outline's coverage ledger**, one or two per item: what the reader must be able to do or answer when they finish. Add one question that asks the reader to explain the subject end to end in about 150 words, since a book can teach every part and never assemble them. Add one that asks where to go next for something the book mentioned and left out, where the book points beyond itself. Eight to ten questions is enough.

A question is answerable from the book when a careful reader of these chapters alone could answer it. Never write a question whose answer lies outside the book's selection: a book is not at fault for leaving out what the outline told it to leave out.

## The revision brief

**The reader's notes become a revision brief before any chapter is touched**, written to `<book>/reader/revision-brief-<N>.md`. Parallel revisers cannot agree a shared fix on their own, so the brief makes the decisions they would otherwise each make differently:

- **Book-wide conventions**, one per finding that spans chapters: a unit explained once in a named chapter, a numbering scheme, a habit to stop, such as recap openings or a repeated closing line.
- **Assigned openings**, where the reader found openings that repeat.
- **Per-chapter changes**, each traced to a finding in the notes: the stumble to fix, the question to answer, the passage to cut.
- **What to keep**, the passages the reader said worked.
- **The budget**, where the book declares a `reading_budget`: the book's read time now, from `check-book.sh`'s `read time:` line, against the budget, and where the book is over, how many words the book as a whole must lose. Revisers take those cuts from what the reader marked as too much. No chapter is handed a word target, for the reason `SKILL.md § Sizing the book` gives. A book with no budget, as a handbook may be, carries no budget item.

Where a finding conflicts with the outline's selection, such as a reader wanting depth on something the outline left to the sources, the selection wins and the finding is noted, not acted on.

## Revising

- **Group revisers by dependency.** Chapters that rely on each other, one teaching what the next uses, are revised by one agent. Others can run in parallel.
- **A reviser gets the brief, the notes, its chapters, the rule file for the profile, the context, and the research ledger**, and the same sourcing rules a first draft meets. A fact a revision adds is from the context, a verified ledger entry, or left out.
- **A fix adds nothing net.** An explanation that goes in is paid for with a cut in the same chapter, chosen from what the reader marked as too much. Revision that only adds is how a book outgrows its budget: in the trial, every chapter grew to within 20 words of its ceiling and the book went from about 70 to about 99 minutes against a 90-minute budget.
- **Revisers write findings to `<book>/outline-findings/`** as drafting agents do, never into the reply.

Then run the checks of step 7 again, and `check-book.sh`'s read-time line.

## Confirming, and when to stop

**A round is one reader and the revision its notes drive**, and `<N>` in the file names is the round's number. Round 1 is the first reader and the first revision.

**Round 2 starts with a second reader, unanchored**: a new agent, with the same prompt and questions, never shown the first reader's notes. An agent shown the earlier notes reads for them and finds them fixed.

**Stop when all of these hold:**

- every question is answered correctly from the book alone;
- no stumble remains that blocks understanding of a taught concept;
- no factual error a reader found remains;
- the book is within its `reading_budget`, where it declares one.

**Two rounds at most.** If the second reader's notes meet every condition, stop. If they do not, revise once more under a second brief, run the checks of step 7, and stop there without a third reader. Report to the operator what the second reader found, what the second revision changed, and anything still open, with both readers' notes. A problem that survives two revisions is usually in the outline, and that is the operator's call.

A rating is reported, never gated on. It is one agent's opinion, and a book that answers every question within budget has done its job.
