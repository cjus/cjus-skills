## PR review: [#42] Stop /pr:close from linking issues other than the ticket

Ticket: `42-stop-pr-close-from-linking-issues-other-than-the-ticket` · PR #49 (draft) · base `main` · 5 commits (`dcb978d`, `39aab66`, `df6a486`, `4bd3e76`, `1deb7da`) · close-gate review

### Summary

The branch makes `/pr:close` step 4's verify, and step 8b's re-run of it, stop when `closingIssuesReferences` holds any issue other than the ticket. References are keyed on repository as well as number. The closing-keyword rule moves into `/pr:summary` step 3. The create and replace paths now write marker, summary and closing line as one body in a single edit. Since the pre-test review, commit `1deb7da` applied that review's important finding, both of its suggestions and its first question. `pr-summary-2026-09-25.md`, which becomes the PR body, has been written.

### Scope of this review

This is a re-review, so it covers the delta: `1deb7da` and the new `pr-summary-2026-09-25.md`. It does not re-audit the four commits `pr-review-2026-09-25.md` already approved.

These items are settled and not re-raised:

- The prior review's ⏭️ item, the "sentence that negates it" claim, was marked DROP.
- The prior review offered a `userLinkedOnly` GraphQL query as an optional alternative to its sidebar sentence. The author took the sentence.
- The lifecycle-script gap is already in `PLAN.md § Deferred`, and close's triage handles it from there.

### Plan alignment

This is unchanged from the prior review: all four phases are delivered. `1deb7da` adds no scope. It refines the Phase 1 stray remedy (`close/SKILL.md:L305-L309`) and the Phase 2 rule (`summary/SKILL.md:L55`). Both are text this PR authored, and both changes answer review findings. No drift.

### Prior findings: did they land?

| Prior item | Where it landed | Status |
|---|---|---|
| 🟡 1: sidebar-linked strays | `close/SKILL.md:L305` | **Landed.** The suggested sentence is in, with a discriminator (no closing keyword in the summary or the body) and an explicit "do not re-run". GraphQL introspection confirms `closingIssuesReferences` takes `userLinkedOnly` and `excludeUserLinked`, so the premise holds. |
| 🟢 1: colon form | `summary/SKILL.md:L55` | **Landed.** "in any case and with or without a colon after them". |
| 🟢 2: stale `$REPO` | `close/SKILL.md:L309` | **Landed.** It names both sources, `.claude/pr-config.json` `repo` and the remote. That matches `reference/config.md:L60`, which derives `repo` from `git remote get-url origin` when the key is not set. |
| Q1: an intended second issue | `close/SKILL.md:L307` | **Answered.** The stop is deliberate: close the other issue by hand after the merge. |
| Q2: this close runs installed 0.2.5 | the summary | **Handled.** The summary's closing-line examples use `#N` and `%s`. See the operator note under Questions. |

### What is working well

- **The author caught a contradiction that answering Q1 would have created.** The old L305 called a stray an issue the merge would close "without anyone having chosen to". Once L307 says the stop holds even for a chosen second issue, that phrase would contradict it. The author changed it to "besides the ticket" in the same commit. Edits that answer a review question often leave the surrounding text arguing the opposite. This one did not.
- **The sidebar sentence gives the model a test as well as a category.** "When neither the summary nor the body carries a closing keyword for it" tells the model how to decide that a stray is a manual link. Without it, the model would only know that a manual link is possible. It also says "do not re-run", which prevents the loop the prior review warned about.
- **The summary obeys the rule it introduces, in the hardest case.** A summary about closing lines has to show closing lines. It shows them with `Closes #N` and `printf '\n\nCloses #%s'`, and it mentions #38, #44 and #45 without a keyword in front. The one near miss, "On PR #38 GitHub resolved those two edits", puts the keyword after the reference, and GitHub does not link that order.
- **The summary names its deviation instead of smoothing it over.** Phase 1's repository keying goes beyond the ticket's literal text. The Plan alignment section says so and gives the reason, which is what `summary/SKILL.md` step 3 asks for.

### Verification I ran

- **Closing-keyword scan of `pr-summary-2026-09-25.md`.** Three scans, all with zero hits:
  - A line-based scan for the nine keywords, case-insensitive, with an optional colon, then whitespace, then `#digits` or `owner/repo#digits`.
  - The same pattern over the whole file with `perl -0777`, so a keyword at the end of one line and a reference at the start of the next would still match.
  - A looser scan allowing up to six non-word characters between the keyword and the reference.

  The file also contains no issue URLs, no `/issues/` or `/pull/` links, and no `GH-` references. The only issue references are #38, #42 (twice, both inside code spans), #45 and #44, and no keyword comes before any of them.
- **Commit messages.** `git log main..HEAD --format=%B` shows five subject-only commits with no closing keyword and reference. This matters because the repo squashes with the commit messages as the body.
- **The summary's claims against the diff and log:**
  - `git diff --numstat main...HEAD` gives `close/SKILL.md` 45/29, `summary/SKILL.md` 2/0, README 2/2 and `plugin.json` 1/1, which is +50/−32. That matches Impact assessment exactly.
  - The "before" jq element matches the removed line.
  - The verify code block matches `close/SKILL.md:L291-L301` verbatim.
  - The "after" body write matches the replace path.
  - The version is 0.2.7 → 0.2.8.
  - The PR title is `[#42] Stop /pr:close from linking issues other than the ticket`.
  - `docs.assertionsFile` is `null` in `.claude/pr-config.json`, as the assertion audit section says.
