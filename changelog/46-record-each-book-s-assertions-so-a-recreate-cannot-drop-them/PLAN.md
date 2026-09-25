# Record each book's assertions so a recreate cannot drop them

Start date: 2026-09-25 10:35:06 MDT

Ticket: #46 (status:todo -> status:in-progress)

## Overview

A book written by `/createbook` rests on its sources and on everything it was told or settled
along the way. The second kind has no home. It lives in chapter prose, in outline revision notes
keyed by paragraph tag, and in commit history, so a recreate from the outline and the sources
drops it. The reference guide shows each way this happens: a premise that changed (a class of
twenty became eleven), a recommendation the operator acted on (an exam window), rulings with no
source, and an answer key that was derived and then corrected.

This branch gives every book an `assertions.json` beside its `book.json`, holding each claim a
fresh run could not rebuild from the brief and the sources alone. A helper script is the only
writer and the only definition of the format. Provenance marks cite entries, and
`check-provenance.sh` fails a mark that cites a superseded entry, reports an entry nothing cites,
and sweeps for prose still built on a superseded premise. `/createbook`, `/updatebook` and
`/check-claims` stop and create the file when a book has none, through a backfill the operator
confirms, and a recreate reads the file first and carries every entry that holds.

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred`, never as new scope.

## About Ticket

**#46: Record each book's assertions so a recreate cannot drop them**

A book written by `/createbook` rests on two things. One is the set of sources in `book.json`, which any later run can open again. The other is everything the book was told or settled along the way, and that has no home. It lands in chapter prose, in `OUTLINE.md` revision notes keyed by paragraph tag, in asides inside ledger rows, and in commit history. While a book is only patched by `/updatebook`, this costs nothing, because the prose that holds those facts is left in place. It costs a great deal once a book is recreated, which `updatebook § When to stop editing in place` calls for whenever the rules a book was written under change. The reference guide is at that point now: `createbook/NOTES.md § The stops checked, and the reports` records that on 2026-09-24 it was set to be recreated rather than patched.

The only protection today is one instruction, given at `updatebook § Rewriting one chapter` step 1 and again at `§ Recreating the book`: carry each revision's facts into the outline first, found by reading `git log -p`. That is archaeology done at the worst moment. The agent has to guess which diff lines were facts and which were rewording, and it only finds what reached git.

### What the reference guide shows

Measured on the reference guide as it stands: guide profile, eighteen chapters, three appendices.

| Measured | Figure |
|---|---|
| Commits that touched the book folder | 60 |
| Commits that changed a chapter and left `OUTLINE.md` alone | 21 |
| `Revised` notes in the outline's chapter rows | 15. 12 of them describe the change by paragraph tag ("[4-12] and the late-work block match..."), and a recreate renumbers every tag |
| Provenance marks | 755. 476 name `fill` and 77 name `measured` |
| Marks naming an `unsourced` label that stands for a fact, not a method | 42, across four labels: the live course as read on one date, an email, a message thread, and a portal page behind sign-in. Because the labels are `unsourced`, no check ever opens anything behind them |

Four cases, each of which a recreate from `OUTLINE.md` and the sources gets wrong:

- **A premise that changed.** The session plans were built for a class of twenty, which was the book's own assumption. The roster turned out to be eleven. Eleven now appears in the prose of eight chapters and in three tag-keyed revision notes. The outline's shared-content table and chapter 1's `Fills in` row still say twenty, so a recreate that works from those rows would rebuild every session grid for twenty.
- **A recommendation the operator acted on.** The book worked out an exam window backwards from the testing center's lead time, and marked the arithmetic `fill`. The resulting date is in five chapter and appendix files, and in a planning document outside the book. It is not in the outline or in any source. A recreate derives the window again, may land on a different date, and has nothing to tell it the first date was already in use.
- **Rulings with no source.** "The live site outranks the older PDF", "the recommended late-work wording matches the course's LMS setting" and "state the rounding conflict and leave it unresolved" all came from the operator. So did two exclusions, no compensation figures and no supervisor's name. A third, no room access codes, was the book's own judgment and is recorded beside them. Some of these are asides inside ledger and decision rows, and some sit in `§ Names, and what stays out`. Each one survives only if the new outline happens to copy it.
- **Answers the book derived and then corrected.** No quiz or exam export carries a correct-answer marker, so the answer key is the book's own derivation. One key has since been corrected. A recreate derives the key again from the items and can reintroduce the error.

The `/createbook` argument is missing too. The outline says the reader persona was "given in the argument, in full", but the argument is not saved in the folder, so a recreate starts from a paraphrase of the brief.

### Proposal: `assertions.json` beside `book.json`

Every book folder carries an `assertions.json` next to its `book.json`. It lists every claim the book stands behind that a fresh `/createbook` run would not reproduce from the brief and the sources in `book.json` alone. That test decides what goes in, and it keeps the file small. Claims derived from a source stay out, because the source is already the record for them. The model's own `fill` stays out until the operator adopts it.

**The file is JSON, so its structure is checked rather than described.** Every entry has the same fields, kinds and statuses come from fixed sets, and a supersession is a pair of links a script can verify. It also stays out of the chapter pipeline without any special handling: `check-book.sh`, `check-provenance.sh`, `check-references.sh` and `build-book.py` only glob `*.md` in a book folder, so none of them can mistake the file for a chapter, and no tool needs to skip it by name.

```json
{
  "format": 1,
  "created": {
    "date": "2026-09-25",
    "how": "backfill",
    "from": ["OUTLINE.md", "provenance marks", "claim-checks", "git log"],
    "candidates": 31,
    "confirmed": 27
  },
  "brief": {
    "argument": "<the /createbook argument, verbatim>",
    "reader": "<the persona, as one sentence>",
    "reader_origin": "argument",
    "profile_origin": "argument"
  },
  "entries": [
    {
      "id": 3,
      "kind": "premise",
      "statement": "Every session plan assumes a class of twenty.",
      "origin": { "by": "book", "how": "no source states enrollment", "date": "2026-09-20" },
      "reaches": "every session plan and every per-student timing",
      "search": ["room of twenty", "twenty students"],
      "applies_to": "prose",
      "citation": "legacy",
      "status": "superseded",
      "superseded_by": 7
    },
    {
      "id": 7,
      "kind": "premise",
      "statement": "The roster is eleven students.",
      "origin": { "by": "operator", "how": "read from the student portal, behind sign-in", "date": "2026-09-22" },
      "reaches": "every session plan and every per-student timing",
      "search": ["roster is eleven", "your eleven"],
      "applies_to": "prose",
      "citation": "legacy",
      "status": "holds",
      "supersedes": 3
    },
    {
      "id": 9,
      "kind": "settled",
      "statement": "The answer key to the weekly quizzes, as derived by the book and checked.",
      "origin": { "by": "book", "how": "no export carries a correct-answer marker", "date": "2026-09-20" },
      "answers": [
        { "item": "quiz 1, item 1", "answer": "B" },
        { "item": "quiz 1, item 2", "answer": "D", "corrected": "2026-09-22" }
      ],
      "applies_to": "prose",
      "citation": "legacy",
      "status": "holds"
    },
    {
      "id": 12,
      "kind": "measured",
      "statement": "SQLite has no EXPLAIN ANALYZE.",
      "origin": { "by": "measurement", "date": "2026-09-20" },
      "measurement": { "ran": "EXPLAIN ANALYZE SELECT * FROM t;", "on": "sqlite3 3.54.0", "result": "Parse error near \"SELECT\"" },
      "applies_to": "prose",
      "citation": "expected",
      "status": "holds"
    }
  ]
}
```

| Field | Rule |
|---|---|
| `format` | The format version, as an integer. A skill or script that finds a newer version than it knows stops and says to update bookcraft. It never guesses at a newer file. The file carries no `$schema` key, because the format's only definition is the helper's `check` |
| `created` | How the file came to exist: `createbook`, or `backfill` with what was read and how many candidates were confirmed. An empty `entries` list is valid only beside a `created` block that says what was searched. Without that rule, a file written just to get past the presence check would look the same as one that searched and found nothing |
| `brief` | The `/createbook` argument verbatim, the persona, and where the persona and the profile came from. The profile's value stays in `book.json`, so nothing is recorded twice |
| `id` | An integer from one sequence. An ID is never reused, even after its entry is retired |
| `kind` | `given`, `ruling`, `premise`, `adopted`, `measured` or `settled` (below) |
| `statement` | The claim, in one sentence |
| `origin` | `by` (`operator`, `book` or `measurement`), `how`, and `date` |
| `applies_to` | `prose` when sentences rest on the entry and their marks should cite it. `book` when it governs the whole book, such as an exclusion or a ruling on which source wins |
| `citation` | On a `prose` entry only: `expected` or `legacy`. `legacy` means the prose resting on the entry was written before the file existed, so no mark cites it yet. A backfill writes `legacy`. A recreate rewrites every mark, so it turns each carried `legacy` into `expected`. So does an edit that rewrites the paragraphs resting on the entry and gives them marks that cite it. Everything else writes `expected` |
| `status` | `holds`, `superseded` (with `superseded_by`) or `retired` (with `retired_reason`). The superseding entry carries `supersedes`, and the two links must agree |
| Fields for one kind | `reaches` and `search` on a `premise`. `search` lists phrases that find prose built on the premise, so a superseded premise can be swept for. `measurement` (`ran`, `on`, `result`) on a `measured` entry. `acted_on` on an `adopted` one. On a `settled` entry, `corrects` holds the reading it replaces. Where the entry settles a set rather than a single fact, it also carries `answers`, a list of `item` and `answer` pairs with an optional `corrected` date |

**The file never names a chapter number or a paragraph tag**, because a recreate renumbers both. The link runs one way, from the prose to the file, through the provenance mark. When a skill needs to know which chapters carry an entry, it works that out from the marks.

| Kind | Holds | Example from the reference guide |
|---|---|---|
| `given` | A fact the operator supplied that no source file holds | The roster of eleven, read from a portal behind sign-in |
| `ruling` | A decision about how to treat the sources or the scope: which source wins, a conflict left open, something included or excluded | The live site outranks the PDF. No compensation figures |
| `premise` | A fact the book's plans are built on, sourced or not. Flagged so that changing it is handled as a rewrite (`updatebook § When to stop editing in place`), not as a patch | The class size. The date of the first session |
| `adopted` | A recommendation the book made that the operator accepted or acted on | The exam window. The late-work policy entered in the LMS |
| `measured` | A live measurement: what was run, on what, when, and the result | The SQLite behaviours now in `OUTLINE.md § Measured on this machine` |
| `settled` | A misreading a review corrected, or a derived answer that was checked. Kept so that a fresh reading does not make the same mistake | The corrected answer key. A PDF whose printed page numbers are offset from its page index. A contact block that gives a different title for someone with the same first name |

### When a skill finds no `assertions.json`

The skill stops and creates the file before doing what it was asked.

- **`/createbook` on a new book** writes the file at step 1, with the brief, before `OUTLINE.md` exists. Pointed at an existing folder with no file, to add chapters or to recreate, it stops and backfills first.
- **`/updatebook`** checks at step 0, straight after the `book.json` check. With no file, it backfills and the operator confirms the candidates. The new file has to be committed before the edit begins. Step 0 refuses a folder with uncommitted changes, and step 5's proof that untouched chapters stayed untouched is a `git diff` that the new file would muddy. So the order is: backfill, confirm, commit, then run step 0 again.
- **`/check-claims`** also stops and backfills, because it reads the file as a source.
- **`/makebook` is exempt.** It binds any folder of markdown, including folders `/createbook` never wrote, and it reads nothing from the file. Requiring the file would stop it binding a plain folder of notes.
- **Scripts do not create the file**, because a backfill needs judgement. When the file is missing, `check-provenance.sh` says so on its summary line and skips the checks that depend on it, the same way it already reports a `book.json` that declares no `provenance`. It never passes quietly. The hard stop belongs to the skills.
- **No flag skips the stop.** The price is one backfill per book, paid by the first run that touches the book after this ships, even when that run is a one-word fix.

### The format

- [x] The helper's `check` is the only definition of the format. No JSON Schema file ships, and no validator library is added to `bookcraft-python`. `createbook/SKILL.md` documents the fields for a reader, and where the two ever disagree, `check` is right.
- [x] Add a helper, `createbook/scripts/assertions.sh`, in Python 3 with the standard library only, with `init`, `add`, `supersede`, `retire`, `correct`, `list` and `check`. It allocates IDs and writes both links of a supersession in one step. `correct` changes one item of an `answers` set in place and stamps its `corrected` date. Superseding a whole answer set to change one answer would copy every other answer for no reason. Its output is always formatted the same way (two-space indent, fixed key order), so each change shows up in a diff as the lines of one entry. Skills write the file through the helper, never by hand, and the gate shows the operator `list`'s table, not raw JSON.
- [x] `check` enforces the whole format: the file parses, the `format` is known, required fields are present, kinds and statuses are from the fixed sets, IDs are unique and never reused, supersession links agree, `citation` appears only on `prose` entries, `answers` items are unique within their set, and no key is unknown (a misspelt key is the likeliest error). `check-provenance.sh` calls the helper's `check` instead of parsing the file itself, so the file is never parsed two different ways.
- [x] Add the file to the book-folder layout in `createbook/SKILL.md § Notes` and in the plugin README.

### Marks cite entries

- [x] Add a reserved mark component, `assertion <id>`, that resolves against `assertions.json` in the way `fill` is built in. The file's name is fixed, so it needs no `sources` entry. `check-book.sh`'s mark grammar already accepts any text after `src:`, so only `check-provenance.sh` changes. Refuse any `sources` key that starts with the reserved word.
- [x] Fail a mark that cites an entry that does not exist, or one that is `superseded` or `retired`. For a premise, this finds every paragraph still built on the old value. The twenty-to-eleven change needed that check and did not have it. **This check only sees prose whose marks cite entries.** In a book that was backfilled, that means prose written after the backfill, so the sweep below covers the rest.
- [x] Sweep for each superseded premise's `search` phrases across the chapters, `OUTLINE.md`, `diagrams/README.md` and the `.svg` files. Report every hit, and never fail on one, because a phrase can match prose that isn't built on the premise. This is the mechanical half of `updatebook § 1`'s advice to grep the whole folder for a fact. On a backfilled book it is the only check that reaches the prose still built on an old premise.
- [x] Report every `holds` entry with `applies_to: "prose"` and `citation: "expected"` that no mark cites. After a recreate, this report names each assertion the new book dropped. `legacy` entries are left out, because nothing could cite them yet, and reporting them would list nearly every backfilled entry on every run until the recreate.
- [x] Add an `assertion` count to the census line.
- [ ] Replace `unsourced` labels with entries wherever a label stands for a fact rather than a method. That makes the 42 marks above checkable, and `measured` joins them once the measurements are entries. `fill` stays.
- [x] Have `/check-claims` give each chapter agent the entries its marks cite. Before raising a finding, the agent consults any `settled` entry that already settles it. The reference guide's outline records one finding that the claim check raises as `unclear` on every run.

### `/createbook`

- [x] Step 1: create the file with the brief, using `init`.
- [x] Steps 2 and 3: every answer, ruling, exclusion or measurement becomes an entry before it reaches the outline. Show `list`'s table at the gate, next to the ledger.
- [x] Move what the outline keeps today that is really register material into entries: the measurements, the settled decisions, the exclusions. The outline points at the entries. A recreate writes a new outline, so anything kept only in the old one is lost.
- [x] Step 5: each outline row lists the entry IDs its chapter carries, the way `Draws on` lists its sources. The chapter agent gets those entries and is told that they outrank its own `fill` and are cited as `assertion <id>`.

### `/updatebook`

- [x] Step 0: stop and backfill when the file is missing, as described above.
- [x] Step 2: add a row to the classification table. An instruction that supplies a fact no source holds, rules on the sources or the scope, changes a premise, or adopts a recommendation writes or supersedes an entry. It does so in the same run and before the prose changes.
- [x] Step 3: an edit that rewrites a paragraph resting on a `legacy` entry gives it a mark citing the entry. Once every paragraph resting on that entry cites it, the edit changes the entry to `expected`.
- [x] Step 4: add the file to the list of what an edit carries.
- [x] Step 5: run `check`, and read the file's diff alongside the chapter diff.
- [x] `§ Rewriting one chapter` and `§ Recreating the book`: read the file, not `git log -p`.

### Recreating a book

- [x] Let `/createbook` start from an existing book folder. It reads `assertions.json` first, takes the brief from it, takes the sources from `book.json`, and carries every entry that holds. A recreate into a new folder starts by copying the file across with its IDs unchanged. Every chapter is written fresh, with marks that cite entries, so the recreate turns each carried `legacy` entry into `expected`. From then on, the uncited-entry report covers the whole book.
- [x] At the gate, report how many entries were carried, which chapters will carry each one, and which conflict with a source, for example a new document that now states the class size. The operator settles each conflict. Neither the file nor the source wins without the operator's say.

### Backfill

- [x] Write the backfill procedure that the stop runs. It draws candidates from these places:
  - `OUTLINE.md`'s measured, decisions and names sections
  - the ledger-row asides that record a ruling
  - the revision notes
  - the marks that name an `unsourced` label
  - the claim-check reports
  - `git log -p` of the chapters

  The operator confirms each candidate, because a revision note can record an edit that was later reversed. The `created` block records what was read and the counts.
- [x] A backfill writes the file and nothing else. It never edits a chapter, because `/updatebook` keeps untouched chapters byte-identical. Every `prose` entry it writes is marked `citation: "legacy"`.
- [x] When a backfill records a superseded premise, it asks the operator for `search` phrases for both values and runs the sweep straight away. It then shows every passage still built on the old value, and says that the fix is a chapter rewrite or the recreate, not a patch (`updatebook § When to stop editing in place`).
- [x] A derived key goes into one `settled` entry with an `answers` list, not into a single statement and not into one entry per item. Where a key was corrected, the `corrected` date comes from the commit that corrected it.
- [ ] Backfill the reference guide before it is recreated. Then check that all four cases above are carried: the roster of eleven, the exam window, the rulings and the corrected key. Also check that the sweep lists the passages still built on a class of twenty.

### Fixtures and release

- [x] Add fixtures:
  - a valid file
  - malformed files that `check` must fail: bad JSON, an unknown kind, a reused ID, a one-sided supersession, an unknown key, an empty `entries` with no `created` block, `citation` on a `book` entry, and a repeated item in an `answers` set
  - a mark citing a superseded entry, which must fail
  - an uncited `expected` entry that holds, which must be reported, and an uncited `legacy` one, which must not
  - a superseded premise whose `search` phrase appears in a chapter and in an `.svg`, where both hits must be reported and the run must still pass
  - a book with no file, which must draw the note rather than pass quietly
- [x] Existing fixture books have no file, and they stay that way: they are the missing-file case the scripts have to report. Make sure the new note does not break any fixture whose expected output is matched exactly.
- [x] Bump bookcraft's version so installed copies pick up the change.

### Not in scope

- What the sources say. The ledger and the sources are the record for that, and the file holds only what no source can.
- A changelog. Git holds the history. The file holds what is true now, and a superseded entry stays only to point at the entry that replaced it.
- Identical wording after a recreate. The file guarantees that the assertions are carried, not that the sentences come back the same.
- Citations from outside the book. Repointing those stays with `createbook § When the book supersedes one that already exists`.

## Plan

- [x] Phase 1: The format and the helper. Add `createbook/scripts/assertions.sh` (Python 3,
      standard library only) with `init`, `add`, `supersede`, `retire`, `correct`, `list` and
      `check`. `check` is the only definition of the format. Document the fields in
      `createbook/SKILL.md`, and add the file to the book-folder layout there and in the plugin
      README.
      Done 2026-09-25.
- [x] Phase 2: Marks cite entries. Add the reserved `assertion <id>` component to
      `check-provenance.sh`, which calls the helper's `check` rather than parsing the file itself.
      Fail a mark citing a missing, superseded or retired entry. Sweep superseded premises'
      `search` phrases across chapters, `OUTLINE.md`, `diagrams/README.md` and `.svg` files as
      reports. Report uncited `expected` entries, add the census count, and print a note when a
      book has no file.
      Done 2026-09-25. The two ticket boxes left open under "Marks cite entries" are not
      checker work: replacing `unsourced` labels with entries is done to a book by its
      backfill (Phases 5 and 7), and `/check-claims` reading entries is Phase 4.
- [x] Phase 3: `/createbook`. Create the file at step 1 with the brief. Turn operator answers,
      rulings, exclusions and measurements into entries at steps 2 and 3, and show `list` at the
      gate. Outline rows list the entry IDs their chapter carries. Move register material out of
      the outline. Start a recreate from an existing folder: carry every entry that holds, turn
      `legacy` into `expected`, and report carried entries and conflicts at the gate.
      Done 2026-09-25. The recreate is `createbook § Recreating a book`, per
      `## Decision: a recreate is a /createbook flag, into a new folder` below. An old folder
      with no file stops it for now; Phase 5 turns that stop into a backfill, along with the
      same stop for any existing folder, because it writes the procedure both run.
