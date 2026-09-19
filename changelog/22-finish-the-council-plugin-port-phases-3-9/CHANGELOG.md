# Finish the council plugin port: phases 3-9

Start date: 2026-09-18 14:33:00 MDT

Complete the council plugin port that #9 (PR #13) and #14 (PR #21) delivered in two partial
passes. The plugin is installable but incomplete: `scripts/detect.sh` does not exist, so
detection always falls through. This branch lands phases 3 through 8 — `detect.sh`, the
`skills/ask` seating join, the `COLLAPSED` class, the reference split, the READMEs and the
remaining suites.

## Changes

### 2026-09-18 — Phase 3: `detect.sh` ported onto `council-lib.sh`

`plugins/council/scripts/detect.sh` and `plugins/council/scripts/test-detect.sh`.

The plugin's last structural gap is closed: the detection block in `skills/ask` and
`skills/setup` no longer falls through to `detection unavailable`.

**The key chain is not implemented a third time.** `detect.sh` sources `council-lib.sh` and
calls `council_resolve_key`, `council_find_bin`, `council_redact`, `council_roster_path`,
`council_display_path` and `council_normalize_endpoint`. That closes a divergence the original
carried: its `grep` did not accept `export KEY=value`, so it printed "absent -- do NOT seat"
for a key `openrouter.mjs` went on to resolve and spend. It also gains level 3 of the chain —
the original checked only the environment and `./.env`, never the user-level file — and gains
`$XDG_CONFIG_HOME`, which its hardcoded `$HOME/.config/council/roster.json` ignored.

**The oracle is replayed against the printed line, not the variable.** `test-detect.sh` runs
`detect.sh` and parses its `openrouter:` line, then checks three separable things per row and
reports them as three distinct failures: that present/absent agrees with `env.mjs`, that the
shared answer is the right one, and that the printed provenance names the level that actually
won. `test-council-state.sh` already covers the library's `COUNCIL_KEY_LEVEL`; what a model
acts on is the render, and a correct library behind a wrong render is the same defect to the
reader.

Three fixes carried over from the sibling script rather than re-landing behavior it had
already corrected:

- The probe URL travels on stdin (`curl -K -`) instead of argv. An endpoint may carry
  basic-auth userinfo, and an argument is visible in the process table to every other user on
  the box for the life of the probe. `council-state.sh` fixed this; the original `detect.sh`
  still passed the URL as an argument.
- A roster that exists but is not a readable file now says so, instead of printing an empty
  summary indistinguishable from an empty roster. The original's `|| echo "(unreadable)"`
  guard was dead code — it tested the exit status of the second `sed` in a pipeline, which
  always succeeds.
- No `curl` on the machine reports `NOT PROBED`, not `not reachable`. Not asked and did not
  answer are different facts, and this is the same third state `council-state.sh` keeps rather
  than folding into the confident branch.

Two smaller honesty fixes: a roster longer than 40 lines now states that the injected summary
is partial, since a partial member list read as a whole one is how a member gets silently
dropped from the seating; and the A-060 warning keeps its generic half — never seat the
council on `OPENROUTER_API_KEY` — with the host-repo attribution dropped, per the phase 9
split decision.

`set -u` is on, which is the one thing that can still make the script exit non-zero. That
trade is deliberate and documented in the header: a mistyped variable would otherwise expand
to empty and print a confidently wrong availability line, and aborting lands on the call
sites' existing `|| echo "detection unavailable"` guard instead.

Verified: `test-detect.sh` 40 cases, `test-env.sh` 46, `test-council-state.sh` 81, all
passing; `claude plugin validate --strict` passes for the plugin and the marketplace; output
is byte-identical under `dash`, `ksh`, `bash` and `zsh`.

