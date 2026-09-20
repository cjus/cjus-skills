## PR review: Fix documentation drift in the root README and hooks README

Reviewed: `1ce4068`, PR #28, base `main`. Scope bound per `PLAN.md`: the four
documentation-accuracy items deferred from #11, and nothing else.

### Summary

Four prose corrections across `README.md` and `plugins/pr/hooks/README.md`, plus the
branch's plan folder. Every factual assertion in the two touched READMEs was independently
re-verified against source during this review, not read for plausibility. **All four items
are correct.** One false claim was found, and it is in the branch's own `CHANGELOG.md`
rather than in the shipped prose.

### Verification performed

Each claim re-derived from source in this worktree rather than from the commit message.

| Claim | Method | Result |
|---|---|---|
| Guard suite is 73 cases | Ran `test-guard-default-branch.sh` with `PATH=/usr/bin:...` | `passed 73, failed 0` ✅ |
| Catalog is complete | `comm` of every `/pr:*` in `README.md` against `ls plugins/pr/skills/` | 22 vs 22, **no difference in either direction** ✅ |
| `/pr:continuity-add` is `/pr:close`'s handoff step | `close/SKILL.md:271` invokes it; `continuity-add/SKILL.md:3` says so | ✅ |
| "repo-root continuity folder" | `docs.continuityRoot` default `"continuity"`, resolved from `git rev-parse --show-toplevel` | ✅ |
| `/pr:continuity-prune` deletes by date | `continuity-prune/SKILL.md:16` — strictly older than `$1` | ✅ |
| Tag format `<plugin>--v<version>` | `claude plugin tag --help`; `--dry-run` on all four printed `council--v0.1.0`, `explain--v0.1.0`, `pr--v0.2.1` | ✅ |
| Marketplace-agreement check | `tag --help`: "validating that plugin.json and any enclosing marketplace entry agree" | ✅ |
| Four plugins share an identical layout | All four have `plugins/<n>/.claude-plugin/plugin.json` + exactly one `marketplace.json` entry | ✅ |
| Bare `.` validates the marketplace | `claude plugin validate --strict .` printed "Validating marketplace manifest: .../.claude-plugin/marketplace.json" | ✅ |
| `--strict` passes everywhere | Marketplace + all four plugins | 5/5 passed ✅ |
| Versions cited (1.0.2, 0.1.0, 0.1.0, 0.2.1) | Read from each `plugin.json` | ✅ current |
| "Tagging one leaves the other three untouched" | Per-plugin tag names; `bookcraft--v1.0.2` already exists while the other three do not | ✅ |
| `code-reviewer` spawned by close Step 2 | `close/SKILL.md:151` `## Step 2. Review gate`, `:157` spawns the `Agent` | ✅ |
| …and by pre-test Step 4 | `pre-test/SKILL.md:58` `## Step 4. Run the checks`, `:64` spawns the `Agent` | ✅ |
| …and **not** by the close gate | `verify-close-landed.sh` contains no agent dispatch; it only blocks a `Stop` | ✅ |
| `/pr:init` creates eleven labels | `init/SKILL.md:106-109` loop: 2 `status:*`, 3 `priority:*`, 6 type | ✅ exactly eleven, names match the README one for one |
| Ticket anchors 87 and 137 had drifted | `git show main:README.md` | ✅ both correct as stated |

Two further cross-checks: no live document anywhere in the repo still claims 54 cases (the
only remaining hits are historical records in #11's plan folder, where they are correct as
history), and `plugins/pr/README.md:142` already described the type labels, so this branch
closes a divergence between the two READMEs rather than opening one.

### What is working well

- **The suite was run, not cited.** The `73` came from execution, and the `31/42` first run
  was diagnosed to an x86 `jq` on an arm64 host rather than logged as a suite failure. I
  reproduced both halves: `/usr/local/bin/jq` really is `Mach-O 64-bit executable x86_64`,
  `/usr/bin/jq` is `jq-1.7.1-apple`. `31 + 42 = 73` — the count is invariant under the
  environment fault, which is exactly why the number was safe to write down.
