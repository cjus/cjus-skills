# A Chapter Carrying A Fence

| | |
|---|---|
| **This chapter** | The test half of the fixture: the same shape as chapter 1, plus one fenced python block whose body opens two lines with hashes. Scope: what the checker says about markdown-looking text that is not markdown. |
| **Act on this** | Run `check-book.sh` on this folder. Before the fence fix this chapter draws two failures and after it draws none, while chapter 1 is silent throughout. |
| **Draws on** | `scripts/check-book.sh`; `reference/chapter-prose.md § Never`. |
| **Fills in** | Nothing. The block below is a plausible lab stub rather than one lifted from a course. |

[2-1] This chapter is chapter 1 with a fenced block added. Everything else about it is deliberately the same: the H1 on line 1, the header table, the tagged paragraphs, the two part headings, the provenance marks and the concept list. One feature differs, so one difference in the checker's output is attributable to it.
<!-- src: scripts/check-book.sh -->

## The block a lesson actually needs

[2-2] A chapter teaching a lab has to show the stub the student starts from, and a stub carries comments. Python comments open with a hash. A banner comment that separates one section of a script from the next conventionally opens with several, which is the shape below and the shape that breaks the two heading sweeps.
<!-- src: scripts/check-book.sh -->

```python
# Load one week of submissions and count the rows in each.
rows = load_submissions("week-01")

### batch size: raise this once the class is past week 2
BATCH = 500

for start in range(0, len(rows), BATCH):
    check(rows[start:start + BATCH])
```
<!-- src: fill (a plausible lab stub, written for this fixture) -->

[2-3] Nothing in that block is markdown. The first line is a comment a python interpreter reads and discards, and the line naming the batch size is the same. Read as markdown they are an H1 and an H3, which is what the two sweeps below the provenance walker do read them as, because neither of them tracks whether it is inside a fence.
<!-- src: scripts/check-book.sh -->

## What each sweep makes of it

[2-4] The cost is worth a fixture rather than a note. A chapter that needs a hash comment gets a failure it cannot fix without rewriting working code into something else, and the reference book has a chapter that rendered a sample as a docstring for exactly that reason. Because every fenced hash raises the same message, a real second H1 and a false alarm read identically, so the failure cannot be trusted in either direction. A hash inside a fence is code, and the binder takes the chapter title from the first heading the page actually renders, so there is nothing in there for the rule to protect.
<!-- src: scripts/check-book.sh -->

## Suggested reading

- The five fence-aware sweeps in the same script, for the pattern the fix copies
- `reference/chapter-prose.md § Never`, for what a chapter may and may not carry
