# Code review — 2026-09-16 (close gate)

**Re-review of the delta.** `pr-review-2026-09-16.md` (pre-test) recorded eight findings, all
folded into `8b10a77`. This pass reviews `8b10a77` and `cd264cc` plus the branch's artifacts,
and re-checks whether each earlier fix actually holds. Prior findings are not re-raised.

## PR review: Let /pr:triage combine issues that share one file or one migration across priority bands

### Summary

Splits `/pr:triage` step 5's consolidation bar into a strict path (members' changes land in one
file or one migration: clause 3 replaced by the highest member's band, clause 1 implied, two
members sufficient) and a loose path that restates today's rule verbatim. Step 6's Combine
block, step 7c's five band-dependent passages and its confirmation, § What this skill never
does, § Common mistakes and `reference/ticketing.md:37` are reconciled to the fork. Two source
files change, +46/−14 and +1/−1; the rest is the branch's own plan folder.

### Do the earlier fixes hold?

| Prior # | Fix shipped in `8b10a77` | Holds? |
|---|---|---|
| 🟡 1 | No-label rule re-grounded on "never ranked, nothing to promote *from*" | **Yes.** `next/SKILL.md:45` and `ticketing.md:29` both use the same laundering argument, so the cross-reference is real rather than asserted. |
| 🟡 2 | Loose-path prohibition re-based on chosen-by-the-skill vs forced-by-the-material | **Substantively yes, citation no.** See 🟢 1 below: the rule now carries its own reason, but it points at a section that draws a different line. |
| 🟡 3 | Inline *(implied…)* / *(replaced…)* tags on clauses 1 and 3 | **Yes.** A partial reader now meets the fork at the clause itself. |
| 🟢 4 | "strength changes only how clauses 1 and 3 apply and how many members are worth grouping"; "Name the strength as part of forming the group" | **Yes.** Both the contradiction and the non-executable ordering instruction are gone. |
| 🟢 5 | **On this path,** prefixed to the two-member caution | **Yes.** |
| 🟢 6 | `Band:` line made repeatable, one clause per promoted member | **Yes.** Matches step 6's "one line per member whose band the group raised". |
| ❓ 7 | Ordering stated: high, then medium, then low | **Yes**, and it is complete: `init/SKILL.md:107` creates exactly those three labels, so no band is unranked. |
| ❓ 8 | Shared material "common to every member, not merely to some pair" | **Yes for strict**; the sentence's second half over-reaches on where the demoted group lands. See 🟢 2. |

### What is working well

- **The two-decision problem in 7c is genuinely solved, not papered over.** The confirmation now
  names the promoted member and both bands *before* the write, which is the only point where an
  operator can still refuse a scheduling change that `/pr:next` will act on. Naming it as "a
  second decision riding inside the same approval" is the right framing: the alternative was an
  operator approving a grouping and receiving a re-prioritization.
- **`Never changes a priority: label` was rewritten rather than left literally-true.** This is
  the hardest kind of honesty in instruction prose: the sentence survived unchanged in letter,
  and the branch still spent four sentences explaining why its intent moved. The closing clause
  ("If you find yourself wanting to edit an existing issue's label, the answer is still no")
  keeps the operative prohibition where a skimmer will hit it.
- **`ticketing.md:37` was in scope and was taken.** A shared reference contradicting its own
  skill is the failure mode that outlives the branch, because the next reader arrives through
  the reference rather than the skill. Catching it in Phase 1 rather than review is the reason
  this PR has no critical findings.
- **The row-3 guard is load-bearing and was added deliberately.** "Reading a shared directory as
  the same file" in § Common mistakes is what keeps the strict definition from eroding on the
  first run that wants it to, and it names the failure in the exact words an eroding agent would
  use.
- **No surviving statement of the old rule.** Re-verified by grep across `plugins/`, `README.md`
  and `docs`: the only consolidation-band sentence outside the skill is the rewritten
  `ticketing.md:37`.
- **Artifact discipline.** `cd264cc` correcting a stale commit SHA in the review record is a
  small thing that keeps the folder trustworthy as a record.

