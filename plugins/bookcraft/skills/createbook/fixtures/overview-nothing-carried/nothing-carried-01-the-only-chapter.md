# The Only Chapter

| | |
|---|---|
| **This chapter** | Why a book with nothing to carry in is the shape worth keeping a fixture for. Scope: the empty case in the glossary cross-check. |
| **Act on this** | Run `check-book.sh` on this folder and expect a summary line rather than an abort. |
| **Draws on** | `scripts/check-book.sh`; `reference/chapter-prose.md § In short`. |
| **Fills in** | Nothing. Every rule this chapter satisfies is read out of the checker itself. |

## In short

This book has one chapter, so no earlier chapter exists to carry anything from and the reminder
line is absent rather than empty. What follows walks through why that shape is worth a fixture
of its own, then through what it costs to leave it untested.

[1-1] A check that collects things and then loops over what it collected has two paths through
it, and the one where nothing was collected is the path nobody writes an example for.
<!-- src: scripts/check-book.sh -->

## Why the absent case needs a fixture

[1-2] The **empty case** here is a book where no chapter names a term on its reminder line. That
is not an unusual book. Every single-chapter book is one, and so is any book whose chapters all
happen to reintroduce nothing, which is common in a short book whose subjects barely overlap.
<!-- src: scripts/check-book.sh -->

[1-3] A fixture whose chapters all carry something in cannot reach that path. The one beside this
folder carries two terms in its second chapter, so it exercises the lookup thoroughly and never
once asks what the lookup does when handed nothing.
<!-- src: scripts/check-book.sh -->

## What it cost to leave it untested

[1-4] Under `set -u` an older bash expands an empty array to an unbound variable and stops the
script. Not a wrong answer, which a reader might notice, but no answer: the run ended before its
summary line, so nothing was reported about any chapter in the book.
<!-- src: scripts/check-book.sh -->

## Suggested reading

- **Empty-collection handling**: why the zero case is the one a loop is most likely to get wrong
- `reference/chapter-prose.md § In short`, for the rules a script does not check
