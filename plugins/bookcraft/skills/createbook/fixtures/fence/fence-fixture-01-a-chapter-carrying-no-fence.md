# A Chapter Carrying No Fence

| | |
|---|---|
| **This chapter** | The control half of the fixture: a structurally valid chapter with no fenced block anywhere in it. Scope: what the checker should say about a chapter that gives it nothing to trip over. |
| **Act on this** | Run `check-book.sh` on this folder and expect this chapter to be named in no failure line, before the fence fix and after it. |
| **Draws on** | `scripts/check-book.sh`; `reference/chapter-prose.md § Headings` and `§ Shape`. |
| **Fills in** | Nothing. Every rule this chapter satisfies is read out of the checker itself. |

[1-1] This chapter exists to be boring. It carries an H1 on line 1, a header table, tagged paragraphs, two part headings, a provenance mark after every unit, and a concept list at the end. The checker has seven sweeps that read a chapter's body, and this chapter is written so that all seven of them pass. What makes it useful is the chapter beside it, which differs in exactly one thing.
<!-- src: scripts/check-book.sh -->

## What the control holds constant

[1-2] A fixture that fails proves nothing on its own, because a failure can come from the defect under test or from the fixture being malformed. Holding a second chapter alongside it, identical in shape and different in one feature, is what separates those two. If this chapter ever starts failing, the fixture is broken and the fix it guards is not what is being measured.
<!-- src: scripts/check-book.sh -->

[1-3] The one feature is a fenced block. This chapter has none, so no sweep in the checker ever sets its fence state while reading it. Every line here is markdown that means what it looks like, which is the condition the two heading tests silently assume about every chapter they read.
<!-- src: scripts/check-book.sh; reference/chapter-prose.md § Headings -->

## Why the assumption is worth testing

[1-4] Five of the checker's sweeps track whether they are inside a fence and two do not. That asymmetry is invisible while every chapter looks like this one, and it stays invisible until a chapter needs to show the reader a command, a config file or a lab stub. A book about teaching a technical course needs that constantly, which is how the defect was found rather than reasoned about.
<!-- src: scripts/check-book.sh -->

## Suggested reading

- The checker's own comments, which name the rule each sweep enforces
- `reference/chapter-prose.md`, for the prose rules a script cannot check
