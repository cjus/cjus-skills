# Harden the book skills: createbook's unchecked outline, check-claims' missing appendix concept, and three undocumented failure modes

Start date: 2026-09-20 19:32:45 MDT

Ticket: #16 (status:todo -> status:in-progress)

Status (2026-09-21): all five phases delivered in 6b497e6, pushed. Draft PR #17 open. The repo
carries no CI workflows, so the branch's checks are the three fixture suites and the citation
checker, all green. Awaiting hands-on testing.

## Overview

`/createbook` hands one outline to every chapter agent and never checks that contract before the
fan-out, so a single bad locator reaches every agent at once. Three further failure modes in the
same machinery are real but undocumented: a brief that points an agent at a concurrently-drafting
sibling, a page locator that passes `check-provenance.sh` while still sending the reader to the
wrong page, and agent findings returned in a message that the harness can truncate to nothing.
Separately, `/check-claims` has no concept of an appendix: `--emit-worklist` reads a chapter
number from the filename's first digit run, so `<slug>-appendix-1-<title>.md` emits as chapter 1,
collides with chapter 1, and `render-report.py` then refuses the entire run.

This branch closes all five: four are hardening and documentation in `createbook/SKILL.md`, the
fifth is a bug fix carrying appendices through `/check-claims` as their own kind.

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred`, never as new scope.

## Plan

- [x] Phase 1: Resolve the outline's own locators at step 3, before the operator gate, so every
      error in the step 2 source ledger is caught once rather than inherited by every chapter
      agent. This is the item whose cost scales with chapter count.
- [x] Phase 2: State in § 5 that a chapter is never briefed to read a concurrently-drafting
      sibling — a sibling's outline row is authoritative, and no agent is pointed at a file
      another running agent is writing.
- [x] Phase 3: Note in § 7 that a resolved page locator is not a correct one, beside the existing
      paraphrase note: a page number inside the PDF's page count still misses when printed page
      numbers differ from the page index.
- [x] Phase 4: Give agent findings a named path in the book folder to land in, resolving the
      conflict between § 5's "report only path and word count" and steps 2 and 5 asking for
      findings that can exceed the harness's return cap.
- [x] Phase 5: Give `/check-claims` an appendix concept — carry an appendix through as its own
      kind so `--emit-worklist` stops collapsing it onto a chapter number, `render-report.py`
      renders a row reading `appendix 2`, `--chapters` can name one, and `judgement.md` says what
      an agent writes in that field.

## Decisions

Recorded 2026-09-21. These close three of the branch's opening questions; the objective itself is
unchanged.

- **Phase 1 is an extension of `check-provenance.sh`, not a new script.** A ledger-only mode reuses
  the resolver that already resolves locators, so the pre-gate check and the step 7 check cannot
  drift apart — which is the failure class this phase exists to close.
- **Phase 4 writes one findings path per chapter**, not one appended file. Agents run in parallel,
  and a single appended file would need locking to avoid interleaved writes. A path per chapter
  also matches `write_worklist()`, which already writes `path.stem + ".json"` per chapter.
- **Phase 5 carries kind and number, rather than a namespaced string.** An appendix is
  `{"kind": "appendix", "number": 1}` in the worklist, the index and the findings file; it renders
  as `appendix 1`; and it is typed as `A1` on the command line. This mirrors `check-book.sh`, which
  already models an appendix as a kind flag plus its own number and fuses to `A<N>` only at the tag
  surface. A free-form string was rejected because the measured failure is agents disagreeing about
  how to name an appendix, and an enum plus an integer is the shape they cannot improvise around.

## Open Questions

- None outstanding. New questions are recorded here as they arise.

## About Ticket

**#16 — Harden the book skills: createbook's unchecked outline, check-claims' missing appendix concept, and three undocumented failure modes**
<https://github.com/cjus/cjus-skills/issues/16>
Labels: status:todo, priority:high, docs

`/createbook` fans a book out to one subagent per chapter, and the outline it hands them is the
only contract they share. Nothing checks that contract before the fan-out, and three further
failure modes in the same machinery are undocumented. All four were measured on one 21-file run.

The fifth item was found later, running `/check-claims` over that same book. It is a bug rather
than a documentation gap, and it blocks that skill outright for any book carrying an appendix.

- [ ] **Resolve the outline's own locators at step 3, before the operator gate.** Step 7 runs
  `check-provenance.sh` over the finished chapters. Nothing resolves the source ledger that step 2
  builds, so every error in it is inherited by every chapter agent at once. Five reached the fan-out
  on that run: three page locators off by one, an anchor attributed to the wrong document, and a
  term-ledger row that contradicted a prose note two lines below it in the same file. All five were
  mechanically findable in about ninety seconds. They were caught only because § 5's prompt tells
  each agent to open the sources rather than write from the brief, which turned the workers into
  independent checks on the contract. That is luck rather than design, and the cost of skipping the
  check scales with the chapter count while the check itself does not.

- [ ] **State in § 5 that a chapter is never briefed to read a concurrently-drafting sibling.** The
  section is right that the outline's fixed handoff nouns are what let chapters be written in
  parallel. But a brief that also says "read the finished chapter N-1 so you do not repeat it"
  races when N-1 is in the same batch, and the file is usually still absent when the agent looks.
  The rule to write down: a sibling's outline row is authoritative, and no agent is pointed at a
  file another running agent is writing.

- [ ] **Note in § 7 that a resolved page locator is not a correct one.** `check-provenance.sh`
  asserts that a page number falls inside the PDF's page count. For any PDF whose printed page
  numbers differ from its page index, and a single cover page is enough to cause that, a citation
  to the wrong page passes clean. Three did on that run, each landing the reader a page early.
  § 7 already sets out what the checker cannot reach; this belongs beside the paraphrase note.

- [ ] **Give agent findings a file to land in rather than a return message.** § 5 says an agent
  reports only its path and word count, which is right on its own. Steps 2 and 5 also ask it to
  report anything the outline got wrong, and the two instructions conflict: a findings-bearing
  return can exceed the harness's return cap, at which point it is truncated to nothing. Three
  agents' findings were lost that way, had to be chased afterwards, and some were never recovered.
  Name a path in the book folder for them instead.

- [ ] **Give `/check-claims` an appendix concept. It currently cannot report on a book that has
  one.** `check-provenance.sh --emit-worklist` takes a chapter's number from the filename's first
  digit run, which is the rule `createbook/SKILL.md § Filenames` states and the reason a book slug
  may not contain a digit. An appendix is named `<book-slug>-appendix-1-<chapter-slug>.md`, so it
  emits as chapter 1 and collides with chapter 1. The book format itself does not have this gap:
  `check-book.sh` counts appendices and the tag scheme knows them, since appendix paragraphs carry
  `[A1-n]` tags. Only the claim-check path flattens them into the chapter sequence. Three
  consequences, measured on a book of eighteen chapters and three appendices:

  - `render-report.py` refuses the whole run with `index.json lists chapter number 1 more than
    once`, exits 1 and writes nothing, so twenty-one completed reading passes produce no report at
    all.
  - `judgement.md` gives an appendix no shape for its `chapter` field, so agents disagree about how
    to name one. Of three appendix agents, one wrote `"chapter": "appendix-1"`, which the renderer
    rejects separately as not a chapter number.
  - `--chapters 2,13` silently also emits appendix 2. This is the worst of the three, because
    `--chapters` is the flag `/updatebook` passes after an edit, so a scoped re-check quietly reads
    a file the edit never touched and folds it into the round.

  That run was rendered by renumbering the three appendices to 19, 20 and 21 in a copy of the
  worklist, touching only the `chapter` identifier and leaving every unit count, verdict and finding
  alone. A real fix carries an appendix through as its own kind, so a report row reads `appendix 2`
  rather than `ch. 20`, `--chapters` can name one, and `judgement.md` says what an agent writes in
  that field.

**Occasion:** the first four before the next book is written with this skill. The first is the one
that compounds, since it is the only one whose cost rises with the number of chapters. The fifth is
not preventive and has no occasion to wait for: no book with an appendix can have a claim-check
report rendered today.

