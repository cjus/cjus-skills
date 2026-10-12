# Keep figures and slides through an updatebook chapter rewrite

Start date: 2026-10-12 09:50:36 MDT

Ticket: #94 (status:todo -> status:in-progress)

## Overview

`/updatebook`'s chapter rewrite (`updatebook/SKILL.md § Rewriting one chapter`) drafts the
chapter again with `/createbook`'s step 5 prompt and replaces the file whole. That prompt has
no line for figures or slides, so the rewritten chapter binds without the figures and slides
the old one placed, and nothing warns. This was already true on `main` before #87. #87 added a
slide exemption that keeps the several-at-once rewrite rule from firing on slide paragraphs.
The exemption does not reach the lettered-tags trigger, though, so a later run can still
rewrite a slide-bearing chapter and drop its slides.

The objective is that a chapter rewrite keeps every figure and slide the old chapter placed,
or drops one only by a recorded decision with its reason, and that a rewrite which loses one
without a decision is visible before the run reports. Once the rewrite keeps them, the slide
exemption's premise no longer holds, so § Placing slides, § Adding prose and § When to stop
editing in place have to agree on what a rewrite now does to slides.

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred`, never as new scope.

## About Ticket

The body of #94 as of the branch start. It has no comments. Its action items are tracked under
`## Plan`.

A follow-up from #87, triaged at its close. Both items share a root cause: an `/updatebook`
chapter rewrite drops the chapter's figures and slides.

- **A chapter rewrite drops the chapter's figures and slides.**
  - `updatebook/SKILL.md § Rewriting one chapter` replaces the chapter file whole, from
    `createbook`'s step 5 prompt. That prompt carries no figure line and no slide line.
  - So a rewritten chapter binds without the figures and slides it had, and nothing warns.
  - Already true on `main` before #87.
  - Occasion: the next `/updatebook` chapter rewrite of a book that carries figures or
    slides.
- **#87's slide exemption does not reach the lettered-tags trigger.**
  - The exemption says paragraphs added to explain slides do not count toward
    `§ Adding prose`'s several-at-once rewrite rule.
  - It does not reach the "already carries several lettered tags" trigger in
    `§ Adding prose` and `§ When to stop editing in place`.
  - It also sits only in `§ Placing slides`, which a later run does not read.
  - So a later run can rewrite a slide-bearing chapter and drop its slides.
  - Fixing the first item makes this one moot. Otherwise, a two-clause edit extends the
    exemption.

Source: `changelog/87-close-the-gaps-a-bookcraft-recreate-leaves-in-figures-and-slides/pr-review-2026-10-12.md`
and `pr-review-2026-10-12-close.md`.

## Recent Context

The decisions this branch builds on are in
`changelog/87-close-the-gaps-a-bookcraft-recreate-leaves-in-figures-and-slides/PLAN.md`:
`/updatebook` places a recreated book's copied slides (§ Placing slides), a slide goes on its
own line directly before the paragraph that explains it, and a figure follows the paragraph
stating what it shows.

## Plan

### A rewrite keeps the chapter's figures and slides

- [x] `updatebook/SKILL.md § Rewriting one chapter`: before drafting, record every figure the
  old chapter places (images outside the slide folder, plus inline `<svg>`) and every slide
  (paths under `book.json`'s `slide_figures` folder), each with the paragraph it sits beside.
  The rewrite answers to that list. New step 3, which also takes in any slide the run was
  placing when the chapter became a rewrite.
- [x] Decide who re-places them in the new draft (see `## Open Questions`), and write it into
  the rewrite procedure: each figure follows the paragraph stating what it shows, each slide
  goes directly before the paragraph that explains it, and one the new chapter no longer
  needs is dropped with its reason. The chapter agent, through `createbook/SKILL.md § 5`'s new
  item 15, which only a rewrite fills; its drops go to its findings file, which rewrite step 5
  now reads. Rewrite step 6 re-checks each kept figure against its new paragraph.
- [x] Make a loss visible: the rewrite's check compares the figures and slides placed before
  and after, and step 6's report lists each one kept, moved or dropped with its reason. A
  dropped figure also leaves `diagrams/README.md` per step 4. Rewrite step 9 diffs what the
  chapter places at `HEAD` against the new file; a dropped figure is recorded in the README as
  passed over, with its reason.

### The slide exemption and the rewrite triggers agree

- [x] Revisit `§ Placing slides`'s exemption bullet, whose reason ("the rewrite ... would drop
  the slides this run placed") stops being true once the rewrite keeps them. Retire or reword
  it so it no longer argues from a failure the branch removes. Retired: slide paragraphs count
  like any others, and a chapter needing several at once is rewritten with its slides.
- [x] Check `§ Adding prose` and `§ When to stop editing in place` for the lettered-tags
  trigger, so neither rule leaves a later run thinking a rewrite costs a chapter its slides.
  Each now says a rewrite keeps the chapter's figures and slides.

### Release

- [x] Bump bookcraft's version in `plugin.json` (currently 1.13.0), and run the fixture checks
  CI runs. 1.13.0 to 1.14.0. At close the suite passes 18 of 18, 232 citations resolve, CI
  passes all five jobs on PR #95, and the close review approved.

## Open Questions

- ~~Who re-places the figures and slides in a rewritten chapter: the chapter agent, handed the
  list through a new line in `/createbook`'s step 5 prompt, or this session after the draft
  lands, by the § Placing slides rules? The prompt is shared with `/createbook`, where a fresh
  book has no figures or slides to carry, so a line there has to be conditional.~~
  **Settled by the operator, 2026-10-12: the chapter agent**, through a step 5 item only a
  rewrite fills.
- ~~Does a figure the rewrite keeps keep its file and its `diagrams/README.md` row unchanged, or
  is it re-checked against the new paragraph it follows?~~ **Settled by the operator,
  2026-10-12: re-checked** against the paragraph it now follows.

## Deferred

- A figure the rewrite drops is recorded in `diagrams/README.md` as passed over, but nothing
  says whether its SVG file leaves `diagrams/`. Left there, step 1's sweep of `.svg` files keeps
  finding facts no chapter shows; removed, a figure another chapter still places would break.

**Triaged at close, 2026-10-12: six items, all DROP, none ticketed.** The one item above, plus
five the pre-test review left as suggestions: a stale findings file read as the agent's, a book
with no `diagrams/README.md` gaining a one-row one, no step 9 fallback for a book outside git, a
retitled inline figure showing as a drop and a gain, and item 15's image-opening phrasing (since
applied at close). None has both a concrete symptom and a named occasion that would pick it up.
