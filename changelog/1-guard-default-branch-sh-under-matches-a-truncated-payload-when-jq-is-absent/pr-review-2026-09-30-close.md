# PR review (close pass): [#1] guard-default-branch.sh under-matches a truncated payload when jq is absent

PR cjus/cjus-skills#53 (draft) · branch `feature/1-guard-default-branch-sh-under-matches-a-truncated-payload-when-jq-is-absent`
· base `main` · reviewed 2026-09-30 · commit `105ee29` plus uncommitted edits to the hooks README,
the hook and the suite · ticket cjus/cjus-skills#1

## Summary

This is a delta review. The earlier review this session (`pr-review-2026-09-30.md`) returned
APPROVE with one Important and three Suggestions. All four were applied as uncommitted edits, and
its two pre-existing fail-opens were escalated as cjus/cjus-skills#54. This pass checks those four
edits for correctness and accuracy, and checks `pr-summary-2026-09-30.md` against the code and for
closing keywords. It does not re-audit the PR.

**Scope, as applied.** Everything the earlier review settled stays settled. The two fail-opens now
tracked in cjus/cjus-skills#54 are **not** re-raised. The three items under `PLAN.md`
`## Deferred` stand as written. `docs.assertionsFile` is `null`, so there is no assertions file to
audit.

**What I verified rather than assumed:**

- **Suite.** 91/91 on the working tree (macOS, bash 3.2). `bash -n` is clean on the hook.
- **Diffstat.** `main` against the working tree, under `plugins/pr`: four files, 157 insertions
  and 16 deletions. That matches the summary exactly.
- **All three README mass-failure shapes, reproduced and itemised.** A broken jq was a shim that
  exits 126 with `Bad CPU type in executable`, placed first on `PATH`. A missing jq was a folder of
  links to every executable on `PATH` except `jq`.
  - Broken jq: **33/58**.
  - Missing jq, run from outside a configured repo with `CLAUDE_PROJECT_DIR` unset: **33/58**.
  - Missing jq, run from the worktree root with `CLAUDE_PROJECT_DIR` unset: **6/85**.
  - Missing jq, run from outside a configured repo with `CLAUDE_PROJECT_DIR` pointed at a
    configured one: **6/85**. This is the new README claim that activation resolves through
    `CLAUDE_PROJECT_DIR` first, and it holds.
  - In **every** shape, exactly two cases pass inside the no-jq sections: "jq is hidden from the
    hook" and "truncated, unconfigured repo is inert".
  - With broken jq, every pass outside those sections is a case that expects no output.
  - In the 6/85 shape, the four passes outside those sections are the three malformed-payload
    cases that point `CLAUDE_PROJECT_DIR` at `$NOCFG` and "empty payload cwd, unconfigured
    project dir". Those are exactly "the cases that point `CLAUDE_PROJECT_DIR` at an unconfigured
    repo".
- **The blind-spot wording, probed.** See the one Suggestion below.
- **cjus/cjus-skills#54** is open, labelled `bug` and `priority:high`, and carries the two-item
  checklist that the CHANGELOG and the summary describe.
- **Closing keywords in the summary.** None. The file's only issue reference is `#54`, as a plain
  mention: "both went into one issue, #54". Nothing auto-closes. The draft PR body is still the
  pre-test placeholder, which `/pr:close` replaces and to which it adds the ticket's closing
  reference.

## What is working well

- **The README fix is the exact claim the suite proves.** "gets the decision it always did" now
  matches the suite's own section header, "behaves as it always did". The parity claim is gone.
- **The mass-failure paragraph is now right case by case, not only in its totals.** Splitting it
  into "what the no-jq sections do in every shape" and "where the shapes differ" is the structure
  that two harnesses needed. I reproduced each clause, including the `CLAUDE_PROJECT_DIR` route,
  which the earlier text left out.
- **The schema-assumption comment is accurate and well aimed.** It names the dependency: the
  closing-quote half proves the *command* closed only if `command` is a unique key. It explains
  why string contents cannot match. And it says precisely which change would break it: a key
  named `command` *ahead of* tool_input's. "Ahead" is the right word. Bash's regex takes the
  leftmost match, and when the real command is cut, nothing after it exists to match.
- **The CHANGELOG entry records the escalation as an escalation**, with the issue number and a
  note that both fail-opens were reproduced independently rather than taken on the reviewer's word.

## Verification of the four applications

