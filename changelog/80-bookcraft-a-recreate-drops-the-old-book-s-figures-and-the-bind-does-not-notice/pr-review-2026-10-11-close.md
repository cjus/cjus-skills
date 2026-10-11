## PR review: bookcraft: a recreate drops the old book's figures, and the bind does not notice

Close-gate review for `/pr:close`, 2026-10-11. Draft PR #81, ticket
`80-bookcraft-a-recreate-drops-the-old-book-s-figures-and-the-bind-does-not-notice`, base `main`,
at `030fead` (1 commit).

This is a re-review. It builds on the pre-test review in the same folder,
`pr-review-2026-10-11.md` (APPROVE, no critical or important findings, four suggestions, two
DROP items), and does not redo that review's exploration. Per the scope contract it reviews the
delta since then, confirms or overturns the earlier conclusions, and checks the new
`pr-summary-2026-10-11.md`, which becomes the PR body. The three operator rulings in
`PLAN.md § Open Questions` are settled and are not reopened: figures are redrawn, with the old
`diagrams/README.md` handed to the figure pass as candidates; slides are copied; the
`check-book.sh` REVIEW line is not built.

### Summary

The branch makes `/createbook --recreate` count the old book's figures and slides at its gate,
copy the `slide_figures` folder, and name `/makebook`'s figure pass as due, with the old README
as candidates. `build-book.py` warns when a folder set up as a book (a `book.json` or an
`assertions.json`) has no `diagrams/README.md`. Since the pre-test review, only plan-folder files
changed: `PLAN.md` gained a `## Deferred` section and `pr-summary-2026-10-11.md` was written. No
code, skill prose or fixture changed.

### What changed since the pre-test review

- `HEAD` is still `030fead`. `git status` shows only the three plan-folder entries: `PLAN.md`
  modified, and `pr-review-2026-10-11.md` and `pr-summary-2026-10-11.md` untracked. So every
  conclusion the pre-test review drew from the code still applies to the code as it stands.
- `PLAN.md`: the diff only appends `## Deferred` at the end. The Overview and the objective are
  untouched, which the plan's own rule requires ("newly discovered work goes under
  `## Deferred`, never as new scope"). The two entries match the pre-test review's two DROP items
  word for word in substance, and both carry their DROP mark forward.
- `pr-summary-2026-10-11.md`: new. Checked claim by claim below.

### Verification done for this review

- `gh pr checks 81`: all five jobs pass, `fixtures` on macos-latest and ubuntu-latest and three
  `iac` jobs. The fixture suite in CI is the one that runs `bind/run.sh`, so the three new
  assertions are green at `HEAD` on both platforms. I did not re-run the local suite. The code
  has not changed since the pre-test review ran it (18 of 18, and 22 of 22 in `bind/run.sh`).
- Closing keywords in `pr-summary-2026-10-11.md`: none. The summary contains none of close,
  closes, closed, fix, fixes, fixed, resolve, resolves or resolved in any form, so no keyword can
  precede an issue reference. The only `#N` reference in it is `PR #81`, on line 126. The PR
  title's `[#80]` prefix links the ticket without closing it.
- Repo conventions for `changelog/**` artifacts, applied to the summary and the new `PLAN.md`
  section: no `org/repo#N` cross-references, no em dashes, no attribution lines, and the
  hostname sweep the conventions call for found 0 hits in either file.
- Spot-checked each of the pre-test review's four suggestions against the source (below).

### Pre-test review: conclusions confirmed

| Pre-test conclusion | Re-check | Holds? |
|---|---|---|
| Every `PLAN.md § Plan` item delivered, in the ruled form | Eight checkboxes, all `[x]`. The diff matches each, as tabulated there | Yes |
| Suggestion 1: the warning prints under the `slides:` heading | `build-book.py`, `main`: the `figure_record_missing` block sits directly after the slides block's last `if blind:` and before `if glossary:` | Yes |
| Suggestion 2: the gate counts images the old chapters reference, while makebook reads the old README | `createbook/SKILL.md` gate bullet 4 says "Count every image an old chapter references". The `makebook/SKILL.md` paragraph says "Each figure it records" | Yes |
| Suggestion 3: the `assertions.json` clause has no test | The guide has a `book.json` and no `assertions.json`. `appendix-slug` has neither. No other bind asserts on the warning | Yes |
| Suggestion 4: "copy that folder into the new one" can be read as changing the path | The step 4 row text is unchanged | Yes |
| Both deferred items are DROP | Neither has a symptom that has occurred or an occasion that would bring it up | Yes |

I found nothing to overturn. I looked again at the warning's scoping and at `src`
(`build-book.py:3988`, `args.folder.expanduser().resolve()`). No `book.json` key relocates
`diagrams/`: the only `diagrams` paths in the script are `FIGURE_RECORD` and the slide-prefix
docstring. So the fixed `diagrams/README.md` path cannot miss a book whose figures live
elsewhere. That closes the one scoping question the pre-test review did not ask.

### pr-summary accuracy

