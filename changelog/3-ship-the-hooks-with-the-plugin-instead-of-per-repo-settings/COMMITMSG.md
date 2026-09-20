correct a drifted case count and condense the branch log

the guard suite's case count was restated in three places and had drifted
twice in one branch, all three saying 48 against an actual 54. the root
README now omits the number entirely, leaving hooks/README.md as the single
place that states it, and PLAN.md's phase 8 note loses a "still outstanding"
line that stopped being true when that phase finished.

condense CHANGELOG.md from 193 lines to 105, keeping all five timestamps and
the evidence under each; the full narrative now lives in the pr summary.

extend hooks/README.md's coverage line with the absent-and-empty cwd cases
the two review rounds added.

record the third review round's approval in pr-review-2026-09-14.md.
