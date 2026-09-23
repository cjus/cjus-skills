# Fixture health for createbook's checker

The fixture folders are the only verification the bookcraft book checkers have, and nothing
ran them but a person remembering to. This adds a runner, the repository's first CI workflow,
and fixes the one folder whose exit code carried no signal at all.

Along the way the ticket's own premise turned out to be wrong in two places, both corrected
here and both recorded rather than quietly fixed.

## `fixtures/provenance/` — the ticket conflated two scripts

The ticket asked whether `provenance-fixture-01-everything-resolves.md` fails because of a
checker defect or because the fixture is a deliberate negative case. It is neither, because
two different scripts are involved and only one of them is the fixture's subject.

The folder **is** a deliberate negative fixture for `check-provenance.sh`, and it already said
so, in its own `book.json`:

> Chapter 1 holds only passing marks, so a run that reports anything against it is a
> regression. Chapter 2 holds one of each failing shape... Expected: 6 failures and 1 review,
> exit 1. This sentence is the fixture's only assertion, since the repo has no CI to hold it.

Measured on a clean branch: exactly 6 failures and 1 REVIEW, all seven against chapter 2, none
against chapter 1. The fixture holds and its name is accurate.

The exit 1 the ticket observed came from `check-book.sh`, a different script, and was
collateral. Both chapters carried one part heading where a chapter's shape is two or three, so
the folder failed a structural rule neither chapter was written to exercise. Nothing about
provenance was being reported either way.

Both chapters are now split into two parts. The folder exits 0 under `check-book.sh` and still
exits 1 under `check-provenance.sh`.

## The ticket undercounted the fixture folders by half

It named four (`fence`, `overview`, `overview-nothing-carried`, `provenance`). There were
eight under `createbook/fixtures/` when it was written — seven of them older than the ticket,
plus `ledger` from #17 — and a ninth under `check-claims/`. Two more findings followed:

- **`guide-under-narration` is a second intentional exit 1**, documented in its `book.json`
  and absent from the ticket entirely.
- **`ledger` is not a book folder.** It holds `OUTLINE.md`, `run.sh` and `sources`, and exits
  2 under `check-book.sh` with `error: no chapter markdown files`. A uniform
  run-the-checker-and-compare loop would have graded it wrongly.

## Key changes

| File | Change |
|---|---|
| `plugins/bookcraft/scripts/test-fixtures.sh` | New, executable. The runner. |
| `.github/workflows/fixtures.yml` | New. The repository's first CI workflow. |
| `.../fixtures/provenance/provenance-fixture-0{1,2}-*.md` | Split into two parts each |
| `.../fixtures/provenance/book.json` | Assertion extended to name both checkers |
| `.../fixtures/jq-unrunnable/run.sh` | Third half: a `PATH` with no `jq` on it |
| `plugins/bookcraft/skills/createbook/NOTES.md` | What was measured, what is asserted |
| `plugins/bookcraft/README.md` | § Fixtures rewritten; ships tree updated |
| `README.md` | New § The fixture suite, and CI |

**Neither checker was modified.** `check-book.sh` and `check-provenance.sh` are byte-identical
to `main`.

## Why the runner does not assert exit codes alone

This is the load-bearing design decision, and `fixtures/provenance/` is the reason for it. That
folder exited 1 for as long as it existed, for a reason unrelated to what it checks. A suite
asserting only `provenance=1` would have passed it indefinitely while reporting nothing.

So every expectation also names a string the output has to carry:

```
# folder | checker | expected exit | strings the output must carry (~ separated)
createbook/guide-under-narration|check-book|1|body carries an H3 or deeper~body carries a block quote~filename does not match
createbook/provenance|check-provenance|1|6 failure(s)
```

And a folder asserted by nothing fails the run, which is what stops the drift that let the
ticket undercount the folders:

```bash
for d in "$ROOT"/skills/*/fixtures/*/; do
  [ -f "$d/run.sh" ] && continue
  printf '%s\n' "$MANIFEST" | grep -q "^$skill/$name|" && continue
  fail "$skill/fixtures/$name/ is asserted by nothing: no manifest row and no run.sh"
done
```

Both checkers are invoked through their shebangs rather than a named interpreter, so a lost
executable bit fails loudly. That matters more than it looks: `check-provenance.sh` and
`check-references.sh` are Python despite the `.sh` extension, and running one with `bash`
produces pages of parse garbage and exit 2 rather than a clean error.

## `jq`

