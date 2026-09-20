# What the Checker Reads

| | |
|---|---|
| **This chapter** | Which guide-profile rules a script can check and which are left to reading. Scope: the second chapter of the guide fixture. |
| **Act on this** | Before adding a rule to the profile, decide which of the two kinds it is, and do not write a check that cannot tell them apart. |
| **Draws on** | `scripts/check-book.sh`; `reference/chapter-prose.md § The guide profile`. |
| **Fills in** | The split between checkable and readable rules, which the spec implies and does not tabulate. |

## In short

Carried in: **profile** (ch. 1), the rule set a book's settings file names, absent meaning the
narration rules.

Some of a rule set can be checked by a script and some cannot, and the difference is not how
important the rule is. What follows walks through what makes a rule checkable, then through the
rules this profile deliberately leaves to a reader.

[2-1] A script can find a literal string and count things. It cannot tell whether a heading earns
its place or whether a callout is the right one. The profile is written so that the rules a
script can hold are the ones stated as literals.
<!-- src: scripts/check-book.sh -->

## What makes a rule checkable

[2-2] A callout is found by its label and by nothing else. The label is four literal characters
of markup, a fixed word, a full stop and a space, which is a grammar that cannot drift. Had the
rule said "a short highlighted aside", nothing could hold it.
<!-- src: reference/chapter-prose.md § The guide profile -->

> **In the room.** When someone asks why the label has to be literal, the answer is that the
> alternative is a checker that guesses, and both of its guesses look like a pass.
<!-- src: reference/chapter-prose.md § The guide profile -->

## What is left to reading

[2-3] Whether a numbered list is a procedure the reader performs or a mechanism they only have to
understand is a judgement about the passage around it. The spec states the test and the checker
does not attempt it, which is the same decision the overview section's walk already records.
<!-- src: reference/chapter-prose.md § The guide profile -->

> **Grade this.** A numbered list walking through how something works, rather than through
> something the reader does, is the defect. It passes every check and it is still wrong.
<!-- src: reference/chapter-prose.md § The guide profile -->

## Suggested reading

- **Lint versus review**: the general form of the split this chapter describes
- **Specification by example**: why a literal grammar outlives a described one
- `scripts/check-book.sh`, for which rules carry a check and which carry only a comment