- **The catalog fix was closed with a diff, not a spot check.** Verifying completeness by
  differencing both directions is what turns "I added the two I knew about" into "the
  catalog is now provably complete". It caught nothing extra, which is the point: the
  absence of a result is the evidence.
- **The two continuity skills got a clause that says what they operate on**, rather than
  being appended to the queue clause where they do not belong. Naming `/pr:continuity-add`'s
  double life as `/pr:close`'s handoff step is real information a reader cannot get from the
  skill name.
- **`## Releasing` was generalized on evidence rather than taste.** The identical-layout
  finding is what makes one parameterized procedure correct instead of four copies, and
  calling out the bare `.` as deliberately *not* parameterized pre-empts the single most
  likely misreading of the new text — a reader who substitutes mechanically would otherwise
  write `claude plugin validate --strict plugins/pr` twice and never check the marketplace.
- **A self-introduced defect was caught before commit.** The "in all three commands" → 
  "throughout" correction in Phase 6 is the branch's own accuracy bar catching the branch.
  The final wording is right: three commands, two carry `<plugin>`.
- **The line-number drift was noticed and the edits anchored on text instead.** The right
  reflex, and the right lesson to record.

### Issues found

#### Critical

None.

#### Important

🟡 **The CHANGELOG states one of the three ticket anchors was still correct; none of them was**

📍 Location: `changelog/27-fix-documentation-drift-in-the-root-readme-and-hooks-readme/CHANGELOG.md:16-17`

**What I see:**

> Two of the four anchors were wrong by the time the work started: the root catalog is at
> `README.md:87`, not `:88`, and the `code-reviewer` one-liner is at `README.md:137`, not
> `:149`. **Only the `/pr:init` anchor at `:71` was still correct.**

**The risk:**

`README.md:71` on `main` is an opening code fence. The `/pr:init` sentence is at **line 69**:

```
69: Run `/pr:init` once per repo. It detects what it can, ...
70:
71: ```
72: /pr:init → /pr:ticket → /pr:start → [ work ] → ...
```

I traced it across every commit in #11's history — `654c40e`, `b81f036`, `02a6603`,
`91369c5` and `main` — and it is line 69 in all of them. `:71` was not "still correct"; it
had drifted by two lines for the same reason the other two had, and on no landed commit did
it ever point at that sentence.

This is narrow but it lands in the worst possible place. The paragraph's own closing line is
*"A documentation-accuracy ticket whose own citations rot is the argument for anchoring on
text rather than line numbers"* — and the sentence that sets up that lesson gets one of its
three data points wrong. It is also the one finding on this branch that fails the standard
the branch itself set: every other number here was derived from source, and this one was
not. The count in the preceding sentence goes with it — it is three of the four anchors that
had drifted, not two.

**Suggested fix:**

> Three of the four anchors were wrong by the time the work started: the root catalog is at
> `README.md:87`, not `:88`; the `code-reviewer` one-liner is at `:137`, not `:149`; and the
> `/pr:init` one-liner is at `:69`, not `:71`. Only the hooks README's anchor, which was
> recorded as text rather than an offset, survived.

**Learning note:**

The claims most likely to go unverified are the ones about your own process rather than
about the code — they feel like recollection, so they never get routed through the same
"derive it from source" check the subject-matter claims get. When a document's thesis is
that citations rot, the citations *in that sentence* are the ones a reader will spot-check
first.

#### Suggestions

🟢 **The `/pr:continuity-prune` one-liner omits that it asks before deleting**

📍 Location: `README.md:87`

**What I see:** "`/pr:continuity-prune`, which deletes entries older than a date you give
it."

**The risk:** Nothing false — it does exactly that. But the skill is
`disable-model-invocation: true`, shows the candidate list, and asks first
(`continuity-prune/SKILL.md:13-14`). The catalog line reads as an unattended delete, which
is the one property a reader most wants to know about the only destructive skill in the
plugin.

**Suggested fix:** "…which lists the entries older than a date you give it and deletes them
once you confirm."

**Learning note:** For a destructive operation, the guardrail is part of the one-line
description, not a detail the full docs can carry alone — a reader deciding whether to type
the command is deciding on the strength of that line.

#### ⏭️ Deferred to follow-up

- **`plugins/pr/scripts/test-acceptance.sh` is missing from the root layout tree** —
  `README.md:133` lists only `scripts/pr-lifecycle-state.mjs` under `pr/`, while the
  `council/` block two entries up does list its `scripts/test-*.sh`. Adjacent to the
  `agents/code-reviewer.md` line this branch edited, but outside the four-item bound.
  Symptom: a reader of the root layout does not learn the plugin ships an acceptance suite
  that `plugins/pr/hooks/README.md:143` tells them to run. Occasion: the next edit to the
  `## Layout` block. theme: root README layout tree completeness
