## PR review: Keep figures and slides through an updatebook chapter rewrite

This is the /pr:close review of draft PR 95, branch
`feature/94-keep-figures-and-slides-through-an-updatebook-chapter-rewrite` against `main`, for
ticket `94-keep-figures-and-slides-through-an-updatebook-chapter-rewrite`. It covers two commits,
460ba53 and fccbcba. The pre-test review (`pr-review-2026-10-12.md`, REQUEST_CHANGES) covered
the first. This is a delta review: it verifies the fixes fccbcba applied and looks for anything
those fixes or the PR summary introduced. That review's five declined suggestions are settled and
are not re-raised. The two operator rulings of 2026-10-12 are fixed scope, and so is the item
parked under `PLAN.md § Deferred`.

### Summary

An `/updatebook` chapter rewrite now lists the figures and slides the old chapter places (rewrite
step 3), hands the list to the chapter agent as `createbook § 5` item 15 (step 4), reads the
agent's findings for drops (step 5), re-checks each kept figure (step 6), and compares what the
chapter places at `HEAD` with the new file (step 9). The procedure's report accounts for each one.
The slide exemption is retired, and § Adding prose, the levels table and § Placing slides agree
that a rewrite keeps a chapter's figures and slides. fccbcba fixed step 9's two defects and item
15's conflict with `chapter-prose.md § Never`.

### Plan alignment

**Every plan item is delivered, and the visibility clause the pre-test review found missing for
inline figures now holds.**

| Objective clause | Where | Status |
|---|---|---|
| A rewrite keeps every figure and slide | Rewrite steps 3 and 4, item 15 | Done |
| Or drops one only by a recorded decision with its reason | Item 15, rewrite steps 5 and 6 | Done |
| A loss without a decision is visible before the run reports | Rewrite step 9, § 6's new bullet | **Done.** Verified below for both title forms and every path form |
| § Placing slides, § Adding prose and § When to stop editing in place agree | `updatebook/SKILL.md` § Adding prose, the levels table, § Placing slides | Done |
| Operator ruling 1, the chapter agent re-places | Item 15 | Done |
| Operator ruling 2, a kept figure is re-checked | Rewrite step 6 | Done |
| Version bump and fixture checks | `plugin.json` 1.13.0 to 1.14.0 | Done. CI passes all five jobs on fccbcba |

### The applied fixes, verified

**Critical 1, step 9's `<title>` pattern, is fixed.** The pattern is now
`<title[^>]*>[^<]*</title>`, normalised by `s/^<title[^>]*>/<title>/`. That matches the house
template's `<title id="xx-t">` (`makebook/references/diagram-style.md`, `figure-template.svg`)
and agrees with the binder's own `SVG_TITLE_RE`. The normalisation also means a changed `id`
alone is not a difference.

**Important 2, the absolute path, is fixed.** `git -C "$(dirname "$CHAPTER")" show
"HEAD:./$(basename "$CHAPTER")"` pins both the repo and the base for `./`, and the second half
still reads `"$CHAPTER"` from the shell's own directory, so the two sides name the same file.

**I ran both lines extracted verbatim from the skill file**, under bash and zsh, in a throwaway
repo with the book in a subfolder whose name has a space:
- Unchanged chapter: no output from the repo root with a relative path, from the book folder
  with a bare name, from `/` with an absolute path, and from `/` through the `/tmp` symlink.
- A rewrite that drops a referenced figure and a bare-title inline SVG, changes an image's
  caption, changes an SVG's title `id`, and keeps the slide: exactly two `<` lines, for the two
  drops. Nothing for the caption, the `id` or the slide.
- Only the `id`-title SVG dropped: one `<` line. Before the fix this printed nothing.
- A slide gained: one `>` line.

**Important 3, item 15 against `chapter-prose.md § Never`, is fixed.** Item 15 now says an
inline SVG keeps its block as it stands, as the one exception to the rule against inline HTML.
The reference resolves (`reference/chapter-prose.md`, `### Never`, whose **Markdown.** rule names
inline HTML). One note on where the sentence sits is under Suggestions.

**Suggestion 7, the step references, is fixed.** Rewrite step 1's "(§ 2)" names the
classification table, whose "Changes a premise" row is the supersede rule. Step 10's "§ 5" names
the five-part check. Together with step 4's "(§ 3)", step 6's "(§ 2's first row)" and step 9's
"(§ 6)", every procedure reference inside the ten-step list now uses §, and each resolves. Step
1's "step 0" stays, and it cannot collide since the list has no step 0. Nothing outside the list
points into it by step number.

**Other checks.**
- Every bare section reference in the changed text resolves: `§ Recreating a book`,
  `makebook § Deciding where a figure helps`, `makebook § Lesson-script slides`,
  `guide.md § A shape for a teaching chapter`, and `NOTES.md`'s § Slides across a recreate,
  2026-10-11.
- Rewrite step 6's "the way the figure pass records one" agrees with `makebook/SKILL.md`, whose
  README records a recreate's candidate "as placed again or as passed over with the reason".
- `scripts/check-citations.py`: 232 resolve on the branch, 227 on `main`, as the summary says.
- Plugin diff: five files, 64 insertions, 11 deletions, as the summary says.
- No em or en dash in the added plugin lines or in the plan folder's files. No attribution in
  the diff or the commit messages. The commit subjects are lowercase imperative.
