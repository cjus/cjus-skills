# Re-validate books that were checked while jq was broken

Start date: 2026-09-21 15:45:10 MDT

Every `book.json` declaration was read as an empty string while a stale x86_64 `jq`
shadowed a working one, so every book folder was checked in the weakest mode available
regardless of what it declared. The machine fix has since landed. This branch re-runs the
checker across every book folder under the now-working `jq` and resolves each disagreement
between a book and its declarations.

## Changes

### 2026-09-22 — the baseline, and what it found

Ran `check-book.sh` against every book folder in the repo under the now-working `jq`. **Six of
eight exit 0, two exit 1, and no book disagrees with its own `book.json`.** The re-validation
comes back clean: there was nothing to correct.

That is a real result rather than an empty one. The bug downgraded the *grading mode*, not the
verdict, so a folder checked under the broken binary passed in a weaker mode than it declared.
`fixtures/fence` is the clearest case. It declares `tags`, `provenance` and `suggested_reading`;
under the degraded path it reported `provenance: off`, `suggested reading: off` and
`tagged: 2/2 (inferred)`, and it now reports all three as `required` and still passes. The books
were always sound; the declaration-gated checks were not being run.

**Measured, not inferred.** Re-running `fixtures/fence` with `jq` removed from `PATH` reproduces
the `declared_*=""` state the broken binary produced. Its mode line reads, in part,
`tagged: 2/2 (inferred)`, `provenance: off`, `suggested reading: off`, `prose: 570` and
`structure: 298` — five fields of the eleven it prints, quoted here out of their printed order.
Two of the three declarations were genuinely unenforced. The third fell back to inference, which
is weaker but not absent: a book whose second chapter dropped its tags would still have failed.
The filename, ordering, heading and prose sweeps ran throughout. Worth stating precisely, because
this record is what a later reader will use to decide how far to distrust historical results, and
"every check was off" would widen that doubt past what the evidence supports.

The absent-`jq` path is not quite the broken-`jq` path, and the difference is the whole bug. With
`jq` absent the checker prints a note saying no declaration was read. With `jq` present and
unrunnable, `command -v jq` succeeded, that note never fired, and the summary line was
indistinguishable from a book that declared nothing. That silence is what the guard now ends.

The two failures are both pre-existing and both already understood:

- `guide-under-narration` exits 1 on five lines, by construction. It is `guide/`'s chapters with
  the `"profile": "guide"` line removed, so the narration rules reject every guide-only
  construct. This is the half that proves the profile is doing the work.
- `fixtures/provenance` exits 1 because both chapters carry one part heading where the shape
  wants two or three. That is issue #18, and its fix stays there. The provenance marks the
  fixture actually exists to exercise are clean: `check-provenance.sh` reports its six
  by-design failures and `--chapters 1` exits 0, both matching what the README claimed.

### The blast radius is smaller than the ticket assumed

`check-provenance.sh` and `check-references.sh` call `jq` nowhere. The silent downgrade could
only ever reach `check-book.sh` and the declarations in a `book.json`, so no provenance or
reference result recorded on this machine was affected. Worth knowing, because the ticket was
written as though every checker were suspect.

### The jq guard is now fully exercisable for the first time

`fixtures/jq-unrunnable/run.sh` passed all nine assertions on 2026-09-22. Its first half needs a
working `jq`
to mean anything, and on this machine it had never had one. It does not trust `PATH` — it hunts
for a working `jq` itself and synthesizes the broken one for the second half — so the machine
fix neither invalidates it nor is required by it.

### 2026-09-23 — two review rounds sharpened the record, and caught two errors in it

The baseline result did not change. What changed is how precisely it is stated, and both
corrections came from review rather than from the original pass.

The first: this changelog said `fixtures/fence` "reported all three as off" and that "the checks
were not being run". Reproducing the degraded path shows two of three off and the third fallen
back to inference, with the filename, ordering, heading and prose sweeps still running. Rounding
that to "everything was off" would have widened the doubt cast on historical results past what
the evidence supports, in the one document written to bound it.

The second was introduced by the fix for the first. Naming what a downgraded mode skips, the
README listed the profile substitution alongside four silent degradations — but a guide book
graded under the narration rules does not slip through quietly, it fails on every construct the
profile exists to allow. `guide-under-narration` is that case and exits 1 on five lines, two
paragraphs below where the text claimed otherwise. The warning now sorts the silent case from the
loud one. A list is an implicit claim that its members behave alike, so naming what is skipped was
only half the fix.

### 2026-09-23 — #23 merged first and superseded the record half of this branch

`main` gained `3467d2c`, which closed #6 by giving the fixture folders `test-fixtures.sh` and the
repo its first CI. It conflicted with this branch in `plugins/bookcraft/README.md § Fixtures`,
because both had rewritten that section.

**Resolved in `main`'s favour, dropping this branch's table entirely.** The table existed so that
"a later runner has an accurate table to assert against", and #23 *is* that runner — one that
asserts the folders directly, pairs every expected exit code with a string the output has to
carry, and fails any folder covered by neither a manifest row nor a `run.sh`. A prose table is
strictly worse than that, and #23's README makes the argument in general terms: "An expected exit
code is not an assertion on its own."

It also made one row of the table wrong. `fixtures/provenance` had exited 1 under `check-book.sh`
since it was written; #23 split both its chapters into two parts and it exits 0 now. So the table
would have shipped a stale assertion within a day of being written, which is the failure mode the
first deferred item predicted — just faster, and resolved by the same commit that predicted it.

What survives from this branch in shipped files is one line: `check-claims/fixtures/` in the
README's shipped-files tree, which `main` still lacked. The re-validation answer that #7 actually
asked for is unaffected and lives here and in `PLAN.md`.

Two consequences worth recording. **#18 is now stale** — it tracks `fixtures/provenance` failing
`check-book.sh` on its part-heading count, and #23 fixed exactly that, so its premise no longer
holds although it is still open. And **both of this branch's deferred items are closed**, one done
by #23 and one made moot by dropping the table.

### Written to stop this rotting, then superseded

This is kept as the record of what the branch wrote before #23 landed, because the reasoning is
still the reasoning, and only the medium changed.

`plugins/bookcraft/README.md § Fixtures` gained a table of every book folder, what it declares and
what `check-book.sh` should exit, with the warning that mattered: read the mode line, not only the
exit code, because a narration book graded below its declaration still exits 0 with the provenance
sweep, the suggested-reading requirement and the overview and glossary cross-checks all off. A
guide book fails the opposite way, loudly, which is why the warning sorted the two rather than
listing them together. It named what is skipped instead of rounding it to "almost nothing", so a
reader who tested it would find it accurate and keep heeding it. `createbook/fixtures/ledger` was
named as the folder that is deliberately not a book, and the shipped-files tree gained the
`check-claims/fixtures/` entry it was missing.

**Of that, only the shipped-files-tree line survives the merge.** `test-fixtures.sh` now carries
the assertions the table carried, and carries them executably; `ledger` is covered by its own
`run.sh` in #23's manifest; and #23's `jq-unrunnable/run.sh` gained a third case exercising the
no-`jq` fallback directly — the same degraded path this branch reproduced by hand to measure.
The warning's substance is worth re-proposing against #23's section as its own change if it is
wanted, rather than smuggled through this branch.
