# Improve guide-book readability across createbook, updatebook and makebook

Start date: 2026-09-24 07:44:16 MDT

Ticket: #28 (status:todo -> status:in-progress)

## Overview

A reread of the reference teaching guide found that its sentences mostly hold up and its
structure is what makes it hard to read. Each structural cause comes from a rule in the book
skills, or a gap in them. The guide profile is a patch over the narration spec, so the narration
rules still shape the page: the handoff chain, handoff closes and teaser headings. The
`## In short` section repeats the chapter's own sentences and talks around its terms.
`/updatebook`'s cheapest edits grow paragraphs past the stop nobody checks, and it patches changed
premises rather than rewriting them. The reader's bound copy still shows the editing marks meant
for the operator.

This branch changes the skills so the next guide book reads better, and so revising it does not
wear it down. The work covers the `createbook` prose spec and procedure, `check-book.sh`,
`/updatebook`'s edit rules, and `/makebook`'s bind. It also covers a blind comparison of
redrafted chapters, so the changes are tried on a reader before a whole book is written under
them.

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred`, never as new scope.

## Plan

- [x] Phase 1: Make `guide` a rule set of its own. Split `chapter-prose.md` into a shared core
      and one file per profile, and have step 5 load the core plus the book's profile. Move the
      reasoning to `NOTES.md` so the file an agent reads at draft time is short, and written in
      the style wanted back. Add before-and-after examples: a handoff opener, a teaser heading and
      a catch-all callout. State the heading test and "the wrong-model passage is a shape, not a
      script".
- [x] Phase 2: Take the handoff chain out of the guide path from end to end: the **Opens on**
      and **Closes on** rows in `SKILL.md § 2`, the opening noun in `§ The plan`, the seam read
      at step 8, and the handoff close. Under `guide`, the opening paragraph orients the reader
      instead.
- [x] Phase 3: Rework `## In short`. Let the summary use the chapter's own terms with a short
      definition, cap its length, forbid reusing the chapter's sentences, and decide what the
      `This chapter` row and the summary each do.
- [x] Phase 4: New `check-book.sh` reports. Paragraphs over 90 words and sentences over 45 words,
      each by tag. Callouts over four sentences. Runs of eight or more words shared between
      `## In short` and the body. Multi-word phrases recurring across three or more chapters.
      Repo-path source keys in the header table. Add fixtures and manifest rows for each.
- [x] Phase 5: Change `/updatebook`'s edit rules. Reorder the cheapest-edit list, give revisions
      a way to add a paragraph without renumbering any tag, add a row for when a premise
      changes, and keep each callout to one idea. Add a rule for when to stop editing in place,
      with three levels where today there are two. Edit in place when the change is local and
      the chapter's claim still holds. Rewrite one chapter, keeping its number, when a premise
      under it changes or it needs several new paragraphs: its tags renumber, only citations
      into it are repointed, and the rewrite is what renumbers any suffixed tags. The premise
      row points here, and step 3's "Edit, never rewrite" says where this level begins.
      Recreate the book, through `createbook § When the book supersedes one`, when its chapters'
      boundaries or order change, or the rules it was written under do. Before a rewrite or a
      recreate, move any fact a revision put only in the prose into `OUTLINE.md`, or the
      regeneration drops it silently.
- [x] Phase 6: Change `/makebook`'s bind. Give readers of a guide book the reading edition,
      swap in display names in the header and the endnotes, and keep the chapter-locating
      markers out of the PDF's text layer.
- [ ] Phase 7: Validation. Redraft one teaching chapter and one administrative chapter under
      the changed rules, from the same outline rows and sources, and compare them blind with
      the current versions.

## Open Questions

- ~~Should the paragraph stop fail a `guide` book or only be reported?~~ **Resolved 2026-09-24:
  fail it.** The only cost named was failing the reference teaching guide and its 46
  over-long paragraphs, and the operator will recreate that book under the new rules rather
  than patch it. Until then, a `/updatebook` run on the current guide starts from a failing
  check, which its step 0 already treats as a failure the editor did not cause.