- **"73 cases" is exact only when the linked-worktree fixture can be created** —
  `plugins/pr/hooks/README.md:134`; `test-guard-default-branch.sh:198-203` skips two probes
  and prints `skip` when `git worktree add` fails, so that run reports 71. Symptom: a
  maintainer on such a machine sees 71 and cannot tell a stale doc from lost coverage, which
  is the exact confusion this ticket was filed to remove. Occasion: the next edit to the
  guard suite, where making the suite print its own total would retire the claim for good.
  theme: guard suite case-count durability
- **Issue #5's body still records the suite as 54 cases** — verified against the live issue:
  "The suite is at 54 cases and its convention is that every defence is pinned by a probe."
  Already parked in `PLAN.md § Deferred`; outside the two-README scope bound. Symptom: the
  next person to pick up #5 sizes the suite from a number that is 19 cases stale. Occasion:
  when #5 is next triaged — a one-line issue-body edit. theme: guard suite case-count
  durability

Noted and **dropped**, not deferred: the layout tree's `reference/*.md` under `pr/` does not
account for `reference/pr-config.schema.json`, which is not a `.md` file — arguable at best
and the gloss "the rules the skills cite" still holds. Also dropped: the root `### pr`
section's "two labels carry state" sits a line above the new eleven-label sentence and could
read as a contradiction, but it is correct (`status:*` and `priority:*` are what the queue
runs on) and it is pre-existing text on `main`.

### Questions

1. **The commit carries `Co-Authored-By: Claude Opus 5 (1M context)`, which this repo's own
   `plugins/pr/reference/git-conventions.md` forbids** — "Commit messages, commit trailers,
   PR titles and PR bodies carry **no** co-author line naming an AI… This holds even when
   the harness's own default attribution behavior would add one." Precedent on `main` is
   genuinely mixed: 17 of 59 commits carry the trailer, including `c171320`, while #11's own
   three commits do not. I am not raising this as a finding, because the harness instruction
   and the repo document point opposite ways and only you can say which governs here. But
   the repo ships that convention as documentation other repos will follow, and this is a
   docs-fidelity branch — worth settling once. The doc names the fix:
   `{"attribution": {"commit": "", "pr": ""}}` in `.claude/settings.json`, which this repo
   does not currently have (`.claude/` holds only `pr-config.json`).
2. Was `README.md:71` perhaps correct in some working state during #11 that I cannot see
   from the landed commits? #11's own review file cites `:71`, so the number came from
   somewhere — but it is 69 on every commit that landed, which is the frame the CHANGELOG
   sentence uses for its other two corrections.

### Verdict

VERDICT: NEEDS_DISCUSSION

The four shipped corrections are all true against source, independently re-derived rather
than taken on the commit message's word — the README work is done and correct. The single
blocker is one false sentence the branch itself introduced at `CHANGELOG.md:16-17`, in a
branch whose objective is eliminating false sentences. It is a two-word fix. Correct it and
this is an `APPROVE`; the three ⏭️ items and the one 🟢 never blocked.
