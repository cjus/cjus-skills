make two regression assertions able to fail, and close the branch

The close-gate review found that two of the assertions added in the previous
commit could not fail, which is the fault the assertions were added to catch.

The superscript case passed the literal six characters backslash-u-0-0-b-2.
Bash does not interpret that escape in a double-quoted string, so the token
reaching the script was not a superscript at all, and str.isdigit() and
str.isdecimal() refused it identically: the assertion passed with the bug in
place. It now builds the character with printf's octal escapes.

The anchored appendix filename rule shipped with no assertion at all, which
its own commit message claimed otherwise. A unit probe now checks five
filenames against chapter_id, including a chapter whose slug contains
"appendix-2-", which is the case the unanchored pattern read as an appendix.
No book folder can carry that file, since check-book.sh rejects the name, so
the rule is checked below the CLI rather than through a fixture.

Both were proved by reverting the fix and confirming the assertion fails.

A third assertion written during this round was itself vacuous and is removed
rather than kept: no assertion can distinguish a colon terminator, because
heading_hit matches on a prefix and both spellings then give the same verdict
for every heading in the fixtures. The comment on CITE_SECTION records the
real reason a colon is excluded, which is not the reason first given.

Closing artifacts: the PR summary, whose testing section now separates what is
asserted from what was only exercised by hand, and the close review.
