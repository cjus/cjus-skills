# bookcraft: a primer profile, subject first, selected and sized to a reading budget

## Overview

`/createbook` was built for document-faithful handbooks: "a guide to a set of resources first, and to its subject second". Its commonest request is different: a small book that gets a reader up to speed on a subject, from context given at creation time. This PR adds a `primer` profile for that goal and makes it the default for new books. `guide` and `narration` stay, described now as the handbook profiles.

The primer's rules come from a hand-built trial: an eight-chapter primer from a 53,000-word technical book, with one chapter also written under the current rules as a control. On the same chapter the primer version was 30% shorter, and no paragraph ran 80 to 90 words, against 73% in the control. It showed the subject running where the control described it. Two test readers answered all nine comprehension questions from the trial book alone. `NOTES.md § The primer profile, 2026-11-18` has the figures.

**This branch is stacked on the #130 branch** and its PR targets that branch, so it should merge after #130's PR.

## Key changes

- `skills/createbook/reference/primer.md` (new): the whole rule set for a primer chapter, read instead of `chapter-prose.md`.
- `skills/createbook/scripts/check-book.sh`:
  - accepts `primer` and closes its chapters on `## Sources and further reading`;
  - allows any number of sections, H3 and appendices;
  - reports a paragraph past 100 words and never fails one;
  - adds a clustering report under every profile.
- `skills/createbook/scripts/check-provenance.sh`: the mark walk stops at the primer's closing section.
- `skills/createbook/SKILL.md`:
  - the profile table and the new default;
  - a new § Under the primer profile, with selection, budget, outline rows, assigned openings, conventions and numbering;
  - primer-aware prompt items, file format and tagging default.
- `skills/updatebook/SKILL.md`: a primer is edited under `primer.md` alone.
- `skills/createbook/fixtures/primer` and `fixtures/primer-failures` (new), with manifest rows in `scripts/test-fixtures.sh`.
- `check-book.sh` also requires a mark on a unit above a primer chapter's first paragraph, since a primer has no header table there to exempt.
- `README.md` "Three profiles", `NOTES.md`, plugin version 1.18.0.

## Code examples

`plugins/bookcraft/skills/createbook/scripts/check-book.sh`, the profile and its settings:

```bash
case "$declared_profile" in
  ""|narration) profile=narration ;;
  guide) profile=guide ;;
  primer) profile=primer ;;
  ...
esac
if [ "$profile" = primer ]; then
  sugg_heading="## Sources and further reading"
  para_max=100
fi
```

The clustering report, run for every chapter:

```bash
if [ "$n_paras" -ge 8 ] && [ $((n_near * 100)) -ge $((n_paras * 40)) ]; then
  report "$base: $n_near of $n_paras paragraphs run $near_at words or more, within reach of the $para_max-word limit; a limit most paragraphs reach is being used as a target"
fi
```

A primer outline row, from `createbook/SKILL.md § Under the primer profile`:

```text
- Opens with: the move the chapter's first paragraph makes ... Neighbouring chapters open
  differently, and no chapter opens by summarising earlier ones.
```

## Plan alignment

Every checklist item in the ticket is done.

- **Selection and size:** a teach, mention and leave table, a reading budget defaulting to 60 to 90 minutes, and a learner's order.
- **Length:** ceilings with no floor or target, plus the clustering report.
- **Explanation:** problem first, a device per concept, teach or point.
- **Outline decisions:** assigned openings, book-wide conventions, numbering for a book drawn from a larger one, and each result owned by one chapter.

Decisions the ticket left open:

- **A standalone rule file**, not a third layer on `chapter-prose.md`. A primer overrides nearly every core rule, and an agent handed both follows whichever it read at more length.
- **The clustering report runs under every profile**, since its evidence came from guide books. Like every report it never fails a run, and no existing fixture trips it.
- **A primer is untagged unless the operator asks**, because it is read, not cited by paragraph.

The research stage, verified outside citations and the reader-test loop are the next two tickets. They are not in this PR.

## Testing

- `plugins/bookcraft/scripts/test-fixtures.sh --strict`: 23 passed, 0 failed, 0 skipped.
- `fixtures/primer-failures` fails on exactly its three faults: an H4, an unmarked fenced block above the first paragraph, and a closing section with no list.
- `fixtures/primer` row asserts:
  - the profile line;
  - a pass;
  - the 102-word paragraph reported as past the ceiling;
  - the clustering report on chapter 2 (6 of 8 paragraphs at 85 words or more);
  - exactly two reports;
  - that chapter 1, nine paragraphs with one long, draws no clustering report;
  - and that the appendix, allowed under primer, draws no failure.
- Every existing fixture passes unchanged, including `guide-reports`, whose exact report count of 7 shows the new report adds nothing to a guide book that does not cluster.
- `check-provenance.sh` on `fixtures/primer` runs clean apart from the expected note that the fixture declares no `sources` map.

## Impact assessment

Twenty files including this plan folder and its two reviews, about 970 lines added and 48 removed. No dependencies change.

- A new book now gets `"profile": "primer"` unless the operator chooses a handbook profile at the gate.
- Existing books are read exactly as before, since an absent profile still reads as `narration`.
- The clustering report can add a `REPORT` line to an existing book whose paragraphs crowd its limit. It never fails a run.
- `check-book.sh` refuses a book that declares `"profile": "primer"` with `"overview": true`, as it refuses a guide with `"overview": false`.

## Deferred work

None.