### Issues found

#### Critical

None.

#### Important

None. Nothing in `8b10a77` regresses the loose path or the objective.

#### Suggestions

🟢 **7c's loose-path prohibition cites a section that draws a different line**

📍 Location: `plugins/pr/skills/triage/SKILL.md:296`

**What I see:**

```markdown
**Forcing high on the loose path** would be a re-prioritization this skill chose rather than one
the material forced, which is the line § What this skill never does draws.
```

§ What this skill never does now reads: the group's band "lands on a **newly created** issue…
rather than a relabelling this skill performs on an existing issue." The line that section
draws is **existing issue versus newly created issue**, not **chosen versus forced**. The
chosen-versus-forced line is drawn in the very next paragraph (`:298`).

**The risk:**

This is the same shape as prior finding 2, one indirection deeper. An agent that follows the
pointer to check whether forcing high on a loose group is forbidden reads a section whose test
is "are you editing an existing label?" — and forcing high on a *newly created* consolidation
issue passes that test. The pointer therefore fails to support the prohibition it is offered
for. The prohibition itself still holds, because the sentence's own opening clause carries it
and step 5's loose section independently pins clauses 1 and 3 "exactly as written above,
unchanged", so this is a weak citation rather than a live hole.

**Suggested fix:**

```markdown
**Forcing high on the loose path** would be a re-prioritization this skill chose rather than one
the material forced, which is the line the next paragraph draws.
```

**Learning note:** In instruction prose a cross-reference is executable: the agent will follow
it and read what is actually there. Cite the passage that states the test you are invoking, not
the nearest section with a related title, or the reference becomes a way to talk an agent out of
the rule you were trying to reinforce.

🟢 **Strict's tie-breaker hands a group to loose without requiring loose's own clause 2**

📍 Location: `plugins/pr/skills/triage/SKILL.md:143`

**What I see:**

```markdown
**The shared file or migration is common to every member, not merely to some pair of them**: a
third issue that overlaps one member but not the rest makes the group loose, not strict.
```

**The risk:**

The first half is exactly right and closes prior finding 8. The second half asserts an outcome
the loose path does not necessarily grant. Loose opens with "Doing any one member still puts you
inside files the others name" — a group where C overlaps A but nothing B names may not clear
that, in which case it is **refused**, not loose. Read literally, the sentence tells an agent
the demotion target is loose and invites it to skip loose's own test. The practical exposure is
small: "Both strengths" still requires the agent to write the strength and its clauses out, and
it cannot honestly write clause 2 for a pairwise-only trio. But the branch's own claim that
"nothing on this path is looser than the bar has always been" is what this sentence sits in
tension with, and the ambiguity is new on this branch.

**Suggested fix:**

```markdown
… : a third issue that overlaps one member but not the rest makes the group **not strict**. It is
a loose group only if clause 2 still holds across every member; where it does not, the group is
refused.
```

**Learning note:** When you split a rule into paths, every sentence that demotes a case from one
path to another is also an admission rule for the receiving path. Say "not X" and let the
receiving path's own test decide, rather than naming the destination for it.

🟢 **The PR summary's per-file impact figures do not match the diff**

📍 Location: `changelog/…/pr-summary-2026-09-16.md` § Impact assessment

**What I see:**

> `plugins/pr/skills/triage/SKILL.md` (+60/−15 region)

