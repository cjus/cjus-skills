# bookcraft: a recreate drops the old book's figures, and the bind does not notice

## Overview

Before this change, `/createbook --recreate` wrote every chapter fresh into a new folder and never
mentioned `diagrams/`. Every figure the old book placed, and the `diagrams/README.md` recording
why, stayed behind in the old folder. `/makebook` then bound the new book without a warning,
because `build-book.py` never read that README. The ticket measured it on 1.11.0: a guide book
with eight figures across eight chapters was recreated and bound with none of them. The bind
ran clean, and the loss was found only by a reader comparing the two editions.

After this change, a recreate accounts for the old figures without carrying them. The operator
ruled that figures are **redrawn, never copied**, because each old figure shows the old worked
examples and its README record cites the old paragraph tags. The recreate counts the old
figures at its gate and names `/makebook`'s figure pass as due. That pass takes the old README as
its candidates, and records each one as placed again or passed over with the reason. Slides
are source material rather than figures drawn from the prose, so the recreate copies them. The
bind now warns when a folder set up as a book has no `diagrams/README.md`, which is the only
trace a figure pass leaves.

## Key changes

- **`plugins/bookcraft/skills/createbook/SKILL.md` § Recreating a book.**
  - Step 4 copies the folder `book.json`'s `slide_figures` names.
  - A new step 9 row names the figure pass as due.
  - The gate grows from three items to five: how many figures the old book placed (with what
    its README records), and how many slides will be copied.
  - Two new paragraphs say why a recreate carries no figure, and that the old README goes to the
    figure pass as candidates while the operator keeps the old folder.
  - The § Notes line about figures landing in `diagrams/` now covers the recreate case.
- **`plugins/bookcraft/skills/makebook/SKILL.md` § Deciding where a figure helps.**
  - A book replacing an earlier edition reads the old README as candidates and redraws any
    figure it places again from the new prose.
  - The report gives the candidates placed again and passed over, which must add up to the
    candidate count. Procedure step 7 names both counts.
  - A book that rightly has no figures still writes the README, and the paragraph names the
    warning.
- **`plugins/bookcraft/skills/makebook/scripts/build-book.py`.** `FIGURE_RECORD` and
  `figure_record_missing`, and a warning in the bind report.
- **`plugins/bookcraft/skills/makebook/fixtures/bind/run.sh`.** Three new assertions on the warning.
- **`plugins/bookcraft/skills/createbook/fixtures/guide/diagrams/README.md`** (new). The guide
  fixture's figure record, which `bind/run.sh` binds with and then without.
- **`plugins/bookcraft/skills/createbook/NOTES.md`.** A new section, § Figures across a recreate,
  2026-10-10, recording the measurement, the operator's rulings and their reasons.
- **`plugins/bookcraft/README.md`.**
  - The folder layout lists `diagrams/README.md`.
  - The `--recreate` row says slides are copied and figures redrawn.
  - The Figures section explains the record and the warning.
  - The troubleshooting table gains a row for the warning.
- **`plugins/bookcraft/.claude-plugin/plugin.json`.** bookcraft 1.11.0 to 1.12.0.

## Code examples

The scope of the warning, `plugins/bookcraft/skills/makebook/scripts/build-book.py`:

```python
FIGURE_RECORD = "diagrams/README.md"


def figure_record_missing(src: Path) -> bool:
    """True when a folder set up as a book has no record of its figure pass.
    ..."""
    if (src / FIGURE_RECORD).is_file():
        return False
    return (src / "book.json").is_file() or (src / "assertions.json").is_file()
```

The warning in the bind report, in the same file:

```python
    if figure_record_missing(src):
        print(f"  warning: no {FIGURE_RECORD} in the book folder, so this "
              f"book's figure decisions were never recorded "
              f"({len(figures)} figure(s) placed).")
```

The recreate's step table, `plugins/bookcraft/skills/createbook/SKILL.md` § Recreating a book:

```markdown
| 4 | Start `book.json` from the old one. ... **Where it names a `slide_figures` folder, copy
      that folder into the new one unchanged**, or the key names a folder that is not there ... |
| 9 | Name `/makebook`'s figure pass as due before the new book is bound, with the old
      `diagrams/README.md` as its candidates and the figure count from the gate (below) |
```