CI asserts that `jq` **runs**, not that it exists. A `jq` on `PATH` that will not execute makes
every `book.json` declaration read as absent, and the fixtures would then grade in the weakest
mode while still exiting 0.

Absent `jq` is a supported configuration and a *different* one, with different right answers:
`fixtures/guide/` passes only because its profile declaration is read. So the runner refuses to
grade the manifest without a working `jq` rather than report failures that are not defects,
and the absent-`jq` path is covered by a third half of `jq-unrunnable/run.sh` instead — which
runs on developer machines too, unlike a CI job would.

## Plan alignment

All five phases completed as planned.

| Phase | Outcome |
|---|---|
| 1 — baseline | Done. Corrected the ticket's folder count and expected codes. |
| 2 — resolve `provenance/` | Done, by the third route: not a defect and not a rename. |
| 3 — the runner | Done, with one deviation (below). |
| 4 — CI | Done. macOS blocking, Linux non-blocking. |
| 5 — verify | Done, both halves measured. |

**Two deviations, both stated rather than absorbed:**

1. **Phase 3 planned "a script that asserts its expected exit code."** The runner asserts
   output strings as well, because Phase 1 demonstrated an exit code alone passes for the
   wrong reason. Same deliverable, stronger assertion.
2. **The proposed second no-jq CI job became a third half of `jq-unrunnable/run.sh`.** Same
   coverage, no extra job, and it runs outside CI too.

Three open questions in `PLAN.md` were settled during the work: the runner's location (inside
the plugin, per the convention every other test script follows), `jq` in CI (present and
asserted), and the runner OS (macOS blocking, Linux alongside).

## Testing

```bash
plugins/bookcraft/scripts/test-fixtures.sh --strict     # 11 checks, 0 failed, 0 skipped
plugins/bookcraft/scripts/test-fixtures.sh plugins/bookcraft --strict   # installed-copy path
python3 scripts/check-citations.py                      # 125 resolve
plugins/pr/hooks/test-guard-default-branch.sh plugins/pr/hooks/guard-default-branch.sh  # 73 cases
```

**Four regressions were introduced deliberately, each caught, each reverted:**

| Regression | Caught by |
|---|---|
| H3 rule silenced in `check-book.sh` | the required substring — **the folder still exited 1** |
| a failing case dropped from the provenance fixture | `6 failure(s)` missing; exit 1 still right |
| a new fixture folder asserted by nothing | the completeness check |
| executable bit cleared on `check-provenance.sh` | the shebang-dispatch precondition |

The first is the one that matters: the exit code was unchanged and the defect was still caught.
That is the entire argument for the design.

**CI was then measured on this PR across three pushed states:**

| Pushed state | macOS | Linux | Run conclusion |
|---|---|---|---|
| the branch as it stands | success | success | success |
| H3 rule silenced | failure | failure | failure |
| a Linux-only failing step | success | failure | **success** |

The second row closes Phase 5: both platforms printed `exit 1 is right and the output is not` /
`missing from the output: body carries an H3 or deeper`, so CI names the silenced rule rather
than reporting a bare non-zero exit.

The third row settles the non-blocking claim, which had been asserted in three documents before
it was checked — and too strongly. `continue-on-error` keeps the *workflow run's* conclusion
`success`, but the ubuntu job and its **check run** both report `failure`. Since `gh pr checks`
reads check runs, a Linux-only failure shows as a red check on the PR and will halt
`/pr:close`'s own CI gate. It does not fail the run and does not block the merge; it is visible,
and it should be. The workflow header and the root README now say exactly that rather than
"cannot fail the branch".

The two commits carrying those probes were labelled TEMPORARY, existed only to measure CI, and
were removed from the branch afterwards.

**Edge cases considered.** `jq` present but unrunnable (exit 126), `jq` absent, `jq` in
`/usr/bin` beside `awk` and `sed` on Linux so directory-pruning cannot hide it, bash 3.2 on
macOS, a fixture folder that is not a book, and a fixture added with no assertion.

## Impact assessment

- **11 files changed, 717 insertions, 10 deletions.** Four of those files are branch artifacts
  under `changelog/`.
- **No dependencies added.** The runner is POSIX shell; CI uses `actions/checkout` and
  `actions/setup-python`.
- **No breaking change.** Neither checker was modified, so no book that passed before fails now.
- **First recorded Linux run** of any of this. The README had said Linux should work with two
  edits and that no run had been recorded; there is one now, and it passed.

## Deferred work

`PLAN.md § Deferred` is empty. Nothing was parked, descoped or punted during this branch.
