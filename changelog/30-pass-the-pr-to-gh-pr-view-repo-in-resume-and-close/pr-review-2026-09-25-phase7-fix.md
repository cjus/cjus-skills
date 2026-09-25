# PR review: Pass the PR to gh pr view --repo in resume and close (Phase 7 fix, close gate)

Close-gate re-review, 2026-09-25, against the merge base `75f1a0b`. Since then `origin/main` has
gained one bookcraft-only commit (#39), which touches nothing here. The branch is one commit
ahead (`2215027`) and pushed. Phases 6 and 7 and this fix exist only in the working tree and in
the untracked plan-folder files, all of which step 7 commits. PR #38 is open and ready. CI is
green: `fixtures` passes on macOS and Ubuntu. Ticket #30.

**What this review covers.** This review covers the delta since `pr-review-2026-09-25-phase7.md`
(NEEDS_DISCUSSION):
- the `[ -s "$SUMMARY" ]` guard on step 4's create and replace pipes (`close/SKILL.md:209-218`)
- the note that goes with the guard (`:227`)
- the record edits that describe the fix and align the re-read wording, in `PLAN.md`,
  `CHANGELOG.md` and the summary

I re-read the rest for regressions but did not re-audit it. `pr-review-2026-09-25-phase6.md`
approved Phases 1 to 6, and the Phase 7 review approved Phase 7's design.

**Settled, and not raised again:** everything the five earlier reviews dropped or deferred. That
includes:
- the halt list at `:37` not naming step 4's newer stops
- qualifying step 4's stops for the deferred-creation path
- the dated line numbers in the phase entries of `CHANGELOG.md` and `PLAN.md`
- the inert quoted keywords in the review files

## Summary

The fix is correct. `&&` binds more loosely than `|`, so
`[ -s "$SUMMARY" ] && { …; } | gh …` parses as `[ -s … ] && ( { …; } | gh … )`. A missing or
empty summary therefore skips the whole pipeline, and the command exits 1 without calling `gh`.
I verified this verbatim in bash and zsh. The regression behind the previous verdict is closed,
and the wording is now the same in all three records. The fix introduces no new in-scope defect.

## What is working well

- **The guard sits before the pipe, where it can still prevent the write.** The fix follows the
  previous review's learning note exactly and does not substitute `set -o pipefail`, which would
  report the failure only after `gh` had written the body.
- **One `SUMMARY` variable feeds both pipes.** The path is typed once, so the error that
  motivated the guard (a mistyped slug or a `<date>` that does not match) now has one place to go
  wrong instead of two.
- **The note at `:227` gives the mechanism, the action and the reason.** It says the pipe's status
  is `gh`'s, that the run should stop, and that step 1 did not produce the summary. That is the
  same shape as the failed-read note directly below it (`:229`), so the two stops read as a pair.
- **The records are honest about the fix.** `CHANGELOG.md:73-75` credits the review finding and
  the operator's decision. The summary's Testing bullet (`:176-177`) describes exactly the test
  that was run, and I reproduced that test.

## Verification

Run on 2026-09-25: gh 2.92.0, `/bin/bash` 3.2.57, zsh 5.9.

| Check | Result |
|---|---|
| Both pipes, run verbatim with a stand-in `gh`, in bash and zsh | **Present summary:** `gh` gets the marker, a blank line, then the summary. That is 60 bytes for a 33-byte summary, with the marker at byte 0. Exit 0. **Empty file or missing path:** `gh` is never invoked, exit 1, no output. Both shells give the same results. |
| `bash -n` and `zsh -n` on the block, including the backslash-newline before the `\|` | Both parse |
| Comment lines inside the block, in the tool's own shell | Treated as comments |
| `gh pr create --help`, `gh pr edit --help` | Both document `--body-file -` as reading from stdin |
| The summary's line references | `close:69` (1b view), `:145` (1d checks), `:221` (the link edit's `BODY` read), `:238` (pre-append check), `:257` (verify) and `pre-test:73` (checks). Each one sits on the cited command. |
| The summary's figures | `git diff 75f1a0b --numstat -- plugins/`, working tree included: 1/1, 32/10, 3/1, 5/1. That is **4 files, +41 −13**, matching summary `:198`. |
| Re-read wording | Skill `:263`, `PLAN.md:114`, `CHANGELOG.md:72` and summary `:80` all say "up to three reads in all". "Three times" survives only in the Phase 7 review, which quotes the old text. |
| The banned-term audit from CLAUDE.md, case-insensitive, pattern read programmatically from that file | Positive control: 8 hits in `CLAUDE.md`, which is gitignored. **Zero** in each of the 13 files the close commits: the 4 plugin files, `PLAN.md`, `CHANGELOG.md`, `COMMITMSG.md`, the five earlier reviews and the summary. `git grep --untracked` agrees. I audited this file after writing it: zero. |
| Closing keyword followed by a literal issue number, in the summary | **None.** One loose match crosses from `:4` to `:5`: the verb is inside the branch name's inline code, and "Issue:" starts the next line. That is not a closing form, and the live Phase 7 run already showed that this header reads `false`. |
| The same check in the other committed files | Inert file text only. Every hit in `PLAN.md`, `CHANGELOG.md` and the reviews targets #30, except the settled past-tense form before #38. `COMMITMSG.md`'s subject also matches; see Questions. |
| `org/repo`-shaped and URL sweep | Only `plugin.json`'s own homepage and repository links, and its pre-existing `$schema` URL |
| Attribution sweep | Clean. The only hit is the host in `plugin.json`'s pre-existing `$schema` URL. |
| `git diff --check` against the merge base, trailing whitespace, final newlines in the plan folder | Clean |
| `plugins/pr/scripts/test-acceptance.sh`, run against the source tree | passed 39, failed 0 |
| Live #38 | Open and ready. The body starts with the marker and ends with the closing line for #30, at 8,743 chars. It is still the pre-Phase-7 summary. `closingIssuesReferences` is `[30]`. This close's step 4 takes the marker row. |

