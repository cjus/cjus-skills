# Finish the council plugin port: phases 3-9

Start date: 2026-09-18 14:33:00 MDT

Ticket: [#22](https://github.com/cjus/cjus-skills/issues/22)

## Overview

Take `plugins/council/` from installable-but-incomplete to complete. Two predecessor branches
delivered it in partial passes: #9 (PR #13) landed the mechanical layer alone, and #14 (PR #21)
landed phases 1 and 2 — the three skill directories, `reference/roster.example.json`, the
marketplace entry, the private-material strip, and `openrouter.mjs` ported off the host repo.

The remaining gap is `scripts/detect.sh`. Without it, the detection block in `skills/ask` and
`skills/setup` always falls through to `detection unavailable`. It degrades cleanly, but no
external provider that needs a local binary or a reachable endpoint can be detected until
phase 3 lands.

This branch lands phases 3 through 8. **Phase 9 is deliberately absent**: it was split at the
repo boundary on #14, and its cjus-dev half is filed separately in that repo.

The nine-phase plan and the five settled design decisions live in
`changelog/14-finish-the-council-plugin-port-phases-2-9/PLAN.md` and are carried forward rather
than restated. Read that file before starting a phase.

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred`, never as new scope.

## Plan

- [x] **Phase 3** — port `detect.sh`, sourcing `council-lib.sh` so the key chain is not
      implemented a third time, and have it report which source won. Replay `test-env.sh`'s
      oracle table against it. **Landed 2026-09-18.**
- [x] **Phase 4** — have `skills/ask` call `council-state.sh` instead of re-deriving seating,
      move the four Claude defaults into the join per the recorded decision, and delete the
      unused `env.mjs:rosterPath`. **Landed 2026-09-18.**
- [x] **Phase 5** — the `COLLAPSED` correlation class, cost statement extended to `pooled`,
      per-choice cost in `/council:setup`. **Landed 2026-09-19**, after settling the open
      question by experiment. One of Decision 1's four bullets moves to phase 7 (the README
      cost block) and one had already landed in phase 1; see the decision below.
- [x] **Phase 6** — split the reference docs out of `SKILL.md` into `reference/providers.md`,
      `reference/trust-boundary.md` and `reference/roster.md`, keeping the honesty contract
      and output contract inline. **Landed 2026-09-19.**
- [x] **Phase 7** — `plugins/council/README.md` plus the repo-root README section and Layout
      block, including the plan-dependence note that the per-member model pins
      (`opus`/`sonnet`/`haiku`/`fable`) are not guaranteed to resolve on every plan.
      **Also inherits Decision 1's "What it costs" block**, which phase 5 could not land
      because no README existed: the structural multiplier, roughly 4x a normal turn and 8x
      for `pooled`, with no dollar figure and no token estimate. **Landed 2026-09-19.**
- [ ] **Phase 8** — `detect.sh` probes and `openrouter.mjs` exit-code tests.

## Status

Updated 2026-09-18. Status only; the objective and the six phases above are unchanged.

**Phase 3 is complete.** `scripts/detect.sh` exists, so the detection block in `skills/ask`
and `skills/setup` no longer falls through to `detection unavailable`. The script sources
`council-lib.sh` rather than re-deriving the key chain, and `scripts/test-detect.sh` replays
`test-env.sh`'s oracle table against **what detect.sh prints**, not against the library
variable — the printed line is what reaches the model's context, and a correct library behind
a wrong render is the same defect to the reader.

Three suites pass at 40, 46 and 81 cases; `claude plugin validate --strict` passes for both
the plugin and the marketplace. `detect.sh` produces byte-identical output under `dash`, `ksh`,
`bash` and `zsh`.

The port closes one real divergence and carries three fixes over from the sibling script. The
divergence: the original's `grep` did not accept `export KEY=value`, so detect.sh printed
"absent -- do NOT seat" for a key `openrouter.mjs` resolved and spent. The three carried
fixes: the probe URL now travels on stdin via `curl -K -` instead of argv, where basic-auth
userinfo was visible in the process table; the roster path now resolves `$XDG_CONFIG_HOME`,
which the original ignored; and a roster that exists but cannot be read now reports as
unreadable rather than printing an empty summary that reads like an empty roster.

**Phase 4 is complete.** `skills/ask` runs `council-state.sh --json` and seats `.seated[]`
rather than reading the roster and performing the consent-by-availability join in prose. The
four Claude defaults are declared once, in `council-lib.sh:council_default_members`, and an
absent roster now seats them and projects `HOMOGENEOUS (anthropic)` instead of reporting
`0 seated`, which contradicted the `Claude-only council` line two rows above it.
`env.mjs:rosterPath` is deleted; it had no callers and was the only reason a second roster-path
resolver existed.

Two suites grew: `test-council-state.sh` is at 91 cases, including one that diffs the seating
against `council_default_members` directly, so a second copy of the default list fails rather
than drifting silently.

**The question the decision left open is settled: `/council:ask` does not own the right to seat
a different set.** One declaration, both readers. The skill lists the four defaults so a reader
can recognise them and says explicitly that they are not there to be seated from.

Phase 4 also removed a piece of prose that had gone stale: the detection block's fall-through
branch told the skill to "proceed without `codex` or `ollama`" when detection was unavailable.
That was correct when the skill derived seating from the block, and wrong once the join does
its own `council_find_bin codex` and its own endpoint probe. The block is now documented as
context, not a decision.

**Phase 5 is complete**, and the open question it was blocked on is settled by experiment
rather than by argument — see the decision below. The short version: `COLLAPSED` was two
failures under one name. An unacceptable pin is now caught mechanically in the join, because
the harness's `model` parameter is a closed enum of exactly the four values the council pins;
a genuine collapse is reported from member self-report, and only a full collapse counts as
confirmed. What the experiment could not settle — what a valid-but-unavailable pin does — is
recorded as still open, and nothing shipped depends on assuming an answer.

Two suites now stand at 99 and 40 cases.

**Phase 6 is complete.** `skills/ask/SKILL.md` is 370 lines, down from 460, and the three
reference files carry what moved out: `reference/roster.md` (the roster format, the three
roster states, the join's JSON contract, the pin rules), `reference/providers.md` (how to call
each external member, with exit codes, timeouts and costs) and `reference/trust-boundary.md`
(attachment limits, the `git config filter.*` check, why the two notices differ).

The honesty contract and the output contract stayed inline, as the phase requires. So did two
things the phase did not name but that the same reasoning covers: the **two untrusted-content
notices**, because they must be emitted verbatim and a control that needs a file read first is
a control that gets skipped; and the **stance table**, because it is consulted on every run and
moving it would have bought four lines at the cost of a read.

Two things the split surfaced and fixed. A skill lives in `skills/<name>/`, so the bare
`reference/…` paths the first pass wrote would have resolved nowhere — they now use
`${CLAUDE_PLUGIN_ROOT}/reference/…`, matching how `skills/setup` already cites the example
roster. And the transplanted provider section arrived carrying prose that had stayed inline,
so `providers.md` briefly held a second copy of the opt-in rationale and the not-seated rule;
both were cut.

`skills/setup` and `skills/status` now point at `reference/roster.md` as well, so the roster
format is documented in one place for all three skills.

**Phase 7 is complete.** `plugins/council/README.md` is 194 lines, following the house style
`plugins/explain/README.md` sets, and the repo-root README gains a `### council` section and a
Layout entry, both placed alphabetically.

Decision 1's **What it costs** block leads the README, ahead of Install, as the decision
specified: the multiplier as Nx and 2Nx, about 4x and 8x at the default four members, with no
dollar figure and no token estimate anywhere.

The plan-dependence note the phase requires is under `## Limitations`, and it states the split
phase 5 established rather than the vaguer version the plan inherited: a pin outside
`opus|sonnet|haiku|fable` fails loudly before any model runs and the join unseats it, while a
valid-but-unserved pin is the case that remains undetermined — so the plugin asks members and
reports `COLLAPSED` only on a full collapse.

Two things verified rather than assumed while writing it. **A Claude-only council needs neither
`jq` nor Node**: `council_roster_rows` is called only from the roster-present branch
(`council-state.sh:95`, inside the `else` at :89), so an absent roster never reaches a parser.
And the "What ships here" tree was diffed against `find plugins/council -type f`, which matches
at 18 files.

Two judgement calls worth recording. The per-suite case counts were written in and then taken
out: **phase 8 adds cases to two of those three suites**, so a README citing 99/40/46 would
have been stale within the branch. And the root README stated "a skill refers to its own files
through `${CLAUDE_PLUGIN_ROOT}`" twice in adjacent paragraphs — deduplicated while adding the
council entry beside it, with the surviving sentence generalised to cover both plugins that now
ship a `reference/` directory.

Next is phase 8, the last phase on this branch: `detect.sh` probes and `openrouter.mjs`
exit-code tests.

## Open Questions

- ~~**What mechanism makes `COLLAPSED` observable?**~~ **Resolved 2026-09-19 by experiment:
      split the question in two and ship the half that is observable.** See
      `## Decision — COLLAPSED splits into a checkable half and a reported half` below.

- [ ] **Needs an operator decision: `M=`/`P=` env prefixes defeat an `allowed-tools` prefix
      rule.** `skills/ask` instructs
      `M=<model> P=<file> node "${CLAUDE_PLUGIN_ROOT}/scripts/openrouter.mjs"`. Claude Code
      strips a leading assignment only for known-safe variables, so `Bash(node:*)` does not
      match and every OpenRouter member prompts. A narrower rule cannot help, because
      `${CLAUDE_PLUGIN_ROOT}` does not expand in a permission pattern.

      The fix worth considering is giving `openrouter.mjs` a `--model` / `--prompt-file`
      interface. It costs nothing in secrecy — only the key must stay out of argv, and it
      already is — but it changes a shipped interface that phase 8 is meant to test, so the
      call belongs to the operator rather than to whoever picks up phase 3.

## Decision — COLLAPSED splits into a checkable half and a reported half

Settled 2026-09-19, by running the experiment rather than reasoning about it.

The question assumed one mechanism was needed. Probing the live Agent tool showed there are
**two different failures** wearing one name, and only one of them needed a mechanism at all.

### What the experiment found

Five spawns: one per pin, plus one deliberately invalid value.

| `model` passed | Result |
|---|---|
| `opus` | Claude Opus 5 (1M context), `claude-opus-5[1m]` |
| `sonnet` | Sonnet 5 |
| `haiku` | Claude Haiku 4.5, `claude-haiku-4-5-20251001` |
| `fable` | Claude Fable 5.1, `claude-fable-5-1` |
| `opus-4.5` | `InputValidationError`, before any model ran |

Three facts came out of it:

1. **`model` is a closed enum, and it is exactly `opus|sonnet|haiku|fable`** — the same four
   the council pins. An unacceptable value fails at the tool boundary, with no model involved.
2. **The roster's `model` field is free-form JSON**, so an unacceptable pin is a typo anyone
   can make, and it would previously have surfaced as an `InputValidationError` partway
   through a fan-out that had already begun spending.
3. **All four pins resolve on this account**, giving four distinct identities, three of them
   different from the session model.

### What it did NOT settle, and the plan does not pretend otherwise

The original framing — what happens when a pin is *valid but unavailable on the plan* — is
**still unanswered**, because all four enum values resolve here and there was no valid-but-
unserved model to probe with. That needs a restricted plan to test on, or an answer from
Claude Code's own documentation. Nothing below depends on assuming it either way.

### The resolution

**The unacceptable-pin half is now checked mechanically, in the join.** `council-state.sh`
validates every Claude member's `model` against `council-lib.sh:COUNCIL_ACCEPTED_PINS` and
unseats a bad one with a reason that names the accepted set — the same shape `no key resolves`
already uses, so it stays out of the participation invariant and out of `DEGRADED`. This is
pure observation; no self-report is involved. `/council:setup` also refuses to write such a
pin, so the tool cannot author the roster its own join would reject.

**The collapse half is reported from member self-report, scoped honestly.** Each member ends
its reply with a `MODEL:` line; the skill strips it before reconciling and compares the set
against the pins passed, in three states: confirmed distinct, `COLLAPSED`, or unverified.

Only a **full** collapse is treated as established — every member independently agreeing it is
the session model is hard to get wrong in the same direction. Any partial mismatch is
`unverified`, because one loose self-description is far likelier than a half-collapse. That is
the same three-state discipline `council-state.sh` already applies to the Ollama probe, where
`unknown` is kept out of both confident branches.

**A correction to this plan's earlier reasoning.** The #14 decision called member self-report
"the likely mechanism" and this branch's own analysis then argued against it as introspection
rather than observation. The experiment weakened that objection: all four members named
themselves specifically and correctly, and one cited its system prompt as the source, which
suggests the harness *tells* a subagent its model rather than leaving it to infer. That makes
self-report closer to reading a supplied fact than to guessing. It is still not proof, which is
why it carries only the full-collapse case.

### Where the class lives

In `skills/ask`, not in `council-state.sh`. The script runs before anyone answers, so its
existing "projected" caveat is correct and was left alone. `skills/status` now points at
`/council:ask` for the confirmation it cannot perform itself.

### Two Decision 1 bullets that are not phase 5 work

- **The README "What it costs" block is phase 7.** Decision 1 opens with it, and there is no
  `plugins/council/README.md` yet. Carried to phase 7 so it is not lost: state the structural
  multiplier, roughly 4x a normal turn and 8x for `pooled`, with no dollar figure and no token
  estimate.
- **Per-choice cost in `/council:setup` already landed in phase 1.** `skills/setup` states the
  Claude member count's cost inside the `AskUserQuestion` bullet that offers it, which is what
  the bullet asked for. Verified rather than redone.

## Related tickets

- **[#15](https://github.com/cjus/cjus-skills/issues/15)** (`priority:medium`) — seven defects
      in the mechanical layer. One of them, `council_normalize_endpoint` mangling a path
      endpoint and failing to bracket IPv6, names its occasion as "when `detect.sh` lands and
      shares the helper" — which is this branch's phase 3. Decide at that point whether the fix
      belongs here or stays on its own ticket; it is not in this branch's objective either way.

## Deferred

Raised while landing a phase. Each is recorded here and triaged at `/pr:close`; nothing here
is in this branch's objective.

### A binary that cannot exec is selected anyway, and the roster gets blamed for it

Found 2026-09-19 while verifying phase 5, on the operator's own machine. Three defects
stacked, and the third is the one that matters.

`/usr/local/bin/jq` here is an x86_64 binary on an arm64 machine. It cannot run — the shell
returns 127, "bad CPU type in executable" — while a working `/usr/bin/jq` and a working `node`
sit on the same `PATH`.

1. **`council_find_bin` accepts it.** It tests `[ -x "$_p" ]`, which a wrong-architecture
   binary passes: the mode bits are fine, the exec is not.
2. **`council_json_backend` therefore selects jq and never falls back to node**, although node
   is present and would have read the roster correctly. "Requiring either is strictly weaker
   than requiring one" is the design's stated claim, and this is the case where it does not
   hold.
3. **The error blames the user's file.** `council_roster_rows` maps *any* non-zero jq status to
   `not valid JSON, or not a JSON object`, so a perfectly valid roster is reported as malformed
   and `/council:status` exits 2. The reader is sent to inspect a correct file while the actual
   fault is a broken tool install.

*symptom:* on a machine with a wrong-architecture jq, `/council:status` and `skills/ask` refuse
to report seating and blame the roster. Both suites also fail wholesale, which is how this was
noticed: 59 of 81 cases failed before the real cause was visible.
*occasion:* any machine carrying a stale Homebrew or Rosetta-era binary earlier on `PATH` than
a working one. Not exotic — `/usr/local/bin` precedes `/usr/bin` in the default macOS `PATH`.

The fix has two halves, and the second is worth more than the first. Distinguish "the backend
could not run" (127/126) from "the backend ran and rejected the file", so the message names the
right culprit; and on the could-not-run case, fall through to the next backend rather than
failing, which is what makes the either-parser claim true. A cheap version of the first half is
to have `council_find_bin` verify exec rather than the mode bit for the backends it selects.

This is adjacent to [#15](https://github.com/cjus/cjus-skills/issues/15)'s backend-parity items
but distinct from all of them: those are about the two backends *disagreeing*, this is about
which one gets *chosen*. Not in this branch's objective, so it is recorded here for triage at
`/pr:close` rather than fixed in phase 5.

### `council_normalize_endpoint` is now live, and still mangles a path endpoint

Surfaced 2026-09-18 by phase 3, which is the occasion [#15](https://github.com/cjus/cjus-skills/issues/15)
named for this defect: "when `detect.sh` lands and shares the helper". **The fix stays on #15.**

`detect.sh` now calls `council_normalize_endpoint`, so the defect has a second caller and a
second symptom. It is not a regression — the original's own inline normalization had the same
two bugs, so sharing the helper carried the behavior across rather than introducing it:

- `myserver/ollama` becomes `http://myserver/ollama:11434`, so a reverse-proxied endpoint is
  probed at a URL that cannot answer.
- `::1` is left unbracketed, so an IPv6 literal does not resolve.

`detect.sh`'s own scheme-without-a-port warning has the matching IPv6 hole: the glob
`*:[0-9]*` matches `[::1]` on the `:1`, so a bracketed IPv6 host with no port is read as
having one and the warning does not fire. Fix it in the same pass as the helper, since one
without the other leaves the other half silent.

Per #15's note on the test approach, the fix belongs in the fixture table rather than in an
edited assertion — `test-detect.sh` and `test-council-state.sh` both need the row, because
both callers must agree.

## About Ticket

**#22 — Finish the council plugin port: phases 3-9**
https://github.com/cjus/cjus-skills/issues/22 · `status:in-progress`, `priority:high`, `feature`

Successor to #14, which delivered phases 1 and 2 and closed on merge of PR #21.

The plugin is now **installable but incomplete**. `scripts/detect.sh` does not exist, so the
detection block in `skills/ask` and `skills/setup` always falls through to
`detection unavailable`. It degrades cleanly, but no external provider that needs a local
binary or a reachable endpoint can be detected until phase 3 lands.

The full plan and the five settled design decisions live in
`changelog/14-finish-the-council-plugin-port-phases-2-9/PLAN.md`. Read that before starting a
phase; it is carried forward rather than restated here.

Phase 9 is deliberately absent. It was split at the repo boundary on #14; its cjus-dev half is
filed separately in that repo, blocked on PR #21.