- [x] Phase 4: `/updatebook` and `/check-claims`. Step 0 stops on a missing file: backfill,
      confirm, commit, then step 0 again. Add the classification row, the `legacy` to `expected`
      rule, the carry, and `check` at step 5. The rewrite and recreate sections read the file,
      not `git log -p`. `/check-claims` stops and backfills too, and reads `settled` entries.
      `/makebook`'s exemption is stated.
      Per the recreate decision below, the "Recreate the book" level and `§ Recreating the
      book` name the `/createbook --recreate` command and do not run the recreate.
      Done 2026-09-25. `/check-claims`' agents get their entries through the worklist, since
      each is given one chapter file and nothing else: `check-provenance.sh --emit-worklist`
      now carries each unit's cited entries and every `settled` entry that holds.
- [x] Phase 5: The backfill procedure. Candidate sources, operator confirmation, the `created`
      block, `legacy` marking, the premise sweep on a superseded premise, and derived keys as one
      `answers` entry with corrected dates taken from the commits that made them.
      Confirmation follows `## Decision: a backfill confirms by triage` below. Also carries the
      stop for an existing folder with no file, moved here from Phase 3.
      Done 2026-09-25: `createbook § Backfilling the assertions file`, and the stops in
      `§ Adding to a book that already exists` and `§ Recreating a book`. Written ahead of
      Phase 4 so that `/updatebook` and `/check-claims` point at a procedure that exists.
      Backfilling the reference guide itself is Phase 7.