- The repo's `pr-config.json` sets `assertionsFile` to null, so the summary's "Assertions. Not
  configured" is accurate and no invariant audit applies.

### PR summary accuracy

**The summary is accurate against the diff, and it carries no closing keyword followed by an
issue reference.** The code example matches step 9 byte for byte. The key changes, deviations,
descoped list, edge cases and deferred item each match the plugin files and `PLAN.md`. Two small
corrections are under Suggestions.

### What is working well

- **The fix for Important 2 kept the second half of the diff unchanged.** Only the `git show`
  side needed `-C`, and the implementer did not over-correct the `placed <"$CHAPTER"` side,
  which is already right from any directory. That kind of restraint is what keeps a one-line
  shell snippet in a prompt correct.
- **The `(step N)` to `(§ N)` pass was done consistently across the whole list**, not only at
  the two places the review named. An agent reading a numbered list that also cites a numbered
  procedure needs exactly one convention for "the other list".
- **The summary is honest about what is not handled.** Three of the declined suggestions appear
  under "Not handled", so the operator sees the known gaps before merging rather than after.

### Issues found

#### Critical

None.

#### Important

None.

#### Suggestions

**1. Item 15's inline SVG exception sits outside the "Say that" the rest of the list uses for
what the agent is told.**

Location: `plugins/bookcraft/skills/createbook/SKILL.md`, item 15.

**What I see:** "Say that the draft places each one ... copied unchanged: ... An inline SVG keeps
its block as it stands, which is the one exception to `reference/chapter-prose.md § Never`'s rule
against inline HTML." Items 2, 9, 12 and 13 put what the agent must hear under "Say that" or "Say
too that", and the plain sentences after it are reasoning for the session.

**The risk:** The conflict this sentence resolves is in the agent's reading, not the session's.
A session that reads it as reasoning and does not pass it on leaves the agent with "copied
unchanged" against § Never, which is the pre-test review's Important 3 again. The damage is
bounded: a drop citing § Never still lands in the findings file and still shows at step 9, so the
objective holds. That is why this is a suggestion.

**Suggested fix:** "Say too that an inline SVG keeps its block as it stands, which is the one
exception to ...".

**Learning note:** When a list has a convention for "this part goes to the agent", a fix that
must reach the agent has to use it. Otherwise the fix lands in the reader who did not have the
problem.

**2. Step 9 says each `<` line needs a reason, but not what to do with one that has none.**

Location: `plugins/bookcraft/skills/updatebook/SKILL.md`, rewrite step 9's paragraph under the
code block.

**What I see:** "A `<` line is a figure or slide the rewrite dropped, and each needs a reason,
from the findings file or the re-check." A `<` line with neither is the exact case the check
exists for, an agent that dropped one silently.

**The risk:** The objective asks for that case to be visible, and it is. But a session holding a
reasonless drop has no instruction, so it may write a reason of its own into the report, which
turns a silent loss into a decision nobody made.

**Suggested fix:** "One with neither goes back in before the report: a figure after the paragraph
stating what it shows, a slide by § Placing slides."

**Learning note:** A check that finds a defect should name the remedy beside the finding, or the
reader supplies the cheapest one, which is usually to explain it away.

**3. Two small corrections to the PR summary.**

Location: `pr-summary-2026-10-12.md`, § Testing and § Key changes.
- **CI is no longer re-running.** "It is re-running on the review fixes" is stale: all five jobs
  pass on fccbcba. Suggested: "CI passes all five jobs on both commits."
- **"Step 6's report gains a bullet"** follows a list of rewrite steps that includes a step 6,
  so it reads as the rewrite's step 6. Suggested: "§ 6's report gains a bullet".
- Optional: the before-and-after exemption excerpt trims the old bullet's last sentence and the
  new one's closing cross-reference. Either restore them or call the excerpt abridged.

#### Deferred to follow-up

None. Considered and dropped, with no entry:
- **"The one exception" to inline HTML, when provenance marks are HTML comments.** A comment is
  not what the rule means by inline HTML, and the rule file already requires marks. Arguable. DROP.
- **A fenced SVG against § Never's fenced-block rule.** "Keeps its block as it stands" governs.
  Arguable. DROP.
- **Rewrite step 6 correcting an SVG file that another chapter also places.** Speculative, since
  nothing shows a book sharing one figure across chapters, and it shares a theme with the item
  already parked under `PLAN.md § Deferred`. DROP here; triage can weigh it with that item.
- **§ 6's new bullet says "by tag" for a book without tags.** Rewrite step 3 already names the
  fallback, opening words. DROP.
- **A `<title>` spanning lines, or a figure line with leading spaces.** `check-book.sh` allows
  leading whitespace and step 9 does not, but both sides of the diff miss it equally. DROP.

### Questions

None. The pre-test review's one question, the new cost of a slide-heavy placing run becoming a
rewrite, is now stated in the summary's Deviations.

### Verdict

**The branch delivers its objective with nothing regressed.** The three in-scope findings from
the pre-test review are fixed correctly and completely, step 9 now reports every drop for both
inline title forms and from any working directory, and the three sections agree on what a
rewrite does to slides. The three suggestions above are optional and none blocks.

VERDICT: APPROVE

Next: optionally apply the three suggestions, then continue `/pr:close`.
