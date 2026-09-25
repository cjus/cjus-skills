## PR review (close gate): [#44] Carry the ticket number into PR titles and squash commits

Ticket: `44-carry-the-ticket-number-into-pr-titles-and-squash-commits` · PR #45 (draft) · base `main` · 2 commits (`5ac3774`, `d1cc14d`)

### Summary

The pr plugin now puts a bracketed *title tag* at the front of every PR title (`[#32] <title>`, or `[ABC-32] <title>` with `ticketPrefix` set), so a squash merge lands with both numbers in its subject. `/pr:pre-test` sets it on create. `/pr:close` step 4b normalizes it with one jq transform and verifies it as a fixed point in the same query as the closing reference. `/pr:init` offers to switch `squash_merge_commit_title` to `PR_TITLE`. The lifecycle `pr` line names both numbers. `config.md` and `ticketing.md` document the rules.

This is a re-review. The earlier review (`pr-review-2026-09-25.md`, APPROVE) raised three 🟡 and three 🟢 findings, and `d1cc14d` claims to resolve all six. This review confirms each one against the code, checks the fixes for new defects, then looks at the branch as a whole. The objective, the operator's resolved Open Questions and the two `## Deferred` items are fixed scope and are not revisited here.

### Status of the earlier review's findings

| # | Finding | Status | Evidence |
|---|---|---|---|
| 🟡 1 | "Ticket ID" in two senses; `config.md` rule contradicted its example | **Resolved** | `config.md:L120`, `L127` define *title tag* (`#123` / `ABC-123`). The rule at `L134` now reads `[<title tag>] `. `close/SKILL.md:L48` derives the title tag and binds it to `$ID`, and `pre-test/SKILL.md:L48` writes `[<title tag>]`. A grep over the plugin finds no remaining `[<ticket ID>]`. |
| 🟡 2 | Step 4b's table could double the tag, and `startswith` accepted it | **Resolved** | `close/SKILL.md:L259-L265` is now one jq transform that strips every leading ticket-shaped token (`(…)+`) and prepends `[$ID] `. `L284-L291` verifies the title as a fixed point of the same regex. I extracted both verbatim and ran them over 26 titles (below). `[#44] [#44]Carry`, which the old check passed, now fails verification and normalizes to `[#44] Carry`. Both operator decisions (`[#N]` is ticket-shaped in a prefixed repo; `[#44]Carry` is normalized) are implemented: `[#12] Carry` with prefix `ABC` → `[ABC-32] Carry`. |
| 🟡 3 | `pr` line went quiet on the missing ref when the PR closed another issue | **Resolved** | `pr-lifecycle-state.mjs:L634-L640` keys the note on `hasCloses === false`. `hasCloses` is `null` on a branch with no ticket (`L305-L309`), so the strict `=== false` cannot print `no closing ref to #null`. The new third phase-8 case (`test-acceptance.sh:L225-L226`) **fails against `5ac3774`'s script and passes on HEAD**, so it guards this exact regression. |
| 🟢 4 | `$CURRENT_MESSAGE` never assigned; reason for sending it backwards | **Resolved** | `init/SKILL.md:L143` reads it with the fail-closed guard. `L140` now gives the direction correctly ("require the title whenever the message is sent"). `L149` warns off the `@tsv` + `read` split. |
| 🟢 5 | Row 4b had no deferred form | **Resolved** | `close/SKILL.md` report row 4b includes `deferred to 8b (no PR yet)`, and step 4 says the title check is deferred with creation. |
| 🟢 6 | Edit placeholder read as "strip every leading tag" | **Resolved (moot)** | The placeholder is gone. The jq transform replaced it, and `[WIP]` and `[XYZ-9]` survive in testing. |

### What is working well

