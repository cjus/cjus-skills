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
- [x] **Phase 8** — `detect.sh` probes and `openrouter.mjs` exit-code tests. **Landed 2026-09-19.**

## Status

Updated 2026-09-19. Status only; the objective and the six phases above are unchanged. The
per-phase narrative lives in `CHANGELOG.md` and is not repeated here.

**All six phases are complete, and both open questions are resolved.** The plugin is no longer
incomplete: `scripts/detect.sh` exists, so the capability block in `skills/ask` and
`skills/setup` no longer falls through; `skills/ask` seats from `council-state.sh --json` instead
of performing the join in prose; the four Claude defaults are declared once in `council-lib.sh`
and an absent roster seats them; `COLLAPSED` can fire; the reference docs are split out; both
READMEs exist; and four probe suites stand at **46, 40, 104 and 46**. `claude plugin
validate --strict` passes for the plugin and the marketplace, and `detect.sh` and
`council-state.sh` produce identical output under `dash`, `ksh`, `bash` and `zsh`.

**Phase 9 is absent by design**, split at the repo boundary on #14. Its cjus-dev half is
[cjus/cjus-dev#89](https://github.com/cjus/cjus-dev/issues/89).

**Two questions settled, and one deliberately left unanswered.** The `COLLAPSED` mechanism was
resolved by probing the live Agent tool rather than by argument, which showed it held two
failures under one name: an unacceptable pin is caught mechanically in the join, because `model`
is a closed enum of exactly `opus|sonnet|haiku|fable`, while a genuine collapse is reported from
member self-report with only a full collapse counting as confirmed. What that probe could **not**
establish — whether a valid-but-unserved pin errors or silently substitutes — is recorded as
still unknown, and nothing shipped assumes an answer. The `M=`/`P=` question was settled by the
operator in favour of a flag interface and applied the same day, which also retired the exit-1
defect its Deferred entry had parked.

**Three deviations, none of them scope changes.** Two of Decision 1's four bullets were not phase
5 work: the README cost block had no README yet and landed in phase 7, and per-choice cost in
`/council:setup` had already landed in phase 1 and was verified rather than redone. Two things
stayed inline through the phase 6 split that the phase did not name — the untrusted-content
notices, since a control needing a file read first is one that gets skipped, and the stance
table, consulted every run.

**The close-gate review returned `APPROVE` and its findings were applied, not carried.** One was
a defect this branch introduced: phase 5's pin check made `NONE` reachable for a roster that
declares members and had them all unseated, while the message still read "the roster declares no
members" — contradicting the `not seated` rows two lines above it. Fixed, with the regression
case whose absence let it through. The review also surfaced that `openrouter.mjs` still exited
`1` on a network failure, a timeout, or a 200 whose body is not JSON, contradicting the
exit-code contract this branch had just documented; those exit `4` now and name the cause.

## Open Questions

- ~~**What mechanism makes `COLLAPSED` observable?**~~ **Resolved 2026-09-19 by experiment:
      split the question in two and ship the half that is observable.** See
      `## Decision — COLLAPSED splits into a checkable half and a reported half` below.

- ~~**Needs an operator decision: `M=`/`P=` env prefixes defeat an `allowed-tools` prefix
      rule.**~~ **Resolved 2026-09-19 by the operator: give `openrouter.mjs` a
      `--model`/`--prompt-file` interface.** Applied the same day. See
      `## Decision — openrouter.mjs takes flags` below.

## Decision — openrouter.mjs takes flags

Settled 2026-09-19 by the operator, and applied immediately.

`openrouter.mjs` now takes `--model <id> --prompt-file <path>` (and `--flag=value`) instead of
reading `M` and `P` from the environment. The command therefore begins with `node`, which
`/council:ask`'s existing `allowed-tools` entry `Bash(node:*)` matches — so OpenRouter members
stop prompting the user on every call. A leading `M=` did not match, because Claude Code strips
an assignment before matching only for a known-safe set of variable names, and no narrower rule
could help: `${CLAUDE_PLUGIN_ROOT}` does not expand inside a permission pattern, so the script
cannot be named there.

**It costs nothing in secrecy.** Only the key must stay out of the process table, and it still
does — it is resolved inside the process through `env.mjs`. A model id and a prompt *path* are
not secrets, and the prompt *content* still never reaches argv, which is the property that made
this a script rather than a `curl` pipeline. `test-openrouter.sh` now asserts both halves
directly: argv carries the model and the path, and argv never carries the key.

**No environment fallback.** Supporting both would leave two interfaces for one idea, which is
what this port has refused everywhere else. Instead, an invocation with `M` or `P` set and no
flags exits 5 and names what replaced it, so the retired form fails loudly rather than looking
like a typo. The only in-repo caller, `reference/providers.md`, was updated in the same change.

**Three consequences beyond the script itself:**

- **`skills/setup`'s suggested project-level grant for `openrouter.mjs` was removed.** It is now
  a rule that changes nothing, since the skill's own `Bash(node:*)` covers the flag form — and
  offering a no-op grant is precisely the habit that step's own warning exists to prevent. Worth
  noting it never worked anyway: the grant began `Bash(node /abs/path/...)`, which an invocation
  starting `M=` could not match either.
- **The exit-1 defect went with it**, as the Deferred entry said it should. A `--prompt-file`
  that cannot be read is now exit 5 naming the path, rather than an uncaught rejection exiting 1
  with a stack trace. The read also moved ahead of key resolution, so every usage error is
  reported before any key problem.
- **`test-openrouter.sh` changed in one function.** `run_or` was deliberately the only thing in
  the suite that knew the calling convention, which is exactly why this cost one edit instead of
  thirty.

## Related tickets

- **[#15](https://github.com/cjus/cjus-skills/issues/15)** (`priority:medium`) — seven defects
      in the mechanical layer. One of them, `council_normalize_endpoint` mangling a path
      endpoint and failing to bracket IPv6, names its occasion as "when `detect.sh` lands and
      shares the helper" — which is this branch's phase 3. Decide at that point whether the fix
      belongs here or stays on its own ticket; it is not in this branch's objective either way.

## Deferred

**Triage outcome, 2026-09-19.** Six items were triaged at close — the two recorded below, plus
four raised by the close-gate review. One was ticketed, two were already tracked, two dropped, and
one was fixed outright rather than deferred.

| Item | Outcome |
|---|---|
| A binary that cannot exec is selected anyway | TICKET → [#15](https://github.com/cjus/cjus-skills/issues/15), added as a comment; backend *selection*, adjacent to its parity items |
| `council_normalize_endpoint` path-mangling and IPv6 | Already on [#15](https://github.com/cjus/cjus-skills/issues/15), by the decision recorded with it |
| `council-state.sh` emits `.roster.path` and `.key.source` unescaped | Already [#15](https://github.com/cjus/cjus-skills/issues/15)'s second item |
| `openrouter.mjs` exits 1 on a network failure, timeout or non-JSON 200 | **FIXED at close**, not deferred — it contradicted the exit-code contract this branch had just documented |
| `detect.sh`'s endpoint scrape takes the first `"endpoint"` | DROP — speculative; needs a second `endpoint` field the schema does not have, and `/council:status` is the authoritative read |
| Whether a valid-but-unserved pin errors or substitutes | DROP as work — no action available on demand. Documented as a limitation in the README and above instead |


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
