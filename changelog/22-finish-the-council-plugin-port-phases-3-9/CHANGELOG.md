# Finish the council plugin port: phases 3-9

Start date: 2026-09-18 14:33:00 MDT

Complete the council plugin port that #9 (PR #13) and #14 (PR #21) delivered in two partial
passes. The plugin is installable but incomplete: `scripts/detect.sh` does not exist, so
detection always falls through. This branch lands phases 3 through 8 — `detect.sh`, the
`skills/ask` seating join, the `COLLAPSED` class, the reference split, the READMEs and the
remaining suites.

## Changes

Every heading below keeps its own date. The full reasoning for each decision lives in `PLAN.md`
and in the commit messages; this is the condensed record.

### 2026-09-18 — Phase 3: `detect.sh` ported onto `council-lib.sh`

`scripts/detect.sh` and `scripts/test-detect.sh`, both new. The capability block in `skills/ask`
and `skills/setup` stops falling through to `detection unavailable`.

It sources `council-lib.sh` rather than implementing the key chain a third time, which closes a
real divergence: the original's `grep` did not accept `export KEY=value`, so it printed "do NOT
seat" for a key `openrouter.mjs` went on to resolve and spend. It also gains level 3 of the chain
and `$XDG_CONFIG_HOME`, both of which the original ignored.

`test-detect.sh` replays `test-env.sh`'s oracle table against **what detect.sh prints**, not the
library variable `test-council-state.sh` already covers — the printed line is what reaches the
model's context, and a correct library behind a wrong render is the same defect to the reader.

Three fixes carried over from the sibling script rather than re-landing behaviour it had already
corrected: the probe URL travels on stdin via `curl -K -` instead of argv, where basic-auth
userinfo was visible in the process table; an unreadable roster says so instead of printing an
empty summary indistinguishable from an empty one (the original's `|| echo "(unreadable)"` was
dead code, testing the second `sed` in a pipeline); and no `curl` reports `NOT PROBED` rather
than `not reachable`. Two smaller honesty fixes: a roster over 40 lines states the injected
summary is partial, and the A-060 warning keeps its generic half with the host-repo attribution
dropped.

`set -u` is on, which is the one thing that can still make it exit non-zero. Deliberate: a
mistyped variable would otherwise print a confidently wrong availability line, and aborting lands
on the call sites' existing `|| echo` guard.

### 2026-09-18 — Phase 4: `skills/ask` seats from the join

`skills/ask` calls `council-state.sh --json` and seats `.seated[]`. What it used to do — read the
roster, union `members[]` with each enabled external provider, fall back to a default table — was
the same join written as prose instructions, which are the ones that get skipped.

The four Claude defaults are declared once, in `council-lib.sh:council_default_members`, emitted
as `stance<TAB>model` so the join cannot tell a default from a declared member. They were
previously nowhere in the plugin; the only four-member list was a test fixture.

An absent roster now seats them and projects `HOMOGENEOUS (anthropic)`. It used to print
`0 seated` two rows below its own `roster: NONE … Claude-only council` line. `NONE` survives with
a narrower meaning, which made zero-seated reachable by a route the skill had never seen, since
its own fallback used to absorb it; `skills/ask` now treats it as a stop rather than seating the
defaults over a roster that deliberately declares none.

`env.mjs:rosterPath` is deleted — no callers anywhere, and a second implementation of a path
`council_roster_path` already resolved. `COUNCIL_ROSTER` is now documented in the
`council-lib.sh` header.

One piece of prose went stale and was removed rather than carried: the detection block told the
skill to "proceed without codex or ollama members" when detection was unavailable — true when the
skill derived seating from that block, false once the join runs its own checks.

### 2026-09-19 — Phase 5: `COLLAPSED`, split into what can be checked and what can only be reported

The blocking question was settled by probing the live Agent tool instead of reasoning about it,
which showed it held two failures under one name.

`model` is a closed enum, exactly `opus|sonnet|haiku|fable`; anything else returns an
`InputValidationError` before a model runs. So the unacceptable-pin half is now mechanical:
`council-state.sh` validates each Claude member's pin against `COUNCIL_ACCEPTED_PINS` and unseats
a bad one with a reason naming the accepted set. This matters because the roster's `model` field
is free-form JSON — `"opus-4.5"` is easy to write and used to surface as a crash partway through
a fan-out that had already begun spending. `/council:setup` refuses to write such a pin. A member
declaring **no** `model` is kept distinct: it seats as `-` and runs unpinned.

The collapse half is reported from member self-report — a `MODEL:` line per member, stripped
before reconciling, compared against the pins passed, in three states. Only a **full** collapse
counts as confirmed; a partial mismatch is `unverified`, since one loose self-description is
likelier than a half-collapse. Same three-state discipline the Ollama probe already uses.

`COLLAPSED` is bracketed in the footer beside `DEGRADED`, and sits *beside* the vendor class
rather than replacing it. The pre-fan-out cost statement now also fires on `pooled` at any member
count, not on size alone.

What the probe could **not** settle — a pin that is valid but unavailable on the plan — is
recorded as still open. Two of Decision 1's four bullets were not phase 5 work: the README cost
block moved to phase 7, and per-choice cost in `/council:setup` had landed in phase 1.

### 2026-09-19 — Phase 6: the reference split

