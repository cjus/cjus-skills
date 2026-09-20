# A Chapter With Nothing Carried In

| | |
|---|---|
| **This chapter** | What the overview section holds and where it sits, for the first chapter of a book, which has nothing behind it to carry forward. Scope: the control half of the fixture. |
| **Act on this** | Run `check-book.sh` on this folder and expect this chapter to be named in no failure line. |
| **Draws on** | `scripts/check-book.sh`; `reference/chapter-prose.md § In short`. |
| **Fills in** | Nothing. Every rule this chapter satisfies is read out of the checker itself. |

## In short

This chapter is the first in its book, so nothing has been taught before it and the line that
would remind you of earlier work is absent rather than empty. What follows walks through where
the short opening section sits in a file, then through what the checker does and does not read
inside it.

[1-1] A chapter opens with its title, then a four-row table, then a short section written for
someone who has not read the chapter. That section is the subject here, and the file you are
reading is also an example of it, which is the only reason a fixture can check the rule at all.
<!-- src: reference/chapter-prose.md § In short -->

## Where the section sits

[1-2] The section is the first H2 in the body and the header table sits immediately before it.
Both halves of that matter. First H2 alone would let a part heading sit above it in a file whose
table had gone missing, and the table alone would let a part heading sit between the two.
<!-- src: scripts/check-book.sh -->

[1-3] A **carried-in line** is the opening paragraph of the section in every chapter but the
first. This chapter has none, and its absence is legal rather than a fault the checker has
decided to forgive.
<!-- src: reference/chapter-prose.md § In short -->

## What the checker reads inside it

[1-4] The section takes no paragraph tag and no provenance mark, so the **walk** you read above
carries neither and the count of tagged paragraphs in this chapter begins at the first paragraph
below the section. A tag there would shift every tag after it, and a tag is an address other
files cite.
<!-- src: scripts/check-book.sh -->

## Suggested reading

- **Address stability**: why a tag that shifts is worse than a tag that is missing
- `reference/chapter-prose.md § In short`, for the rules a script does not check
