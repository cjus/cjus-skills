# What the Checker Reads

| | |
|---|---|
| **Act on this** | Before adding a rule to the profile, decide which of the two kinds it is, and do not write a check that cannot tell them apart. |
| **Draws on** | `scripts/check-book.sh`; `reference/guide.md`. |
| **Fills in** | The split between checkable and readable rules, which the spec implies and does not tabulate. |

## In short

Carried in: **profile** (ch. 1), the rule set a book's settings file names, absent meaning the
narration rules.

The second chapter of the guide fixture covers which guide rules a script can check and which
are left to a reader. A rule is checkable when it is stated as a literal, such as a callout's
label. Whether a list is a procedure is a judgement, and no script makes it.

[2-1] A script can find a literal string and count things. It cannot tell whether a heading earns
its place or whether a callout is the right one. The profile is written so that the rules a
script can hold are the ones stated as literals.
<!-- src: scripts/check-book.sh -->

## What makes a rule checkable

[2-2] A callout is found by its label and by nothing else. The label is four literal characters
of markup, a fixed word, a full stop and a space, which is a grammar that cannot drift. Had the
rule said "a short highlighted aside", nothing could hold it.
<!-- src: reference/guide.md -->

> **In the room.** When someone asks why the label has to be literal, the answer is that the
> alternative is a checker that guesses, and both of its guesses look like a pass.
<!-- src: reference/guide.md -->

## What is left to reading

[2-3] Whether a numbered list is a procedure the reader performs or a mechanism they only have to
understand is a judgement about the passage around it. The spec states the test and the checker
does not attempt it, which is the same decision the narration summary's term rule records.
<!-- src: reference/guide.md -->

> **Grade this.** A numbered list walking through how something works, rather than through
> something the reader does, is the defect. It passes every check and it is still wrong.
<!-- src: reference/guide.md -->

## Suggested reading

- **Lint versus review**: the general form of the split this chapter describes
- **Specification by example**: why a literal grammar outlives a described one
- `scripts/check-book.sh`, for which rules carry a check and which carry only a comment
