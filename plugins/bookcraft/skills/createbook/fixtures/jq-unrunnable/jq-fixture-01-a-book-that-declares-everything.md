# A Book That Declares Everything

| | |
|---|---|
| **This chapter** | Why a checker that cannot read `book.json` is more dangerous than one that cannot run at all, and what the guard does about it. Scope: the single chapter of the jq fixture. |
| **Act on this** | Run `run.sh` in this folder after any edit to how `check-book.sh` reads `book.json`, and expect both halves to pass. |
| **Draws on** | `scripts/check-book.sh`; `changelog/29-add-a-guide-profile-to-createbook-and-makebook/PLAN.md § Phase 0`. |
| **Fills in** | Nothing. Every claim here is read out of the checker itself. |

## In short

A checker reads this book's declarations from a JSON file, and it needs a working `jq` to do it.
Where that tool is present but cannot run, the declarations read as absent, the folder is graded
against the weakest rules available, and the run still ends by saying the structure is sound.
What follows walks through why the empty answer is the dangerous one, then through what the
guard does instead.

[1-1] A book folder carries a settings file naming what the book promises to do: that every
paragraph is addressed, that every unit says where it came from, that every chapter ends on its
edges. A checker reads that file to know what to hold the book to.
<!-- src: scripts/check-book.sh -->

## Why an empty answer is worse than a missing tool

[1-2] A tool that is absent announces itself, and the checker has a documented path for it: grade
what can be graded without the file and say on the summary line that it did. The reader of that
line knows exactly how much the run was worth.
<!-- src: scripts/check-book.sh -->

[1-3] A tool that is present and cannot run announces nothing. Every call to it returns an empty
string, every declaration reads as a key that was never written, and the run grades a fully
declared book as one that declared nothing. The summary line cannot tell the two apart, because
by the time it prints there is no longer any difference between them.
<!-- src: scripts/check-book.sh -->

## What the guard does instead

[1-4] The check is to run the tool rather than to look for it. Finding it on the path proves that
a file exists at a name; feeding it a small input and reading back what it returns proves it
works. The second question is the one the rest of the run depends on, so it is the one worth
asking.
<!-- src: scripts/check-book.sh -->

[1-5] Where the answer comes back wrong the run stops, names the file it found, and says what
would have happened had it continued. Stopping is the right response rather than a harsh one: a
run that continues produces a **silent pass**, which is a result the reader has no way to
distrust.
<!-- src: scripts/check-book.sh -->

## Suggested reading

- **Fail-closed design**: why a check that cannot run should refuse rather than approximate
- **Architecture mismatch on a shared path**: how a binary for one processor ends up first in line on another
- `scripts/check-book.sh`, for the guard itself and the comment above it
