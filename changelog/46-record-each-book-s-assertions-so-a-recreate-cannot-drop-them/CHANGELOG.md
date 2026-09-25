# Record each book's assertions so a recreate cannot drop them

Start date: 2026-09-25 10:35:06 MDT

A recreate rebuilds a book from its outline and its sources, and drops every claim that lived
only in the prose. This branch gives each book an `assertions.json` that records those claims,
has the book skills stop and create one when it is missing, and makes a recreate carry it.

Condensed 2026-09-25 at `/pr:close`. Every timestamp is kept, and the detail of each decision
lives in `PLAN.md`'s Decision sections, `createbook/NOTES.md § assertions.json, 2026-09-25`,
and `pr-summary-2026-09-25.md`.

## Changes

### 2026-09-25 10:49:30 MDT — Phase 1: the format and the helper

`createbook/scripts/assertions.sh` is standard-library Python and runs on 3.9. Its `check` is the
format, and every write validates the whole file before and after. Decisions past the ticket's
text, each toward the stricter reading:

- `next_id`, with no gaps below it, so an ID can never come to mean a different claim.
- An `expect` command, since the ticket's `legacy` to `expected` rule needed one.
- `was` beside `corrected` on an answer.
- A backfill may write the argument as `null` and an origin as `unrecorded`.
- `created` is always required.
- `legacy` appears only in a backfilled file.
- `given` is by the operator, and `measurement` is the origin of `measured` entries only.
- A replacement is always newer than what it supersedes, which rules out a cycle.
- A repeated JSON key fails.

### 2026-09-25 11:03:00 MDT — Phase 2: marks cite entries

`check-provenance.sh` imports the helper's `load` by path and never parses the file itself.

- `assertion <id>` fails when the entry is missing, superseded or retired, and the word is
  reserved in `sources` and `unsourced`.
- Superseded premises are swept as REVIEW over every markdown file in the book folder and its
  figures.
- Uncited `expected` entries are REVIEW.
- Both reports cover the whole book even under `--chapters`.
- The census gains an `assertions` line, and a missing file reads `NOT CHECKED`.
- Two fixture runners that import a copy of the checker now copy `assertions.sh` beside it.

### 2026-09-25 11:07:58 MDT — Phase 3: /createbook writes the file (the recreate waits)

- Step 1 starts the file with the argument verbatim.
- Step 2 maps what reading the sources turns up to kinds, and the outline keeps no register of
  its own.
- Chapter rows gain Carries.
- The gate shows `list`, and every answer becomes an entry.
- Step 5 passes each agent its entries and forbids it from writing the file.
- A new `brief` command, because the gate corrects what step 1 wrote.
- One writer at a time.
- `"unsourced": ["measured"]` leaves the template.

### 2026-09-25 11:44:03 MDT — Decision: how a recreate is started

The operator chose `/createbook --recreate <old-folder> <new-folder>`, into a new folder, with
`/updatebook` only naming it. The reasoning is in `PLAN.md`.

### 2026-09-25 11:49:37 MDT — Decision: how a backfill is confirmed

The operator chose triage: solid candidates grouped by kind for striking, doubtful ones asked one
by one. A review file for an oversized backfill is under `## Deferred`.

### 2026-09-25 12:03:59 MDT — pr plugin: a standing grant can cover /pr:close (outside #46)

Operator-directed and outside the objective. Four sites in the pr plugin now allow a standing
grant to cover `/pr:close`: as its own step, never from inside another skill, after the testing
`pre-test` asks for, and never a merge. The acceptance suite passed 39 of 39.

### 2026-09-25 12:05:58 MDT — Phase 3 complete: the recreate

`createbook § Recreating a book` has a per-step table of what differs. The gate adds three
reports: entries carried, which chapter carries each, and conflicts with sources.
`expect --all` runs before step 7, so the uncited report names every drop. An existing-folder
argument now only ever appends. A walk-through on a scratch copy named exactly the dropped
entries.

### 2026-09-25 12:12:27 MDT — Phase 5: the backfill procedure

Written before Phase 4, so the stops it adds point at something that exists.
`createbook § Backfilling the assertions file` runs the triage in eight steps: gather, check
against the book, ask the doubtful ones, strike the rest, ask what was missed, write in one pass,
sweep, then confirm and commit alone. `/createbook` now stops and backfills for an existing
folder.

### 2026-09-25 12:15:51 MDT — Phase 4: /updatebook, /check-claims and /makebook

- **`/updatebook`:**
  - step 0 stops on a missing file: backfill, confirm, commit, then step 0 again
  - a classification row writes entries before the prose changes
  - a changed premise is superseded first
  - `legacy` turns `expected` once every paragraph resting on the entry cites it
  - the file is carried and checked
  - the rewrite section reads the file instead of `git log -p`
  - the recreate section names the command
- **`/check-claims`:** stops on a missing file. `judgement.md` gains
  `§ Entries the book stands behind`, and `--emit-worklist` carries `entries` and `settled`.
- **`/makebook`:** states its exemption.

### 2026-09-25 12:21:22 MDT — Phase 6: fixtures and release

- `createbook/fixtures/assertions/` has a `run.sh` that rebuilds the committed file
  byte-identical, fails ten malformed files by name, and runs the checker over the folder and
  mutated copies. A copy of the checker with key rules broken failed it.
- `test-fixtures.sh` and CI check that the helper is executable.
- The provenance manifest row asserts the missing-file note.
- `NOTES.md` records the reasoning.
- bookcraft moves to 1.8.0.

### 2026-09-25 12:22:13 MDT — Synced main, and pr moves to 0.2.7

`main` gained #45, which had also moved pr to 0.2.6. The identical bump would have left this
branch's pr change without a version of its own, so pr is now 0.2.7. PR #48 is retitled with the
`[#46]` prefix #45 introduced.

### 2026-09-25 12:37:52 MDT — Pre-test review: APPROVE, and its findings fixed

Draft PR #48 opened, and the review approved with four Important findings, all fixed:

- a backfill's `supersede` names `--citation legacy`
- books whose marks are not read are still swept
- "now:" follows the supersession chain to its end
- the worklist keys are tested

Suggestions taken: file mode kept on write, the note printed under `OK*` too, XML entities
decoded in figures, `init --how createbook` refused for an existing book. The fixture grew from
25 to 31 assertions.

### 2026-09-25 15:39:29 MDT — Phase 7: the reference guide, backfilled

Run in the book's own repo with this branch's scripts, and recorded here in generic terms only.

- 41 candidates, 40 confirmed. Four were asked individually, and the rest were confirmed by kind.
- Three of the four cases are carried. The unadopted recommendation stays `fill`, by the
  operator's ruling.
- The sweep's first four phrases found 21 of 33 premise lines. The file was rewritten before
  commit with ten phrases from a bare-value grep, which found 35 lines, 33 of them real.

Four procedure fixes followed:

- propose phrases from the bare-value sweep
- look for a saved argument before writing `null`
- check an exclusion by searching for what it keeps out
- leave out a live-system read a later export now carries

The missing command to amend a written entry's phrases is under `## Deferred`.

### 2026-09-25 15:42:31 MDT — Phase 7 complete

The operator confirmed the file, and it is committed and pushed in the book's own repo. Every
phase is done.