- [x] Phase 6: Fixtures and release. Add the fixture cases the ticket lists, confirm the
      missing-file note breaks no exact-output fixture, record the reasoning in `NOTES.md`, bump
      bookcraft's version, and run `scripts/test-fixtures.sh`.
      Done 2026-09-25. `createbook/fixtures/assertions/run.sh` makes 31 assertions, and
      every case the ticket lists is among them. `provenance`'s manifest row asserts the
      missing-file note. bookcraft goes from 1.7.1 to 1.8.0. `test-fixtures.sh --strict`
      passes: 17 passed, 0 failed, 0 skipped.
- [ ] Phase 7: Validate on the reference guide, in its own repo. Backfill it, confirm the four
      cases are carried and that the sweep lists the passages still built on twenty. Record the
      outcome here in generic terms only: nothing from that book's sources, people or course
      names comes into this repo.

## Open Questions

- ~~How is a recreate started: a flag on `/createbook` naming the old book folder, or a route
  from `/updatebook`'s "Recreate the book" level into `/createbook`?~~ **Resolved 2026-09-25 by
  operator decision: a flag, `/createbook --recreate <old-folder> <new-folder>`, into a new
  folder.** See `## Decision: a recreate is a /createbook flag, into a new folder` below.
- ~~How does a backfill present dozens of candidates for confirmation: one at a time, or grouped
  by kind with the operator striking the ones to drop?~~ **Resolved 2026-09-25 by operator
  decision: by triage.** Solid candidates are grouped by kind for striking, and doubtful ones are
  asked one by one. See `## Decision: a backfill confirms by triage` below.

