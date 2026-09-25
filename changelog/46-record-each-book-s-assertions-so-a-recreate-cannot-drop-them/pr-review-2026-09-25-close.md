## PR review: [#46] Record each book's assertions so a recreate cannot drop them

PR #48 (draft) · branch `feature/46-record-each-book-s-assertions-so-a-recreate-cannot-drop-them`
· base `main` · reviewed 2026-09-25 · `/pr:close` review gate

### Summary

This is a re-review. The pre-test review (`pr-review-2026-09-25.md`) approved the branch with four
Important findings and five suggestions. This pass covers the delta since then: `6dd0855` (the
fixes for those findings), `7446788` (procedure changes drawn from the backfill of the reference
guide, plus the sweep's measured precision and recall in `NOTES.md`) and `b7893b6` (Phase 7
ticked). The rest of the branch was reviewed once and is not re-audited here, and the merge of
`main` at `1cc1b53` (#45) is not this branch's work.

**Scope, as applied.** Nothing the prior review settled is re-raised. Its "considered and
dropped" items stay dropped. Both `## Decision` sections, the two `## Deferred` entries, and the
operator-directed pr 0.2.7 change are treated as settled. The pr plugin was not touched after the
prior review.

**What I verified rather than assumed:**

- **All four prior Important findings are fixed, and each fix is right.**
  1. Backfill step 6 (`createbook/SKILL.md:764`) now names `--citation legacy` on the
     `supersede` and says why. `supersede`'s docstring says `citation` does not carry over.
  2. `check-provenance.sh` reads `assertions.json` before both early exits (`:1670-1685`), and
     `without_marks` (`:1555-1579`) validates the file and sweeps on both markless paths. The
     invalid state returns 1, and the missing state prints `assertions NOT CHECKED`.
  3. `current()` (`:1535-1545`) walks the chain to its end, and `now_said` names a retired end
     as retired. I confirmed that the walk terminates. `problems_in` requires
     `supersedes < id` and requires both links to agree (`assertions.sh:477-483`, `:550-572`),
     so every chain strictly increases by ID and cannot cycle.
  4. The worklist test asserts both `settled` and a unit's `entries`. The CHANGELOG explains
     `cited == {3}`: a unit citing only an entry is not emitted, by the same rule as `fill`.
- **The suggestions taken are correct:**
  - The write keeps the file's mode.
  - `OK*` carries the missing-file note.
  - SVG entities are decoded after the markup is blanked.
  - `init --how createbook` refuses a folder holding markdown. `/createbook` step 1 runs
    `mkdir -p` and then `init`, so no legitimate path is blocked. The recreate never runs
    `init`.
  - The stray space is fixed.
- **The new fixture cases test what they name.** `expect`'s `!` prefix is a real negative match,
  so the chain case proves "now:" does not stop at entry 2. The mode test's `expect 4` is a real
  write, because entry 4 in the committed file is a `legacy` prose entry that holds.
- **No exact-output fixture is disturbed.** Only one manifest row runs `check-provenance`, and it
  now asserts the missing-file note.
- **No outside name was introduced.** I scanned every added line on the branch for capitalised
  tokens, URLs, handles and hashes. The only hits are fixture inventions, the fixture's model
  byline, and the SVG namespace. The short quoted phrases in the new `NOTES.md` paragraph are
  generic fragments of prose about the old value. None of them names a person, course,
  organisation, source or repository.
- **The PR summary carries no closing keyword followed by an issue number, and no em dash.** The
  only em dashes on added lines are in the CHANGELOG header format, which the repo uses
  throughout, and in pre-existing README text.
- **Commit conventions hold.** Every non-merge subject on the branch is lowercase imperative, and
  no commit or PR text carries an attribution marker.
- **CI passes on both jobs** (`fixtures (macos-latest)` and `fixtures (ubuntu-latest)`).

### What is working well

- **The review fixes went past the minimum where it mattered.** The prior review offered a
  one-sentence doc fix as the floor for the markless sweep. The branch moved the register read
  ahead of both early exits instead, so the checker now does what the PLAN promised ("it never
  passes quietly") on the older books a backfill is most likely to meet.
- **The fixes were proven by breaking them.** The CHANGELOG records that a copy with each fix
  undone failed the chain, markless, entity and mode assertions. Using 0640 in the mode test so
  that neither `mkstemp`'s 0600 nor a 0644 umask default could pass it by accident is a careful
  choice, and the comment says why.
- **Phase 7 fed real evidence back into the procedure, not only a status tick.** The bare-value
  sweep instruction (`SKILL.md:736`) is backed by a measured recall gap: 21 of 33 lines found
  with the first phrases. Checking an exclusion by searching for what it keeps out is backed by a
  lifted exclusion that nothing else recorded. `NOTES.md` now separates that measurement from
  assertion, as the Phase 6 note promised it would.
- **The honest reporting of a partial case.** The fourth ticket case, the recommendation, was
  left out because the operator said it had not been acted on. The PLAN, CHANGELOG and PR summary
  all say so, instead of forcing the box to read as four of four.
- **The helper gap found in Phase 7 went into `## Deferred`**, with its occasion ("revisit if a
  real book needs it"), rather than into scope.

### Plan alignment

- **Every phase is ticked, and every ticked box has matching code or prose.**
- **Two ticks are justified deviations, recorded as such.**
  - The `unsourced` box is ticked because each fact-like label's facts are now entries. The
    marks themselves keep their labels until a rewrite or the recreate, because a backfill never
    edits a chapter, which is a settled design rule. The PLAN states this plainly.
  - The Phase 7 box carries three of the four cases. The fourth is excluded by the operator's
    answer, and the procedure is right to exclude an unadopted recommendation.
- **The four procedure fixes in `7446788` refine the backfill.** None of them widens the
  objective.

### Issues found

#### Critical

None.

#### Important

None.

#### Suggestions

🟢 **1. `NOTES.md`'s kind breakdown sums to 37, not the 40 entries written**

📍 Location: `plugins/bookcraft/skills/createbook/NOTES.md:1064`

**What I see:** "20 measurements, 9 rulings ..., 4 given facts, 2 settled entries ..., and the
premise pair". That makes 20 + 9 + 4 + 2 + 2 = 37. The CHANGELOG, the PLAN and the PR summary all
say 40 entries (38 hold, 1 superseded, 1 retired).

**The risk:** This paragraph exists to be the measured record, as distinct from what is only
asserted. A total that does not add up is the first thing a later reader will distrust. Three
entries are unaccounted for, perhaps an `adopted` kind left out of the list.

**Suggested fix:** Name the missing kind and its count, or correct the total. Only the author can
check this, against the file in the book's own repo.

**Learning note:** A breakdown and its total are two claims about one set, so they should be
written from one count.

🟢 **2. The new "what goes in" sentence and the step 1 table read against each other on live
sites**

📍 Location: `plugins/bookcraft/skills/createbook/SKILL.md:692` against `:703`

**What I see:** Line 692 now leaves out "anything read on the open web, which a fresh run reads
again". Line 703 still gathers a fact label for "a live site read on a date" as a `given`.

**The risk:** An agent facing a fact label for a public page gets two instructions that point
opposite ways. The skill's own rule (`:34`, web-derived material is `fill`) supports line 692.
The intent of line 703 is presumably a site behind sign-in, which the operator read and a fresh
run cannot reopen. The same kind of condition applies to "a later, re-openable export": it is
carried by a fresh run only if the export is a source that `book.json` declares, because a
recreate takes its sources from there.

**Suggested fix:** In the row at `:703`, write "a live site behind sign-in, read on a date". At
`:692`, write "a later, re-openable export that `book.json` declares as a source".

🟢 **3. The bare-value sweep names only the word form of the value**

📍 Location: `plugins/bookcraft/skills/createbook/SKILL.md:736`

**What I see:** "Grep the folder for the value itself (`twenty`, not `room of twenty`)".

**The risk:** The sentence after it says arithmetic built on a premise rarely repeats its
canonical phrase, and arithmetic and tables often use numerals. An agent following the example
literally greps only the word.

**Suggested fix:** "Grep for the value in words and in figures (`twenty` and `20`)". The whole-word
boundary in `phrase_pattern` already keeps a numeral out of dates such as `2026-09-20`.

🟢 **4. The entity comment in `sweep_text` claims more than it guarantees**

📍 Location: `plugins/bookcraft/skills/createbook/scripts/check-provenance.sh:1489-1491`

**What I see:** "No entity spans a newline, so the line numbers reported stay true." That is
true, but an entity can *decode to* a newline (`&#10;`, `&#xA;`). `html.unescape` over the whole
text would then shift every later line number in that figure.

**The risk:** It is rare in SVG text content, and the REVIEW line still names the file and the
phrase, so the cost is a wrong line number. The comment is the part worth fixing.

**Suggested fix:** Decode entity by entity and fold a produced newline to a space:
`re.sub(r"&#?\w+;", lambda m: html.unescape(m.group()).replace("\n", " ").replace("\r", " "), text)`.
Alternatively, reword the comment.

🟢 **5. The mode test does not check that its write happened**

📍 Location: `plugins/bookcraft/skills/createbook/fixtures/assertions/run.sh`, the
`chmod 640` block

**What I see:** `"$A" expect "$tmp/chain" 4 >/dev/null` has no exit-code check. It is sound
today, because entry 4 is `legacy` and holds. If the fixture data ever changes so that `expect`
is refused, nothing is written, the mode stays 0640, and the test passes without testing
anything.

**Suggested fix:** Capture the exit code and assert it is 0 before reading the mode.

**Learning note:** An assertion about a side effect should first assert that the effect's cause
ran.

🟢 **6. PR summary wording.** "Mutated copies fail as they should" lists "a book with no marks"
and "a figure entity", and both of those cases pass with REVIEW lines (exit 0). Moving them to
their own clause would fix it. Separately, "gains an `--recreate` argument row" should read "a
`--recreate`".

**Considered and dropped, not worth a ticket:**

- A broken exclusion (as opposed to a lifted one) found by the new check at `SKILL.md:728` has no
  named follow-up step. The operator is asked either way, so this is arguable.
- The PLAN's `## Outside the objective` records "39 of 39" for the pr suite. That was accurate
  when written, before #45's tests arrived, and the CHANGELOG records 42 later.

#### ⏭️ Deferred to follow-up

- **Pre-existing outside names in two skill files**:
  - `createbook/SKILL.md:593` names a course code and an LMS product.
  - `updatebook/SKILL.md:145` names the same LMS product.

  Both are on `main` since the repo was rebuilt, and this branch neither added nor moved them. It
  only appended a sentence to the second line. The repo's own rule forbids naming a course or
  organisation. Symptom: a published repo names a course that the no-outside-names rule
  forbids. Occasion: the next name-audit sweep of the repo, or sooner at the operator's call,
  since the rule is strict. theme: outside-name hygiene

### Questions

1. On Suggestion 1: which kind holds the three entries the breakdown leaves out?
2. On Suggestion 2: is "a live site read on a date" in the step 1 table meant only for sites
   behind sign-in? If so, one word settles the conflict.

### Verdict

VERDICT: APPROVE

The delta since the pre-test review fixes all four of its Important findings correctly, and adds
well-evidenced procedure refinements with no regression. Every item above is a suggestion, and
the one deferred item predates the branch. Next: `/pr:close`. Suggestions 1 and 2 are worth a
minute each before the squash if convenient.
