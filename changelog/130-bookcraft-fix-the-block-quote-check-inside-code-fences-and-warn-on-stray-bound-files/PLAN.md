# bookcraft: fix the block-quote check inside code fences and warn on stray bound files

Start date: 2026-11-18 21:49:34 MST

Issue: https://github.com/cjus/cjus-skills/issues/130

## Overview

Two defects found while building a trial book. Under the narration profile, `check-book.sh` read a `> ` line inside a fenced code block as a block quote. `/makebook` bound a working note left in the book folder as a chapter, with nothing said beyond the chapter count.

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred`, never as new scope.

## About Ticket

- [x] **`check-book.sh` reads a `> ` line inside a fenced code block as a block quote, under the narration profile.** Track fences the way the guide path does, and add a fixture.
- [x] **`/makebook` binds any markdown file in the book folder that is not skipped by name or by `exclude`.** Warn when a bound file does not follow the chapter filename pattern its neighbours follow.

## Plan

- [x] Make the narration block-quote check fence-aware, as the guide callout check already is.
- [x] Extend `fixtures/fence` with a fenced shell session, which fails on main and passes here.
- [x] Add `book_model.strays`, and have the binder warn for each stray it binds.
- [x] Cover `strays` in `fixtures/book-model` (stray, excluded, `labels`, plain notes folder).
- [x] Document both in `createbook/SKILL.md` and `makebook/SKILL.md`; bump the plugin to 1.17.1.

## Status

Done. `scripts/test-fixtures.sh --strict` passes 21 of 21. The review gate approved (pr-review-2026-11-18.md); its one acted-on suggestion reworded the stray warning so it is also true of a misnumbered name such as `bk-1-one.md`.

## Deferred

- None.
