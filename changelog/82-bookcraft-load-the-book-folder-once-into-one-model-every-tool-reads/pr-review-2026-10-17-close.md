## PR review: [#82] bookcraft: load the book folder once, into one model every tool reads

Reviewed 2026-10-17 for the `/pr:close` gate. PR #96 is at `9ee270a`, 9 commits ahead of `main` and 0
behind. Ticket: `82-bookcraft-load-the-book-folder-once-into-one-model-every-tool-reads`.

**This is a re-review, so it covers only what changed.** The prior review, `pr-review-2026-10-15.md`,
approved at `df0db16`. Since then there are two changes:
- Commit `9ee270a`, which applies two of that review's 🟢 suggestions in
  `plugins/bookcraft/scripts/book_model.py`.
- The new `pr-summary-2026-10-17.md`, which will become the PR body.

Everything the prior review settled stays settled:
- its verified areas
- its two ⏭️ items, both marked DROP
- the two 🟢 suggestions the branch chose to leave, which `CHANGELOG.md` records under 2026-10-15
  14:44
- rulings R1 to R10

### Summary

`9ee270a` restores `main`'s handling of `"profile": 0`. A value of `0` is rejected as an unknown
profile again, where before the fix it quietly got the narration rules. The model also now refuses a
tab or line break in `glossary_file`, `front_matter_file` or `description_file`, so the `--tsv` rule
that no field holds a tab is enforced where the values come in. The PR summary is accurate against
`git log main..HEAD`, the diff and CI, and it contains no closing keyword.

### What is working well

- **The profile fix is minimal and explains itself.** It tests `None` and `False` by identity and
  keeps the `_tostring` guard. The comment says exactly why `in (None, False)` was wrong: `0 == False`
  in Python. The next editor will not "simplify" it back.
- **The tab check is made where values enter the model.** It lives in `_file_key`, the one function
  that reads all three file keys. `classify` reaches it through `skipped()`, so the binder and both
  Python checkers get the same refusal as `check-book.sh`. They do not each defend the row grammar
  separately.
- **The CHANGELOG entry gives each decision.** It says which suggestions were applied and which were
  left, so this review has nothing to re-argue.

### What I verified

1. **`"profile"` across JSON values, under `/usr/bin/python3` 3.9.6.** I emitted `--tsv` for each
   value:

   | Value | `decl profile` row |
   |---|---|
   | `0` | `0` |
   | `0.0` | `0.0` |
   | `1` | `1` |
   | `true` | `true` |
   | `"narration"` | `narration` |
   | `false`, `null`, `""` | none |

   This matches jq's `.profile // empty`, where only `null` and `false` are absent. An empty string
   reads as absent on both sides, because it prints as empty. **End to end, `check-book.sh` on
   `{"profile": 0}` exits 2 with the same message on the branch and on `main`:**
   `error: book.json "profile" must be "guide" or absent, not: 0`. So the regression the prior
   review found is gone.
2. **The file-key refusal.** I ran 12 cases: each of the three keys with a tab, an LF, a CR and a
   clean name. The nine bad values exit 2 with a `ModelError`, and the three clean names pass.
   `check-book.sh` passes that exit through as 2, and its message shows the value's `repr`
   (`'g\tx.md'`), so the cause is visible.
3. **The suite.** 19 of 19 pass locally. `book-model/run.sh` reports `OK` with 75 checks.
4. **CI.** All six jobs pass on `9ee270a`, including `checkers (macos-latest, python system)`. This
   answers the prior review's second question.
5. **The PR summary against the record.** Each of these claims checked out:

   | Claim | How I checked it |
   |---|---|
   | Inventory on `498a68a` | It is the merge base |
   | "eleven `jq` reads" | 11 `$(jq` reads of `book.json` in `main`'s `check-book.sh` |
   | 75 fixture checks | Counted in the `book-model/run.sh` output |
   | 26 files, +2,259/−699, about 820 lines of plan, changelog and review | `git diff --shortstat`; the plan files total 429 + 175 + 218 = 822 |
   | 3.9.6 with no venv passes 16 | Recorded in `CHANGELOG.md` at 12:44 |
   | Both drift mutations | Recorded in `CHANGELOG.md` at 12:44 |
   | All five code excerpts | Each matches the current source, or `main`'s source for the "before" binder excerpt |
   | Issue references | #17 merged 2026-09-21, and #21 (`check-claims: appendix numbers collide with chapter numbers, so render-report refuses the whole run`) was filed 2026-09-22, which is "the day before" as the summary says |
   | R1 to R10 ruled 2026-10-15 | `CHANGELOG.md` entry at 12:17 |
6. **No closing keyword.** The summary refers to #72, #21 and #17, and none of those references
   follows `close`, `fix` or `resolve` in any of their forms.
   - The nearest phrase is "#21, can be closed by hand". There the reference comes before the verb,
     so GitHub does not read it as a closing reference.
   - #82 is not referenced at all, which matches the lifecycle state's "no closing ref to #82".
7. **No cross-project references.** I read the summary in full, and it names no other project.

### Issues found

#### Critical

None.

#### Important

None.

#### Suggestions

🟢 **Neither new refusal is pinned by a fixture**

📍 Location: `plugins/bookcraft/scripts/book_model.py:L110`, `L325-L330`. No fixture row covers either.

**What I see:**
The summary's "Edge cases considered" lists `"profile": 0` and a tab in a filename. A filename with a
tab is covered by the model's earlier `UNSAFE` check on file rows. But no fixture runs
`{"profile": 0}` or a tab inside a `book.json` file key: a grep of `fixtures/` and `test-fixtures.sh`
finds neither.

**The risk:**
Small. Both inputs are contrived. But the profile bug was a one-character-class slip that 19 green
fixtures did not catch, and the same slip could come back in a later tidy-up.

**Suggested fix:**
Optional. Add two table rows to `book-model/run.sh`, which already builds `book.json` variants:
- `{"profile": 0}` expects a `decl profile 0` row.
- `{"glossary_file": "g\tx.md"}` expects exit 2.

Or leave it. "Considered" is an accurate word for cases that were run by hand.

**Learning note:**
A one-line fix for a bug that review found, not a test, is the cheapest place to add the test. The
existing suite has already shown it does not reach that input.

---

🟢 **The summary leaves out two small facts**

📍 Location: `pr-summary-2026-10-17.md`, § Impact assessment ("Behavior on odd names") and § Deferred
work ("From the review, recorded and dropped").

**What I see:**
- **Every tool now refuses a tab or line break in a `book.json` file key, the binder included.**
  `classify` → `skipped` → `_file_key` is shared by all of them. On `main`, the binder would have
  looked for a file with that name. This is a behavior change that the "Behavior on odd names" list
  does not mention.
- **The two suggestions the branch left unapplied** (an empty mark above the H1, and CR-only line
  endings) are recorded only in `CHANGELOG.md`. The summary's "recorded and dropped" bullet lists
  only the review's two ⏭️ items.

**Suggested fix:**
Optional. Add one bullet to each section, so that everything dropped can be found in the committed
PR body, as the scope contract intends.

#### ⏭️ Deferred to follow-up

None new. The prior review's two ⏭️ items were marked DROP, and the summary already records them as
dropped. The two 🟢 suggestions the branch left are settled per `CHANGELOG.md`.

### Questions

None.

### Verdict

VERDICT: APPROVE

`9ee270a` fixes both in-scope suggestions without regressing anything. The suite passes 19 of 19,
and CI passes on all six jobs. The summary is accurate and has no closing keyword, so it is ready to
be the PR body. The two 🟢 items are optional.