- **The fixed-point verification is the right shape of assertion.** Checking `title == T(title)` rather than `startswith` means verification and normalization cannot disagree about what a good title is. It also catches every "plausible bad" title the transform would still change, which a prefix test structurally cannot. This is a clean fix for 🟡 2's point that an assertion should tell the good result apart from the plausible bad one.
- **The transform fails safe on its own inputs.** `[ -n "$TITLE" ]` and `[ -n "$NEW_TITLE" ]` guard both sides. A malformed `ticketPrefix` makes jq exit non-zero (I checked with `A(B`), so the chain stops before `gh pr edit` rather than writing a bad title.
- **The piped verify documents its own failure mode.** "A pipe's exit status is `jq`'s, so a `gh` failure shows up as an empty result" (`close/SKILL.md:L293`) is exactly what a model would otherwise miss, and "no output is a stop" closes it.
- **The phase-8 regression test is honest.** It fails on the pre-fix script and passes on the fix. A test added alongside a fix often passes on both.
- **The terminology fix went all the way down.** `close`, `pre-test` and `config.md` all use *title tag*, and `$ID` is bound once in `close`'s setup rather than redefined inline.
- **Repo hygiene.** Commit subjects are lowercase imperative with no bodies carrying attribution. The banned-term sweep over the whole diff and the untracked PR summary is clean, and there are no `org/repo#N` or `github.com/<org>/<repo>` strings.

### Verification I ran

- `test-acceptance.sh plugins/pr` on HEAD: **passed 42, failed 0**.
- The same suite with `5ac3774`'s `pr-lifecycle-state.mjs` swapped in: **41 passed, 1 failed**, the new "a PR closing another issue still names it" case. The fix is what makes it pass.
- `scripts/check-citations.py`: 181 resolve, 10 skipped as untracked.
- The step-4b transform and the verify expression, extracted verbatim, run with jq 1.8.2 over 20 unprefixed-repo titles and 6 prefixed-repo titles. Every realistic shape normalizes, is idempotent, and verifies after normalizing: exact, untagged, `[#44]Carry`, `[#44]: Carry`, `[#44] : Carry`, doubled, `[#44][#12]`, wrong ID, `[WIP]`, `[XYZ-9]`, `[abc-32]` lower-case, `[ABC-7] [#3]`. The two exceptions are in 🟢 2.
- The same transform with `ID=""` and with `PREFIX=""` in a prefixed repo (🟢 1).
- `gh api repos/cjus/cjus-skills` reads back `true  PR_TITLE  COMMIT_MESSAGES`, matching the operator decision recorded in PLAN.md.
- PR #45's title is `[#44] Carry the ticket number into PR titles and squash commits`, as the operator decided.
- No doc or hook quotes the old `pr       #N` line or the old `closing ref #N` evidence string, so neither text change breaks a consumer.

### Issues found

#### Critical

None.

#### Important

None.

#### Suggestions

🟢 **1. An unset `$ID` rewrites the title, and leaves a residue the fixed point then accepts**

📍 Location: `plugins/pr/skills/close/SKILL.md:L259-L265`

**What I see:**
The 4b chain guards `$TITLE` and `$NEW_TITLE`, but not `$ID`. Shell state does not persist between Bash calls, so `$ID` exists only if the model sets it in the same call.

**The risk:**
With `ID=""`, `[#44] Carry` becomes `[] Carry` and is **edited onto the PR**. That run's verification fails, since `[] ` is not a fixed point, so the close halts loudly. That part is fine. The problem is the next run with `$ID` set: `[]` is not ticket-shaped, so the result is `[#44] [] Carry`. That title **is** a fixed point, so it verifies green and lands in the squash subject. The ticket number is still carried, so this is not a regression against the objective. It does need a model slip, but it is a destructive edit that a later run cannot clean up. By contrast, an unset `$PREFIX` doubles the tag, fails verification, and self-heals on the next run. I checked both.

**Suggested fix:**
Guard the one input that is not read from GitHub:

```bash
[ -n "$ID" ] && TITLE=$(gh pr view "$BRANCH" --repo "$REPO" --json title --jq .title) && [ -n "$TITLE" ] \
  && NEW_TITLE=…
```

