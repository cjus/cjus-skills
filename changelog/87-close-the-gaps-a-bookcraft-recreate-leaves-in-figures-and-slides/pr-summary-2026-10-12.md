# Close the gaps a bookcraft recreate leaves in figures and slides

## Overview

The branch for #80 made `/createbook --recreate` account for the old book's figures and copy its
slide folder. It left two gaps, which the ticket for this branch, #87, records.

- **Figure candidates.** The recreate's gate counted every figure the old chapters placed, but
  `/makebook`'s figure pass took only the old `diagrams/README.md` as its candidates. A figure the
  old chapters placed and the README never recorded could still leave the book by drift.
- **Slides.** The recreate copied the slide folder, but nothing placed the copied slides in the
  new chapters, so a recreated book bound without them and nothing said so.

This branch makes the figure pass take its candidates from both of the old book's records, its
chapters and its README, with a figure in both counted once. The recreate's gate counts the same
set. Copied slides now arrive explicitly unplaced: the recreate's report lists them, and the
operator places them through a new `/updatebook` section, where each new lesson needs it. All of
it is prose in the skills except one warning sentence in the binder. bookcraft goes to 1.13.0.

## Key changes

- **`plugins/bookcraft/skills/makebook/SKILL.md` § Deciding where a figure helps.** The
  replacing-an-edition paragraph now gathers candidates from the old README's placed figures and
  from every image and inline SVG the old chapters place. It leaves out the slide folder in both,
  and matches a figure in both by file name, or by `<title>` for an inline one. A candidate the
  old README never recorded is named in the new README by its old file name or `<title>`, plus
  the old chapter that placed it. The placed-again plus passed-over sum still answers to the
  candidate count.
- **`plugins/bookcraft/skills/createbook/SKILL.md` § Recreating a book.**
  - The gate's figure count is the same union. It names each figure only one record holds,
    which shows exactly where the old README fell behind its book.
  - Step 9 points the figure pass at the old folder rather than the old README. Where slides
    were copied, it lists each one as not yet placed and names `/updatebook`.
  - The gate's slide count says the new chapters will place none of them.
  - A new paragraph explains why drafting places no slide, and why placing one later moves no
    tag. It also says to place slides before repointing outside citations.
  - § Notes is aligned with all of this.
- **`plugins/bookcraft/skills/updatebook/SKILL.md`.** Gains a "Places a slide" row in step 2's
  table and a new § Placing slides:
  - A slide goes directly before the paragraph that explains it, because the slide row floats
    and that paragraph prints beside the art. This is the reverse of a figure.
  - The path must start with the `slide_figures` folder, or the bind numbers the slide as a
    figure.
  - The explanation is said to the reader, never as what to say over the slide in a room.
  - Paragraphs added for slides do not count toward the several-at-once rewrite rule, because
    that rewrite would drop the slides.
  - A slide no lesson needs stays unplaced, with a reason.
  - The report gives each slide's chapter and the tag of the paragraph beside it.
- **`plugins/bookcraft/skills/makebook/scripts/build-book.py`.** The last sentence of the
  missing-`diagrams/README.md` warning names both records.
- **`plugins/bookcraft/skills/createbook/NOTES.md`.** Two dated sections:
  - § Figure candidates across a recreate, 2026-10-11.
  - § Slides across a recreate, 2026-10-11. It records the three placement options weighed,
    the operator's rulings, and the correction the pre-test review caught.
- **`plugins/bookcraft/README.md`.** The `--recreate` row says how slides get placed.
- **`plugins/bookcraft/.claude-plugin/plugin.json`.** 1.12.1 to 1.13.0.

## Code examples

The binder's warning, `plugins/bookcraft/skills/makebook/scripts/build-book.py`, in the
`figure_record_missing` branch of the report:

```python
# before
              f"writes it too. After a recreate, the old book's "
              f"{FIGURE_RECORD} lists the candidates.")
# after
              f"writes it too. After a recreate, the candidates are "
              f"every figure the old book placed, in its chapters or "
              f"its {FIGURE_RECORD}.")
```

The candidate set, `plugins/bookcraft/skills/makebook/SKILL.md` § Deciding where a figure helps:

```markdown
Where the operator names the old book's folder, gather the candidates after step 1 from both of
its records of what it placed:

- every figure the old `diagrams/README.md` records as placed, where it has one;
- every figure an old chapter places: each image it references, and each inline SVG, fenced or raw.

Leave out anything under the folder the old `book.json`'s `slide_figures` names, in either
record, because slides are copied rather than redrawn. A figure in both counts once, matched by
its file name, or by its `<title>` for an inline one.
```