| Claim in the summary | Against the diff | Accurate? |
|---|---|---|
| Ticket measurement: eight figures across eight chapters, on 1.11.0 | Matches `PLAN.md § About Ticket` and `NOTES.md § Figures across a recreate` | Yes |
| Step 4 copies the `slide_figures` folder, and a new step 9 row | Steps 5, 6 and 8 have no rows. 9 is a new row | Yes |
| The gate grows from three items to five | "add three things" became "add five things", and two bullets were added | Yes |
| makebook step 7 names both counts, and the paragraph names the warning | Both are in the `makebook/SKILL.md` diff | Yes |
| The code excerpts | `FIGURE_RECORD`, `figure_record_missing` and the first `print` match the source. Elisions are marked `...` | Yes |
| Eight checkboxes done. Copying ruled as "redraw" | Matches `PLAN.md` | Yes |
| Three new `bind/run.sh` assertions, as described | Matches the three `report` pairs | Yes |
| Two mutations each fail exactly one new assertion | Never-fires fails only the no-record guide bind. Unscoped fails only `appendix-slug`, since the first guide bind has a README | Yes, by reasoning |
| 18 of 18 locally, 22 of 22. Citations resolve | From the pre-test run. Code unchanged | Yes |
| CI passes all five jobs, with fixtures on macOS and Ubuntu | `gh pr checks 81` | Yes |
| `check-provenance.sh`'s premise sweep "finds nothing" in the guide's README | See Suggestion 2 | Imprecise |
| 10 files changed, 383 added, 18 removed | True at `030fead`. Will drift (Suggestion 1) | Yes, for now |
| Breaking changes: none. The warning never fails a bind | The block only `print`s, and the return code is unaffected | Yes |
| Deferred work and the four declined suggestions | Match `PLAN.md § Deferred` and the pre-test review | Yes |

### What is working well

- **The summary reads the operator rulings as rulings.** It says what was decided and why, in
  the same three reasons `NOTES.md` records. It does not restate the plan's checkbox wording as
  if the copy option were still open.
- **The summary is honest about what the branch did not take.** It lists all four declined
  suggestions by name under Deferred work, so a reader of the merged PR sees the known gaps.
  The usual summary leaves them out.
- **The `## Deferred` section keeps the plan's discipline.** It is appended, not woven into the
  Plan, and each entry keeps its DROP mark, so `/pr:close` triage does not have to re-price
  them.
- **The PR body cannot close the ticket by accident.** The summary uses no closing keyword at
  all, rather than relying on phrasing to avoid one.

### Issues found

#### Critical

None.

#### Important

None.

#### Suggestions

**1. The diff-size line in Impact assessment will be stale once close commits the plan folder**

Location: `pr-summary-2026-10-11.md`, § Impact assessment, first bullet.

**What I see:** "10 files changed, 383 lines added and 18 removed. Two of those files are the
branch's `PLAN.md` and `CHANGELOG.md`."

**The risk:** the close commits the plan-folder artifacts: the `PLAN.md` `## Deferred` lines,
this summary, and both reviews. The PR's own file count then reads 13 and the line count rises
by several hundred, so the body disagrees with the Files tab on the day it merges. This is
cosmetic, which is why it is only a suggestion.

**Suggested fix:** state the count that will not move: "8 files outside the plan folder, 176
lines added and 18 removed", or keep the current figures and add "at `030fead`".

**Learning note:** a document that ships in the same change it describes should not quote a
measurement of that change, because writing it changes the number.

**2. The `check-provenance.sh` edge-case line gives the wrong reason**

Location: `pr-summary-2026-10-11.md`, § Testing, Edge cases considered, last bullet.

**What I see:** "`check-provenance.sh`'s premise sweep finds nothing in it."

**The risk:** the sweep does read `diagrams/README.md` (`check-provenance.sh`, the function
collecting the files a superseded premise can survive in). It finds nothing on the guide only
because no fixture runs `check-provenance.sh` on the guide, and the guide has no
`assertions.json` to sweep. The pre-test review stated it that way. As written, the line
implies the README was swept and came back clean, which a later maintainer might rely on when
giving the guide an `assertions.json`.

**Suggested fix:** "and no fixture runs `check-provenance.sh` on the guide, which has no
`assertions.json` to sweep."

**Learning note:** "the check found nothing" and "the check never ran" are different evidence.
Say which one you have.

The pre-test review's four code suggestions still stand as written there. The summary records
that the branch declines them, and that is a legitimate choice for optional items.

#### Deferred to follow-up

These do not affect the verdict. Both are carried from the pre-test review unchanged, already
recorded in `PLAN.md § Deferred`, and marked DROP:

- DROP. A `slide_figures` value of plain `diagrams` would make recreate step 4 copy the old
  figures and README. `createbook/SKILL.md § Recreating a book`, step 4. Speculative, because the
  value is documented only as `diagrams/slides`. Theme: recreate slide copy.
- DROP. The fixtures paragraph in `plugins/bookcraft/README.md` does not list the three new
  `bind/run.sh` assertions. It lagged before this branch. Theme: fixture docs.

Nothing new is deferred by this review.

### Questions

- The pre-test review's open question still has no recorded answer: after a recreate, who
  places the copied slides in the new chapters? It is not a finding, because slide placement
  predates the branch. If the operator expects the consuming project to place them, one clause
  in the summary's Overview would stop a reader from taking "the recreate copies them" to mean
  they reappear in the bound book.

### Verdict

VERDICT: APPROVE

The code is unchanged since the pre-test APPROVE, CI is green at `HEAD`, and the plan's
Deferred section is faithful. The pr-summary is accurate and contains no closing keyword.
Its two wording suggestions are optional and can be taken or left before the merge.