`council_normalize_endpoint`'s path-mangling and IPv6 defect now has a live second caller.
It stays on [#15](https://github.com/cjus/cjus-skills/issues/15) and is recorded under
`PLAN.md § Deferred`; it is not a regression, since the original's inline normalization had
the same two bugs.

### 2026-09-18 — Phase 4: `skills/ask` seats from the join

`plugins/council/skills/ask/SKILL.md`, `plugins/council/scripts/council-lib.sh`,
`plugins/council/scripts/council-state.sh`, `plugins/council/scripts/env.mjs`,
`plugins/council/scripts/test-council-state.sh`.

**`skills/ask` runs the join instead of performing it in prose.** It now calls
`sh "${CLAUDE_PLUGIN_ROOT}/scripts/council-state.sh" --json` and seats exactly `.seated[]`.
What it used to do — `Read` the roster, union `members[]` with each enabled
`external.<provider>`, and fall back to a default table when the roster was absent or
unreadable — was the same join `council-state.sh` performs, written as instructions. Prose
instructions are the ones that get skipped, and the two were already free to disagree.

The skill now reads `.projectedCorrelation` for the footer class rather than classifying the
roster itself, `.notSeated[]` for the one-line "consented but unavailable" notes, `.roster.state`
to know the defaults were used, `.ollamaProbed` to avoid claiming unconfirmed diversity, and
`.maxConcurrentExternal` for the fan-out cap.

**The four Claude defaults are declared once**, in `council-lib.sh:council_default_members`,
emitted as `stance<TAB>model` — the same shape `members claude` yields — so the join cannot
tell a default from a declared member and needs no branch for them. They were previously
nowhere in the plugin: the only four-member list under `plugins/council/` was a test fixture,
and a fixture is not a declaration.

**An absent roster now seats those four and projects `HOMOGENEOUS (anthropic)`.** It used to
report `0 seated` and `NONE` two rows below its own `roster: NONE ... Claude-only council`
line, so the report contradicted itself; and nobody opens `/council:status` to learn what a
file says, they open it to learn what the next council will do. `NONE` survives with a narrower
meaning — a roster that is *present* and declares no members — which makes its existing
message ("the roster declares no members") exactly true for the first time.

That narrowing made zero-seated reachable by a route the skill had never seen, since its own
fallback used to absorb it. `skills/ask` now treats `NONE` with `.seating.total: 0` as a stop:
a roster that declares no members is a decision, and seating the defaults over it would
override the user.

**`env.mjs:rosterPath` is deleted.** It had no callers anywhere under `plugins/` — no
production caller, no test — and existed only as a second implementation of a path
`council_roster_path` already resolves, minus `$COUNCIL_ROSTER`. Deleting it dissolves the
precedence question rather than answering it. `COUNCIL_ROSTER` is now documented in the
`council-lib.sh` header as winning over the config dir, which closes #9's deferred
"undocumented" item for the sh side, now the only side.

One piece of prose went stale and was removed rather than carried: the detection block's
fall-through told the skill to "proceed without `codex` or `ollama` members" when detection was
unavailable. True when the skill derived seating from that block; false once the join runs its
own `council_find_bin codex` and its own endpoint probe. The block is now documented as
context for *explaining* an unseated member, never as the basis for seating one.

Verified: `test-council-state.sh` 91 cases (was 81), `test-detect.sh` 40, `test-env.sh` 46, all
passing; `claude plugin validate --strict` passes. The new rows cover the defaults' seating,
class and vendor, that the text report no longer contradicts itself, that `NONE` now requires a
present roster — and one that diffs `.seated[]` against `council_default_members` directly, so
a second copy of the default list fails the suite instead of drifting quietly.

Settled in passing: the decision's remaining question — whether `/council:ask` still owns the
right to seat a different set once the defaults live in the library — is answered no. One
declaration, both readers.

### 2026-09-19 — Phase 5: `COLLAPSED`, split into what can be checked and what can only be reported

`plugins/council/scripts/council-lib.sh`, `plugins/council/scripts/council-state.sh`,
`plugins/council/scripts/test-council-state.sh`, `plugins/council/skills/ask/SKILL.md`,
`plugins/council/skills/setup/SKILL.md`, `plugins/council/skills/status/SKILL.md`.

The blocking question — what mechanism makes `COLLAPSED` observable — was settled by probing
the live Agent tool instead of reasoning about it, and the probe showed the question contained
two different failures under one name.

**`model` is a closed enum: exactly `opus|sonnet|haiku|fable`.** Passing anything else returns
an `InputValidationError` before a model runs. All four resolve on this account, returning four
distinct identities, three of them different from the session model.

**So the unacceptable-pin half is now mechanical.** `council-state.sh` validates each Claude
member's `model` against `council-lib.sh:COUNCIL_ACCEPTED_PINS` and unseats a bad one with a
reason naming the accepted set — the same shape `no key resolves` uses, so it stays out of the
participation invariant and out of `DEGRADED`. This matters because the roster's `model` field
is free-form JSON: `"model": "opus-4.5"` is easy to write, nothing in the schema rejects it,
and it used to surface as a crash partway through a fan-out that had already begun spending.
`/council:setup` now also refuses to write such a pin, so the tool cannot author the roster its
own join would reject.

A third case is kept distinct from both: a member that declares **no** `model` seats with `-`,
spawns with no override, and runs on the session model. That is a roster that did not ask for a
pin, not a pin that failed, and the two must not print alike.

**The collapse half is reported from self-report, scoped to what self-report can carry.** Each
member ends its reply with a `MODEL:` line, which the skill strips before reconciling and
compares against the pins it passed. Three states: confirmed distinct, `COLLAPSED`, or
unverified. Only a **full** collapse counts as confirmed — every member independently agreeing
it is the session model is hard to get wrong in the same direction — and any partial mismatch
is `unverified`, since one loose self-description is far likelier than a half-collapse. Same
three-state discipline `council-state.sh` already applies to the Ollama probe, where `unknown`
is kept out of both confident branches.

`COLLAPSED` is bracketed in the footer template alongside `DEGRADED`, which is what Decision 1
asked for: a class living only in prose is the one omitted from the report that needed it. It
sits *beside* the vendor class rather than replacing it, so a roster whose Claude members
collapsed while a seated Ollama member answered is still `CROSS-VENDOR`.

**The pre-fan-out cost statement now fires on `pooled` at any member count**, not on size
alone. Doubling a four-member council costs what an eight-member single round does, and the
old size-only rule let the cheaper-looking mode through.

**What the experiment did not settle is recorded as still open.** The original framing — a pin
that is valid but unavailable on the plan — could not be tested, because all four enum values
resolve on this account. Nothing shipped here assumes an answer.

One correction recorded rather than buried: the #14 decision called member self-report "the
likely mechanism", and this branch's own analysis then argued against it as introspection
rather than observation. The experiment weakened that objection — all four members named
themselves specifically and correctly, and one cited its system prompt as the source, which
suggests the harness supplies the fact rather than leaving it to be inferred. Still not proof,
which is why self-report carries only the full-collapse case.

Two of Decision 1's four bullets were not phase 5 work. The README "What it costs" block has no
README to live in yet and is carried to phase 7; per-choice cost in `/council:setup` already
landed in phase 1 and was verified rather than redone.

Verified: `test-council-state.sh` 99 cases (was 91), `test-detect.sh` 40, `test-env.sh` 46, all
passing; `claude plugin validate --strict` passes. The eight new rows cover the three pin cases
and one invariant that nothing else couples — that every pin in `council_default_members` is
itself an accepted pin, so editing the defaults to an unacceptable value fails the suite instead
of producing a default council that unseats itself.

### 2026-09-19 — Phase 6: the reference split

`plugins/council/reference/roster.md`, `plugins/council/reference/providers.md`,
`plugins/council/reference/trust-boundary.md`, `plugins/council/skills/ask/SKILL.md`,
`plugins/council/skills/setup/SKILL.md`, `plugins/council/skills/status/SKILL.md`.

`skills/ask/SKILL.md` goes from 460 lines to 370, with the detail behind it moved into three
reference files and a pointer table near the top saying when to read which. The rule applied
throughout: **the skill carries the action, the reference carries the contract and the why.**

- **`reference/roster.md`** — the roster file's shape, the three roster states that must never
  print alike (absent seats the defaults, present-and-empty seats nobody, unparseable refuses),
  the default council and where it is declared, the model-pin rules, and the join's full JSON
  contract with its exit codes.
- **`reference/providers.md`** — what each provider spends, the never-interpolate-into-argv
  rule, and the invocation for OpenRouter, Ollama and Codex with exit codes, the key chain,
  timeouts and the 429 rule.
- **`reference/trust-boundary.md`** — the `MEMBER_QUESTION`/`JUDGE_QUESTION` split, the
  attachment caps, the `git config filter.*` check before diffing an untrusted repo, and why
  the judge notice and the member notice are deliberately different.

The honesty contract and output contract stayed inline, as the phase specifies. Two more things
stayed for the same reason, though the phase did not name them: the **two untrusted-content
notices**, which must be emitted verbatim — a security control that first requires reading
another file is a control that gets skipped — and the **stance table**, consulted on every run,
where moving it would have saved four lines and cost a read.

Two problems the split surfaced. A skill lives in `skills/<name>/`, so the bare `reference/…`
paths the first pass wrote would have resolved nowhere; they now use
`${CLAUDE_PLUGIN_ROOT}/reference/…`, matching how `skills/setup` already cites the example
roster. And the transplanted provider section arrived still carrying prose that had stayed
inline, leaving `providers.md` with a second copy of the opt-in rationale and the
not-seated-is-not-DEGRADED rule — both cut, since duplication across a split is the failure
mode the split exists to remove.

`skills/setup` and `skills/status` also point at `reference/roster.md` now, so the roster format
is documented once for all three skills.

Verified by grepping every load-bearing block to confirm it survived and landed in the right
file: the three provider invocations, the exit codes, the attachment caps, the `filter.*`
check, both verbatim notices, the honesty contract and the output contract. Suites unchanged at
40, 99 and 46; `claude plugin validate --strict` passes for the plugin and the marketplace.
