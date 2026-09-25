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

### 2026-09-25 12:12:27 MDT — Phase 5: the backfill procedure

`createbook § Backfilling the assertions file` holds the procedure, written ahead of Phase 4 so
the stops in `/updatebook` and `/check-claims` point at something that exists. It follows the
triage decision in eight steps:

1. **Gather** from six places, in order: the outline's register-like sections, ledger asides,
   revision notes, marks with a fact-like `unsourced` label (one candidate per fact, not per
   mark), `claim-checks/`, and `git log -p`, starting with commits that changed a chapter and
   left the outline alone. Each candidate is dated by `git log --reverse -S`. A changed premise
   is gathered as a pair, and a derived key as one `answers` set.
2. **Check** each against the book as it stands, so a reversed revision is caught mechanically.
3. **Ask individually** about reversals, unclear authorship, search phrases for both values, the
   argument, and unrecorded origins.
4. **Strike the rest** from tables grouped by kind.
5. **Ask** what the backfill missed.
6. **Write** in one pass, since nothing written can be deleted. Every `prose` entry is
   `legacy`, and key corrections are replayed through `correct --date`.
7. **Sweep** each changed premise and name the passages still built on the old value, with the
   rewrite or recreate as the fix.
8. **Confirm** with `list`, then commit the file alone.

`/createbook` now stops and backfills for an existing folder, whether adding chapters or
recreating. `/makebook`'s exemption and the absence of any skip flag are stated where the
procedure opens.

### 2026-09-25 12:15:51 MDT — Phase 4: /updatebook, /check-claims and /makebook

**`/updatebook`:**
- **Step 0** stops on a missing file: backfill, confirm, commit, then step 0 again, with no skip
  flag. It also runs `assertions.sh check` and records the `assertions` census line.
- **Step 1** reads `list` beside the outline.
- **Step 2** gains a classification row: supplying a fact, ruling on the sources or scope, or
  adopting a recommendation writes an entry before the prose changes. The "Changes a premise"
  row now supersedes the premise first, with `search` phrases, so the sweep finds the old
  passages.
- **Step 3:** a rewritten paragraph cites its entry, and `expect` runs once every paragraph
  resting on a `legacy` entry cites it.
- **Step 4** carries the file, and a re-run measurement supersedes its entry.
- **Step 5** checks the file, reads its diff beside the chapters', and compares the
  `assertions` line.
- **Step 6** reports entry changes by ID.
- **`§ Rewriting one chapter`** reads the file instead of `git log -p`, and passes carried
  entries to the chapter agent. **`§ Recreating the book`** names `/createbook --recreate` and
  stops.

**`/check-claims`:** step 1 stops on a missing file. `judgement.md` gains
`§ Entries the book stands behind`: a sentence that could rest on a cited entry does, and
`settled` entries are read before any finding is raised. The entries reach the agents through
the worklist, because each gets one chapter file and nothing else. `--emit-worklist` adds
`entries` to each unit and `settled` to each chapter file.

**`/makebook`** states its exemption in its notes. The README's `/updatebook` section no longer
says facts are carried into `OUTLINE.md` by hand.

Worklist tested on a scratch book: a unit citing a source and an entry carried the entry, and
the chapter file carried the settled one. `scripts/test-fixtures.sh`: 16 passed, 0 failed.

### 2026-09-25 12:21:22 MDT — Phase 6: fixtures and release

**`createbook/fixtures/assertions/`** is a one-chapter book with a figure and a backfilled
`assertions.json`. Its `run.sh` makes 25 assertions:

- The committed file is rebuilt from the helper's own commands, with fixed dates, and must come
  back byte-identical. This covers `init`, `brief`, `add`, `supersede`, `correct`,
  `retire` and `expect`, and the layout.
- `check` passes the file and fails the ten files in `malformed/` by name: the ticket's eight,
  plus a repeated JSON key and a deleted entry. A refused write leaves the file byte-identical,
  and a newer format exits 2 from both the helper and the checker.
- `check-provenance.sh` passes the folder with exactly three REVIEW lines: the uncited
  `expected` entry, and the superseded premise swept out of a wrapped, bolded chapter line and
  out of a figure split across `<tspan>`s. It reports neither uncited `legacy` entry.
- Mutated copies fail as they should: a citation of a superseded entry, a citation of a retired
  entry, an unreadable component, a missing file, and a reserved source name.
- `check-book.sh` passes the folder.

Breaking the sweep and the `legacy` filter in a copy of the checker failed the fixture, so it
catches both. It also passes with Python 3.9 first on `PATH`.

Other changes:

- `test-fixtures.sh` checks that `assertions.sh` is executable, and `provenance`'s manifest row
  now asserts `assertions NOT CHECKED`. The existing fixture books stay without a file, as the
  missing-file case.
