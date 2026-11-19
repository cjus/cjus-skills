bookcraft: test a book on a reader and hold its revision to a reading budget

reference/reader-test.md is the procedure: a fresh agent reads only the chapters as the book's reader, notes stumbles and what it could do without, answers questions from the coverage ledger, and rates the book; its notes become a revision brief; revisers work by dependency group and every addition is paid for by a cut; a second, unanchored reader confirms, two rounds at most.
check-book.sh reads reading_budget, prints the book's read time for a primer or a budgeted book, and reports a book past its budget.
createbook/SKILL.md adds step 8b and puts reading_budget in the primer template and step 9's report.
updatebook/SKILL.md reports the read time and suggests a whole-book re-test after a large primer edit.
fixtures/primer runs past a declared budget, fixtures/research declares none, and fixtures/primer-bad-budget is refused.
README, NOTES.md and the plugin version, 1.20.0.
The plan folder holds the plan, changelog, PR summary and review.
