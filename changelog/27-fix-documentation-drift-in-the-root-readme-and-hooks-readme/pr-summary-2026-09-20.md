# Fix documentation drift in the root README and hooks README

Closes #27.

## Overview

Four documentation-accuracy defects deferred from #11 (PR #25). All four were verified against source when filed and were byte-identical on `main`, so they were pre-existing drift rather than anything that branch introduced.

This branch's entire product is accuracy, so every corrected claim was re-derived from source rather than reasoned about: the probe suite was run, the skill catalog was diffed against the filesystem, the release commands were executed against all four plugins, and the two one-liners were checked against the skill files that implement them. The review gate then re-derived all of it independently, across two passes, and caught three defects this branch had introduced in its own prose — including a miscount in the very paragraph written to correct the previous miscount. All are fixed here; see Plan alignment.

## Key changes

The four items in the ticket:

| File | Change |
|---|---|
| `plugins/pr/hooks/README.md` | Guard probe suite case count, 54 → 73 |
| `README.md` | Root catalog completed with the two missing continuity skills |
| `README.md` | `## Releasing` generalized from bookcraft's paths to a `<plugin>` parameter |
| `README.md` | `code-reviewer` attribution and `/pr:init` label description corrected |

Four more, added at the close triage by operator decision rather than filed as follow-ups:

| File | Change |
|---|---|
| `plugins/pr/hooks/test-guard-default-branch.sh` | Counts skipped cases and prints an invariant total |
| `plugins/pr/hooks/README.md` | Documents the totals line and the `jq` architecture trap |
| `README.md` | `scripts/test-acceptance.sh` added to the layout tree |
| `.claude/settings.json` | New — suppresses AI attribution, per `git-conventions.md:22` |
| `plugins/pr/reference/git-conventions.md` | Its own snippet omitted `sessionUrl`, so it did not achieve what its prose requires |

Plus a comment on issue #5 correcting its stale 54-case figure, left as a comment so the original wording stands.

## Code examples

**The release procedure, before and after.** It named one plugin's paths as *the* procedure though four ship:

```diff
-`plugins/bookcraft/.claude-plugin/plugin.json` carries the version, and it is the source of truth.
+Each plugin releases on its own, and the procedure is the same for all four.
+`plugins/<plugin>/.claude-plugin/plugin.json` carries that plugin's version and is the source of truth for it.

-claude plugin tag plugins/bookcraft
+claude plugin tag plugins/<plugin>
```

The shape question — one parameterized procedure or a per-plugin list — was settled on evidence rather than preference. All four plugins have an identical layout (`plugins/<name>/.claude-plugin/plugin.json` plus one entry in `.claude-plugin/marketplace.json`), so a per-plugin list would have been the same text four times. The new prose also states that versions move independently, which is already true: 1.0.2, 0.1.0, 0.1.0, 0.2.1.

**The `code-reviewer` attribution** credited a component that spawns nothing:

```diff
-    agents/code-reviewer.md       the review agent the close gate spawns
+    agents/code-reviewer.md       the review agent /pr:close and /pr:pre-test spawn
```

The close gate is the `Stop` hook, `verify-close-landed.sh`. It checks that a close landed; it spawns no agent. The real spawn sites are `close/SKILL.md:151-157` (Step 2) and `pre-test/SKILL.md:58-64` (Step 4).

**The `/pr:init` label description** understated the command by more than half:

```diff
-and creates the `status:*` and `priority:*` labels the queue runs on.
+and creates eleven labels: the two `status:*` and three `priority:*` labels the queue runs on,
+plus six type labels — `bug`, `feature`, `refactor`, `docs`, `infra` and `research`.
```

Verified against the creation loop at `init/SKILL.md:106-109`, name for name.

## Plan alignment

All six phases completed as planned, in order, and the objective was delivered before scope was extended.

- **Phase 1 (ground truth)** — ran the probe suite, enumerated the skills, confirmed the four plugins, read the two skill files and the label loop. Both of `PLAN.md`'s open questions were resolved here, neither needing an operator decision.
- **Phases 2–5 (the four edits)** — applied as specified.
- **Phase 6 (re-verification)** — every corrected claim re-checked. `claude plugin validate --strict` passes on the marketplace and all four plugins; `claude plugin tag --help` confirms the `{name}--v{version}` format and the marketplace-agreement check the prose claims.

**One deviation, and it is worth naming.** The ticket's own citations had rotted — four of its five anchors. Issue #27 cites three line numbers and two paths. All three line numbers had moved: the catalog was at `README.md:87` not `:88`, the `code-reviewer` line at `:137` not `:149`, and the `/pr:init` sentence at `:69` not `:71`, where line 71 is inside a code fence. One path is wrong too: `plugins/bookcraft/plugin.json` does not exist on `main` and never did — the manifest is at `plugins/bookcraft/.claude-plugin/plugin.json`. Exactly one anchor survived, `plugins/pr/hooks/README.md`. Edits were anchored on text rather than offsets. `PLAN.md`'s phase text preserves the original numbers as filed, since the objective is immutable.

