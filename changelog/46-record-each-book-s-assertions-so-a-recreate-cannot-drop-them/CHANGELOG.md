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
