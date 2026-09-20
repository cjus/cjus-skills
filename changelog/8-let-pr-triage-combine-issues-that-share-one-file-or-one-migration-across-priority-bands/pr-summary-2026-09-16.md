# Let /pr:triage combine issues that share one file or one migration across priority bands

## Overview

`/pr:triage` step 5 refused to consolidate two issues whose work lands in the same file or the
same migration when they carried different `priority:` labels. That bar is right for issues that
merely share a theme and wrong for work that cannot be split, where it costs a full duplicated
lifecycle — a branch, a worktree, a plan folder, a review gate, the close artifacts and a
continuity entry — to deliver what is often a single extra line.

This PR splits the consolidation bar by **strength** rather than loosening any clause. Clause 2
becomes the spine of step 5: every group clears it, and its strength decides how clauses 1 and 3
apply. A **strict** path covers members whose changes land in the same file or the same
migration — clause 3 is replaced by "the group takes the highest member's band", clause 1 is
implied, and two members suffice. A **loose** path covers everything else that still clears clause 2,
and keeps today's rule exactly. The report now names which strength applied and every member the group promoted.

## Key changes

| File | Change |
|---|---|
| `plugins/pr/skills/triage/SKILL.md` | § Step 5 restructured around the strict/loose fork; § Step 6's Combine block gains the strength and a `Promotes:` line; § Step 7c's five band-dependent passages and its confirmation prompt reconciled; § What this skill never does and § Common mistakes updated |
| `plugins/pr/reference/ticketing.md` | The one paragraph stating the consolidation rationale for the whole plugin, outside the skill |

## Code examples

**The fork, at `plugins/pr/skills/triage/SKILL.md` § Step 5.** Strict is a positive test and
loose is its explicit negation, so no group satisfies both and none satisfies neither while
still clearing clause 2:

```markdown
### Strict clause 2: the members' changes land in the same file or the same migration

- **Clause 3 is replaced.** The group takes the **highest** member's band — high, then medium,
  then low — and **the report names each promoted member explicitly** ...
- **Clause 1 is implied and not separately required.** ...
- **Two members suffice.** ...

### Loose clause 2: clause 2 holds, but across more than one file

Doing any one member still puts you inside files the others name, yet no single file or
migration is common to them. **Clauses 1 and 3 both apply exactly as written above, unchanged.**
```

This shape matters more than the wording: an agent **cannot** route a same-file cross-band group
to loose in order to refuse it, because loose's own definition excludes it. The bug this ticket
is about is closed structurally rather than by exhortation.

**The sentence that had to stop being universal, in § Step 7c.** Before:

```markdown
That is the correct outcome rather than a hole: **consolidation changes how work is grouped,
never whether it is scheduled.**
```

After — the claim is scoped and the exception is named, because a low+high strict group enters
at high and the low member crosses from outside `/pr:next`'s queue to inside it:

```markdown
**On the loose path, consolidation changes how work is grouped, never whether it is scheduled.**
The strict path is the deliberate exception. ... **This is the one case where consolidation does
change whether work is scheduled**, it is confined to members sharing one file or one migration,
and the report names the promoted member so it is never discovered after the fact.
```

**The report, in § Step 6**, so a reader can tell why a group formed:

```markdown
- **Group: {one-line name for the shared work}** ({priority band}) · {strict | loose}
  Members: #NN, #NN, #NN
  **One changeset:** {the material all of them sit in; on strict, the file or the migration by name}
  **One occasion:** {the event that picks all of them up}
  **Promotes:** #NN {priority:medium} → {priority:high}
```

## Plan alignment

All six phases and all four ticket checkboxes completed as planned.

**Three items landed beyond the phase list, each a consequence of the fixed objective rather
than an addition to it:**

- **`plugins/pr/reference/ticketing.md:37`** carried the combining rationale outside the skill
  ("the combining bar required them to agree"). Phase 5 was scoped to § What this skill never
  does; leaving this would ship a reference contradicting its own skill.