**Four defects were introduced by this branch and caught before merge** — one by self-review, three by the review gate across two passes:

1. The first draft of the generalized `## Releasing` said to substitute the plugin name "in all three commands" when only two of the three contain `<plugin>`. Caught in Phase 6 self-review.
2. The `/pr:continuity-prune` one-liner omitted that the command lists its targets and asks before deleting — a material omission for a destructive command. Caught at the first review gate.
3. The changelog claimed only one of the ticket's anchors had drifted. Caught at the first review gate.
4. The correction to (3) was itself wrong: it said three anchors had drifted and that both paths held. The real count is four of five. Caught at the second review gate.

That last one is the honest headline of this branch. A documentation-accuracy change miscounted the same paragraph twice, and both times an adversarial gate caught what self-review had just signed off. The gate is load-bearing here, not ceremonial.

**Scope was extended once, at the close triage, by operator decision.** The deferred-work triage normally files survivors as follow-up issues; the operator directed that they be addressed here instead. The four additions are listed in Key changes. The original objective was already complete at that point, so this added work rather than revising it, and `PLAN.md` records the extension separately from the immutable objective.

## Testing

The probe suite gained two skip cases' worth of accounting but no new assertions; everything else is prose. Verification is by re-deriving each claim:

```bash
# 73 cases. Note: the jq first on PATH may be an x86-only binary that
# aborts on Apple Silicon, which drives the failure count up for reasons
# unrelated to the hook. Check `jq --version` before reading a mass failure
# as a regression.
PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
  ./plugins/pr/hooks/test-guard-default-branch.sh ./plugins/pr/hooks/guard-default-branch.sh
# => passed 73, failed 0, skipped 0  (73 cases)

# Catalog completeness: both diffs must be empty.
diff <(ls plugins/pr/skills/ | sed 's|^|/pr:|' | sort) \
     <(grep -o '/pr:[a-z-]*' README.md | sort -u)
# => 22 on disk, 22 named, no difference either direction

# The documented release procedure, against every plugin.
claude plugin validate --strict .
for p in bookcraft council explain pr; do claude plugin validate --strict "plugins/$p"; done
# => all pass
```

The `code-reviewer` and `/pr:init` claims are checked by reading `close/SKILL.md:151-157`, `pre-test/SKILL.md:58-64` and `init/SKILL.md:106-109`.

**The skip path is itself tested**, since it is the case a passing run never exercises:

```bash
# Force the linked-worktree fixture to fail, and confirm the run stays legible.
sed 's|git -C "$WTBASE" worktree add -q -b feature/1-wt "$WT" 2>/dev/null|false|' \
  plugins/pr/hooks/test-guard-default-branch.sh > /tmp/t-skip.sh && chmod +x /tmp/t-skip.sh
PATH="/usr/bin:/bin:/usr/sbin:/sbin" /tmp/t-skip.sh ./plugins/pr/hooks/guard-default-branch.sh
# =>   skip linked worktree resolves main config      (worktree add failed)
# =>   skip linked worktree, feature commit passes    (worktree add failed)
# => passed 71, failed 0, skipped 2  (73 cases)
```

Before this branch that run printed one skip line for two skipped cases and `passed 71, failed 0`, which is indistinguishable from a complete run that lost two cases. The exit code is unchanged: it still keys on the failure count alone, so a skip does not turn the suite red.

## Impact assessment

- **Files changed:** 5 shipped (`README.md`, `plugins/pr/hooks/README.md`, `plugins/pr/hooks/test-guard-default-branch.sh`, `plugins/pr/reference/git-conventions.md`, new `.claude/settings.json`), plus branch artifacts under `changelog/`.
- **Dependencies:** none.
- **Breaking changes:** none.
- **Behavior:** one change, in the probe suite's output only. It counts skips and prints a total; no case's assertion, input or expected result is altered, and the exit code still keys on the failure count alone. `passed 73, failed 0, skipped 0  (73 cases)` on a full run.
- **`.claude/settings.json` is new and affects contributors**, turning off the harness's AI attribution repo-wide. It implements what `plugins/pr/reference/git-conventions.md:22` already required; it does not introduce the policy.
- **Risk:** low and mostly confined to prose. The suite change is the only executable one and is covered by running the suite both ways.

## Deferred work

Triaged at close. The operator directed that the survivors be addressed on this branch rather than filed, so all four were fixed here and are listed in Key changes above. One item dropped:

- **Issue #27's own body cites `plugins/bookcraft/plugin.json`**, which does not exist — the manifest is at `plugins/bookcraft/.claude-plugin/plugin.json`. Dropped: cosmetic once this ticket closes on merge, and no occasion would cause it to be picked up. It is the one stale citation of the four that this branch does not fix, which is the only reason it is recorded at all.

## Assertion audit

`docs.assertionsFile` is `null` in `.claude/pr-config.json`, so the assertions convention is **disabled** for this repo. No audit applies and no entry was written.