`git diff main...HEAD --numstat` reports `46 14` for that file and `1 1` for `ticketing.md`. 60
is `--stat`'s total changed-line count for the file, and 15 is the whole branch's deletion
count, including the plan folder. The aggregate line above it ("5 files changed, 308 insertions,
15 deletions") is correct.

**Suggested fix:** `+46/−14`.

**Learning note:** This becomes the PR body. A reviewer who spot-checks one number and finds it
wrong discounts the rest of the assessment, which is a poor return on a figure the tooling will
print for you.

🟢 **"nothing in the plugin had written down" overstates the band-ordering gap**

📍 Location: `changelog/…/pr-summary-2026-09-16.md` § Testing, and `changelog/…/CHANGELOG.md`
§ Review hardening

Both artifacts say the band ordering was something "nothing in the plugin had written down
before this branch". `plugins/pr/skills/next/SKILL.md:61` already reads "`priority:high` always
outranks `priority:medium`". What was unwritten is **low's** place, since `next` filters low out
at `:43` rather than ranking it. The prior review stated this precisely ("only asserts high >
medium and low is defined by exclusion"); the artifacts rounded it off.

**Suggested fix:** "which the plugin had only stated for high over medium".

**Learning note:** An absence claim bounds only where you looked — the skill under review makes
this point itself in § Common mistakes. The same discipline applies to the prose that describes
the change.

🟢 **Overview's "a loose path covers everything else"**

📍 Location: `changelog/…/pr-summary-2026-09-16.md` § Overview

Loose covers everything else *that still clears clause 2*; a group failing clause 2 reaches
neither path and is refused. The summary's own "Code examples" section states it precisely, so
this is only the overview rounding. Worth a two-word fix while the file is open, given this text
becomes the PR body.

#### ⏭️ Deferred to follow-up

None. No pre-existing defect adjacent to this diff clears the TICKET bar, and the prior review
reached the same conclusion. The one observation both reviews noted — that a two-member *loose*
group is close to a null set, since a file common to both members makes the group strict — is
correctly recorded as an observation and left alone; writing it into the skill would be new
scope.

### Artifact accuracy against the diff

Checked, since `pr-summary-2026-09-16.md` becomes the PR body.

- **"§ Step 7c's five band-dependent passages and its confirmation prompt"** — accurate. Five
  pre-existing passages changed (`Approved groups then`, `Why these combine`, the *inherits the
  members' band* paragraph, the *Forcing high* paragraph, the `priority:low` paragraph), plus
  the new confirmation and the new `Band:` line.
- **Phase 6 trace table** — consistent with `PLAN.md`'s ticket table in both directions: #71 is
  the medium member in both strict rows, so "names #71 promoted medium→high" is right twice.
- **Row 3 stays refused** — traced through the shipped text: a two-file directory is neither one
  file nor one migration (strict excluded by its own definition, reinforced by the new § Common
  mistakes bullet), and medium/medium/low fails loose's clause 3. Matches the operator decision.
- **"No breaking change… strictly additive"** — supported. Every group that combined under the
  old bar clears loose unchanged; the only behavioural widening is the intended one.
- **Testing section** — `.claude/pr-config.json` declares no `checks` and there is no
  `.github/workflows/`, both verified, so "no CI reports on it" is accurate rather than an
  excuse.
- **Assertion audit** — `docs.assertionsFile` is `null`, so disabled is the correct outcome.
- **`CHANGELOG.md` line citations** — `L131-143`, `L241`, `L256`, `L262-266`, `L283` all resolve
  on `main` as described. `L271` is one line off (it lands on *Never closes on age*; the
  `priority:` bullet is `L272`). Not worth a fix.
- **`PLAN.md`** — records the objective, both operator resolutions and the three out-of-phase
  dependents as status rather than as new scope, which is what the scope contract asks. All six
  phases and four ticket boxes are checked and each is traceable to shipped text.

### Questions

1. `:298` says the strict promotion is "forced by the material rather than chosen by this
   skill". If an operator approves a strict group but balks at the promotion inside the same
   `AskUserQuestion`, is that a declined group? Since the band is forced by the material, I read
   it as a full decline, but 7c only defines "a declined group leaves its members untouched".
   One clause would close it — worth a ticket only if it shows up in practice.
2. The `priority:low` + `priority:medium` strict case lands in `/pr:next`'s queue by the general
   rule, but the illustrative paragraph names only low + high. Intentional as an example, or
   worth generalising the sentence?

### Verdict

VERDICT: APPROVE

Objective delivered; all eight prior findings' fixes hold in substance, and the five suggestions
above are wording fixes that do not block the merge.
