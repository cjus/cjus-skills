# Re-validate books that were checked while jq was broken

Closes #7.

## Overview

A stale x86_64 `jq` binary shadowed a working one on the operator's machine. Every `jq` call in
`check-book.sh` is `2>/dev/null`, so each `book.json` declaration read as an empty string and every
book folder was graded in a weaker mode than it declared — silently, because nothing on the summary
line distinguished that from a book declaring nothing. The machine fix landed before this branch
opened. This branch answers the question the ticket actually asked: now that `jq` runs, does every
book in the repo satisfy what its `book.json` declares?

**It does. Every folder satisfies what it declares, and no book disagrees with its own
declaration**, so there was nothing to correct. That is a result rather than an absence of one: the
bug degraded the *grading mode*, not the verdict, so the books were always sound while the
declaration-gated checks were not being enforced.

**The record half of this branch was superseded before it merged.** It originally wrote a
per-folder table of declaration and expected exit code into the README, explicitly so that "a later
runner has an accurate table to assert against". #23 then landed that runner —
`plugins/bookcraft/scripts/test-fixtures.sh` plus the repo's first CI — and it asserts every folder
directly. The table was dropped when `main` merged in, since an executable assertion beats a prose
one. What remains shipped is a single line; what remains *useful* is the answer to #7 and two
findings that bound the damage more tightly than the ticket assumed.

## Key changes

| File | Change |
|---|---|
| `plugins/bookcraft/README.md` | One line: `check-claims/fixtures/` added to the shipped-files tree, which `main` still lacked. The `§ Fixtures` table this branch wrote was dropped when `main` merged in — see Plan alignment |
| `changelog/7-.../PLAN.md` | Status through all four phases, all three open questions resolved, the deferred items recorded and then closed |
| `changelog/7-.../CHANGELOG.md` | The baseline result, the measured evidence behind it, the two bounding findings, and the record of what #23 superseded |

No executable code changed. The diff is documentation.

## Code examples

The whole of what this branch changes in shipped files:

```diff
     reference/judgement.md          what a verdict means and what is in scope
     scripts/render-report.py        turns per-chapter findings into one report
+    fixtures/                       the appendix-versus-chapter collision, and its runner
```

The measurement the branch turns on, reproduced by running `fixtures/fence` with `jq` removed from
`PATH` — the same `declared_*=""` state the broken binary produced. Five fields of the eleven the
mode line prints, quoted out of their printed order:

```
tagged: 2/2 (inferred)   provenance: off   suggested reading: off   prose: 570   structure: 298
```

That is what establishes the bug's actual shape: two declarations unenforced, the third fallen back
to inference rather than off, and the filename, ordering, heading and prose sweeps running
throughout. #23's `jq-unrunnable/run.sh` now exercises this same fallback as a third case, so the
path is asserted in CI rather than only measured here once.

## Plan alignment

All four phases completed as planned, and both remaining ticket action items are checked.