## Plan alignment

Every one of the plan's eight checkboxes is done.

- **Recreate, five items: done as planned.** For the item that left copying open, the operator
  went further than either option the review on the ticket weighed. Figures are not copied, not
  even under a "re-check these" heading: every figure is redrawn, with the old README as its
  candidates. A copied README would also have silenced the new bind warning before the figure
  pass had run.
- **Bind: done as planned**, scoped to folders with a `book.json` or an `assertions.json`, as
  the review on the ticket proposed.
- **`check-book.sh` REVIEW line: considered and not built, by the operator's ruling.**
  - `check-book.sh` runs at `/createbook`'s step 7, before `/makebook`'s figure pass, so it
    would name every old figure on every recreate.
  - Both inputs offered for it, a flag or a `book.json` field, point outside the book folder at
    a folder the operator later deletes.
  - The measured failure, a figure pass that never ran, is caught by the bind warning. The
    unmeasured one, a pass that forgets a candidate, shows in `/makebook`'s report as counts
    that do not add up.
  - The review on the ticket said `check-book.sh` already reads `diagrams/README.md`. It does
    not; `check-provenance.sh` does.
- **Release: done.** Version 1.12.0, with the README updated.

**One correction made during the work.** The plan's CI-fixture question was first answered from
three fixture books, all with no `book.json`. `bind/run.sh` also binds
`createbook/fixtures/guide` twice, and that book has a `book.json` and a figure, so the warning
would have fired there. The guide now carries its own `diagrams/README.md`.

## Testing

**Automated.**

- `bind/run.sh` gains three assertions:
  - the guide, bound with its README, does not warn;
  - the second guide bind removes the README and must warn, counting 1 figure;
  - `appendix-slug`, a folder with no `book.json`, must not warn.
- Two mutations of `build-book.py` each fail exactly one of the new assertions: a warning that
  never fires, and one with no scoping.
- `test-fixtures.sh --strict` passes 18 of 18 locally, and `bind/run.sh` passes 22 of 22.
- `scripts/check-citations.py` reports every citation resolving.
- CI on PR #81 passes all five jobs, including the fixture suite on macOS and Ubuntu.

**By hand.**

- Bind a book folder that has a `book.json` and no `diagrams/README.md`, and read the warning
  and its figure count.
- Add a README and bind again: the warning is gone.
- Bind a plain folder of notes: no warning.
- Read `createbook/SKILL.md` § Recreating a book and `makebook/SKILL.md` § Deciding where a
  figure helps together, as an agent doing a recreate would.

**Edge cases considered.**

- A book that rightly has no figures still writes the README, which silences the warning
  legitimately.
- A plain folder of notes is never asked for one.
- The old book may have no README at all, and then the candidates are the figures the gate
  counted.
- Adding `diagrams/README.md` to the shared guide fixture changes no other fixture's result. The
  suite runs only `check-book.sh` on the guide, and that script reads markdown one level deep,
  so it never sees `diagrams/`.

## Impact assessment

- Outside the branch's plan folder, 8 files changed, with 176 lines added and 18 removed.
- Dependencies: no new dependency.
- Breaking changes: none. The warning is printed and never fails a bind. It fires on a book
  folder that carries a `book.json` or an `assertions.json` and no `diagrams/README.md`, which
  includes every such book bound before this change, until its figure pass writes the record.
- `/createbook`, `/makebook` and the README change in prose only, and no script's interface
  changes.

## Deferred work

The pre-test review named two low-value items, both under `PLAN.md § Deferred` and marked to
drop at triage:

- A `slide_figures` value of plain `diagrams` would make the recreate's slide copy carry the old
  figures and README. The value is undocumented, so the risk is speculative.
- The fixtures paragraph in `plugins/bookcraft/README.md` does not list the three new
  `bind/run.sh` assertions. That paragraph already lagged behind the fixtures before this
  branch.

The same review also made four optional suggestions, which this branch does not take:

- The warning prints under the `slides:` heading of the bind report.
- The two skills name different numbers as the candidate count: the gate counts images the old
  chapters reference, and `/makebook` reads the old README.
- The `assertions.json` half of the warning's scope has no test.
- Step 4's slide-copy wording could say outright that the folder keeps its path.

Assertions file: not configured in this repo, so there is no audit.