| Earlier finding | Applied at | Verdict |
|---|---|---|
| 🟡 README claimed jq parity for a whole payload | `plugins/pr/hooks/README.md:L139-L140` | Correct and accurate |
| 🟢 Mass-failure explanation off for the no-jq sections | `plugins/pr/hooks/README.md:L167-L182` | Correct and accurate; every clause reproduced |
| 🟢 Blind-spot comment described one cut, not a class | `plugins/pr/hooks/guard-default-branch.sh:L260-L262`, suite `L336-L338` | Class now named correctly; one word overclaims (see Suggestion) |
| 🟢 Name the uniqueness assumption | `plugins/pr/hooks/guard-default-branch.sh:L254-L258` | Correct and accurate |

## Issues found

#### Critical

None.

#### Important

None.

#### Suggestions

🟢 **"Every test below reads exactly what the whole payload would give it" is not true of GIT_VERB
for the second class of cut the comment names**

📍 Location: `plugins/pr/hooks/guard-default-branch.sh:L260-L262`

This is my own wording from the earlier review, applied faithfully, so the correction is mine.

**What I see:**

```
# The cuts both halves pass land just after a `}` that follows the command's close:
# tool_input's own, or one inside a later value. The command is whole there, so every
# test below reads exactly what the whole payload would give it. The suite pins one.
```

**The risk:**
The token and mode tests read only the command and `permission_mode`, so for them the claim holds.
GIT_VERB, however, runs on `$INPUT`, the whole raw payload (`L313`), and not on the command. When
the cut lands on a `}` inside a later value, GIT_VERB loses the rest of that value. Measured with
jq hidden and a configured repo as the project dir:

| payload | no jq | jq |
|---|---|---|
| command `ls`, description `a } then git commit -m x`, whole | `ask` (over-match on the description) | `pass` |
| the same, cut just after the `}` in the description | `pass` | — |

The decisions differ, so "exactly" is false. It is **harmless**, and the comment's conclusion
stands. The command is whole, so any verb inside it matches identically. A cut can drop only an
over-match on later text, which the jq path would not gate anyway, and a cut that ends in `}`
cannot create a new match. The problem is only that the comment states a stronger invariant than
the code keeps. In a file whose header says that reading it is not evidence, that is exactly the
kind of sentence a later editor leans on.

The suite's comment at `test-guard-default-branch.sh:L336-L338` describes only its own case, a
cut after tool_input that drops `,"tool_use_id":"t"}`. There the claim holds in effect, so that
comment can stay.

**Suggested fix:**

```
# The cuts both halves pass land just after a `}` that follows the command's close:
# tool_input's own, or one inside a later value. The command is whole there, so every
# test below still reads all of it. A cut can drop only text after the command, and
# with it only a match GIT_VERB would have over-made there, one the jq path would not
# gate either. The suite pins the first.
```

If you take it, the CHANGELOG bullet that says the comment now guarantees "every later test reads
what the whole payload would give it" needs the same change.

**Learning note:**
The earlier review's advice was to state the invariant, not one outcome. The follow-on is to state
the invariant the code *actually keeps*. Here that is "the command is read whole", not "the input
is identical". The difference only shows up when you check which variable each test reads:
`$INPUT` rather than the command.

#### ⏭️ Deferred to follow-up

None new. The two fail-opens in cjus/cjus-skills#54 are escalated, not re-raised here. The three
`PLAN.md` `## Deferred` items stand as written.

## PR summary check (`pr-summary-2026-09-30.md`)

Accurate against the code, with no closing keyword. Specifically:

- The check snippet matches `guard-default-branch.sh:L274-L278` verbatim.
- 73 → 91 is 18 cases: the jq-hidden check plus 4, 5 and 8. The "Six of them fail against the
  unfixed hook" line is right. The two truncation-section cases that do not expect `deny` pass on
  `main`.
- The mutation table matches the CHANGELOG's seven rows. The 157/16 diffstat and the four files
  are right. CI's two `fixtures` jobs pass. The 0.08s cost figure matches the CHANGELOG, and it
  is consistent with the hook's "under 0.1s".
- The Deferred section describes cjus/cjus-skills#54 correctly and credits the drop of the CI
  item to the reviewer, which is accurate.
- DROP-level nit, no action needed: the bullet list reads "4 cases, 5 cases, 8 cases", which sums
  to 17. The first-case sentence just above it supplies the 18th.

## Questions

None.

## Verdict

VERDICT: APPROVE

All four review findings were applied correctly, and the README paragraph is now accurate in every
clause I measured. The one remaining wording nit is optional. Proceed with `/pr:close`.
