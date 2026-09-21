# Fixture Handbook

A stand-in source for the provenance fixture. Nothing here is course material.

## What The Grain Is

One row of the fact table means one line item on one sale — get the grain wrong
and the model is wrong.

## When Not To Index

An index costs a write on every insert, so a table that is written far more
often than it is read is the case to leave alone.

**Question 3** (2 pts, multiple choice)

Which of these is a reason to skip an index?

### Requirements

1. **Name the grain.** One sentence.
2. **Write the fact table.** Keys and measures.