- CI's list of scripts that must be executable gains `assertions.sh`.
- The README's fixture list is now "Eight fixtures".
- `createbook/NOTES.md § assertions.json, 2026-09-25` separates what the ticket measured from
  what is only asserted. The sweep's hit rate is named as unmeasured until a real backfill counts
  it.
- bookcraft goes from 1.7.1 to 1.8.0.

`test-fixtures.sh --strict`: 17 passed, 0 failed, 0 skipped.

### 2026-09-25 12:22:13 MDT — Synced main, and pr moves to 0.2.7

`main` gained #45, which carries the ticket number into PR titles and squash commits and also
moved pr to 0.2.6. That is the number this branch had bumped to. The two identical bump lines
merged without a conflict, which would have left this branch's `/pr:close` change without a
version of its own, so pr is now 0.2.7. The merge was otherwise clean. Draft PR #48 is retitled
with the `[#46]` prefix #45 introduced, since the installed pr (0.2.5) predates it.

### 2026-09-25 12:37:52 MDT — Pre-test review: APPROVE, and its findings fixed

Draft PR #48 was opened so CI runs, and the review is in `pr-review-2026-09-25.md`: APPROVE,
with four Important items, all fixed on this branch.

1. **The backfill's `supersede` would have written the new value `expected`.** It would then be
   uncited on every run, and nothing could turn it back. Step 6 now names `--citation legacy` and
   says why, and `supersede`'s docstring says `citation` does not carry over. The reviewer offered
   carrying it over instead; the stricter default stays, since in a book edited through
   `/updatebook` a carried-over `legacy` would drop the uncited report's safety net.
2. **The sweep never ran on a book with no `provenance` or no `sources`.** Both early exits came
   before the file was read, and those older books are the ones a backfill is likeliest to meet.
   The file is now read first, and `without_marks` checks it and sweeps it on both paths. Only the
   uncited report, which needs marks, is skipped, and the summary says so.
3. **"now:" followed one link.** `current()` walks the supersession chain to its end, which ends
   because `check` requires every replacement to be newer. A retired end is named as retired.
4. **The worklist's `entries` and `settled` were untested.** `run.sh` now checks both. It asserts
   `cited == {3}` rather than the reviewer's `{2, 6, 7}`, because a unit citing only an entry is
   not emitted, by the same rule as `fill`.

Suggestions taken:

- A write keeps the file's mode. `mkstemp`'s 0600 had survived the rename.
- The missing-file note prints under `OK*` as well as `OK`.
- Figures have their XML entities decoded before the sweep.
- `init --how createbook` refuses a folder that already holds markdown, which is a book to backfill.
- The message about `citation` on a `book` entry no longer says no mark cites one.
- A stray space and a wrong count in `NOTES.md` are fixed.

`run.sh` grows from 25 to 31 assertions. A copy with each fix undone failed four of them: the
chain, the markless sweep, the entity, and the mode. The mode check uses 0640, because 0644 is
also what the umask fallback produces and would have hidden the regression.
`test-fixtures.sh --strict`: 17 passed. pr acceptance: 42 passed.

### 2026-09-25 15:39:29 MDT — Phase 7: the reference guide, backfilled

The backfill ran against the reference guide in its own repo with this branch's scripts, and
followed `createbook § Backfilling the assertions file` step by step. Everything below is kept
generic; nothing from that book comes into this repo.

- **Gathered:** 41 candidates. Four were asked individually: an exclusion found broken, the
  sweep phrases, whether a recommendation had been acted on, and who made a settled reading. The
  other 36 were confirmed from tables grouped by kind, with nothing struck.
- **Written in one pass:** 40 entries (38 hold, 1 superseded, 1 retired). `check` passes. The
  argument is verbatim, recovered from a prompts file beside the book.
- **Cases carried:** three of the ticket's four, the roster premise, the rulings and the
  corrected key. The recommendation case is out because the operator has not acted on it, which
  is the procedure working.
- **The sweep:** its first four phrases found 21 of 33 premise lines. The file was rewritten
  before commit with ten phrases drawn from a bare-value grep, which found 35 lines, 33 of them
  real.

Four procedure fixes came from the run, all in the backfill steps:

- Propose `search` phrases from a sweep of the bare value word.
- Look for a saved argument before writing it as `null`.
- Check an exclusion by searching for what it keeps out, which is how the lifted one was found.
- Leave out a live-system read that a later re-openable export now carries.

`NOTES.md` now records the sweep's measured precision and recall in place of "not yet measured".
A helper gap, no way to amend a written entry's phrases, is under `## Deferred`. The file's
commit in the book's repo waits on the operator.