## Deferred

- **A review file for a backfill too large to confirm in chat.** Candidates written to a file in
  a subfolder of the book, such as `<book>/backfill/`, never a `*.md` at the top level, where
  `/makebook` would bind it and the sweep would report the old premises it quotes. The operator
  edits the file, and a helper `import` validates and writes the confirmed ones. Not built,
  because the expected 30 to 50 candidates fit the triage. Revisit if a real backfill does not.

## Outside the objective, by operator direction

- **pr plugin 0.2.7: a standing grant can cover `/pr:close`.** Added 2026-09-25 at the
  operator's direction, not part of #46. Four sites said `/pr:close` "is always the
  operator's to invoke": `reference/lifecycle.md`, and the `ticket`, `resume` and `pre-test`
  skills. They now make the one exception of a standing grant, recorded in the project's
  instructions or memory. Even under a grant, `/pr:close` runs as its own step and never from
  inside another skill. Under `pre-test` it runs only after the hands-on testing the verdict
  asks for. A grant never covers a merge or anything else that writes to the default branch.
  The version goes to 0.2.7, one past `main`'s 0.2.6 from #45, so installed copies refresh. The pr acceptance suite
  passes 39 of 39.

## Decision: a recreate is a /createbook flag, into a new folder

Settled 2026-09-25 by operator decision.