- ~~Which scheme lets a revision add a paragraph without renumbering?~~ **Resolved 2026-09-24:
  a letter suffix.** Paragraphs added after `[1-2]` become `[1-2a]`, `[1-2b]`, and in an
  appendix `[A2-4a]`. `check-book.sh` accepts a gapless `a`, `b`, `c` run after an existing
  number, and a chapter rewrite renumbers them away, per Phase 5. Five consumers change:
  `check-book.sh`, `check-references.sh`, `check-provenance.sh`, `/check-claims`, and
  `build-book.py`'s `PARA_TAG_RE`, which strips tags for the reading edition and would print
  a suffixed tag it does not match. `check-references.sh`'s `TAG` and `TAGDEF` accept no
  appendix tag today, so `[A1-99]` goes unseen; accepting `[A2-4a]` means accepting
  `[A2-4]`, so that gap closes in the same change.
- ~~Should a `guide` book bind to the reading edition by default, or should one run write both
  editions?~~ **Resolved 2026-09-24: declare it.** `/createbook` step 4 writes
  `"edition": "reading"` into a guide book's `book.json`, which `/makebook` already honors,
  so its two-file contract stands. `--no-reading-edition` binds the editor copy; both
  editions default to the same filename, so the editor copy takes its own `--out`. Step 9's
  report says which file is which.
- ~~Should the `This chapter` row merge into `## In short`, or should the two get distinct
  jobs?~~ **Resolved 2026-09-24: merge, under `guide` only.** The header drops the row and
  keeps `Act on this`, `Draws on` and `Fills in`; `## In short` is the one summary. The spec
  names the walk's ban on glossed terms as the one rule keeping the two apart, and Phase 3
  removes it. No script reads the row, so the change is the spec, the guide fixtures, the
  guide profile's header rule, and `updatebook § 4`'s "four rows".
- ~~How do the citations across the plugin get repointed when `chapter-prose.md`
  splits?~~ **Resolved 2026-09-24: the core keeps the name.** `chapter-prose.md` stays as the
  shared core, with `narration.md` and `guide.md` beside it. Rule names do not change, so a
  citation changes only its filename, and only when its rule moved. Before Phase 1 closes, a
  one-off script confirms every `<file> § <rule>` citation in the plugin resolves to a
  heading or a bold-led rule in the file it names.
- ~~Phase 7 needs the operator. Who reads blind, and where does the redraft run?~~
  **Resolved 2026-09-24: the operator reads, and the redraft runs in the source repo.** The
  four versions are labelled A to D, with the key in a file the operator opens only after
  scoring. The redraft runs on a branch in the repo that holds the reference guide, its
  outline and its sources; its path is passed to the run and never written here. An
  unattended run stops once the redrafts are ready to read.

## Deferred

- **A bind test in CI.** The fixture suite cannot exercise `build-book.py`, because CI
  installs Python and `jq` and not the Chromium the binder drives, and a skipped fixture fails
  under `--strict`. Phase 6's changes (display-name swap, hidden page markers) were verified by
  hand on `fixtures/guide/` and `fixtures/guide-reports/`. Found 2026-09-24.

## About Ticket

**Improve guide-book readability across createbook, updatebook and makebook**

I reread the reference teaching guide end to end, judging it by what a guide is for: someone who opens one chapter the week they need it. Most of the sentence-level work holds up. By a script count, only 4 of its 2,071 sentences run past the 45-word stop. The measured claims are the strongest passages in the book, and the tables, the numbered procedures and the `Decide.` and `Grade this.` callouts are the parts a reader can actually use. What makes the book hard to read is structural, and each cause comes from a rule in the skills, or a gap in them, rather than from the drafting.

All figures below come from that book as it stands now: guide profile, tagged, eighteen chapters and three appendices, revised many times after its first bind. It is one book, so trust the direction of each finding more than its size, as `createbook/NOTES.md § The guide profile` already says of its own figures.

| Measured | Figure |
|---|---|
| Words on the page, from `check-book.sh` | 49,158 prose, 21,065 structure, 5,381 overview: about 7.2 hours at 175 words a minute |
| Bound PDF | 330 pages |
| Chapter prose | mean 2,341 and longest 3,376, against the 1,895 mean `NOTES.md` records for the version written under the ceiling. Some of the rise came from revisions, not drafting |
| Paragraphs over the 90-word stop | 46 of 576, 13 of them over 120, the longest at 207 |
| Sentences over the 45-word stop | 4 of 2,071 |

