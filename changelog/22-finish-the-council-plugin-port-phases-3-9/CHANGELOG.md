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

### 2026-09-19 — Phase 7: the READMEs

`plugins/council/README.md` (new), `README.md`.

`plugins/council/README.md` is 194 lines in the house style `plugins/explain/README.md` sets —
title, intro, contents, per-skill sections with real invocations, and a "What ships here" tree.
The repo-root README gains a `### council` section and a Layout entry, both alphabetical.

**Decision 1's "What it costs" block leads the file**, ahead of Install, as that decision
specified. It gives the multiplier — Nx for `individual`/`categorized`, 2Nx for `pooled`, so
about 4x and 8x at the default four members — and no dollar figure or token estimate anywhere,
because the reasoning that makes the skills refuse a consensus percentage argues equally against
a number implying precision they cannot have.

**The plan-dependence note states what phase 5 actually established**, not the vaguer version
the plan inherited. Under `## Limitations`: a pin outside `opus|sonnet|haiku|fable` fails before
any model runs and the join unseats it with a reason; a pin that is a valid name the plan cannot
serve is the case that was *not* determined; so the plugin asks each member what it ran on and
reports `COLLAPSED` only when every member names the same model. It also says plainly that a
member's model report is the member's own and not an observation the plugin made.

The README carries the four correlation classes as a table, the three roster states and why the
unparseable one refuses rather than falling back, Ollama's total absence of authentication, and
the write-the-port-explicitly rule.

Two claims verified rather than asserted. **A Claude-only council needs neither `jq` nor Node** —
`council_roster_rows` is called only from the roster-present branch (`council-state.sh:95`,
inside the `else` at :89), so an absent roster never reaches a parser. And the "What ships here"
tree was diffed against `find plugins/council -type f`: 18 files, matching.

Two judgement calls. The per-suite case counts were written in and then removed, because
**phase 8 adds cases to two of those three suites** and a README citing 99/40/46 would have gone
stale inside the same branch. And the root README stated "a skill refers to its own files through
`${CLAUDE_PLUGIN_ROOT}`" twice in adjacent paragraphs; that was deduplicated while adding the
council entry beside it, and the surviving sentence generalised to cover both plugins that now
ship a `reference/` directory.

No version bump. `plugins/council/.claude-plugin/plugin.json` stays at `0.1.0`; releasing is a
separate step and not this phase's call.

Verified: `claude plugin validate --strict` passes for the plugin and the marketplace; suites
unchanged at 40, 99 and 46.

### 2026-09-19 — Phase 8: the remaining suites

`plugins/council/scripts/test-openrouter.sh` (new), `plugins/council/scripts/test-detect.sh`,
`plugins/council/README.md`, `README.md`.

The last phase on this branch. Four suites now stand at 46, 26, 99 and 46.

**`test-openrouter.sh`, 26 cases, no network.** It covers every documented exit: `5` on bad
usage and, separately, that a usage error is reported *before* the key chain, so a caller who
mistyped the invocation is not told their key is missing; `3` with no key at any level, naming
all three levels it checked; `4` on HTTP 401, HTTP 500, and the three shapes of a 200 that
carries nothing usable — whitespace-only content, no `choices`, and a non-string content.

The 200-with-nothing cases matter more than they look. Exiting `0` with empty stdout would read
to the caller as a member that answered with silence, and silence is not a position.

It also pins what the request is: `/api/v1/…` and not `/v1/…`, `model` always sent explicitly
because OpenRouter treats it as optional and silently falls back to the account default, and a
prompt full of shell metacharacters arriving byte-identical — which is the reason this is a
script rather than a `curl` pipeline.

**The network is stubbed with a preload, not with an endpoint override.** An env var pointing
this script elsewhere would mean anyone who can set an environment variable can redirect a
bearer token to a host they control, and that is the exact property the script exists to hold.
`node --import` replaces `fetch` before the script loads: no production change, no new
interface. The stub also records what it received, which is how the suite asserts the key
really *was* sent as a bearer token while never appearing in stdout or stderr — a script that
leaked nothing because it sent nothing would pass the leak case on its own.

**`run_or` is the only function that knows the calling convention.** The `M=`/`P=` interface
still has an open operator decision against it, so when it changes the suite changes in one
place rather than in thirty call sites.

**`test-detect.sh` gained the probe cases phase 3 deliberately left out**, taking it to 46.
They use a real loopback server rather than a mocked `curl`, because what is under test is which
reply shapes the probe accepts and a mock would only restate the assertion: an Ollama-shaped
reply reports `UP` with a count; a healthy server with no models pulled is still `UP`, which is
why the fingerprint is the `models` key rather than a non-empty list; a non-Ollama 200 is called
out instead of accepted, since seating on it would send council prompts to whatever that service
is; an HTTP 500 is `not reachable` rather than an answer, because `curl -fsS` turns a proxy's
error page into a non-zero exit; and a closed port is `not reachable`. It also asserts the probe
asks `/api/tags` rather than trusting that it did.

Three harness bugs were found and fixed while writing these, all the same family — state set
inside a subshell never reaching the parent. `RC` set in a command substitution left callers
reading the *previous* case's exit status; `SRV_PID` set the same way left a "stopped" server
still answering the next case; and the test server used `require` inside an `.mjs`, so it died
on first request and read as an unreachable endpoint. Results now travel through files, and the
suites were run repeatedly to confirm the server cases are not flaky.

One finding recorded under `PLAN.md § Deferred` rather than fixed: **`openrouter.mjs` exits `1`
on a missing prompt file**, which is none of its three documented codes — `readFile` rejects
and nothing catches it. The fix is small, but it touches the same interface the `M=`/`P=`
decision covers, so both belong in one pass. The suite asserts what is safe to assert today:
non-zero, nothing on stdout, not blamed on the key chain.
