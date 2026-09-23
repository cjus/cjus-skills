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
verdict, so a folder checked under the broken binary passed in the weakest mode available while
declaring much more. `fixtures/fence` is the clearest case — it declares `tags`, `provenance`
and `suggested_reading`, reported all three as off under the stale binary, and now reports all
three as `required` and still passes. The books were always sound; the checks were not being
run.

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

`fixtures/jq-unrunnable/run.sh` passes all nine assertions. Its first half needs a working `jq`
to mean anything, and on this machine it had never had one. It does not trust `PATH` — it hunts
for a working `jq` itself and synthesizes the broken one for the second half — so the machine
fix neither invalidates it nor is required by it.

### Recorded so this cannot silently rot again

`plugins/bookcraft/README.md § Fixtures` gains a table of every book folder, what it declares
and what `check-book.sh` should exit, with the warning that matters: read the mode line, not
only the exit code, because a folder graded below its declaration still exits 0 while checking
almost nothing. `fixtures/ledger` is named as the folder that is deliberately not a book — no
chapter files, so the checker exits 2 — and the shipped-files tree gains the
`check-claims/fixtures/` entry it was missing.