## The probes you asked about

1. **Operator precedence.** In the POSIX grammar, an AND-OR list joins pipelines, so `|` binds
   tighter than `&&` and `||`. Bash and zsh both follow it, which the test confirms. The exit
   status is 1 when the check fails and `gh`'s status otherwise.
   - In bash, the brace group on the left of a pipe runs in a subshell. zsh does the same for
     every pipeline element except the last. That does not matter here, because nothing the
     group sets is read afterward.
2. **bash vs zsh.** The two shells gave the same results on the present, empty and missing
   cases.
   - `[` and `printf` are builtins in both.
   - The single-quoted marker needs no escaping in either shell.
   - The `#` lines in the block are treated as comments in the tool's shell.
3. **Does the stop note fit the rest of step 4 and step 8b?** Yes.
   - **Step 4.** The note matches the other stop notes (`:229`, `:261`): a bold stop plus a
     reason. It does not collide with the deferred-creation path (`:250`). There, step 1's summary
     exists on disk, uncommitted, so the guard passes. `gh pr create` then fails with its "no
     commits" message, and the close defers as written. What separates the two outcomes is
     whether `gh` printed anything; see Suggestion 1.
   - **Step 8b.** "Create the PR now exactly as step 4 describes" carries the guard and its stop
     along with it. By 8b the summary is committed, so the guard can only fail on a wrong path.
     8b already reports a failure after the sentinel is armed as a stop, "reported as a failed
     close", so a guard stop there fits the existing pattern. Qualifying step 4's stops for 8b
     was settled at the Phase 6 review.
   - **The halt list at `:37`** does not name this stop. That is settled.
4. **Figures and line references in the summary.** All accurate; see the table.

## Issues found

### Critical

None.

### Important

None.

### Suggestions

**1. The guard fails silently, so a replace run in the same call as the append still lets the
append through**

Location: `plugins/pr/skills/close/SKILL.md:216-224` and `:227`

**What I see:** `[ -s "$SUMMARY" ]` exits 1 and prints nothing. The code block reads as a
sequence ("Or, on a replace row … Then, on every path that appends …"). The summary's own code
example (`:107-115`) also shows the replace and the append together. Suppose both run as one
Bash call against a placeholder body, and the summary is missing:
1. The replace exits 1 and prints nothing.
2. The append reads the old body and succeeds.
3. The call's final status is 0, and there is no output at all.