Slide placement, `plugins/bookcraft/skills/updatebook/SKILL.md` § Placing slides:

```markdown
Read the chapter, find the paragraph that explains what the slide shows, and put the slide on a
line of its own directly before it: `![Caption](<slide folder>/<file>)`. That is the reverse of
a figure, which follows the paragraph stating what it shows.
```

## Plan alignment

**Completed as planned.**
- Both figure-candidate items: the makebook candidate rule, and createbook's step 9, candidates
  paragraph and folder note.
- Both slide items. The decision is written into createbook and into updatebook, the skill that
  places them. The recreate's report lists the unplaced slides.
- The release item: the version bump and the CI fixture checks.

**Operator rulings.** All four of the plan's open questions were settled on 2026-10-11:
- The operator places slides, through `/updatebook`.
- A slide goes where the new lesson needs it, not where the old book had it.
- No bind warning for unplaced slides.
- No recorded candidate list in the new folder.

A fifth question came from the pre-test review on 2026-10-12. It was settled as option A:
paragraphs added for slides are exempt from the several-at-once rewrite.

**Deviations.**
- **The gate's figure count was widened to the same union**, though the plan named only step 9,
  the candidates paragraph and the folder note. Without it, the pass would answer to a larger
  number than the operator had been shown whenever the old README listed a figure no chapter
  placed.
- **The first slide-placement text put a slide after the paragraph it supports**, carrying the
  figure rule across. The pre-test review caught it, and the third commit corrects it. The
  correction is recorded in `NOTES.md`.

**Descoped.** None.

## Testing

**Automated.**
- `plugins/bookcraft/scripts/test-fixtures.sh --strict` passes 18 of 18 at the branch tip.
- `scripts/check-citations.py` resolves 227 citations.
- CI passed all five jobs at the branch tip.

No fixture was added or changed. The skill changes are prose, and no fixture asserts the one
binder sentence that changed. `makebook/fixtures/bind/run.sh` matches only "figure decisions were
never recorded".

**By hand.**
- Read `createbook/SKILL.md § Recreating a book` beside `makebook/SKILL.md § Deciding where a
  figure helps`. Both should describe one candidate set, the gate's count and the pass's sum
  should answer to each other, and the slide folder should be left out of both records.
- Read `updatebook/SKILL.md § Placing slides` against the guide fixture
  (`createbook/fixtures/guide/guide-fixture-01-what-a-profile-selects.md`). There a slide is
  followed by the paragraph that explains it, "The slide above ...".
- The real test is the next recreate:
  - Of a book whose README missed a figure: the gate names that figure, and the figure pass
    decides it.
  - Of a book carrying slides: the report lists them as not yet placed, and one `/updatebook`
    run places them before the paragraphs that explain them.

**Edge cases considered.**
- An old book with no README: the candidates are the chapters' figures alone.
- A README entry no chapter places: it is still a candidate, and the gate names it.
- A README that lists slides: they are left out.
- A slide path outside the `slide_figures` folder: it would bind as a numbered figure, and the
  text warns.
- A second placing run: the bind's `slides:` line is a running total.
- Several explanatory paragraphs in one chapter: they are exempt from the rewrite trigger.

## Impact assessment

- **Size.** The plugin changes are 107 insertions and 11 deletions across seven files. The rest
  of the diff is this branch's own plan folder: `PLAN.md`, `CHANGELOG.md`, the two reviews, this
  summary and the commit message. It came to 466 insertions before the close added its own
  artifacts.
- **Dependencies.** None changed.
- **Breaking changes.** None to any interface or file format.
  - A recreate's figure pass may now meet more candidates than before, which is the point.
  - `/updatebook` gains a new kind of edit.
  - `/makebook`'s output is unchanged apart from the wording of one warning.
- **Version.** bookcraft 1.12.1 to 1.13.0.

## Deferred work

One item was parked under `## Deferred` in `PLAN.md`, from the pre-test review. An `/updatebook`
chapter rewrite drops the chapter's figures and slides, because § Rewriting one chapter replaces
the file whole from `/createbook`'s step 5 prompt, which carries neither. Nothing warns. This was
already true on `main` before this branch. Its occasion is the next chapter rewrite of a book that
carries figures or slides.
