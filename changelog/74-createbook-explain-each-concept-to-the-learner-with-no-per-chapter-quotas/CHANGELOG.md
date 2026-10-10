# createbook: explain each concept to the learner, with no per-chapter quotas

Start date: 2026-10-09 11:09:51 MDT

`/createbook` chapters written as directions to an explainer leave a reader who is learning the
subject without the explanation. This branch makes every chapter explain each concept directly
to the learner, after `qe`'s method, and removes the per-chapter quotas on the devices that
carry an explanation.

## Changes

### 2026-10-09 11:32:37 MDT: Phases 1 to 9, the rules

The operator settled the four open questions first (`PLAN.md § Open Questions`): six new terms
becomes a report, likely questions go in the prose, the four steps go in the core for both
profiles, and Phase 10 runs before close.

- `chapter-prose.md` drops the per-chapter quotas on wrong models, analogies, numbers, hedges and
  the simplification flag (§ Explaining devices have no quota keeps each device's form). It
  adds the explanation, the knowledge boundary, the four steps with the why required, facts
  against concepts, and likely questions. It also adds two before-and-after pairs.
- `guide.md`'s teaching shape loses the lesson script and gains a direction-to-explanation pair.
  § The wrong model loses its per-chapter cap.
- `SKILL.md` gains the knowledge boundary, the coverage ledger and Teaches rows, the gate's
  flags, the sample stop, and § 5's new prompt items.
- `NOTES.md` gains § Explaining to the learner, 2026-10-09.
- The `updatebook`, README and version changes (1.10.0 to 1.11.0) follow.

Verified: 203 citations resolve (190 on `main`), both rule files are within the stops with no
em dash, and the fixtures pass 18 of 18.

### 2026-10-09 11:51:35 MDT: the pre-test review's findings, fixed

Draft PR #75 opened. `pr-review-2026-10-09.md` approved with three important findings, all
fixed:

- guide openings leave the fluent side unglossed
- the sample stop moved to the end of § 4, after `book.json` exists
- likely questions stop at the book's edge without adding to the concept list

Its smaller suggestions were taken too. Its deferred items went to `PLAN.md § Deferred`.

### 2026-10-09 12:06:56 MDT: Phase 10, the blind set ready for scoring

Chapter agents redrafted one teaching chapter and one administrative chapter of the reference
teaching guide under these rules (at `2463162`). They had the same outline rows, sources and
entries as the current versions, and never saw them. Both redrafts pass the book's checkers.

The four versions were blinded A to D on a branch in the source repo, which this repo does not
name. The agents reported ten and thirteen new terms against six, and outline rows that still
capped numbers.

### 2026-10-09 19:11:37 MDT: Phase 10 settled by the operator's ruling

The operator spot-checked the four versions, did not score them blind, and ruled the revised
rules the default. `NOTES.md` records that as a judgment, not a blind verdict, with the
measurements. `guide.md` needed no change. The blind set stays scorable on its branch.

### 2026-10-09 19:17:39 MDT: close

`pr-review-2026-10-09-close.md` approved. The summary's overview stopped calling the blind
comparison the acceptance test, and `NOTES.md § The handoff chain leaves the guide path` now
says the comparison it promised was prepared and not run.