- **Phase 1, baseline** — `check-book.sh` run against all eight folders carrying a `book.json`.
  **As measured on 2026-09-22: six exit 0, two exit 1.** Every folder is graded in the mode it
  declares. (`fixtures/provenance` has since moved to 0, fixed by #23.)
- **Phase 2, classify** — two failures, neither new and neither a declaration error.
  `guide-under-narration` fails on five lines by construction; `fixtures/provenance` failed on the
  part-heading count that was issue #18, which #23 has since fixed.
- **Phase 3, apply resolutions** — **nothing to apply.** No book and no declaration disagreed once
  `jq` could read them. #18's fix was left with #18, per the plan's own instruction; #23 made it
  first.
- **Phase 4, record** — written as a table in `plugins/bookcraft/README.md § Fixtures`, then
  **superseded before merge.** The phase existed so "a later runner has an accurate table to assert
  against"; #23 landed that runner and it asserts the folders directly. The table was dropped when
  `main` merged in. The phase's goal is met, by better means than it specified.

**Deviations.** Three. The third is consequential and is the reason the shipped diff is one line:

1. The plan scoped Phase 1 to "all eight book folders carrying a `book.json`". A ninth folder,
   `createbook/fixtures/ledger`, was checked as well to establish that it is deliberately not a book
   — no chapter files, so the checker exits 2. It is named in the README so the next reader does not
   repeat the question.
2. The plan's `## About Ticket` records that `fixtures/fence` "reported all three as off" under the
   stale binary. Reproducing the degraded state shows two of three off and the third fallen back to
   inference. The operator's sentence is **left as written**, with the correction recorded beside it
   rather than edited into their record of an earlier branch.
3. **#23 merged into `main` first and superseded this branch's README work.** It closed #6 by
   giving the fixture folders `test-fixtures.sh` and the repo its first CI, rewriting the same
   `§ Fixtures` section. The conflict was resolved wholly in `main`'s favour: the table is gone,
   and only the `check-claims/fixtures/` shipped-files-tree line — which `main` still lacked —
   survives. #23 also fixed `fixtures/provenance`, which now exits 0 under `check-book.sh` where
   the dropped table recorded 1, so the table had gone stale within a day of being written.

**The one open question is resolved.** Whether "every existing book folder" extended beyond this
repo was the single thing only the operator could answer, since books written outside it are not
verifiable from here. Answered 2026-09-23: no outside books need checking. Scope is the in-repo
folders, every one of which is re-validated, so nothing is left outstanding on #7.

## Testing

Verify from the repo root. Since #23 this is one command, and it is what CI runs:

```bash
plugins/bookcraft/scripts/test-fixtures.sh          # every folder, every assertion
plugins/bookcraft/scripts/test-fixtures.sh --strict # a skipped check is a failure
python3 scripts/check-citations.py                  # the pre-commit hook's checker
```

**Results on the merged tree:** `test-fixtures.sh` reports `passed 11   failed 0   skipped 0` and
exits 0; `check-citations.py` reports 125 citations resolving.

To reproduce the finding this branch rests on, which no suite asserts because it is a statement
about a *past* state rather than current behaviour:

```bash
# Build a PATH that shadows every system dir except jq, then re-run fence.
d=$(mktemp -d); mkdir -p "$d/bin"
for dir in /usr/bin /bin /usr/sbin /sbin; do
  for f in "$dir"/*; do n=$(basename "$f"); [ "$n" = jq ] && continue
    [ -e "$d/bin/$n" ] || ln -sf "$f" "$d/bin/$n" 2>/dev/null; done; done
PATH="$d/bin" bash plugins/bookcraft/skills/createbook/scripts/check-book.sh \
  plugins/bookcraft/skills/createbook/fixtures/fence
```

**Edge cases considered.** The degraded path was reproduced directly rather than inferred. That is
what established that tags fall back to *inferred* rather than off, and that the structural and
prose sweeps keep running — plus the distinction that matters most: absent `jq` prints a note
saying no declaration was read, while broken `jq` printed nothing, which is why the failure was
silent and is the actual bug.

**No automated tests were added by this branch.** The gap it identified is closed by #23's
`test-fixtures.sh` rather than by anything here.

## Impact assessment

- **Files changed vs `main`:** 1 shipped document (one added line), plus this branch's own
  artifacts under `changelog/7-.../`.
- **Dependencies:** none added or changed.
- **Breaking changes:** none. No executable code was modified, so no skill, script or fixture
  behaves differently than it did before this branch.
- **Merge:** `origin/main` was merged in to resolve a conflict in
  `plugins/bookcraft/README.md § Fixtures`, where #23 had rewritten the same section. Resolved
  wholly in `main`'s favour; see Plan alignment.
- **CI:** the repo gained its first CI in #23, `.github/workflows/fixtures.yml`, which runs
  `test-fixtures.sh` on every push and pull request. This branch is green under it.

## Two findings beyond the objective

**The blast radius is narrower than the ticket assumed.** `check-provenance.sh` and
`check-references.sh` call `jq` nowhere — they read `book.json` through Python's `json`. The silent
downgrade could only ever reach `check-book.sh` and the declarations in a `book.json`, so no
provenance or reference result recorded on this machine was affected. The ticket was written as
though every checker were suspect.

**The jq guard is fully exercisable for the first time.** `fixtures/jq-unrunnable/run.sh` passed all
nine of its assertions on 2026-09-22. Its working-`jq` half needs a working `jq` to mean anything,
and on this machine it had never had one. It does not trust `PATH` — it hunts for a working `jq`
itself and synthesizes the broken one — so the machine fix neither invalidates it nor is required
by it. #23 has since added a third case covering the no-`jq` fallback, taking it to 13 assertions,
all passing on the merged tree.

## Deferred work

Both items were raised by the close-time review, triaged onto issue #6, and then **closed the same
day** — so nothing is carried forward.

- **Nothing executable asserts the new table.** Done by #23: `test-fixtures.sh` asserts every
  folder, pairing each expected exit code with a string the output must carry, and failing any
  folder covered by neither a manifest row nor a `run.sh`. CI runs it on every push and pull
  request. Issue #6 is closed.
- **`check-claims/fixtures/appendix/book.json` under-counts its own assertion sites.** Moot. The
  item existed because the README table was a third site; dropping the table returns the count to
  the two the file already names.

**One thing this branch surfaces that is not its own work:** #18 is now stale. It tracks
`fixtures/provenance` failing `check-book.sh` on its part-heading count, and #23 fixed exactly
that — the folder exits 0 now. The issue is still open and its premise no longer holds.

## Assertion audit

**Disabled for this repo.** `docs.assertionsFile` is `null` in `.claude/pr-config.json`, so there is
no assertions file to audit against and none was created. Likewise `docs.continuityRoot` is `null`,
so no continuity entry was written.
