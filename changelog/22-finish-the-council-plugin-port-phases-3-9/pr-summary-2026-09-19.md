# Finish the council plugin port: phases 3-9

Closes the three-branch arc that moved `council` out of the source repo and into this repo. #9
(PR #13) landed the mechanical layer, #14 (PR #21) landed the skills, and this branch lands
everything that was still outstanding: phases 3 through 8, plus both open questions that
predecessor branches deliberately left for an operator.

## Overview

The plugin was **installable but incomplete**. `scripts/detect.sh` did not exist, so the
capability block in `skills/ask` and `skills/setup` always fell through to
`detection unavailable`, and no provider needing a local binary or a reachable endpoint could be
detected at all. `skills/ask` performed the consent-by-availability seating join in prose rather
than calling the script written to do it. The `COLLAPSED` correlation class existed only as a
caveat saying it could not be detected. There was no README.

All of that is now done, and two questions that had been carried forward across branches are
settled — one by experiment rather than argument, one by an operator decision applied the same
day.

The plugin ships three skills, four reference documents, six scripts and four probe suites
totalling **236 cases**. `claude plugin validate --strict` passes for both the plugin and the
marketplace manifest.

## Key changes

| File | Change |
|---|---|
| `scripts/detect.sh` | **New.** The capability probe, ported off the host repo and sourcing `council-lib.sh` rather than re-deriving the key chain. |
| `scripts/council-lib.sh` | Gained the single declaration of the default council and of the model values the harness accepts, plus `$COUNCIL_ROSTER` documentation. |
| `scripts/council-state.sh` | An absent roster now seats the four defaults instead of reporting `0 seated`; Claude pins are validated against the accepted set. |
| `scripts/openrouter.mjs` | Now takes `--model` / `--prompt-file` instead of `M=` / `P=` in the environment, and an unreadable prompt file is exit 5 rather than an uncaught rejection. |
| `scripts/env.mjs` | `rosterPath` deleted; it had no callers and was a second implementation of a path `council_roster_path` already resolved. |
| `skills/ask/SKILL.md` | Seats from `council-state.sh --json` rather than deriving seating in prose; gained the post-hoc pin check; 460 lines down to 370 after the reference split. |
| `skills/setup/SKILL.md` | Constrains the pins it may write; drops a suggested permission grant that is now a no-op. |
| `skills/status/SKILL.md` | Points at `/council:ask` for the confirmation it cannot perform, and names the bad-pin case. |
| `reference/roster.md`, `providers.md`, `trust-boundary.md` | **New.** The contract and rationale split out of `SKILL.md`. |
| `README.md` (plugin), `README.md` (root) | **New** plugin README; root README gains a `council` section and Layout entry. |
| `scripts/test-detect.sh`, `test-openrouter.sh` | **New** suites, 46 and 40 cases. `test-council-state.sh` went 81 → 104. |

## Code examples

**The divergence phase 3 closed.** The original `detect.sh` implemented the key chain a third
time with a `grep` that did not accept `export KEY=value`, so it printed "do NOT seat" for a key
`openrouter.mjs` went on to resolve and spend. It now sources the shared implementation:

```sh
# scripts/detect.sh
COUNCIL_SCRIPT_DIR="$DIR"
. "$LIB"
...
if council_resolve_key; then
  echo "openrouter: $COUNCIL_KEY_NAME present (from $COUNCIL_KEY_SOURCE) -- one key, many vendors"
else
  echo "openrouter: $COUNCIL_KEY_NAME absent -- do NOT seat OpenRouter members"
fi
```

**Seating stopped being prose.** `skills/ask` used to instruct the model to read the roster,
union `members[]` with each enabled `external.<provider>`, and fall back to a default table —
the same join `council-state.sh` performs, written as instructions that could be skipped:

```markdown
- **Read the roster first.** Use `Read` on `$COUNCIL_ROSTER` if set, else …
- If `members[]` is absent or the roster is unreadable, fall back to the default table below
```

It now runs the join and seats the answer:

```bash
sh "${CLAUDE_PLUGIN_ROOT}/scripts/council-state.sh" --json
```

**The permission defect the flag interface fixed.** Every invocation used to begin
`M=... P=... node ...`, and Claude Code strips a leading assignment before matching a permission
rule only for a known-safe set of variable names — so `Bash(node:*)` never matched and every
OpenRouter member prompted the user:

```js
// scripts/openrouter.mjs, before
const model = process.env.M;
const promptPath = process.env.P;
```

```js
// after — the command now begins with `node`, which the existing grant matches
if (name !== "--model" && name !== "--prompt-file") {
  badUsage(`unknown argument ${JSON.stringify(arg)}.`);
}
```

Only the key must stay out of the process table, and it still does; a model id and a prompt path
are not secrets. The suite asserts both halves against the recorded argv.

## Plan alignment

**All six phases this branch carries are complete.** Phase 9 was absent by design, split at the
repo boundary on #14; its source repo half is a ticket in the source repo.

| Phase | Outcome |
|---|---|
| 3 — `detect.sh` | As planned, sourcing `council-lib.sh`, reporting which source won, with the oracle table replayed against it. |
| 4 — the seating join | As planned. Defaults moved into the join, `env.mjs:rosterPath` deleted. |
| 5 — `COLLAPSED` | As planned, after settling its blocking question. Two of Decision 1's four bullets were not phase 5 work (see deviations). |
| 6 — the reference split | As planned, honesty contract and output contract kept inline. |
| 7 — the READMEs | As planned, including Decision 1's cost block and the plan-dependence note. |
| 8 — the remaining suites | As planned. |

**Both open questions are resolved.**

*What mechanism makes `COLLAPSED` observable?* Settled by probing the live Agent tool rather
than by argument, which showed the question held two different failures under one name. `model`
is a closed enum of exactly `opus|sonnet|haiku|fable`, so an unacceptable pin fails before any
model runs and the join now unseats it with a reason — pure observation. A genuine collapse is
reported from member self-report, scoped so that only a *full* collapse counts as confirmed and
any partial mismatch is `unverified`. **What the probe could not settle is recorded as still
unknown**: whether a valid-but-unserved pin errors or silently substitutes could not be tested,
because all four values resolve on the account available. Nothing shipped assumes an answer.

*The `M=`/`P=` prefix decision.* Resolved by the operator in favour of the flag interface, and
applied the same day.

**Deviations, all recorded in `PLAN.md`:**

- **Two of Decision 1's four bullets were not phase 5 work.** The README "What it costs" block
  had no README to live in and moved to phase 7, which landed it. Per-choice cost in
  `/council:setup` had already landed in phase 1 and was verified rather than redone.
- **Two things stayed inline through the phase 6 split that the phase did not name**: the two
  untrusted-content notices, because a security control that first requires reading another file
  is one that gets skipped, and the stance table, consulted every run.
- **The exit-1 defect was fixed rather than left deferred.** Its Deferred entry said it belonged
  in the same pass as the `M=`/`P=` decision because both live in the same argument-handling
  code; when that decision landed, it went with it.

**Nothing was descoped.**

**The close-gate review returned `APPROVE`, and its findings were applied rather than
deferred.** One was a defect this branch introduced: phase 5's pin check made `NONE` reachable
for a roster that *declares* members and had them all unseated, while the message still read
"the roster declares no members" — contradicting the `not seated` rows printed two lines above
it, and sending the user to rewrite a file whose only fault was one typo. The two cases now
print differently, `skills/ask` checks `.notSeated[]` before saying which it is, and
`test-council-state.sh` gained the regression case whose absence let it through.

Three smaller findings were stale text this branch wrote: `test-detect.sh`'s header still said
the probe cases were not there yet, `reference/providers.md` referred to a block above it that
the phase 6 split left behind, and the root README's Layout block was misaligned.

One finding went further than the reviewer's note. `openrouter.mjs` still exited **1** with an
unhandled rejection when the request itself failed — a network error, a timeout, or a 200 whose
body is not JSON — which contradicted the exit-code contract this branch had just documented and
tested in that same file. Those paths now exit `4` and name the cause, with four cases covering
them.

## Testing

Four suites, all offline, run from `plugins/council/scripts/`:

```bash
./test-detect.sh          # 46 — the capability block, the oracle replay, and the probe
./test-openrouter.sh      # 40 — exit codes and the argument grammar, no network
./test-council-state.sh   # 104 — the key chain, the join, backend parity
./test-env.sh ./env.mjs   # 46 — the Node key chain, value-exact
```

`claude plugin validate --strict plugins/council` and `claude plugin validate --strict .` both
pass.

**By hand:** `/council:status` with and without a roster; `/council:setup` to write one;
`/council:ask` for a real fan-out. `detect.sh` and `council-state.sh` were confirmed to produce
identical output under `dash`, `ksh`, `bash` and `zsh`.

**Edge cases the new suites cover.** Three roster states that must not print alike (absent seats
the defaults, present-and-empty seats nobody, unparseable refuses). A pin outside the accepted
set, and separately a member declaring no pin at all. A prompt of shell metacharacters arriving
byte-identical. A 200 from OpenRouter carrying no usable content, which must not read as a
member that answered with silence. An Ollama endpoint answering with something that is not
Ollama. A healthy Ollama with no models pulled, which must not read as down. The key absent from
stdout, stderr, argv and an `sh -x` trace — asserted alongside proof that it *was* in fact sent,
since a script that leaked nothing because it sent nothing would pass the leak case alone.

One environment note for reviewers: a wrong-architecture `jq` earlier on `PATH` than a working
one makes three of the four suites fail wholesale. That is the subject of a deferred item below.

**Assertions file: disabled.** `docs.assertionsFile` is `null` in `.claude/pr-config.json`, so
no audit applies. **Continuity: disabled** for the same reason.

## Impact assessment

18 files, **+2549 / −168**, across 5 commits.

- **No dependencies added.** Nothing is installed when a plugin is installed, so the roster is
  read through `jq` *or* Node, and a Claude-only council needs neither.
- **One breaking interface change**, internal to the plugin: `openrouter.mjs` no longer reads
  `M` and `P` from the environment. The only in-repo caller was updated in the same commit, and
  an invocation using the retired form exits 5 naming what replaced it rather than failing
  obscurely. Anything outside this repo calling that script directly must switch to
  `--model` / `--prompt-file`.
- **One behaviour change a user will notice:** an absent roster now reports four seated members
  and `HOMOGENEOUS (anthropic)` where it previously reported `0 seated` and `NONE`.
- **No version bump.** `plugins/council/.claude-plugin/plugin.json` stays at `0.1.0`; releasing
  is a separate step.

## Deferred work

Two items are parked under `PLAN.md § Deferred`, neither in this branch's objective.

**`council_normalize_endpoint` mangles a path endpoint and does not bracket IPv6.** Phase 3 is
the occasion [#15](https://github.com/cjus/cjus-skills/issues/15) named for this defect —
"when `detect.sh` lands and shares the helper" — so it now has a second caller and a second
symptom. `myserver/ollama` becomes `http://myserver/ollama:11434`, and `::1` is left unbracketed.
It is **not a regression**: the original's inline normalization carried the same two bugs, so
sharing the helper moved the behaviour rather than introducing it. `detect.sh`'s own
scheme-without-a-port warning has the matching IPv6 hole, since the glob `*:[0-9]*` matches
`[::1]` on the `:1`. The fix stays on #15, and both halves want doing in one pass.

**A binary that cannot exec is selected anyway, and the roster gets blamed for it.** Found while
verifying phase 5, on a machine whose `/usr/local/bin/jq` is an x86_64 binary on arm64. Three
defects stack: `council_find_bin` accepts it because `[ -x ]` passes on the mode bits;
`council_json_backend` therefore selects `jq` and never falls back to Node although Node is on
the same `PATH`; and `council_roster_rows` maps *any* non-zero `jq` status to
`not valid JSON, or not a JSON object`, so a perfectly valid roster is reported as malformed and
`/council:status` exits 2. The third is the one that matters — it sends the reader to inspect a
correct file while the fault is a broken tool install. Adjacent to #15's backend-parity items
but distinct from all of them: those concern the two backends *disagreeing*, this concerns which
one is *chosen*.