- **The `AskUserQuestion` confirmation in § Step 7c now names the promotion.** A strict group
  carries two decisions in one approval — that the group is real, and that the lower member
  should be scheduled at the higher band.
- **§ Common mistakes gained "Reading a shared directory as the same file."** This is the guard
  that keeps the row-3 decision below from eroding.

**Two operator decisions shaped the result:**

1. **The ticket's group 3 (#23, #24, #34) stays refused, and that is intended.** Those members
   share a two-file directory, which is neither one file nor one migration, so they fall to the
   loose path and fail clause 3 on medium/medium/low. The change reaches two of the ticket's
   three motivating groups by design.
2. **Loose is today's clause 2 restated genuinely verbatim.** Phase 3 called for a verbatim
   restatement while the ticket described loose as members that "share a feature area but sit in
   different files" — two different edits, since today's clause 2 is already file-shaped and
   grants no different-files permission to restate. The narrower reading shipped, keeping the
   overview's promise to split the bar rather than loosen any clause.

Nothing was deferred or descoped.

## Testing

This branch changes skill instruction prose, which an LLM executes as procedure. There are no
automated suites: `.claude/pr-config.json` configures no `checks`, and the repo has no
`.github/workflows/` directory, so no CI reports on it.

**Verification was by trace**, reading § Step 5 through § Step 7c end to end against the three
groups the ticket recorded as refused in that downstream repo:

| Group | Shared material | Bands | Strength | Outcome |
|---|---|---|---|---|
| #69, #71 | one `revoke` migration | high, medium | strict | **forms** at high; report names #71 promoted medium→high |
| #71, #82 | one `revoke` migration | medium, high | strict | **forms** at high; report names #71 promoted medium→high |
| #23, #24, #34 | a two-file directory | medium, medium, low | loose | **still refused** on clause 3, as intended |

**To verify by hand:** run `/pr:triage` against a queue containing two issues whose work lands in
one file under different bands. It should now propose the group, label it `strict`, and name the
promoted member with its prior band. Then check that two issues merely sharing a theme across
different files under different bands are still refused.

**Edge cases considered:** an unlabelled issue on the strict path (still refused — it was never
ranked, so there is nothing to promote it from); a strict group whose members already agree (a
no-op, and the report says nothing about promotion); a strict group of three promoting two
members (the combined issue's `Band:` line takes one clause per promoted member); and the band
ordering's low end, which nothing in the plugin had written down before this branch
(`next/SKILL.md:61` stated only that high outranks medium).

## Impact assessment

- **5 files changed, 308 insertions, 15 deletions** across 4 commits.
- Two of those files are source: `plugins/pr/skills/triage/SKILL.md` (+46/−14) and
  `plugins/pr/reference/ticketing.md` (one paragraph). The rest are this branch's own plan
  folder.
- **No dependency changes.** No code, no schema, no migration.
- **No breaking change.** Loose-path behaviour is byte-identical in effect to today's rule, so
  any group that combined before still combines on the same terms. The change is strictly
  additive: groups that were refused for crossing bands while sharing one file now form.
- **Behavioural note for operators:** a strict group can now raise a member's effective band,
  which moves it in `/pr:next`'s ranking. This is surfaced at four points — step 5's replacement
  clause, step 6's `Promotes:` line, the `AskUserQuestion` confirmation, and the combined issue's
  `Band:` line.

## Deferred work

None. `PLAN.md` has no `## Deferred` section, and the review's deferred block was empty — the
reviewer looked for pre-existing defects adjacent to the diff and found nothing clearing the
TICKET bar.

One observation was recorded in `pr-review-2026-09-16.md` and deliberately not acted on: a
two-member **loose** group is close to a null set, since if doing A puts you inside a file B
names, that file is common to both and the group is strict. Loose is therefore really about
three or more members with pairwise but not global overlap. Harmless, and writing it down would
have been new scope.

## Assertion audit

`docs.assertionsFile` is `null` in `.claude/pr-config.json`. Assertions are **disabled** for this
repo, so no audit was performed and no entry was added.
