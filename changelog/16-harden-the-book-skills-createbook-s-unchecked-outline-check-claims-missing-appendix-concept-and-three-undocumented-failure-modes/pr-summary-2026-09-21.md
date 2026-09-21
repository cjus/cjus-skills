## Overview

`/createbook` fans a book out to one subagent per chapter, and the outline it hands them is the
only contract they share. Nothing checked that contract before the fan-out, so an error in the
source ledger was not one chapter's error: it went to every agent drawing on that row at the same
time, and each wrote prose around it. This PR resolves the ledger at step 3, before the operator
gate, and writes down three further failure modes in the same machinery that were real but
undocumented.

It also fixes a bug that blocked `/check-claims` outright for any book carrying an appendix.
`--emit-worklist` took a chapter's number from the filename's first digit run, so
`<slug>-appendix-1-<title>.md` emitted as chapter 1, collided with the real chapter 1, and
`render-report.py` refused the entire run with `index.json lists chapter number 1 more than once`.
Twenty-one completed reading passes produced no report at all. An appendix is now carried through
as its own kind.

## Key changes

| File | Change |
|---|---|
| `createbook/scripts/check-provenance.sh` | New `--ledger-only` mode; `chapter_number()` becomes `chapter_id()` returning `(kind, number)`; `--chapters` accepts `A1` |
| `check-claims/scripts/render-report.py` | `want` map and four sorts keyed on `(kind, number)`; renders `appendix 1` rows |
| `check-claims/reference/judgement.md` | Findings shape carries `kind` and `number` in place of a bare `chapter` |
| `createbook/SKILL.md` | § 3 runs the ledger check; § 5 gains the sibling-read rule and the findings path; § 7 gains the page-locator note |
| `check-claims/SKILL.md` | `--chapters` spelling, and the `kind`/`number` contract for agents |
| `createbook/fixtures/ledger/` | New fixture, 16 assertions |
| `check-claims/fixtures/appendix/` | New fixture, 16 assertions |
| `bookcraft/.claude-plugin/plugin.json` | 1.4.1 to 1.5.0 |

## Code examples

The identifier, which is the heart of the appendix fix. An appendix numbers in its own sequence,
so the pair is the identifier rather than the number alone:

```python
# check-provenance.sh
APPENDIX_FILE = re.compile(r"^[a-z]+(?:-[a-z]+)*-appendix-(\d+)-")

def chapter_id(name):
    m = APPENDIX_FILE.search(name)
    if m:
        return "appendix", int(m.group(1))
    m = re.search(r"\d+", name)
    return ("chapter", int(m.group(0))) if m else (None, None)
```

The renderer's uniqueness check, which is what refused the run. Keyed on the pair, chapter 1 and
appendix 1 no longer collide:

```python
# render-report.py, before
n, u = c.get("number"), c.get("units")
if not isinstance(n, int) or isinstance(n, bool) or n in want:
    print(f"error: {index_path} lists chapter number {n!r} ...")
    return 2

# after
key, u = file_id(c), c.get("units")
if key is None or key in want:
    ...
```

The ledger mode's entry point, which runs before `book.json` is read because step 4 has not
written it yet:

```python
# check-provenance.sh, in main()
if mode == "ledger":
    return check_ledger(book)
```

## Plan alignment

All five phases in `PLAN.md` are complete, none deferred, none descoped.

| Phase | Outcome |
|---|---|
| 1. Resolve the ledger at step 3 | Done as `--ledger-only` |
| 2. Sibling-read rule in § 5 | Done |
| 3. Page-locator note in § 7 | Done |
| 4. Findings path for agents | Done, one path per chapter |
| 5. Appendix concept for `/check-claims` | Done as `(kind, number)` |

`PLAN.md`'s three open questions were decided by the operator and recorded in its `## Decisions`
section. Two deviations worth stating:

**Phase 5's identifier is neither shape the plan offered.** The question asked for a separate
`appendix` field or a namespaced `chapter` string. Review of `check-book.sh` found the book format
had already answered it: an appendix is modelled there as a kind flag plus its own number, fused
to `A<N>` only at the tag surface. This PR mirrors that. A free-form string was rejected because
the measured failure is agents disagreeing about how to name an appendix, and an enum plus an
integer is the shape they cannot improvise around.

**The renderer rejects the old `"chapter": N` findings shape rather than accepting it as a legacy
alias.** Findings never outlive their run, so nothing needs the compatibility, and leniency here
would let the spec drift silently.

## Testing

Two fixtures, 33 assertions, both runnable with no arguments:

```bash
plugins/bookcraft/skills/createbook/fixtures/ledger/run.sh
plugins/bookcraft/skills/check-claims/fixtures/appendix/run.sh
```

To see the bug this fixes, on the appendix fixture:

```bash
python3 plugins/bookcraft/skills/createbook/scripts/check-provenance.sh \
  --emit-worklist /tmp/wl plugins/bookcraft/skills/check-claims/fixtures/appendix
# index.json now lists kind "chapter" number 1 AND kind "appendix" number 1
```

**Asserted** by the suites: a chapter whose slug contains `appendix-N-` is still a chapter; a
capitalised locator reaches its resolver while a heading keeps its case; a section citation
followed by prose after an em dash resolves to the heading alone; a `--chapters` token that
`str.isdigit()` accepts and `int()` rejects exits 2 rather than tracebacking; a findings file in
the superseded `"chapter": N` shape is named and skipped while the rest of the report still
renders; `--chapters 1` does not also emit appendix 1. The four fixes in `0648cc2` were each
checked by reverting the fix and confirming the assertion fails, so they pin behaviour rather than
merely passing.

**Exercised by hand but not asserted**, and so not claimed as covered: a findings file whose
`number` is a bool; an appendix that is partial and carries notes; a heading containing a colon.
The last one has no assertion because none can distinguish it — `heading_hit` matches on a prefix,
so truncating at a colon and not truncating produce the same verdict for every heading in the
fixtures. The colon is excluded from the terminator set anyway, because truncating there would
narrow what a citation asserted without saying so.

The repo has no CI, so the fixtures and `scripts/check-citations.py` are the whole signal.
`check-book.sh` passes on the new appendix fixture.

## Impact assessment

19 files changed, 1,128 insertions, 73 deletions. No dependencies added; the scripts use the
standard library only.

**One breaking change.** `reference/judgement.md`'s findings contract changes from `"chapter": N`
to `"kind"` plus `"number"`, and `render-report.py` rejects the old shape. The blast radius is one
run: a worklist is regenerated in about a second and findings never outlive the run that produced
them. No stored artifact carries the old shape.

`--chapters` remains backward compatible: `--chapters 2,13` means exactly what it did, except that
it no longer also emits appendix 2.

## Deferred work

Nothing is parked under `## Deferred` in `PLAN.md`; the section does not exist because no phase was
deferred.

Four items were surfaced by review, judged not worth fixing, and recorded in
`pr-review-2026-09-21.md` so they stay findable: `check_ledger` builds a fresh `Source` per row, so
a PDF named by four rows is read four times; a `Re-openable: No` row whose Source cell holds a URL
ending `.pdf` draws a spurious REVIEW; `_tables` splits on raw `|` so an escaped `\|` shifts the
columns; and `'0'`/`'A0'` parse rather than being refused at parse time, being caught downstream
instead.

Two facts found during the work that belong to other tickets rather than this one:
`createbook/fixtures/provenance/` fails `check-book.sh` on its part-heading count, which predates
this branch, and issue #16's text says `render-report.py` exits 1 on the duplicate refusal when it
returns 2.

Assertions are disabled in this repo (`docs.assertionsFile` is `null`), so no audit statement
applies.