**`/createbook --recreate <old-folder> <new-folder>` runs a recreate. `/updatebook` never
runs one.** Its "Recreate the book" level and `§ Recreating the book` stop and name that
command.

- **It lives in `/createbook`, because the skills already divide the work that way.**
  `updatebook/SKILL.md` says it "does not recreate a book. It says when one is due, and
  `/createbook` does the work". A recreate reruns `/createbook`'s own procedure: outline, gate,
  chapter agents, checks. A route through `/updatebook` would have one skill drive another's
  steps, or duplicate them.
- **It is a flag, not a second argument naming an existing folder.** That form already means
  "add chapters to this book" (`createbook § Adding to a book that already exists`). If the same
  command could append or rewrite every chapter depending on what it found in the folder, one
  misread would replace a whole book.
- **It writes into a new folder and refuses the old one.** A recreate is due when chapter
  boundaries or order change, so the filenames change too. In place, the old chapter files
  would sit beside the new ones, and `/makebook` binds every `*.md` in the folder. The old book
  also stays readable, for repointing outside citations
  (`createbook § When the book supersedes one that already exists`). The operator deletes it
  once satisfied.
- **It takes no book description.** The brief in `assertions.json` is the request, and a
  different request is a new book, not a recreate. A brief whose argument a backfill left `null`
  is said so at the gate, and the operator can supply the argument through
  `assertions.sh brief --argument`.