### The guide profile patches the narration spec, and the narration machinery still reaches the page

- [ ] **Take the handoff chain out of the guide path from end to end.** `chapter-prose.md § The guide profile` drops the rule that a chapter opens on the previous chapter's closing noun. But `SKILL.md § 2` still requires an **Opens on** row and a **Closes on** row for every chapter, `§ The plan` still says the opening noun is fixed, and step 8 still reads the seams to check it. So the outline recorded both nouns for every chapter, and the agents used them. Chapters open on "The blanks are the fields...", "The redundancy is what week one's mapping leaves behind", "The dependency your room can now name is the one that hurts" and "The scan is what week four ended on". Each "the" points at something a reader who jumped straight to that chapter never saw, which is exactly the failure the profile was written to remove. Under `guide`, drop both rows, the plan line and the seam read. Ask the opening paragraph to orient the reader in plain words instead: where this chapter sits in the course, and what it settles.

- [ ] **Drop the handoff close under `guide` as well.** The profile keeps the rule that "a chapter still closes on a handoff noun where the outline gave it one". The result is closing lines built to deliver a noun rather than a verdict: "Before you touch anything in Canvas, you need the thing the calendar does not carry, which is the points." One of these closes is false. Chapter 1 ends "Everything in this chapter is a date" after covering the prerequisites, the tag convention, pass-offs, withdrawal grades and the roster. Let a guide chapter close on its main point or on what the reader should do next.

- [ ] **Give `guide` its own rule file, not an override at the end of the narration spec.** A guide chapter agent reads about 9,000 words of narration rules, then about 2,400 words saying which of them to ignore. `SKILL.md § 5` already warns that an agent told only to read the file reads the narration rules first and at length. Split `chapter-prose.md` into a shared core (voice, reference, provenance, the bans) plus one file per profile, and have step 5 load the core and the book's profile.

- [ ] **Add short before-and-after examples of the guide register.** The spec is almost all budgets and prohibitions, and a drafting agent copies an example more reliably than it meets a count. Three pairs would cover the defects in this ticket: a handoff opener rewritten to orient the reader, a teaser heading rewritten as a plain label, and a catch-all callout split in two.

- [ ] **Write the spec in the style the chapters should come back in, and move its reasoning to `NOTES.md`.** The spec's own prose is dense and abstract, and its verbal habits show up in the chapters. "Rather than" appears 5.4 times per 1,000 words in `chapter-prose.md` and 3.6 in the book: 217 times in about 61,000 words of running text, or about once every 280 words. "Carries" follows the same pattern, at 4.1 per 1,000 in the spec and 2.0 in the book. This is a correlation, not a measured cause, and it becomes cheap to test once the file is split.

- [ ] **Ask for headings that tell a skimming reader what each section covers.** The profile allows a heading that states the point, but nothing asks for one. So the narration habit of teaser headings survived: "The verb that does not exist", "Two constraints that do not hold", "The shape the room argues about", "What the second copy holds". Write down a test: could a reader find this section from the contents page when looking for the thing it covers?

- [ ] **Stop the wrong-model passage reading like a template.** Under `guide` the wrong-model passage is optional, but where one is written it comes out in the same words each time: "suggests itself" in four chapters, "The instinct is a good one" in three, "The obvious move is" in three. Say in the spec that its four moves (question, fix, concession, failure) are a shape, not a script. Add a report-only check to `check-book.sh` for multi-word phrases that recur across three or more chapters.

### In short: shorter, in plain terms, and not a copy of the chapter

- [ ] **Let the summary use the chapter's own terms, and cap its length.** The rule that the summary may use no term the chapter defines turns it into a riddle in exactly the chapters that need it most. Chapter 10's summary covers functional dependencies, candidate keys and attribute closure but may not name any of them. So it says "the arrow two slides later", "one gets heard as small when it means irreducible" and "a procedure you can run in chalk". Allow a term with a short definition in the same clause, and cap the summary at about 120 words or five sentences. That cap is a judgement, not a measurement. These sections now run 150 to 400 words. In both chapters checked in the bound PDF, the header table plus this section push the first prose paragraph onto the chapter's third page.