- **The verify jq against PR #45, live.** Run verbatim from the summary with jq 1.8.2, `N=44`, `ID=#44` and `PREFIX=""`, it returns `[9599,true,true,[]]`, as the summary claims.
- **`plugins/pr/scripts/test-acceptance.sh plugins/pr`:** passed 42, failed 0.
- **PR #49 now:** a draft, with the pre-test placeholder body and `closingIssuesReferences: []`. That is expected before close step 4 runs.
- **The installed plugin.** `~/.claude/plugins/cache/cjus-skills/pr/0.2.5/skills/close/SKILL.md:L257-L258` is the number-only verify, with no stray or title element. `L200` still creates and then appends. This is relevant to the operator note below.

### Issues found

#### Critical

None.

#### Important

🟡 **1. The summary's Testing section overstates the pre-test review's jq evidence**

📍 Location: `changelog/42-stop-pr-close-from-linking-issues-other-than-the-ticket/pr-summary-2026-09-25.md:L110-L111`

**What I see:**
> - The review agent ran it on 10 more, covering empty `gh` output, `null` references and a `null` repository. Each one stops the close.

**The risk:**
The pre-test review's table (`pr-review-2026-09-25.md`, "Verification I ran") lists 10 payloads.

- **"10 more" is wrong.** Six of the ten are the same six the author ran: no refs, ticket only, ticket plus #30, `other/repo` #42, mixed case, and #30 only. Only four are new: `repository: null`, `closingIssuesReferences: null`, `body: null`, and empty input.
- **"Each one stops the close" is wrong.** Two of the ten, ticket only and ticket with mixed-case owner/name, correctly pass as `[1,true,true,[]]`.

This file becomes PR #49's body, the permanent record of how the change was tested. `reference/evidence-discipline.md` lists "counts not computed from observed data" as a fabrication pattern. A reader would conclude that 16 distinct payloads were tested and that none of them passes. This is not a regression against the objective and does not block. It is a one-line fix, and it is cheapest now, before step 4 writes the body.

**Suggested fix:**
```markdown
- The pre-test review re-ran it on 10 payloads, four of them new: empty `gh` output,
  `closingIssuesReferences: null`, a reference with `repository: null`, and `body: null`. Each of
  the four stops the close, and the two ticket-only cases still pass.
```

**Learning note:**
"More" and "each" are quantitative claims, just as a number is. When you pass on someone else's evidence, copy the count and the outcome from the source table rather than from memory. Relayed evidence tends to grow a little each time it is summarized.

#### Suggestions

🟢 **1. The quoted text for report row 8b does not match the row**

📍 Location: `pr-summary-2026-09-25.md:L34`, against `plugins/pr/skills/close/SKILL.md:L399`

The summary says rows 4 and 8b say "and no other issue". Row 4 does. Row 8b reads "present and no other". Drop the quotation marks ("Report rows 4 and 8b now name the no-other-issue check") or quote each row as it stands.

🟢 **2. "Re-reads are unchanged" sits next to a bullet describing a re-read change**

📍 Location: `pr-summary-2026-09-25.md:L87`

"Phase 3 … the verify's existing re-reads are unchanged" is accurate. `git show df6a486` does not touch the re-read paragraph; `dcb978d` (Phase 1) extended it to strays. But the Key changes bullet "Re-reads: a stray straight after an edit is re-read like a `false`" makes it read as a contradiction. Suggested wording: "Phase 3 relies on the verify's re-reads, which Phase 1 extended to strays."

#### ⏭️ Deferred to follow-up

None new. The prior review's one ⏭️ item was DROP and stays settled. The `PLAN.md § Deferred` item reaches close's triage from the plan.

One thing I considered and did not raise: the sidebar test at L305 could mistake a stale resolution that outlasts three re-reads for a manual link. The prior review offered `userLinkedOnly: true` as the precise test, and the author chose the sentence. The check fails closed, and the single-edit write makes a long stale window unlikely, so this stays settled.

### Questions

1. **Operator note for this close, not a finding.** The installed 0.2.5 plugin runs it. Three consequences:
   - Step 4 will replace the body, then append the closing line, which is the two-edit shape this PR removes. If 8b reads `[]` after the push, re-saving the identical body is what restored the link on PR #38 (`PLAN.md`, About Ticket).
   - 0.2.5's verify is number-only, so the stray check does not run on this PR. The keyword scan above stands in for it. You can also run the summary's verify block by hand with `N=42`, `ID=#42` and `PREFIX=""` after 8b. It should print `[<len>,true,true,[]]`.
   - 0.2.5 does not check the title. It is correct now, `[#42] …`, so confirm it is unchanged after `gh pr ready`.

### Verdict

VERDICT: APPROVE

`1deb7da` lands the three applied review items and the Q1 answer correctly. The summary carries no closing reference, and its claims match the diff and the log except for one overstated testing sentence (🟡 1). Fix that sentence before step 4 writes the body. Nothing regresses `main` against the objective.
