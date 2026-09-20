# Add a guide profile to createbook and makebook

Start date: 2026-09-20 09:21:08 MDT

Ticket: [#29 Add a guide profile to createbook and makebook](https://github.com/cjus/cjus-skills/issues/29)

## Overview

The bookcraft plugin's prose rules were derived from audio-narration transcripts, so a book written as a preparation guide comes out as a chain of linked essays with a lookup layer bolted on: well written and hard to use. This branch adds a `guide` profile to `createbook` (a second rule set in `reference/chapter-prose.md`, selected by `"profile": "guide"` in `book.json`, absent meaning the current narration rules), a `reading` edition to `makebook` (paragraph tags stripped from the page, `Draws on` and `Fills in` rows moved to chapter endnotes, glossary code spans rendered and sorted, lesson-script slide rows kept off the Figures page, callouts rendered as boxed asides), a read-time estimate that counts every word on the page, reader-facing display names for sources, and a fix for `check-book.sh`, which on this machine passes every book in its weakest mode because `command -v jq` finds an x86_64 binary that cannot run.

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred`, never as new scope.

Dependency: #29 says it depends on #26 landing first. #26 merged as PR #32 and was the HEAD of `main` this branch was cut from, so the dependency is satisfied. `main` has since moved to `3de2915`, synced into this branch on 2026-09-20: #23 landed as PR #33 and #34 as PR #35. The rewrite of the reference guide in another repo is the validation run and is not part of this branch.

## Plan

- [x] Phase 0: `check-book.sh` passes without reading `book.json` (bug, separable) — **mostly landed with #26; see the phase section**
  - [x] Probe by running `jq` rather than `command -v jq`, so an unrunnable binary counts as absent — `ed4653e`, `check-book.sh:112`
  - [x] Stop discarding `jq`'s stderr — `:113-117` name the path and the consequence on stderr
  - [x] When the declarations could not be read, say so rather than describing the book as one that declared nothing — done harder than asked: `exit 2` at `:118`
  - [x] Give the same treatment to any other bookcraft script that gates on `command -v jq` — none exists; `check-book.sh` is the only one, and its second `command -v jq` at `:120` is unreachable while broken
  - [x] Fixture: a `book.json` with all four declarations and a `PATH` where `jq` is unrunnable must exit non-zero rather than 0 with `inferred`/`off` — `fixtures/jq-unrunnable/`
  - [x] Sequence the edit against the checks #26 added to the same file — #26 has landed and made the edit; `check-book.sh` is untouched by the eight commits synced on 2026-09-20. Those follow-ups are still outside this repo.
- [x] Phase 1: a guide profile in `createbook`
  - [x] `"profile": "guide"` in `book.json`; absent means the current rules
  - [x] Second rule set in `reference/chapter-prose.md`; the narration profile stays exactly as it is
  - [x] Opening: no handoff-noun requirement, no ban on re-orientation; `## In short` required; chapter 1's four hooks optional
  - [x] Headings: may carry the point, may be a question, H3 allowed under a part; a heading is still never a term's first appearance
  - [x] Callouts: a fixed, checkable set of labelled block quotes (`> **Decide.**`, `> **Warning.**`, `> **In the room.**`, `> **Grade this.**`); any other or unlabelled block quote still fails
  - [x] Procedures: numbered lists allowed and preferred for anything done in order; chained-not-numbered keeps its scope (mechanism walks)
  - [x] Section ends: a part may end on a signalled one-sentence takeaway; exit-on-weakness optional; `§ Never` phrase bans stay
  - [x] Wrong model: at most one per chapter, only where a source or the classroom names it, not required
  - [x] Header table: `This chapter` and `Act on this` stay on the page; `Draws on` and `Fills in` stay in the source and move to endnotes in the reading edition
  - [x] Provenance in prose: the mark carries it; prose names a source only when quoting or when the reader must open it; book-level caveats stated once in `about-this-book.md` and once above the keys appendix
  - [x] Appendix file kind: bound after chapters and before the glossary, skipped by part-count and handoff rules; decide filename convention and tagging (`[A-3]` or untagged); `check-book.sh` and `build-book.py` both recognize it
  - [x] Suggested chapter shape for a teaching guide in `SKILL.md` step 2, offered not enforced
  - [x] Outline gate: step 3 shows the profile beside the tag decision
  - [x] `check-book.sh` reads the profile and applies the right rule set; part-count rule tolerates H3s under `guide`
  - [x] Fixtures: a small `guide` book that passes; a narration book with an H3 and a callout that fails
  - [x] `updatebook` reads the profile so an edit to a guide is held to the guide rules
- [x] Phase 2: a reading edition in `makebook`
  - [x] `--reading-edition` (or `"edition": "reading"` in `book.json`): strip `[N-M]` tags from the page, move `Draws on` / `Fills in` to chapter endnotes, leave the source markdown untouched; PDF and EPUB
  - [x] Glossary code spans: render inline code in terms and definitions; sort by term text with backticks removed
  - [x] Lesson-script blocks: figures under a declared folder (`"slide_figures": "diagrams/slides"` or similar) render as a compact row beside their notes, excluded from the Figures page and numbering, never orphaning a divider slide; legibility floor still applies
  - [x] Render Phase 1 callouts as boxed asides in both formats, label as the box title
  - [x] Existing edition stays the default
- [x] Phase 3: sizing that counts what the reader reads
  - [x] Read-time estimate at `SKILL.md` steps 3 and 9 covers every word: prose, tables, lists, headers, slide notes, concept lists
  - [x] Under `guide`, exceeding six-to-ten chapters at the gate requires the operator to name the shortest path, which lands in `about-this-book.md § How to read it`
- [x] Phase 4: reader-facing source names
  - [x] A `sources` entry may carry a display name beside its path; the key stays for `check-provenance.sh`; step 5's chapter prompt says prose cites the display name and the mark cites the key
  - [x] `check-book.sh` flags a mark key that looks like a repo path appearing in prose
- [x] Validation and acceptance
  - [x] Phase 0's fixture fails on an unrunnable `jq`. **The second half needs restating:** the reference book's summary line cannot read `required` / `on` / `on` on this machine while `/usr/local/bin/jq` is the x86_64 binary, because `check-book.sh` now exits 2 before reaching the summary. Either repair that jq and then assert the line, or assert the `exit 2` instead
  - [x] Guide fixture passes `check-book.sh`; narration fixture with an H3 and a callout fails; every existing fixture and the reference book still pass under their current profile
  - [x] A reading-edition bind of the guide fixture shows no paragraph tags, endnotes carrying `Draws on`, a glossary with rendered code spans sorted correctly, and a slide row absent from the Figures page; `epubcheck` silent
  - [x] Step 3's gate output shows the profile, the full-word read time, and the reader. The reader half is already in place from #23; this branch adds the profile and the read time beside it
  - [x] `README.md`, both `SKILL.md`s, `chapter-prose.md` and `NOTES.md` updated; `NOTES.md` records which new rules are asserted and which were measured; version bump from `1.2.0`, which #34 set (the plan originally said "after #26's", which was `1.1.0`). Root `README.md` is now a plugin catalog after #35, so the update there is a catalog entry rather than prose

## Status

Complete as of 2026-09-20. All five phases and all five acceptance criteria done. bookcraft
`1.2.0` -> `1.3.0`. Not yet committed; no PR.

**Synced `main` in first**, fast-forward `2949445` -> `3de2915`, eight commits, no conflicts, which
brought in #23 (PR #33) and #34 (PR #35).

**Phase 0** was four-fifths already shipped with #26 in `ed4653e`; the fixture that was missing is
now `fixtures/jq-unrunnable/`, a two-half runner proving the guard fires on a `jq` that exits 126
and that the same book passes in the strongest mode with a working one. Verified with teeth: a copy
of the checker with the guard deleted exits 0 with `inferred`, failing all four negative assertions.

**Phases 1 to 4** are new work across nine files. The rule set is
`chapter-prose.md § The guide profile`; `check-book.sh` reads the profile and applies it;
`build-book.py` binds the reading edition, the callouts, the slide rows and the appendices.

### Evidence

| Check | Result |
|---|---|
| `check-book.sh` on `fence`, `overview`, `overview-nothing-carried`, `jq-unrunnable`, `guide` | exit 0 |
| `check-book.sh` on `guide-under-narration` | exit 1, five failures by design |
| `check-provenance.sh` on `provenance`, and `--chapters 1` | exit 1 and exit 0, both unchanged |
| `fixtures/jq-unrunnable/run.sh` | exit 0, both halves |
| Bind of `fence`, `overview`, `guide`, each in both editions | 6 binds, exit 0, `epubcheck` 0 errors on all six |
| Default-edition text of `fence` and `overview` vs the committed builder | byte-identical |
| No-jq fallback on every fixture | runs, degrades, and says which rule set it used |

### Deviations

**The acceptance line "the reference book's summary line reads `required` / `on` / `on`" was
restated.** Two things were wrong with it. The checker's vocabulary is `required`, not `on`, and on
this machine the line is unreachable at all: `/usr/local/bin/jq` is still the x86_64 binary, so
`check-book.sh` now exits 2 before any summary. The fixture asserts the guard instead, which is the
behaviour the phase actually bought.

**`check-provenance.sh` had to change, and the ticket did not say so.** Allowing the object form of
a `sources` entry broke its parser: `[val] if isinstance(val, str) else val` iterates a dict over
its **keys**, so `{"path": ..., "display": ...}` resolved `path` and `display` as two relative
paths and reported each as a declared source that does not exist. Two fabricated failures per
display-named source, and the real file never opened. Fixed in the same pass, with a guard for an
object carrying no `path`.

**A bug of my own, found and fixed before it shipped.** Reading the profile inside the jq block left
`declared_profile` unset on the no-jq path, and `set -u` turned the documented no-jq fallback into a
dead run. Both new variables are now initialised with the other declarations, and the no-jq note now
names the profile it defaulted to, because a guide book checked under the narration rules fails on
every construct the profile exists to allow and nothing previously said why.

**The review gate returned REQUEST_CHANGES and found five defects**, one blocking: `emit_slide`
nested its legibility measurement under `is_svg`, which is always false for a slide, so the slide
legibility report could never flag anything. Verified by measuring one piece of art both ways
(2.4pt flagged as a figure, silent as a slide) and fixed by branching on what was read rather than
on how it was authored. Also fixed: appendix carried-in terms graded against a chapter number they
do not have, a step-4 template that defaulted every new book to a guide in the reading edition, an
appendix figure numbered `3.1`, a dead awk counter, and a repo-path check that did not exempt
fenced blocks. See `pr-review-2026-09-20.md`.

**The glossary fix had to land twice.** The EPUB has its own glossary builder with the same three
symptoms. Both now share `gloss_sort_key` and `inline_code_html`.

**Five open questions were settled without the operator**, each recorded with its reasoning in
`NOTES.md § Five decisions the ticket left open`: appendix filenames and tagging, the reading
edition switch, the no-jq policy, the slide-figure key, and the source display-name form. All five
are cheap to revisit, since nothing outside this plugin depends on any of them yet.

## Open Questions

- Appendix file kind: what filename convention, and are appendices tagged (`[A-3]`) or untagged?
- Reading edition switch: CLI flag (`--reading-edition`), `book.json` key (`"edition": "reading"`), or both?
- Should `check-book.sh` fail outright, or only warn, when `book.json` contains `"provenance"` but the mode resolved to `off`? **Narrowed by #26:** a jq that is present but unrunnable now exits 2 (`check-book.sh:112-118`), so only the jq-absent-entirely case is still open.
- Slide-figure folder: which `book.json` key name, and is the compact row a reading-edition-only rendering or available in the default edition too?
- Source display names: object form (`{"path", "display"}`) or a parallel `source_names` map?
- ~~#23 (the reader persona at the gate) is referenced by the acceptance bar but is a separate ticket; is it landed, and if not, does the gate line here wait for it?~~ **Answered 2026-09-20: landed** as PR #33 and synced in. Its gate text is live at `createbook/SKILL.md` §§ 2, 3 and 5, so the profile line joins an existing reader line rather than waiting for one.

## About Ticket

The reference teaching guide (held in a separate private repo) is the reference book for this plugin, and it is the best evidence available on what `/createbook` plus `/makebook` produce when the subject is a preparation guide. Read end to end on 2026-09-20 against the four skill specs, the finding is the one `createbook/NOTES.md § The resource-first rewrite` already recorded on 2026-09-10: **well written and hard to use.** That rewrite added the reference furniture (header table, tables, concept lists, glossary) and kept every narration device the prose spec was built on, so the book is eighteen linked essays with a lookup layer attached rather than a guide. The spec's own lineage explains it: `NOTES.md:21-23` derives the rules from "explained slowly / for sleep" transcripts and `:39` records that the derivation passed through an audio-narration prompt. A listener cannot look back; a guide's reader does almost nothing else.

This ticket asks for a **guide profile** in `createbook` and a **reading edition** in `makebook`, plus one checker bug found on the way that makes every `check-book.sh` run on this machine a false pass. #26 (the `## In short` section) and #23 (the reader persona at the gate) each fix one piece of this and are not duplicated here; this ticket depends on #26 landing first. The full rewrite of the reference guide that #26 says is coming is work in another repo and is the validation run for this ticket, not part of it.

Line numbers are against bookcraft `1.0.2`. **That is now two versions stale** (`main` is `1.2.0`), so the `SKILL.md` citations below run about nineteen lines low: `:160-162` is at 179 and `:217` at 226 in the current file. The `NOTES.md` citations still resolve, since #23 appended below them.

## Evidence, measured 2026-09-20

| Measure | Value | Where |
|---|---|---|
| Bound length | 310 pages at 14pt, US Letter | `pdfinfo` on the committed PDF |
| Words in the 18 chapter files, provenance comments excluded | 61,723 | counted by a throwaway script over the markdown |
| Of which prose paragraphs | 34,281 (55.5%) | same |
| Slide notes (`Say / Land / Ask / Watch / Time` bullets) | 8,733 (14.1%) | same |
| Tables | 8,564 (13.9%) | same |
| Chapter header tables | 5,187 (8.4%) | same |
| Concept lists | 2,562 (4.2%) | same |
| Other lists and fenced blocks | 1,635 and 761 | same |
| Read time the skill reports | "about 194 minutes", prose only | the reference guide's `OUTLINE.md:19` (2026-09-12 run) |
| Read time over every word at the same 175 wpm | about 352 minutes | arithmetic on the rows above |
| The skill's own default size | six to ten chapters; "a survey-shaped default is how a preparation guide becomes a three-hour read that nobody finishes" | `createbook/SKILL.md:160-162` |
| Chapters here | 18; the fold to 16 was offered at the gate and declined | the reference guide's `OUTLINE.md:869-870` |
| Chapter header word counts | 157 (ch. 12) to 381 (ch. 6); `Draws on` rows 46 to 167 words | counted |
| Chapter 7's header | fills PDF page 86 entirely; the first paragraph starts on page 87 | PDF |
| Chapters opening on the previous chapter's handoff noun | 17 of 18 | #26's count, confirmed |
| How the front matter says to read the book | each week's chapters "the weekend before that week starts" | `about-this-book.md:33` |
| "the export carries no key" caveat | 22 occurrences across 13 chapters | grep |
| "no course document" / "no source" hedges | 19 / 26 | grep |
| "this book's" / "mine" attributions | 50 | grep |
| "chapter N" cross-references in prose | 156 | grep |
| "the fix you would reach for" wrong-model opener | 13 | grep |
| "where this bites" sober-paragraph opener | 12 | grep |
| Parenthetical citations in chapter 4's prose | 30 in 1,945 words | counted |
| Repo path printed to the reader | `CLAUDE.md § Teaching Calendar`, in monospace, PDF page 12 | `book.json:134` maps it to `../../../CLAUDE.md` |
| Slide wireframes | 66 across chapters 7 to 17, added at bind (the reference guide's bind run), not by the spec | git; a divider slide costs half a page for a one-sentence note, PDF page 100 |
| Figures page | 76 entries over three pages, 66 of them slides | PDF pages 8 to 10 |
| Glossary rendering | backticks printed literally; the `PRAGMA foreign_keys` and `STRICT` entries sort under `#` | PDF page 298; `glossary.md:41,43` |

The operator's decisions account for part of this: eighteen chapters, tags on, and the answer keys were all settled at the outline gate. Everything else in the table is the spec's.

## The spec rules that fight a guide

| Rule | Where | What it does to this book |
|---|---|---|
| Every later chapter opens on the previous chapter's closing noun, "no fresh hook and no re-introduction" | `chapter-prose.md § Open` (`:45`), `§ What the reader arrives with` (`:13`) | Chapter 13 opens "The report has a second reader this week: a model." for a reader the front matter told to start there. #26 adds the orientation section; the handoff-noun requirement itself stays. |
| Headings must be redundant with the prose, noun phrases only, no questions, no term the prose has not glossed | `§ Headings` (`:53-59`) | "The term and its two edges", "One week, one module, one lab": a reader scanning to find something gets nothing to scan by, in a book whose second reading is by scanning (`§ The reader`, `:9`). |
| No H3, no callouts, no italics, block quotes banned | `§ Never` (`:172`) | Warnings, decisions, in-the-room advice and grading rules all render as body paragraphs. Nothing on the page says which kind of sentence you are reading. |
| Mechanism walks chained, "never numbered"; `§ Voice` bans ordinal sequencing | `:29`, `:150` | Right for explanation. The habit spread to procedures: the Canvas setup steps (ch. 3), the testing-center steps and the vault steps (ch. 18) are all bullets. |
| Every part exits on a weakness, never success; the close may not replay the parts; "Key takeaways" banned | `:29`, `§ Close` (`:49`), `§ Never` (`:174`) | Every section ends on a cliff and none ends on a consolidation point. The portable sentence exists and is unsignaled inside the prose. |
| "One full wrong model, only ever one", and `§ Before sending` makes it mandatory: "if none does you wrote a summary" | `:35`, `:210` | In chapters 10, 12 and 14 the misconception is real and the passage is the best teaching in the book. In chapter 3 the "skim and publish" fix is a strawman the rule forced. |
| Paragraph tags reach the printed page, on by default | `createbook/SKILL.md:111-115` | An editor's address system at the head of every paragraph the instructor reads. Right for the operator's workflow, wrong on the reader's page. |
| Provenance in prose "where it matters" plus the four-row header | `§ Provenance` (`:90`), `§ The chapter header` (`:61-76`) | Chapter 4's density above, and a repo path a reader cannot open. The `Draws on` row is an inventory rather than a pointer. |
| Reference matter has no home outside the chapters | no rule provides one | Quiz keys sit in chapters 7, 10, 12, 14 and 17, the exam key in 18, the open-decisions table at chapter 6 after sixty pages, and a lab's grading list or rubric pair is reproduced in chapters 2, 8, 10, 12, 15 and 17. |
| Slide notes are figures | `makebook/SKILL.md § Diagrams` treats every standalone image as a numbered figure | The `Say / Ask / Watch` notes are the most usable teaching content in the book and they render as captions at the tail of each essay, each slide framed and numbered, after the argument a reader planning Monday has to scroll past. |

What a guide needs instead is well established and none of it is exotic: an advance organizer before detail, layered reading paths, headings that carry the argument, callouts that signal what kind of thing a passage is, numbered procedures for procedures, checklists at the point of action, worked examples, and reference matter kept in appendices. Same-breath gloss and wrong-model-first, the two patterns `NOTES.md:23` says were actually measured across the source corpus, survive all of that unchanged.

## Phase 0: `check-book.sh` passes without reading `book.json` (bug, separable)

> **Status, 2026-09-20: fixed before this branch started, by #26.** Commit `ed4653e` ("stop check-book.sh on a jq that is present but will not run") landed in PR #32, which is this branch's base, and the measurement below was taken against the code as it stood before that commit. `check-book.sh:112` now probes by running `jq` (`printf '{}' | jq -e .`), prints the path and the consequence on stderr, and exits 2. Re-run today on `fixtures/provenance`, it does exactly that and prints no summary line. The environmental condition is still live — `/usr/local/bin/jq` is `Mach-O 64-bit executable x86_64` and exits 126 — which is why the new guard fires.
>
> **What is left of this phase is the fixture** and the acceptance restatement it forces. The narrative below is kept as the record of how the bug was found; read it as history, not as current behaviour.

Measured then, in this order:

1. `check-book.sh` on the reference book exits 0 and prints `tagged: 18/18 (inferred)    provenance: off    suggested reading: off` plus the `note: this book neither declares "tags" in book.json nor was given a flag` line, while `book.json` declares `tags`, `provenance`, `suggested_reading` and `glossary` all `true`.
2. `bash -x` shows every `jq` call at `check-book.sh:88-113` returning empty: `declared_tags=`, `declared_prov=`, `declared_sugg=`, `extra=`.
3. `command -v jq` at `:87` succeeds because `/usr/local/bin/jq` exists and is executable. Running it under `bash` fails: `Bad CPU type in executable`, exit 126. The binary is `Mach-O 64-bit executable x86_64`, the machine is arm64, and Rosetta is not installed. `/usr/bin/jq` (`jq-1.7.1-apple`) works, but `/usr/local/bin` precedes `/usr/bin` on `PATH`.
4. Every `jq` call carries `2>/dev/null`, so the failure is silent, and `set -uo pipefail` at `:20` does not catch a failed command substitution.

So on this machine the checker has been running in its weakest mode: tags inferred, the provenance-mark check off, the concept-list check off, and the `exclude` list ignored. The `OK structure is sound` line at the end is the "checker exiting 0 is not a checker that ran" case exactly. Whether the runs recorded for the reference guide on 2026-09-13 and 2026-09-14 (its `prompts.md:25-27`, `OUTLINE.md:19`) were degraded the same way is not knowable from what they recorded; the note may have printed and gone unread.

- [x] Probe with `jq --version >/dev/null 2>&1` (or `jq -n true`) rather than `command -v jq`, so an unrunnable binary counts as absent. **Done by `ed4653e`**, with `printf '{}' | jq -e .` as the probe.
- [x] Stop discarding `jq`'s stderr, or capture it and print it in the note, so the reason is on the page. **Done**: `:113-117` name the binary's path and what it would have caused.
- [x] When `book.json` exists and the declarations could not be read, say so rather than describing the book as one that "neither declares tags nor was given a flag". **Done, and more strongly than asked**: the run fails with `exit 2` at `:118` instead of printing a corrected note, so there is no summary line to misread. The related question of failing when `"provenance"` is declared but the mode resolved to `off` survives only for the jq-absent-entirely case; see `## Open Questions`.
- [x] Give the same treatment to any other bookcraft script that gates on `command -v jq`. **Nothing to do**: `check-book.sh` is the only script in the plugin that gates on it, and the second occurrence at `:120` is unreachable while jq is broken because `:112` exits first.
- [x] **Done.** Added the case to the fixtures: a `book.json` with all four declarations and a `PATH` where `jq` is unrunnable must exit non-zero rather than 0 with `inferred`/`off`. The guard exists; nothing tests that it stays. Existing fixtures are `fixtures/{overview,overview-nothing-carried,provenance,fence}`, none of which manipulates `PATH`.

Note a ticket in another repo holds four other `check-book.sh` follow-ups. #26 has landed and made its changes to this file; `check-book.sh` was untouched by the eight commits synced from `main` on 2026-09-20, so the fixture work has a clean surface here. Those follow-ups remain in the other repo.

## Phase 1: a guide profile in `createbook`

Add `"profile": "guide"` to `book.json` (absent means the current rules, so every existing book still passes), and a second rule set in `reference/chapter-prose.md` that the chapter agents read when it is set. The narration profile stays exactly as it is. The guide profile differs in these places, each of which is a finding above:

- [x] **Opening.** No handoff-noun requirement and no ban on re-orientation. The `## In short` section from #26 is required, and the first paragraph may say where the reader is. Chapter 1's four hooks are optional.
- [x] **Headings.** May carry the point, may be a question, and H3 is allowed under a part. The rule that a heading is never a term's first appearance stays, since it is the one rule in that section with evidence behind it (`NOTES.md:43`).
- [x] **Callouts.** A fixed, checkable set of labelled block quotes, on the order of `> **Decide.**`, `> **Warning.**`, `> **In the room.**`, `> **Grade this.**`, rendered by `makebook` as boxed asides. The block-quote ban lifts only for these labels; `check-book.sh` rejects any other block quote and any unlabelled one.
- [x] **Procedures.** Numbered lists allowed and preferred for anything the reader does in order. The chained-not-numbered rule keeps its scope, which is the mechanism walk in prose.
- [x] **Section ends.** A part may end on a signalled one-sentence takeaway. Exit-on-weakness becomes optional. The phrase bans in `§ Never` stay.
- [x] **Wrong model.** At most one per chapter, and only where a source or the classroom names the misconception. Not required.
- [x] **Header table.** `This chapter` and `Act on this` stay on the page. `Draws on` and `Fills in` stay in the source file and move to endnotes in the reading edition (Phase 2).
- [x] **Provenance in prose.** The mark carries the provenance. The prose names a source only where the sentence quotes it or where the reader must open it. Book-level caveats, the answer-key one included, are stated once in `about-this-book.md` and once above the appendix that holds the keys; chapters carry the mark only.
- [x] **Appendices.** An appendix file kind, bound after the chapters and before the glossary, skipped by the part-count and handoff rules, for the matter the findings above show scattered: answer keys with their flags, rubric pairs, open decisions, the source ledger. `check-book.sh` and `build-book.py` both need to know the kind; decide the filename convention and whether an appendix is tagged (`[A-3]`) or untagged.
- [x] **A suggested chapter shape for a teaching guide**, offered in `SKILL.md` step 2 rather than enforced: an at-a-glance box, the concepts in teaching order (each with its definition, the failure to watch for, the assessment item it feeds), the lesson script, the grading section, the key.
- [x] **Outline gate.** Step 3 shows the profile beside the tag decision, for the same reason the tag decision sits there (`SKILL.md:217`): it is one word to change at the gate and a rewrite of every chapter afterwards.
- [x] `check-book.sh` reads the profile and applies the right rule set: H3 and labelled block quotes pass under `guide` and still fail under narration; the appendix kind is recognized; the part-count rule tolerates H3s.
- [x] Fixtures: a small `guide`-profile book that passes, and a narration book carrying an H3 and a callout that still fails.
- [x] `updatebook` reads the profile so an edit to a guide is held to the guide rules.

## Phase 2: a reading edition in `makebook`

- [x] `--reading-edition` (or `"edition": "reading"` in `book.json`): strip the `[N-M]` paragraph tags from the rendered page, move each chapter's `Draws on` and `Fills in` rows to chapter endnotes, and leave the source markdown untouched so the tags other files cite keep resolving. Both PDF and EPUB.
- [x] **Glossary code spans.** Render inline code inside a term and a definition, and sort by the term text with the backticks removed, so `PRAGMA foreign_keys` sorts under P rather than `#` (`glossary.md:41,43`, PDF page 298 today).
- [x] **Lesson-script blocks.** A figure whose path sits under a declared folder (`"slide_figures": "diagrams/slides"` or similar) renders as a compact row, the slide art at reduced width beside its notes, is excluded from the Figures page and from figure numbering, and never orphans a divider slide on half a page. The legibility floor still applies to the art.
- [x] Render the Phase 1 callouts as boxed asides in both formats, with the label as the box title.
- [x] Keep the existing edition as the default so nothing rebinds differently until asked.

## Phase 3: sizing that counts what the reader reads

- [x] The read-time estimate at `SKILL.md` steps 3 and 9 covers every word on the page: prose, tables, lists, headers, slide notes and concept lists. `check-book.sh` already prints prose and structure separately, so the arithmetic is one addition; today the structure half is silently left out and understated this book by nearly half.
- [x] For the guide profile, exceeding the six-to-ten default at the gate requires the operator to name the shortest path through the book, and that path lands in `about-this-book.md § How to read it`. The sentence at `SKILL.md:162` already says why.

## Phase 4: reader-facing source names

- [x] Let a `sources` entry carry a display name beside its path (`{"path": "...", "display": "the course calendar"}`, or a parallel `source_names` map), keep the key for `check-provenance.sh`, and have step 5's chapter prompt say that prose cites the display name and the mark cites the key.
- [x] `check-book.sh` flags a mark key that looks like a repo path (`CLAUDE.md`, anything ending `.md` or `.py`) appearing in prose.

## Validation and acceptance

The reference book is the test case, under the other repo's rewrite ticket that #26 names, once this has shipped and is installed. What this ticket itself must show before it closes:

- [x] Phase 0's fixture fails on an unrunnable `jq` and the reference book's summary line reads `required` / `on` / `on` on this machine.
- [x] The guide-profile fixture passes `check-book.sh`; the narration fixture with an H3 and a callout fails it; every existing fixture and the reference book still pass under their current profile.
- [x] A reading-edition bind of the guide fixture shows no paragraph tags, endnotes carrying the `Draws on` rows, a glossary with rendered code spans sorted under the right letter, and a slide row that is not on the Figures page. `epubcheck` silent.
- [x] Step 3's gate output shows the profile, the full-word read time, and (from #23) the reader.
- [x] `README.md`, both `SKILL.md`s, `chapter-prose.md` and `NOTES.md` updated; `NOTES.md` records which of the new rules are asserted and which were measured, in the file's existing terms; version bump after #26's.

For the rewrite that follows in the other repo, the numbers to compare against the table above are page count, the word split, and whether chapter 13 can be opened cold on a Saturday and used on Monday. My estimate for the same content under this profile is 150 to 180 pages at 14pt; it is an estimate, nothing has been built.

## Not verified

- The page estimate above.
- Whether the 2026-09-13/14 checker runs recorded for the reference guide were degraded the way today's is. The recorded output does not say.
- No reader trial of either edition. The instructional-design points are the literature's, not measurements on this book.
- Nothing in `build-book.py` was read by line for this ticket; the glossary and figure findings are from the bound output, and the code locations are for the implementer to find.

