# The Only Chapter

| | |
|---|---|
| **This chapter** | What the handbook says about the grain and about indexes. Scope: the only chapter of the appendix fixture. |
| **Act on this** | Run `run.sh` in this folder and read the report it renders. |
| **Draws on** | `sources/handbook.md`. |
| **Fills in** | Nothing. |

## In short

The handbook this book declares says two things worth restating: what the grain of a fact table
means, and when an index is not worth its write cost.

## What the handbook says about the grain

The grain is what one row of the fact table means, and the handbook is blunt about the cost of
getting it wrong.
<!-- src: handbook § What The Grain Is -->

## What it says about indexes

An index costs a write on every insert, which is the reason the handbook gives for leaving some
tables alone.
<!-- src: handbook § When Not To Index -->