- **What it does**, from the ticket:
  - It copies `assertions.json` across with its IDs unchanged, and starts `book.json` from the
    old one. The profile can still change at the gate, because changed rules are the usual
    reason for a recreate.
  - It carries every entry that holds through the outline's Carries rows.
  - The gate reports how many entries were carried, which chapter carries each, and which
    conflict with a source. The operator settles each conflict.
  - After drafting, `expect --all` runs, and then `check-provenance.sh`'s uncited report names
    exactly what the new book dropped.
- **An old folder with no `assertions.json` stops and backfills first**, as `/createbook` does
  for any existing folder (Phase 5).

## Decision: a backfill confirms by triage

Settled 2026-09-25 by operator decision, choosing among four options: one at a time, grouped by
kind with striking, a review file, and triage.

**The skill checks every candidate against the current prose and git before asking anything.
It then shows the solid ones grouped by kind, for the operator to strike, and asks the doubtful
ones one by one.** Every candidate is still shown, so the operator confirms each, as the ticket
requires, but their attention goes where the evidence is weakest.

What shaped it:

- **A backfill arrives uninvited.** It fires on the first `/updatebook`, `/createbook` or
  `/check-claims` run after this ships, even a one-word fix, so its cost lands on an operator
  who came to do something else. One at a time means about ten AskUserQuestion calls at roughly
  40 candidates, and fatigue waves the late ones through.
