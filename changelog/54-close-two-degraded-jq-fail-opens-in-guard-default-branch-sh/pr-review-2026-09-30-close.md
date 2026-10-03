## PR review: [#54] Close two degraded-jq fail-opens in guard-default-branch.sh (close gate)

Reviewed 2026-09-30 against `main` @ `a26f79c`, branch head `58aee16` (two commits), draft PR #57.

**This is a re-review, so it covers the delta.** The pre-test review, `pr-review-2026-09-30.md`,
approved `df75cf4`. This pass covers:

- what `58aee16` changed: `gate()`'s safe-shape swap, the timing comment, one new probe, and the
  README counts
- whether `pr-summary-2026-09-30.md` and the README and CHANGELOG claims hold

The pre-test review's two ⏭️ items are filed as #58 and #59, and this branch's `PLAN.md`
`## Deferred` items are settled. Neither set is re-raised here.

### Summary

Without jq, the no-jq branch now matches `GIT_VERB_RAW`, which accepts JSON syntax at the verb's
boundaries. A jq that is on `PATH` but cannot run is detected after a failed parse and sent to the
no-jq branch. `gate()` falls back to `printf` whenever `jq -nc` prints nothing. Since the last
review, the fallback tests the reason and the deny instruction each against a safe shape, and
swaps each on its own, so a reason holding a quote keeps the approval-token instruction.

### What is working well