`reference/roster.md`, `reference/providers.md` and `reference/trust-boundary.md`, all new.
`skills/ask/SKILL.md` goes from 460 lines to 370, with a pointer table saying when to read which.
The rule: the skill carries the action, the reference carries the contract and the why.

The honesty contract and output contract stayed inline as the phase specifies. Two more stayed
for the same reason though the phase did not name them: the two untrusted-content notices, since
a security control that first requires reading another file is one that gets skipped; and the
stance table, consulted every run.

Two problems the split surfaced. A skill lives in `skills/<name>/`, so the bare `reference/…`
paths the first pass wrote would have resolved nowhere — they use `${CLAUDE_PLUGIN_ROOT}` now.
And the transplanted provider section arrived still carrying prose that had stayed inline,
leaving `providers.md` with a second copy of the opt-in rationale; cut, since duplication across
a split is the failure the split exists to remove.

### 2026-09-19 — Phase 7: the READMEs

`plugins/council/README.md` is new, 194 lines in the house style `plugins/explain/README.md`
sets. The root README gains a `council` section and a Layout entry, both alphabetical.

Decision 1's **What it costs** block leads the file, ahead of Install, as that decision
specified: the multiplier as Nx and 2Nx, about 4x and 8x at the default four members, with no
dollar figure or token estimate anywhere.

The plan-dependence note states what phase 5 established rather than the vaguer inherited
version: a pin outside the four fails loudly and the join unseats it; a valid-but-unserved pin is
the case that was not determined; so the plugin asks members and reports `COLLAPSED` only on a
full collapse.

Two claims verified rather than asserted: a Claude-only council needs neither `jq` nor Node,
since `council_roster_rows` is called only from the roster-present branch; and the "What ships
here" tree was diffed against `find`, matching at 18 files. The per-suite case counts were
written in and removed, because phase 8 changes two of them.

### 2026-09-19 — Phase 8: the remaining suites

`scripts/test-openrouter.sh` is new; `test-detect.sh` gained the probe cases phase 3 left out.

The OpenRouter suite makes no network calls and **does not ask for an endpoint override** to
achieve that: an env var pointing that script elsewhere would let anyone who can set an
environment variable redirect a bearer token to a host they control. A `node --import` preload
replaces `fetch` before the script loads. The stub records what it received, which is how the
suite asserts the key really *was* sent as a bearer token while never appearing in output — a
script that leaked nothing because it sent nothing would pass the leak case alone.

The probe cases use a real loopback server rather than a mocked `curl`, because what is under
test is which reply shapes the probe accepts: the Ollama fingerprint, a healthy server with no
models pulled, a non-Ollama service on the port, an HTTP 500, and a closed port. They also assert
the probe asks `/api/tags` rather than trusting that it did.

Three harness bugs were found and fixed, all the same family — state set inside a subshell never
reaching the parent. Results travel through files now.

### 2026-09-19 — `openrouter.mjs` takes flags, and OpenRouter members stop prompting

The operator settled the `M=`/`P=` question in favour of a flag interface, applied the same day.

`openrouter.mjs` takes `--model <id> --prompt-file <path>`, so the command begins with `node`,
which `/council:ask`'s existing `Bash(node:*)` grant matches — OpenRouter members stop prompting
on every call. A leading `M=` did not match, because Claude Code strips an assignment before
matching only for a known-safe set of variable names, and no narrower rule could help since
`${CLAUDE_PLUGIN_ROOT}` does not expand inside a permission pattern.

It costs nothing in secrecy, and the suite proves that rather than asserting it: two cases read
the recorded argv, confirming it carries the model and the prompt path and never the key. No
environment fallback — an invocation with `M` or `P` set and no flags exits 5 naming what
replaced it.

The exit-1-on-an-unreadable-prompt-file defect went with it, as its Deferred entry said it
should. That read also moved ahead of key resolution, so every usage error is reported before any
key problem. `skills/setup`'s suggested grant for `openrouter.mjs` was removed as a rule that now
changes nothing — it never worked anyway. The suite changed **in one function**, which is why
`run_or` was written that way.

### 2026-09-19 — Close-gate review findings

The review gate returned `APPROVE`. Its findings were applied rather than carried, because one
was a defect this branch introduced.

**`NONE` claimed a roster declared no members when it had declared members and lost them all.**
Phase 5's pin check made that reachable: a roster with one member pinned to `opus-4.5` seats
nobody, and the report listed the unseated member then said "the roster declares no members" two
lines below. The same self-contradiction phase 4 removed from the absent-roster case,
reintroduced somewhere new. The two readings print differently now, and `skills/ask` checks
`.notSeated[]` before saying which — the advice differs completely: an empty one is a decision to
respect, a non-empty one is a typo or a missing key to fix. `test-council-state.sh` gained the
regression case whose absence let it through.

**`openrouter.mjs` still exited 1 on the most ordinary failure it has.** A network error, a
timeout, and a 200 whose body is not JSON all rejected unhandled, contradicting the exit-code
contract this branch had just documented in that file. They exit `4` now and name the cause,
including undici's `cause.cause.code` so `ECONNREFUSED` reaches the message.

Three findings were stale text this branch wrote: `test-detect.sh`'s header still said the probe
cases belonged to a later phase, `reference/providers.md` pointed at a block the phase 6 split
left in another file, and the root README's Layout block was misaligned.

Suites: 46, 40, 104, 46 — 236 cases, all passing.