- **Nothing written can be deleted.** The helper only retires and never reuses an ID. So
  confirmation finishes before the first `add`, and candidates live in the session until then.
- **AskUserQuestion takes at most four questions per call, with two to four options each.** It
  can carry individual questions but not a list to strike from.
- **A uniform table invites rubber-stamping**, the failure `createbook § 3` names for the persona:
  "a label reads as something already settled". Grouping alone makes solid and doubtful
  candidates look the same.

The procedure Phase 5 writes:

1. **Gather candidates** from the sources the ticket lists. Each gets a proposed kind, a full
   sentence, a proposed origin with its date taken from the commit that introduced it, and its
   evidence: an outline section, a commit, or a mark's location.
2. **Check each against the current state.** A revision note whose change is still in the
   chapter text is current. One whose text is gone is "possibly reversed", which is the ticket's
   stated reason for confirming at all, found mechanically instead of from memory.
3. **Ask individually, always:**
   - every possibly-reversed candidate
   - every ruling whose author the evidence does not settle (`origin.by`)
   - `search` phrases for both values of each superseded premise, after which the sweep runs at
     once and shows the passages still built on the old value
   - the original argument, which is written `null` where it is lost
4. **Show everything else grouped by kind for striking**, each with its evidence and proposed
   origin, never as a bare label.
5. **Ask what the backfill missed.** It reads only what reached the repo.
6. **Write in one pass:** `init` with `from`, `candidates` and `confirmed`; each premise before its
   replacement; a corrected answer key added as first derived, then corrected, dated to the commit
   that fixed it. Every `prose` entry is `legacy`.
7. **Show `list` as the final confirmation**, before the commit that `/updatebook`'s step 0
   requires.

A review file (option C) is kept under `## Deferred` for a book whose candidates will not fit in
a message.