- **The safe-shape rewrite is correct as written.** Under `/bin/bash` 3.2.57, `JSON_SAFE`'s class
  holds exactly `"`, `\` and the control characters, DEL included, in both `C` and `en_US.UTF-8`.
  `[`, `]`, `:` and the letters of `cntrl` all test safe, so the `\[` inside the brackets is read
  as a literal backslash followed by `[:cntrl:]`, as the comment says.
  - Under UTF-8, NEL and invalid UTF-8 now swap rather than slip through, which is the fail-closed
    property the pre-test review asked for.
  - An empty `stop`, in ask mode, tests safe and stays empty.
- **The separate swap does what the CHANGELOG says.** Take bypass mode, a jq that fails only on
  `-nc`, and `-C /nonexistent/a"b`. The reason is swapped, the output is valid JSON, and the
  output still says `re-run the command prefixed with PR_ALLOW_MAIN=1`.
- **The new token probe is well built.** It uses a real fixture config with `A"B`, and it reaches
  the `stop` swap by the only route that can hand it an unsafe value.
- **The docs match reality.** Every count I checked reproduced exactly (below). The README's
  rewritten explanation of the mass-failure shapes names exactly the four cases that pass.

### Independent verification (macOS, `/bin/bash` 3.2.57, jq 1.8.2)

Scripts are in this session's scratchpad under `cr/`: `safe.sh`, `swap.sh` and `shapes.sh`.

- **Suite.** `passed 114, failed 0, skipped 0  (114 cases)`, in about 16s.
- **README mass-failure shapes**, with a stub jq that exits 126 first on `PATH`:
  - Outside a configured repo: `passed 35, failed 79, skipped 0  (114 cases)`. The four passes in
    the degraded-jq sections are exactly the four the README names: jq hidden, jq broken, and the
    two unconfigured-repo cases.
  - Inside a configured repo: `passed 8, failed 106, skipped 0  (114 cases)`.
  - I did not re-run the missing-jq variant. The pre-test review showed that missing and broken
    give the same shape, and the hook now treats them the same way.
- **`pr-summary-2026-09-30.md`.**
  - **No closing keyword** is followed by an issue reference. The only references are #1, #58 and
    #59, used descriptively.
  - #58 and #59 are open, and their titles match the summary's descriptions.
  - **Case counts.** 91 + 10 + 8 + 4 + 1 = 114, matching the suite diff.
  - **Line counts.** From `--numstat`: 787 added and 57 removed. The plan folder accounts for 571
    added lines (195 + 162 + 214). Code and docs account for 216 added and 57 removed.
  - **Mutants.** "13 mutants, 7 + 3 + 3" matches the CHANGELOG's table once the single swap
    mutant is split in two.
  - **Code excerpts.** All three match the hook at `58aee16`.
- **CHANGELOG claims.**
  - I checked these: 114 cases, the shapes 35/79 and 8/106, and the "about 0.4s" figure. The last
    one agrees with the 0.42s the pre-test review measured.
  - I did not re-run these, which are taken as recorded: the Linux run, the acceptance suite's 42
    of 42, and the byte-identical jq-path stdout.

### Issues found

#### Critical

None.

#### Important

None.

#### Suggestions

🟢 **The recovery the separate swap preserves is not pinned by any case**

📍 Location: `plugins/pr/hooks/test-guard-default-branch.sh:L407-L412`

**What I see:**

```
# The deny instruction names the configured token, so it is the other part printf may
# be handed unsafe. It is swapped on its own, which is what lets a reason with a quote
# in it keep the recovery.
...
hj "a token name holding a quote still denies" deny "$(jq -nc ... )" "$TOKREPO"
```

**The risk:**
`58aee16` exists to keep the approval-token instruction when only the reason is unsafe. No case
checks it:

- `pj` compares only the decision.
- The quoted-reason case runs in `default` mode, where `stop` is empty.

I rebuilt the pre-review joint swap as a mutant, which replaces both parts whenever either is
unsafe. It passes **114 of 114** (`swap.sh`), and for bypass with a quoted `-C` path its output
drops `PR_ALLOW_MAIN=1`. The decision is still `deny`, so nothing fails open. But the behaviour the
comment attributes to the separate swap would be lost silently, and the CHANGELOG's "every one
caught" covers removing each swap, not merging them.

**Suggested fix:**
Add one case after the token probe that checks the reason text:

```bash
out=$(printf '%s' "$(rawp bypassPermissions 'git -C /nonexistent/a"b commit -m x')" |
  CLAUDE_PROJECT_DIR="$MAINREPO" PATH="$HALFJQ:$PATH" "$HOOK")
if [[ $(echo "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason' 2>/dev/null) == *"PR_ALLOW_MAIN=1"* ]]
then PASS=$((PASS+1)); printf '  ok   %-56s kept\n' "a quoted reason keeps the recovery"
else FAIL=$((FAIL+1)); printf '  FAIL %-56s dropped\n' "a quoted reason keeps the recovery"; fi
```

That makes the suite 115 cases, so the README's count and both shapes would move by one.
**Deferring this is equally defensible.** It is a message on a path no real jq is known to reach.

**Learning note:**
A mutation table shows what the suite catches, but only for the mutants someone thought to write.
When a commit's purpose is a specific behaviour, the mutant to write is the code as it stood just
before that commit.

---

🟢 **The summary's size line goes stale once `/pr:close` commits it**

📍 Location: `pr-summary-2026-09-30.md`, "Impact assessment", first bullet

**What I see:** "7 files, 787 lines added and 57 removed. Of those, 571 added lines are the
branch's own plan folder."

**The risk:** it is accurate for `58aee16`. The PR's final diff will also contain the summary
itself and this review, so the file and line totals in the PR body will be low. The code-and-docs
figure of 216 added and 57 removed will stay right. This is cosmetic.

**Suggested fix:** keep only the code-and-docs figure, or recompute the totals after the close
commit. There is a matching wording nit in the CHANGELOG. "The 12 earlier ones plus a separate
mutant for each swap" reads as 14. "The 12 earlier ones, with the swap mutant split in two" says
13.

#### ⏭️ Deferred to follow-up

None new. The pre-test review's two items are filed as #58 and #59. The branch's `PLAN.md`
`## Deferred` entries, keeping `GIT_VERB_RAW` in step and the stale "ships NO test suite"
paragraph, go to `/pr:close` triage as already written.

**Checked and dropped**, noted here so they are not re-tested:

- **`gate()`'s comment overstates slightly.** It says "Everything the no-jq branch passes is a
  fixed literal". But an `ALLOW_NAME` inherited from the environment reaches `stop` there. The
  pre-test review already dropped inherited `ALLOW_NAME`, and the swap keeps the output valid
  either way.
- **Under the `C` locale, invalid UTF-8 tests safe** and would be printed raw. This is the settled
  #1 limitation, and it is not reachable through a branch name on APFS.
- **The suite's new temp directories are never removed**: `BADJQ`, `HALFJQ` and `TOKREPO`. That
  matches the suite's existing convention, which has no cleanup at all.

### Questions

None.

### Verdict

VERDICT: APPROVE

`58aee16` applies both pre-test suggestions correctly. The suite passes 114 of 114, the README's
counts and shapes reproduce exactly, and the PR summary is accurate with no closing keyword. The
two 🟢 items are optional. Proceed with `/pr:close`.
