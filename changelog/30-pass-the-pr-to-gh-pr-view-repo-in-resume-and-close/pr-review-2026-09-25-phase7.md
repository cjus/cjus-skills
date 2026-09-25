# PR review: Pass the PR to gh pr view --repo in resume and close (Phase 7 close gate)

Close-gate review, 2026-09-25, against the merge base `75f1a0b`. Since then `origin/main` has
gained one bookcraft-only commit (#39), which touches nothing here. The branch is one commit ahead
(`2215027`) and pushed. Phases 6 and 7 exist only in the working tree. PR #38 is open and ready,
and CI is green. Ticket #30.

**What this review covers.** This review covers the delta since `pr-review-2026-09-25-phase6.md`
(APPROVE): the Phase 7 edits to close step 4 (`close/SKILL.md:198-259`), plus the rewritten
summary, `PLAN.md`, `CHANGELOG.md` and the untracked files that step 7 commits. Phases 1 to 6 were
not re-audited.

**Settled, and not raised again:** everything the four earlier reviews dropped or deferred.
That includes the Phase 6 suggestions to qualify step 4's failed-read stop for the
deferred-creation path and to name the new stops in the halt list at `:37`. It also includes the
dated line numbers in `CHANGELOG.md`'s Phase 1 entry, the placeholder `org/repo` URL, and the
past-tense "resolve" keyword before #38 that two review files quote.

## Summary

Phase 7 makes close step 4 safe to re-run:

- Every body close writes now starts with `<!-- pr:close:summary -->`.
- A new table row replaces a body that carries the marker with the current summary.
- After a create or a replace, the link is appended without the pre-append check, which reads a
  field that lags.
- The verify re-reads a `false`.

The design is sound, and the table, the prose and step 8b fit together. One defect is new. The
`{ printf …; cat …; } | gh …` pipe hides a failed `cat`. A wrong or missing summary path therefore
writes a body holding only the marker over the old one, and the verify passes it. On `main` the
same mistake failed with exit 1.

## What is working well

- **The marker is anchored to the start of the body**, the same way as pre-test's placeholder
  and for the reason `evidence-discipline.md:48` gives. Every PR about this plugin will mention
  the marker in its summary. This one does, in inline code. The anchor stops those mentions from
  matching.
- **Skipping the pre-append check after a create or a replace is the right cut.** The reason is
  structural: the body was just written from a summary that carries no link. Lag is the
  secondary reason, not the primary one. The change removes a read that could only ever be
  wrong.
- **The records are honest about the lag evidence.** `PLAN.md`, `CHANGELOG.md` and the summary
  report exactly what was seen:
  - After an append, a read of `false` followed by `true`. This happened in the third close run
    (`PLAN.md:131-133`) and again in the Phase 7 clean test (`:115-117`).
  - The earlier `true` just after a replace is put down to an inline-code literal, not to lag.
  - The summary's "Not verified" section names the open question: how long the lag can last.
- **The behavior change is written down for the operator.** The summary (`:202-204`) says that
  hand edits to a body close wrote are replaced, and how to keep them.
- **The scope held.** All of Phase 7 sits in step 4. No other skill, script or doc needed to
  change (see probe 3).

## Verification

Run on 2026-09-25 with gh 2.92.0.

| Check | Result |
|---|---|
| The banned-term audit from CLAUDE.md, case-insensitive, pattern read programmatically from that file | Positive control: 8 hits in `CLAUDE.md`. **Zero** in each of the 12 files the close commits: the 4 plugin files, `PLAN.md`, `CHANGELOG.md`, `COMMITMSG.md`, the four earlier reviews and the summary. `git grep --untracked` agrees. I audited this file after writing it, and it is also zero. |
| Closing keyword followed by a literal number, over those 12 files and #38's body | Every hit targets #30: `COMMITMSG.md:1` (the subject), `PLAN.md:99` and `:134`, `CHANGELOG.md:74`, `pr-review-2026-09-24.md:55`, and the last line of #38's body. The files are inert text. The one exception is the settled past-tense "resolve" before #38 in `pr-review-2026-09-25.md:70` and `:189` and in `pr-review-2026-09-25-rerun.md:56`, which is also inert file text. **The summary has none.** #38's `closingIssuesReferences` is `[30]`. |
| `org/repo`-shaped and URL sweep | The settled placeholder in two review files, plus `plugin.json`'s links to this repo |
| Attribution sweep | Clean. The only hit is `plugin.json`'s pre-existing `$schema` URL. |
| `git diff <merge-base> --numstat -- plugins/`, working tree included | 1/1, 28/10, 3/1, 5/1: **4 files, +37 −13**. That matches summary `:194`. |
| The summary's line references | `close:69` (1b view), `:145` (1d checks), `:219` (guarded link edit), `:234` (pre-append check), `:253` (verify) and `pre-test:73` (checks). Each one sits on the cited command. |
| `gh pr create --help` and `gh pr edit --help` | Both list `-F, --body-file file  Read body text from file (use "-" to read from standard input)`. |
| The create pipe at `:210-212`, run verbatim with a stand-in `gh`, in bash and zsh | `gh` receives the marker, a blank line, then the summary bytes. The marker starts at byte 0. |
| The same pipe with the summary path missing | `cat` prints "No such file or directory", the pipeline exits **0**, and `gh` receives only the marker line. The full step 4 chain against a stateful stand-in: the replace exits 0, the guarded append exits 0, and the verify returns **`[37,true]`**. |
| `main`'s form with the path missing: `gh pr create … --body-file /nonexistent/… --dry-run` | `open …: no such file or directory`, exit 1, nothing sent |
| Live #38 | The body starts with the marker and ends with the closing line for #30, at 8,743 chars. It is the pre-Phase-7 summary, so this close's step 4 takes the marker row for real. |
| Argument-less `gh pr <sub> --repo` under `plugins/` | Only `list` (in next, triage and reviews) and close's `create --head` |
| `plugins/pr/scripts/test-acceptance.sh` | passed 39, failed 0 |
| `git diff --check` against the merge base, trailing whitespace, final newlines in the plan folder | Clean |

## The probes you asked about

1. **Are the table and the prose coherent?** Yes.
   - **Row order.** "Open, real description" sits above the two replace rows. Read as
     first-match, a body carrying the marker would land in "keep". The placeholder row has sat
     below that row on `main` without trouble, though, and `:242` and `:244` say both kinds of
     stub are "not a description". The rows therefore read as classes, not as a first-match
     sequence. There is an optional tidy-up in Suggestions.
   - **"Draft → handle the body as above"** also covers the marker row. A draft carrying the
     marker is replaced, then marked ready. That is correct.
   - **Step 8b.** When creation was deferred, 8b says "create the PR now exactly as step 4
     describes, including the edit that appends". It therefore gets the marker and the unchecked
     append. 8b's unconditional verify never rewrites the body, so the marker has no other
     interaction with it. There is one gap. 8b restates the stop as "a zero length or a `false`
     is a stop" without the re-read. In the deferred path, create, append and verify run back to
     back, which is exactly where lag was seen. See Suggestions.
2. **Does `{ printf …; cat …; } | gh pr create … --body-file -` work?** Yes, verified above.
   The brace group runs in the current shell, `printf '%s\n\n'` writes the marker and a blank
   line, and gh reads stdin. The flaw is the exit status. A pipeline returns the status of its
   last command, so a failed `cat` is invisible. `set -o pipefail` would not fix this: it only
   changes the status reported afterwards, and by then gh has already written the body. See
   Important.
3. **Is anything else in the plugin affected?** No.
   - **`pr-lifecycle-state.mjs`.** Line 300 uses the placeholder only for the
     `pr-body-placeholder` gap on a ready PR (`lifecycle.md:69`), which means "a stub that should
     have been replaced". A body carrying the marker is the finished summary, the state that gap
     is waiting for. Teaching the script the marker would add a signal that nothing reads. It is
     fine that it does not know it.
   - **Docs.** `README.md:261` ("This document becomes the PR body at close") is still true.
     `lifecycle.md` and `evidence-discipline.md` need no change.
   - **Pre-test.** Its placeholder text ("/pr:close replaces this body with the PR summary and
     adds the closing reference") is still accurate.
   - **`/pr:summary`** does not know the new rule against literal closing keywords. See
     Deferred.
4. **Are the lag claims supported?** Yes, with one wording drift.
   - `PLAN.md:115-117` and `:131-134`, `CHANGELOG.md:73-75`, and summary `:46-47` and `:170-176`
     state only what was seen. After an append, a read of `false` was followed by `true`. The
     three `false` reads before the append were correct values, not lag.
   - The skill (`:240`, `:259`) widens this to "lags a body edit by a moment". The only lag seen
     came after an append, but an append is a body edit made with the same call, so the wider
     claim is fair. The summary's "Not verified" line covers how long the lag lasts.
   - **The drift.** `PLAN.md:114`, `CHANGELOG.md:72` and summary `:78` say the verify "re-reads
     a `false` up to three times". The skill says "up to three reads in all", which is two
     re-reads. See Suggestions.
5. **Is the summary accurate?** Its figures and all six line references are correct. There are
   three small wording slips:
   - `:78`: "three times", as above.
   - `:140`: "Phase 6 ships in the same unreleased 0.2.5" should say Phases 6 and 7.
   - `:36-37`: "a failed read of any kind can no longer wipe the description" claims too much
     until the Important item below is fixed. After the fix it is true.

   `PLAN.md:22`, new in Phase 7, says "the first and third close runs stopped at triage". That
   disagrees with `CHANGELOG.md:39-45`, where the first run halted at the review gate and the
   re-run stopped at triage. Summary `:141` has the same wording, carried over from the approved
   Phase 6 text.

## Issues found

### Critical

None.

### Important

**A failed `cat` in the create and replace pipes writes a body holding only the marker, and the
verify passes it**

Location: `plugins/pr/skills/close/SKILL.md:210-216`, with `:225` and `:257`

**What I see:**

```bash
{ printf '%s\n\n' '<!-- pr:close:summary -->'; cat "<changelogRoot>/<slug>/pr-summary-<date>.md"; } \
  | gh pr edit "$BRANCH" --repo "$REPO" --body-file -
```

**The risk:** the path can be wrong: a mistyped slug, a `<date>` that does not match the file
step 1 wrote, or a placeholder left unsubstituted. Then this happens:

1. `cat` fails on stderr, and the pipeline exits 0 with gh's status.
2. gh writes a body that holds only the marker. On a replace row, that overwrites the previous
   summary.
3. The guarded append reads a non-empty body, the marker, and appends the closing line.
4. The verify sees a length of 37 and `true`.

The PR then renders as nothing but the closing line, and the close reports green. Phase 1 called
this outcome the ticket's data-loss risk, and this is a new way to reach it. On `main` the same
mistake stopped at `gh pr create --body-file <path>` with exit 1. Neither check catches it: the
`:225` guard does not fire because the body is not empty, and the verify only requires a
non-zero length. The model does see `cat`'s stderr, which lowers the odds. Both the exit code
and the PR URL gh prints still say success.

**Suggested fix:** check the file before the pipe, the same idea as the `:219` guard:

```bash
SUMMARY="<changelogRoot>/<slug>/pr-summary-<date>.md"

# No PR: create from the summary, marker first
[ -s "$SUMMARY" ] && { printf '%s\n\n' '<!-- pr:close:summary -->'; cat "$SUMMARY"; } \
  | gh pr create --repo "$REPO" --base "$DEFAULT_BRANCH" --head "$BRANCH" \
      --title "<resolved issue title>" --body-file -

# Or, on a replace row: overwrite the body with the summary, marker first
[ -s "$SUMMARY" ] && { printf '%s\n\n' '<!-- pr:close:summary -->'; cat "$SUMMARY"; } \
  | gh pr edit "$BRANCH" --repo "$REPO" --body-file -
```

`&&` binds more loosely than `|`, so a missing or empty file skips the whole pipeline, which then
exits 1. I tested this in bash and zsh. On the good path the body becomes the marker plus the
summary. On a missing path the command exits 1 and leaves the old body untouched. Then extend
the `:225` note: "If the summary file is missing or empty, **stop** before the create or
replace." Do not substitute `set -o pipefail` for the guard, because gh has already written the
body by the time that status arrives.

**Learning note:** a pipeline reports only the status of its last command. When the last stage
of a pipe writes something, check the inputs to the earlier stages **before** the pipe runs. By
the time any status comes back, the write has already happened. This is the lesson of Phase 6's
`$(…)` again: the silent failure has moved from a command substitution into a pipe.

This item is in scope and not a deferral. Phase 7 introduced the pipe, and `main` fails loudly
where this branch now succeeds silently. It is the only item behind the verdict.

### Suggestions

**Limit "whenever this skill writes a body" to the summary writes, and put the opt-out in the
skill**

Location: `close/SKILL.md:244`

The append to a kept description also writes a body (`gh pr edit --body "$BODY…"`). Read
literally, `:244` says to put the marker on that body too. If a model did, the next close would
replace the operator's description with the summary. The code block is unambiguous, so the risk
is low. Suggested wording: "Whenever this skill **creates or replaces a body from the summary**,
the marker goes on its first line… Never add it to a kept description. To keep hand edits to a
body this skill wrote, delete the marker line." At present the opt-out appears only in summary
`:203-204`.

**Carry the re-read into step 8b's stop sentence**

Location: `close/SKILL.md:391`

Suggested wording: "A zero length, or a `false` that survives step 4's re-reads, is a stop."
When creation was deferred, 8b runs create, append and verify back to back.

**Use the same count of reads everywhere**

Location: `PLAN.md:114`, `CHANGELOG.md:72`, summary `:78`, against `close/SKILL.md:259`

The records say "re-reads up to three times" and the skill says "three reads in all". Pick one.
The summary becomes the PR body, so it matters most there.

**Small record fixes**

- Summary `:140`: name Phase 7 in the 0.2.5 sentence.
- Summary `:36-37`: this becomes true once the Important item is fixed.
- `PLAN.md:22`: "the first and third" should read "the second and third", per `CHANGELOG.md`.

**Optional: add `Bash(printf:*)` and `Bash(cat:*)` to close's `allowed-tools`**

Location: `close/SKILL.md:4`

Step 4 now calls both. Pre-test lists `Bash(printf:*)` for its own placeholder body, so this
matches the plugin's convention. It also avoids a permission prompt partway through the close
where the operator's settings do not already allow those commands.

**Optional: define "real description" by exclusion**

Location: `close/SKILL.md:201`

For example, "Open, real description (none of the body rows below)". Alternatively, move that row
below the two replace rows so a first-match reading also lands correctly.

### Deferred to follow-up

These do not affect the verdict.

- **Step 4's verify accepts extra closing references, and the rule against closing keywords in
  the summary lives in close, not in `/pr:summary`.**
  - Location: `close/SKILL.md:240` and `:253-257`, and `summary/SKILL.md`.
  - Symptom: a summary that puts a closing keyword before a related issue's number closes that
    issue on merge. The verify still passes, because it only checks that #N is present.
  - Occasion: the next edit to `/pr:summary`'s output rules or to close step 4's verify.
  - Theme: close step 4 body hygiene.
- **DROP: step 6 writes the assertion-audit statement into the summary after step 4 has already
  written the PR body**, so the body lacks it. The order predates this branch, and the marker now
  lets a re-run refresh the body. Theme: close step order.

## Questions

- **`COMMITMSG.md` predates Phase 7.** It does not mention the marker, the unchecked append or
  the re-read. It counts three close reviews, not four. It also says two deferred items are
  parked, and both are now done. Step 5 has to rewrite it. The Phase 6 review made the same
  request.
- **The installed `/pr:close` is 0.2.3.** This close's step 4 lands on the marker row for real,
  so run the 0.2.5 replace, append and verify by hand, with the `[ -s "$SUMMARY" ]` guard. Expect
  the verify to report a length of about 11,430 (the summary's 11,389 chars plus the marker and
  the link), not 8,743.

## Verdict

VERDICT: NEEDS_DISCUSSION

The regression, against Phases 6 and 7: on `main`, a wrong summary path made step 4's create fail
with exit 1. With Phase 7's pipe, the same mistake exits 0 and writes a body holding only the
marker over the old one. The verify passes that body, which breaks the Phase 6 guarantee that a
failed read cannot wipe the description. The fix is a one-line `[ -s "$SUMMARY" ] &&` guard on
both pipes. Add it, or confirm that you are deliberately taking the risk, and the close can go
ahead.