The verify then passes the placeholder plus the link. I reproduced this with a stateful stand-in
`gh` in bash and in zsh. Against a body carrying the marker, the result is the stale summary with
a second link.

A smaller point: `-s` does not test readability. A non-empty file the process cannot read still
sends a marker-only body, and I verified that with a mode-000 file. The note at `:227` names the
"unreadable" case. In practice that case cannot happen, because the same user just wrote the file.

**The risk:** the note says to stop, but nothing in the output tells the model that the check
failed. **This is not a regression.** `main` had no replace command, and a model could have
chained an improvised replace the same way there. Its failure would at least have printed a
message. The case also needs a missing summary right after step 1 wrote one, so it is unlikely.

**Suggested fix:** either of these is enough. The sentence is the cheaper one.

```bash
SUMMARY="<changelogRoot>/<slug>/pr-summary-<date>.md"
[ -r "$SUMMARY" ] && [ -s "$SUMMARY" ] || echo "STOP: no readable summary at $SUMMARY" >&2
```

Alternatively, add a sentence to `:227`: "Run the create or the replace as its own command, and
read its exit status before running the append."

**Learning note:** a guard that fails silently works only if the reader notices the silence. When
the reader is an agent that may batch commands, make every stop condition print a line that
names it.

**2. Carried from the Phase 7 review and not taken.** One line each. These are the operator's
call, and I do not re-argue them.

- Summary `:142`, "Phase 6 ships in the same unreleased 0.2.5": Phase 7 and this fix ship in it
  too.
- Summary `:143`, "The first close stopped at deferred-work triage", and `PLAN.md:22`, "the first
  and third close runs". Per `CHANGELOG.md:39-46`, the first run halted at the review gate, and
  the second run, the re-run, stopped at triage. The summary becomes the PR body.
- Step 8b's stop sentence (`:395`) still lacks the re-read. `:248` still says "whenever this
  skill writes a body". `Bash(printf:*)` and `Bash(cat:*)` are still absent from `allowed-tools`.

### Deferred to follow-up

These do not affect the verdict. Both are carried from the Phase 7 review. That close stopped at
step 2, so its triage has not run yet.

- **Step 4's verify accepts extra closing references, and the rule against closing keywords in
  the summary lives in close, not in `/pr:summary`.**
  - Location: `close/SKILL.md:244` and `:257-261`, and `summary/SKILL.md`.
  - Symptom: a summary that puts a closing keyword before a related issue's number closes that
    issue on merge. The verify still passes, because it only checks that #N is present.
  - Occasion: the next edit to `/pr:summary`'s output rules or to close step 4's verify.
  - Theme: close step 4 body hygiene.
- **DROP: step 6 writes the assertion-audit statement into the summary after step 4 has already
  written the PR body.** The order predates this branch, and the marker now lets a re-run refresh
  the body. Theme: close step order.

## Questions

- **`COMMITMSG.md` still describes Phase 6 only.**
  - Its body covers the checks and the link-edit guard.
  - It counts "the three close reviews".
  - It says it parks two new deferred items.

  Step 5 rewrites the file after this gate. The rewrite should cover:
  - Phase 7: the marker, the unchecked append, the re-read and the summary guard
  - five close reviews, counting this one
  - no deferred items left parked

  Its subject leads with a closing verb and #30. That is presumably intended for the merge, but
  check that it matches the commit convention step 5 uses.
- **The installed `/pr:close` is 0.2.3.** This run's step 4 lands on the marker row, so do the
  replace, the append and the verify by hand from the 0.2.5 text, including the guard. Expect the
  verify to report a length of about 11,750: the marker, the summary's 11,716 characters and the
  closing line. It should not report 8,743.

## Verdict

VERDICT: APPROVE

The Phase 7 regression is fixed, and the fix is verified in bash and zsh. The two remaining items
are a suggestion and two carried deferrals, and none of them blocks. Continue from step 3. Do
step 4 by hand from the 0.2.5 text.
