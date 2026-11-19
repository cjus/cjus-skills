# bookcraft: fix the block-quote check inside code fences and warn on stray bound files

Start date: 2026-11-18 21:49:34 MST

Issue: https://github.com/cjus/cjus-skills/issues/130

## Changes

- **Block quotes inside fences.** Under the narration profile, `check-book.sh` ran a plain
  `grep '^\s*> '` over the whole body, so a shell session quoted in a fenced block failed the
  book on its `> ` prompt. A chapter agent working to pass moved the typed commands out of the
  block and into the prose. The check now skips fenced lines, the way the guide profile's
  callout check already did.
  - `fixtures/fence` chapter 2 gains a fenced shell session. On main it fails with "body
    carries a block quote"; here it passes. `guide-under-narration`, which carries a real block
    quote, still fails as before.
- **Stray files the binder binds.** `/makebook` binds every markdown file it does not skip by
  name or `exclude`, so a working note left in a book folder bound as a chapter. The new
  `book_model.strays` names each chapter-kind file with no number in its name, in a folder whose
  other chapters carry one. The binder warns for each, saying what it was bound as and that
  `exclude` drops it.
  - Nothing is reported for a plain folder of notes (no file numbered) or a book that declares
    `labels`, where an unnumbered introduction is intended.
  - `fixtures/book-model` covers the four cases. A real bind of the fence fixture with a
    `BRIEF.md` added prints the warning.
- Documented in `createbook/SKILL.md § 7` and `makebook/SKILL.md` under `exclude`. Plugin
  version 1.17.1.
