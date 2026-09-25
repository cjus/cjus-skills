# Record each book's assertions so a recreate cannot drop them

Start date: 2026-09-25 10:35:06 MDT

A recreate rebuilds a book from its outline and its sources, and drops every claim that lived
only in the prose. This branch gives each book an `assertions.json` that records those claims,
has the book skills stop and create one when it is missing, and makes a recreate carry it.

## Changes

### 2026-09-25 10:49:30 MDT — Phase 1: the format and the helper

`createbook/scripts/assertions.sh` is Python 3, standard library only, and runs on 3.9 as
well as CI's 3.12. It has `init`, `add`, `supersede`, `retire`, `correct`, `expect`, `list`
and `check`, and `check` is the format. Every write validates the whole file before and
after, so the helper refuses to write onto a broken file and cannot produce one. A missing
flag is reported as the key it would have written. `load` and `problems_in` import by path,
the way `check-provenance.sh` already borrows from `check-references.sh`, which is how
Phase 2 will read the file without parsing it a second way.

Decisions the ticket left open, each taken toward the stricter reading:

- **`next_id`, a top-level high-water mark, and no gaps below it.** Uniqueness alone cannot
  stop an ID being reused. Delete the newest entry by hand and the next `add` takes its ID,
  so a mark citing the old ID resolves cleanly to a different claim. With `next_id`, every
  ID from 1 to `next_id - 1` must be present, so a deletion fails `check`.
- **`expect`, a command the ticket's own rules needed and its list left out.** A recreate,
  and an edit that gives every paragraph resting on an entry a citing mark, turn `legacy`
  into `expected`, and skills never write the file by hand.
- **A corrected answer records `was` beside `corrected`**, the two as a pair, because the
  point of keeping a derived key is that a fresh derivation can land on the old mistake
  again. A backfill replays a correction: add the answer as first derived, then `correct`
  it, dated to the commit that fixed it.
- **A backfill may write `brief.argument` as `null` and an origin as `unrecorded`.**
  Existing books never saved the argument, and a paraphrase filed as the verbatim argument
  is the failure the field exists to prevent. A file `/createbook` starts may do neither.
- **`created` is required even when there are entries**, not only when `entries` is empty.
  `init` always writes it, so the only file lacking it is one written by hand.
- **Smaller rules added:** `legacy` only in a backfilled file; a `given` entry is by the
  operator; `measurement` is the origin of `measured` entries only; a replacement is newer
  than what it supersedes, which rules out a cycle; `search` is required on every premise
  and is never carried over by `supersede`; a repeated JSON key fails rather than letting
  the parser keep the last one silently.

Tested in a scratch folder under both Pythons: the ticket's four-entry example built
through the helper, every malformed case the ticket lists plus ten more, and every write
refusal, each leaving the file byte-identical. `scripts/test-fixtures.sh`: 16 passed, 0
failed. The fixture folders themselves are Phase 6.

### 2026-09-25 11:03:00 MDT — Phase 2: marks cite entries

`check-provenance.sh` reads `assertions.json` through `assertions.sh`'s `load`, imported
by path the way it already borrows from `check-references.sh`, so the file still has one
parser. A file that fails its own check fails the run, and entries are not resolved against
it. A newer format exits 2 with the helper's own wording.

- **`assertion <id>`**, one entry to a component, with an optional gloss. It fails when the
  entry is missing, superseded or retired, or when the book has no file at all. A component
  starting with the reserved word that does not parse fails by name instead of falling
  through as an unknown source. A `sources` key or `unsourced` label starting with it fails.
- **The sweep** reports each superseded premise's `search` phrases as REVIEW, never FAIL.
  It matches case-insensitively across line breaks and markdown emphasis, whole words only,
  and a figure's markup is blanked in place, so a phrase split across `<tspan>`s matches and
  keeps its line number. **It covers every markdown file in the book folder, not only the
  chapters and `OUTLINE.md` the ticket names**, because `about-this-book.md` and the
  glossary are bound into the book too. `claim-checks/` and `outline-findings/` stay out:
  they quote old prose back.
- **Uncited `expected` entries** are REVIEW, and `legacy` ones are left out.
- **Both reports run over the whole book under `--chapters`**, the way the tag list already
  does. A scoped run that hid a superseded premise in another chapter would defeat the
  sweep's purpose, and the summary line marks them `(whole book)`.
- **Summary:** an `assertion` count on the census line, and an `assertions` line with
  entries, holds, cited, uncited, premises swept and passages found. A book with no file
  gets `assertions NOT CHECKED` there and a sentence under the OK line, so a vacuous pass
  cannot read as a real one.

Two fixture runners, `createbook/fixtures/ledger/run.sh` and
`check-claims/fixtures/appendix/run.sh`, import a copy of `check-provenance.sh` from a temp
folder, and failed until they also copied `assertions.sh` beside it, as they already copy
`check-references.sh`. The missing-file note itself broke no exact-output fixture.

Tested on a scratch book under Python 3.9 and 3.14 with every shape above. Hits were found
across a line break and emphasis, in `OUTLINE.md` and in an SVG split across tspans; there
were none in `claim-checks/`, "twenty-first" or "plenty". `check-book.sh` raises nothing
about the new marks. `scripts/test-fixtures.sh`: 16 passed, 0 failed.

### 2026-09-25 11:07:58 MDT — Phase 3: /createbook writes the file (the recreate waits)