- [ ] **Forbid the summary from reusing the chapter's sentences, and check for it.** In five chapters the summary shares 20 to 44 six-word runs with the opening paragraph. Chapter 10's summary opens with the opening paragraph's first two sentences almost word for word, and chapter 16's ends on a near copy of its closing sentence. Anyone who reads the summary and then the chapter reads the same sentences twice within a minute. A script can find an exact shared run of, say, eight or more words between the summary and the body without any judgement; have the checker report it.

- [ ] **Decide which summaries a guide chapter needs.** A chapter now states its main point four times: in the header's `This chapter` row, in the `## In short` summary, in each part's closing sentence, and in the chapter's close. The header tables (about 5,000 words across the book) and the `In short` sections (5,381) make up about 14% of the book, all of it read before any chapter's first paragraph. Give each one a distinct job, or merge the `This chapter` row into the summary.

### Revisions: `/updatebook` wears a finished chapter down

- [ ] **Check the 90-word paragraph stop and the 45-word sentence stop in `check-book.sh`.** The spec calls both of them hard stops, but nothing enforces either one, and `updatebook/SKILL.md § 5` leaves both to the editor. The sentence stop held; the paragraph stop did not. 28 of the 46 over-long paragraphs are in chapters 1 to 4, which are among the most revised, and one paragraph grew from 81 words at first bind to 207 in a single revision. Report each over-long paragraph by its tag, and decide whether it should fail the check.

- [ ] **Reorder the cheapest-edit list in `updatebook § Adding prose`.** Its first choice is "Grow an existing paragraph, up to the 90-word stop", and since nothing checks that stop, this is how those paragraphs grew. Callouts, tables and lists carry no tag, which makes them the other free place to add text. Chapter 1's pass-off `Warning.` now packs in a definition, a points split, a no-make-up rule, a scheduling gap, a named contact and a note on the teaching model. Give revisions a way to add a paragraph without changing any existing tag, for example a suffixed tag such as `[1-2a]` that the checker accepts until someone deliberately renumbers. Today a revision has to choose between renumbering and bloating a paragraph.

- [ ] **Add a row to `updatebook § 2` for when a premise changes.** When a fact that a chapter's plans are built on changes, the current edit rules patch it in place. Here, the class size the plans assumed changed from twenty to eleven. Five chapters now carry "your roster is eleven, so..." asides while keeping plans built for twenty. Chapter 11 carries both four-evening schedules, with the arithmetic for the outdated one, before saying "The grid below is the one to run." When a premise changes, the passages built on it should be rewritten and anything no longer useful cut, even though that means renumbering tags and updating citations.

- [ ] **Keep each callout to one idea, and enforce the length the spec already sets.** The profile says a callout is one to four sentences, but nothing checks it. `Warning.` labels 23 of the book's 59 callouts, and several of them are not warnings.

### Binding: what the reader's copy shows

- [ ] **Give readers of a guide book the reading edition.** This book was bound in the default edition. So every paragraph opens on a tag like `[16-1]`, and every chapter opens with the `Draws on` and `Fills in` rows written for the operator. Either make the reading edition the default for a `guide` book, or have one run write both a reader PDF and an editor PDF. Either way, `/createbook`'s step 9 report should say which file is which.

- [ ] **Stop repo-path source keys reaching the page through the header.** `check-book.sh`'s repo-path check skips every table row, on the reasoning that the reading edition moves the `Draws on` row into the endnotes. But the default edition prints that row, and the endnotes print the same text, because the binder never swaps in display names. Four files' `Draws on` rows name the key `CLAUDE.md § Teaching Calendar`, even though `book.json` gives it a display name. Have `/makebook` swap in display names in the header and the endnotes, or extend the check to cover the header.

- [ ] **Keep the chapter-locating markers out of the PDF's text layer.** `pdftotext` returns `ZQCH016QZ`, `ZQTOCSTARTQZ` and similar markers, so a screen reader or a copy and paste picks them up. `makebook/SKILL.md § Notes` documents this, but it is still something the reader runs into.

### Validation

- [ ] **Redraft two chapters under the changed rules and compare them blind.** `NOTES.md § The guide profile` records that none of the profile's rules has been tried on a reader. Take one teaching chapter and one administrative chapter, redraft each from the same outline row and sources, and have them read blind against the current versions. That would show whether these changes help before a whole book is written under them.