**Learning note:**
The fail-closed guards here all protect values *read* from GitHub. A value *derived* earlier in the skill and carried across tool calls is just as likely to be empty, and here it is the one that controls a write.

---

🟢 **2. "Running it twice changes nothing" does not hold for a title starting with a space or colon**

📍 Location: `plugins/pr/skills/close/SKILL.md:L262`, `L267`, `L287`

**What I see:**
The regex is `^(\[…\][ :]*)+`. It eats spaces and colons only *after* a token, so a title with no leading token keeps its leading space or colon:

| In | T(in) | T(T(in)) | verify(T(in)) |
|---|---|---|---|
| ` Carry` | `[#44]  Carry` | `[#44] Carry` | false |
| `: Carry` | `[#44] : Carry` | `[#44] Carry` | false |
| ` [#44] Carry` | `[#44]  [#44] Carry` | `[#44] Carry` | false |

**The risk:**
Low. The failure is loud: verification halts, and a re-run normalizes the title. GitHub most likely trims leading whitespace from titles, which leaves the colon case, and that is pathological. But `L267` states idempotency as a universal property, and the fixed-point check is only sound when that holds.

**Suggested fix:**
Allow leading separators and make the group optional, in both the 4b snippet and the verify. The operator-tag behavior is unchanged, and I checked that all seven cases above and the 4b table's rows stay idempotent:

```
("^[ :]*(\\[(#[0-9]+" + (if $p == "" then "" else "|" + $p + "-[0-9]+" end) + ")\\][ :]*)*") as $re
```

**Learning note:**
A fixed-point check is only as strong as the transform's idempotency. Test T(T(x)) = T(x) on the inputs *just outside* the tokens you strip, and not only on the tokens themselves.

---

🟢 **3. `/pr:pre-test` never says to read `ticketPrefix`**

📍 Location: `plugins/pr/skills/pre-test/SKILL.md:L13-L19`, `L52`

**What I see:**
`L52` asks for `[ABC-32]` "with `ticketPrefix` set" and says to "take the number from the state check's `ticket` line". That line carries only `#42`, and Step 1 names no config read. `close/SKILL.md:L48` lists `ticketPrefix` explicitly.

**The risk:**
In a prefixed repo, a model can open the draft as `[#32] …`. It self-heals, because `/pr:close` treats `[#N]` as ticket-shaped and rewrites it to `[ABC-32]`, per the operator's decision. So the only cost is a wrong-shaped title while the PR is a draft.

**Suggested fix:**
In `L52`, change "Take the number from the state check's `ticket` line." to "Take the number from the state check's `ticket` line and `ticketPrefix` from `.claude/pr-config.json`."

#### ⏭️ Deferred to follow-up

None new. The two `PLAN.md § Deferred` items are fixed scope and go to triage as they stand. Considered and **dropped**:

- A `ticketPrefix` with regex metacharacters goes into the regex unescaped. jq errors, and the `[ -n "$NEW_TITLE" ]` guard stops the edit, so it fails safe. No real prefix looks like that.
- A title that is *only* a tag (`[#44]`) normalizes to `[#44] `. If GitHub trims the trailing space, verification would fail on every run. That title is pathological.
- An issue title that itself starts with a ticket-shaped token gives a created title that fails verification. It halts loudly, and the next run's 4b normalizes it. Issues filed by `/pr:ticket` do not carry such a token.
- The transform regex and the verify regex are duplicated across two snippets and must stay in sync. They are identical today, and the prose says one is the fixed point of the other.

### Questions

None. The earlier review's two questions were answered by the operator and are implemented as decided.

### Verdict

VERDICT: APPROVE

All six earlier findings are resolved, and the fixes introduce no regression. The PR delivers its objective: the ticket ID reaches the PR title, is verified at close, and, with `PR_TITLE` now set, reaches the squash subject. The three 🟢 items are optional one-line hardenings of the new transform, and none of them blocks.