`createbook/SKILL.md` now starts `assertions.json` at step 1, before the outline exists, with
the argument verbatim, flags included, passed as `--argument="..."` so a leading flag is not
read as the helper's own. At step 2, a table maps what reading the sources turns up to a kind:
a measurement, an assumed premise, a conflict between sources, an exclusion. **The outline keeps
no register of its own.** Measurements, rulings, exclusions and settled decisions live in the
file, and a row cites an ID where it needs one. Each chapter row gains **Carries**, the `prose`
entries it rests on. At step 3 the gate shows `list` beside the ledger, and every answer becomes
an entry before it reaches the outline: `given`, `ruling`, `adopted`, a supersede for a
corrected premise, or a retire for a rejected proposal. Step 5's prompt gains an item, now 9,
giving each agent its carried entries and every `book` entry, and telling it to cite them as
`assertion <id>` and never to write the file. Items 1 to 5, which the text cites by number, did
not move.

- **`brief`, a helper command the ticket did not list.** Step 1 writes the persona and its
  origins before the gate, and the gate exists to correct them, so they had to be changeable. It
  never replaces a recorded argument, since a second version of a verbatim argument is a
  paraphrase. It only fills one that a backfill left `null`.
- **One writer at a time, stated as a rule.** Each write rewrites the whole file, so two
  parallel chapter agents adding entries would lose one silently. Agents report a measurement or
  a contradicted entry in their findings file, and the session adds or supersedes the entry
  after the batch and re-points the mark.
- **`"unsourced": ["measured"]` is out of the `book.json` template**, and `unsourced` is
  documented as "for a method, never for a fact". A measurement is now an entry. The chapter-format
  example's measured mark reads `assertion 3 (the docker build output)`.
- The README's `/createbook` section says what the file records and that the gate shows it.

Deferred, as recorded in `PLAN.md`: starting a recreate from an existing folder (the first Open
Question), and the stop for an existing folder with no file (Phase 5, with the backfill).
Tested by running the documented step 1 to 3 commands against a scratch book, and every `brief`
refusal. `scripts/test-fixtures.sh`: 16 passed, 0 failed.

### 2026-09-25 11:44:03 MDT — Decision: how a recreate is started

The operator settled the first Open Question: **`/createbook --recreate <old-folder>
<new-folder>`**, written into a new folder, and `/updatebook` only names the command. This
matches the split both skills already document (`/updatebook` "does not recreate a book").
It keeps "point `/createbook` at an existing folder" meaning "add chapters", so the command
never has to guess between appending and rewriting. It also keeps the old chapter files out
of the new folder, where `/makebook` would otherwise bind them. The reasoning, and what the
flag does, are in `PLAN.md § Decision: a recreate is a /createbook flag, into a new folder`.
It unblocks the rest of Phase 3 and fixes how Phase 4's recreate sections read.

### 2026-09-25 11:49:37 MDT — Decision: how a backfill is confirmed

The operator settled the second Open Question: **by triage.** The skill checks each candidate
against the current prose and git. Solid ones are shown grouped by kind for striking. Doubtful
ones are asked individually: a possibly reversed revision note, a ruling with an unclear author,
the `search` phrases for a superseded premise, and the argument. All four options were weighed
against when a backfill arrives (uninvited, on the first run after this ships), the rule that
nothing written can be deleted, AskUserQuestion's limit of four questions per call, and the
rubber-stamping a uniform table invites. The procedure is in
`PLAN.md § Decision: a backfill confirms by triage`, and a review file for oversized backfills
is under `## Deferred`. Both Open Questions are now closed.

### 2026-09-25 12:03:59 MDT — pr plugin: a standing grant can cover /pr:close (outside #46)

This change is operator-directed and outside the ticket. It is recorded in
`PLAN.md § Outside the objective, by operator direction`. The operator granted standing
permission to run `/pr:cp` and `/pr:close` on feature branches, with `main` kept gated, and
asked for the pr plugin's own text to allow that. Four sentences said `/pr:close` is always
the operator's to invoke, and each now allows a standing grant. A grant still runs the close
as its own step, never from inside another skill, and after the hands-on testing `/pr:pre-test`
asks for. It never extends to a merge. pr is now 0.2.6. The acceptance suite passes 39 of 39.

### 2026-09-25 12:05:58 MDT — Phase 3 complete: the recreate

`createbook § Recreating a book` implements the decision: `/createbook --recreate <old-folder>
<new-folder>`. It takes no description. The new folder must be absent or empty, and never the
old one. The old folder must carry an `assertions.json` that passes `check`.

A table lists how each step of the procedure differs:

- **Step 1:** the file is copied with its IDs unchanged, and the brief comes from it.
- **Step 2:** the sources are read again, every entry that holds is carried, and the old chapters
  are not an input.
- **Step 4:** `book.json` starts from the old one, with its paths rewritten for the new folder.
- **Step 7:** `expect --all` runs before the checks, so the uncited report names every drop.

The gate adds three reports: the carried count, which chapter carries each entry, and which
entries a source now contradicts, each of which the operator settles.

"Adding to a book" now says an existing-folder argument only ever appends. The Arguments table,
`argument-hint` and the README gain the flag.

**An old folder with no file stops the recreate for now.** Phase 5 turns that stop into a
backfill, so this commit ships no pointer to a procedure that does not exist yet.

Walked on a scratch copy: after `expect --all`, the uncited report named exactly the two entries
the new chapter did not carry. `scripts/test-fixtures.sh`: 16 passed, 0 failed.
