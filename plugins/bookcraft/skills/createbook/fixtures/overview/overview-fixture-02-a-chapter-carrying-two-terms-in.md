# A Chapter Carrying Two Terms In

| | |
|---|---|
| **This chapter** | What the carried-in line holds, how many terms it may name, and what the checker resolves each of them against. Scope: the half of the fixture that exercises the cross-check. |
| **Act on this** | Run `check-book.sh` on this folder and expect both carried terms to resolve to chapter 1 in the glossary. |
| **Draws on** | `scripts/check-book.sh`; `reference/chapter-prose.md § In short`; `glossary.md`. |
| **Fills in** | Nothing. Every rule this chapter satisfies is read out of the checker itself. |

## In short

Carried in: **carried-in line** (ch. 1), the opening paragraph naming what a chapter reintroduces.
**walk** (ch. 1), the part that says what a chapter argues in the order it argues it.

Two terms are named above and the limit is three, so this chapter sits under it with one to
spare. What follows walks through how that limit is counted, then through what the checker does
with each name once it has them.

[2-1] The line above names two things taught in the chapter before this one. Naming them costs a
sentence each and saves the reader the trip back, which is the whole trade the section makes.
<!-- src: reference/chapter-prose.md § In short -->

## How the names are counted

[2-2] The count is of bolded terms rather than of chapter references. An entry typed without its
reference would otherwise be invisible to both the limit and the lookup at once, passing each
because neither could see it.
<!-- src: scripts/check-book.sh -->

[2-3] A **ceiling** is what the limit is, and it is under no pressure to be reached. Zero is
legal, one is common, and a chapter that reaches for a third name it does not need has written a
worse line than the one it replaced.
<!-- src: reference/chapter-prose.md § In short -->

## What each name is resolved against

[2-4] Every name is looked up in the glossary and the chapter it points at has to be earlier than
this one. That catches the reminder pointing forward, which reminds the reader of nothing, and
the name the book never taught anywhere.
<!-- src: scripts/check-book.sh -->

[2-5] The lookup matches a whole entry and never part of one, so a name is resolved against the
entry that bears it rather than against a longer entry that happens to contain it. Matching part
of one would report a pass on a name the glossary does not hold.
<!-- src: scripts/check-book.sh -->

## Suggested reading

- **Substring matching**: why a lookup that matches part of a key reports passes it has not earned
- `reference/chapter-prose.md § In short`, for the rules a script does not check
