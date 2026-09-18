# Finish the council plugin port: phases 2-9

Start date: 2026-09-18 09:03:01 MDT

## Overview

Take `plugins/council/` from inert to installable. Its predecessor (#9, PR #13) landed the
mechanical layer alone — `scripts/env.mjs`, `scripts/council-lib.sh`, `scripts/roster-rows.mjs`,
`scripts/council-state.sh` and their two suites. The plugin ships no skills and is deliberately
absent from `.claude-plugin/marketplace.json`, so nothing consumes any of it yet.

This branch lands the parts that make it a plugin a user can install: the three skill
directories, `reference/`, `detect.sh`, the `COLLAPSED` correlation class, the READMEs, the
remaining test suites, and the retirement of the cjus-dev copy.

The nine-phase plan and the four settled design decisions live in
`changelog/9-port-the-council-skills-into-a-reusable-council-plugin/PLAN.md` and are carried
forward rather than restated. Read that file before starting a phase.

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred`, never as new scope.

## Plan

- [x] Phase 1 (rest): the three skill directories (`skills/ask`, `skills/setup`,
      `skills/status`), `reference/`, and the marketplace entry. The marketplace entry is
      held back deliberately until a skill exists, so the listing never advertises an
      unusable plugin. **Landed 2026-09-18.** `reference/` carries only
      `roster.example.json`; the three `.md` files belong to phase 6, which is what splits
      them out of `SKILL.md`.
- [x] Phase 2 (rest): strip repo-private material from the four shipped files, and move
      `council-setup` off its sibling-relative path onto `${CLAUDE_PLUGIN_ROOT}`.
      **Landed 2026-09-18**, and it also closed #9's third blocker by porting
      `scripts/openrouter.mjs` onto `env.mjs`, which was the last thing still reaching into
      the host repo.
- [ ] Phase 3 (rest): port `detect.sh`, sourcing `council-lib.sh` so the key chain is not
      implemented a third time, and have it report which source won. Replay `test-env.sh`'s
      oracle table against it.
- [ ] Phase 4 (rest): have `skills/ask` call `council-state.sh` instead of re-deriving
      seating. **`/council:status` shipped early, in phase 1** — it was the natural place to
      put it once the skill directories existed, and it needed nothing phase 4 adds. What
      remains here is the `skills/ask` half, plus deleting `env.mjs:rosterPath` per the
      decision below.
- [ ] Phase 5: `COLLAPSED` correlation class, cost statement extended to `pooled`,
      per-choice cost in `/council:setup`.
- [ ] Phase 6: split the reference docs out of `SKILL.md`, keeping the honesty contract and
      output contract inline.
- [ ] Phase 7: `plugins/council/README.md`, the repo-root README section and Layout block.
- [ ] Phase 8 (rest): `detect.sh` probes and `openrouter.mjs` exit-code tests.
- [ ] Phase 9: retire the cjus-dev copy and relocate the A-060 warning. **Split at the repo
      boundary on 2026-09-18** — only the `detect.sh` half lands here; the cjus-dev half is
      its own ticket there, blocked on this PR. See
      `## Decision — phase 9 splits at the repo boundary`.

## Status

Updated 2026-09-18. Status only; the objective and the nine phases above are unchanged.

**Phases 1 and 2 are complete**, and all five open questions were settled before either
started. The plugin is no longer inert: it ships three skills, carries a marketplace entry,
and every path resolves through `${CLAUDE_PLUGIN_ROOT}`. `claude plugin validate --strict`
passes for both the plugin and the marketplace; the two existing suites pass at 46 and 81
cases.

Porting `scripts/openrouter.mjs` closed the **last of #9's three blockers**. Nothing in the
plugin reaches into a host repo any more.

The one interim gap is deliberate: `scripts/detect.sh` is phase 3, so the detection block in
`skills/ask` and `skills/setup` falls through to its `detection unavailable` branch. Verified
to degrade cleanly, and both skills already handle that line by proceeding Claude-only.

Next is phase 3 (`detect.sh`), which is also what makes two of the open items live — the
`council_normalize_endpoint` defect on #15, and the probe path the status decision assumes.

**Closing on 2026-09-18 with phases 3-9 outstanding.** Two review passes ran — one at
`/pr:pre-test` on `410de58`, one at the close gate on the full branch — both returning
APPROVE, and both sets of findings were applied rather than deferred. The branch merges as a
partial delivery of this ticket, exactly as #9 did before it: that branch shipped the
mechanical layer alone and closed, with this ticket filed as its successor. Phases 3-9 need
the same treatment, so a successor ticket is the one piece of follow-up this close must not
drop.

## Open Questions

The three design questions the ticket says must be settled before the phases that depend on
them, plus the two carried forward from #9. **All five were settled on 2026-09-18**, before any
phase started; each has a `## Decision` section below carrying the reasoning and what it
touches. One new question was opened by that round and is live.

- ~~**What does an absent roster project?**~~ **Resolved 2026-09-18: move the defaults into
      the join.** An absent roster projects the four default Claude members, not `0 seated`.
      See `## Decision — an absent roster projects the four Claude defaults` below.
- ~~**Will `/council:status` pass `--no-probe`?**~~ **Resolved 2026-09-18: no — probe by
      default, keep `--no-probe` as an explicit opt-out.** See
      `## Decision — /council:status probes by default` below.
- ~~**Precedence between `COUNCIL_ROSTER` and `XDG_CONFIG_HOME`.**~~ **Resolved 2026-09-18:
      no precedence rule needed — delete the unused resolver.** See
      `## Decision — delete env.mjs:rosterPath rather than reconcile it` below.

Carried forward from #9:

- ~~**Model alias availability.**~~ **Closed 2026-09-18 as not answerable, and already
      handled.** Downgraded to the phase 7 README task that already covers it. See
      `## Decision — model alias availability is a limitation, not a question` below.
- ~~**Phase 9 touches a second repo (`cjus-dev`).**~~ **Resolved 2026-09-18: split it.** The
      cjus-dev half becomes its own ticket there, blocked on this PR. See
      `## Decision — phase 9 splits at the repo boundary` below.

Opened by the decisions above:

- [ ] **What mechanism makes `COLLAPSED` observable?** Phase 5 ships the class; nothing yet
      observes which model a member actually ran on, and without that the class can never
      fire. Needs settling before phase 5, not during it. See the model-alias decision below.

## Decision — an absent roster projects the four Claude defaults

Settled 2026-09-18, ahead of phases 3 and 4.

`council-state.sh` currently reports `0 seated` and `projected correlation: NONE` when no
roster exists, while `/council:ask` with no roster seats four Claude members. The script's own
`roster:` line already says the right thing — `NONE at <path> -- Claude-only council` — and the
seating line two rows below contradicts it. **The defaults move into the join**: an absent
roster seats the four Claude members and projects `HOMOGENEOUS (anthropic)`, which is the
honest reading of four members from one vendor.

The rejected alternative was to narrow the wording so the script reports only what the roster
declares. It was the smaller change, but it leaves the tool answering a question next to the
one the reader is asking: nobody opens `/council:status` to learn what a file says, they open
it to learn what the next council will do.

What this decision touches:

- [ ] **The defaults need a single declared home first.** They are currently nowhere in the
      plugin. The only four-member list under `plugins/council/` is the `CLAUDE4` fixture in
      `test-council-state.sh:107-111` (`opus`/risk-first, `sonnet`/simplicity-first,
      `haiku`/long-horizon, `fable`/contrarian), and a fixture is not a declaration. The real
      defaults live in the cjus-dev copy's `skills/ask/SKILL.md` prose. Declare them once —
      `council-lib.sh` is the natural home, matching how the key chain is not implemented a
      third time — and have both the join and `skills/ask` read from that one place.
- [ ] **`NONE` survives, with a narrower meaning.** It becomes reachable only from a *present*
      roster declaring no members. Its existing text, `NONE -- the roster declares no members`,
      is then exactly true; today that string also fires for an absent roster, where it is
      false.
- [ ] **One oracle row asserts the old answer.** `test-council-state.sh:224`,
      `t "absent roster seats nobody" 0 "$(j "$OUT" '.seating.total')"`. The assertion and its
      name both encode `0`, so both change. Per #15's note on the test approach, add the new
      input to the fixture table rather than editing the row in place where that is possible.
- [ ] **No concurrency change needed.** `MAXCONC` already defaults to `2` in the roster-absent
      branch (`council-state.sh:162`), so the `concurrency:` line stays correct.

Still open, and now sharper: if the defaults are declared in `council-lib.sh`, does
`/council:ask` still own the right to seat a different set? The decision assumes not — one
declaration, both readers — but phase 4 is where that gets tested.

## Decision — /council:status probes by default

Settled 2026-09-18, ahead of phases 3 and 4.

**`/council:status` does not pass `--no-probe`.** The flag stays, documented as an explicit
opt-out for scripted callers, `--json` consumers that want only the roster join, and the case
where someone already knows the LAN host is down.

The question was framed as a latency-versus-noise tradeoff, but reading
`council-state.sh:129-150` the probe is not cosmetic — it decides seating:

```
up      → ollama members seated
down    → unseated, "endpoint not answering"
unknown → seated anyway, PROBE_SKIPPED=1
```

`--no-probe` collapses `down` into `unknown`, and `unknown` still seats the member. So the
flag does not merely soften a claim, it reports a seat that may not exist. The comment at
line 140 already names this: collapsing the third state into the confident branch "is what
turns a skipped probe into a CROSS-VENDOR claim, which is an over-claim in the exact
direction the honesty contract exists to prevent."

Why the cost is acceptable:

- **The probe is conditional.** The whole block sits inside `if ollama.enabled = true`, so a
  Claude-only council never probes. After the decision above, Claude-only is the documented
  projection for an absent roster, which makes no-probe the common path already.
- **The stall is narrower than the framing.** A closed port on localhost refuses immediately;
  `-m 3` is only spent when Ollama is enabled *and* the endpoint is filtered or the host is
  off. That is the case where the roster asserts diversity the user is not getting, which is
  worth three seconds.
- **An always-on hedge is one nobody reads.** Defaulting to `--no-probe` sets `PROBE_SKIPPED`
  on every run, so the unconfirmed-diversity suffix would fire every time. Same failure mode
  as `lifecycle.md`'s note that a gate which false-positives trains the operator to click
  through it.
- **The silent-probe objection does not apply here.** It is a real concern for `detect.sh`
  running on every skill load, where nobody asked for network activity. Someone typing
  `/council:status` is asking what the next council will do, so the probe is the command
  working. The argument for `--no-probe` is strongest where the probe is implicit and
  weakest where it is the point.

**A knock-on for `allowed-tools`, worth catching before phase 4 writes it.** Decision 3 in the
#9 plan grants `/council:status` exactly `Bash(node:*), Read`. That predates the resolution of
`council-state.mjs` into `council-state.sh`, so the grant names the wrong interpreter: it needs
`Bash(sh:*)`. The probe itself adds no grant — `curl` is spawned inside `council-state.sh`
(line 135) rather than as its own tool call, as are `jq` and the `roster-rows.mjs` fallback —
so one `Bash(sh:*)` covers the whole script. Carry the correction into phase 4 rather than
copying Decision 3's list verbatim.

## Decision — delete env.mjs:rosterPath rather than reconcile it

Settled 2026-09-18, ahead of phase 4.

The question assumed the two resolvers disagree about `XDG_CONFIG_HOME`. They do not. The
config-dir halves are identical:

```
council_lib.sh:48  council_config_dir()  XDG_CONFIG_HOME/council  else  $HOME/.config/council
env.mjs:144        configDir()           XDG_CONFIG_HOME/council  else  $HOME/.config/council
```

The whole divergence is `COUNCIL_ROSTER`, which `council_roster_path` (`council-lib.sh:53`)
honors unconditionally and `env.mjs:rosterPath` (`env.mjs:153`) does not know about.

**`rosterPath` has no callers.** A grep across `plugins/` returns its own definition and
nothing else — no production caller, no test. The parity problem exists only because there are
two implementations of one idea and one of them is dead.

- [ ] **Delete `env.mjs:rosterPath`.** This dissolves the question instead of answering it. If
      a JS caller ever needs the roster path it gets written then, with `COUNCIL_ROSTER`
      included, rather than inheriting a gap nobody noticed.
- [ ] **Document `COUNCIL_ROSTER` in the `council-lib.sh` header**, stating that it wins over
      the config dir. This closes #9's deferred "COUNCIL_ROSTER is undocumented" item for the
      sh side, which is now the only side.

One correction to #9's framing while recording this. Its deferred list calls `COUNCIL_ROSTER`
"a production override, not a test-only knob." In-repo the evidence runs the other way: all 11
call sites are in `test-council-state.sh`, where it is how a fixture roster gets injected. It
should be documented as supported either way — a test seam that shapes the public API is still
public — but the reason to document it is the injection, not a production use that does not yet
exist.

The rejected alternative was teaching `rosterPath` about `COUNCIL_ROSTER`. It keeps two
implementations agreeing forever for no current caller, which is the instinct the port already
rejected when it refused to implement the key chain a third time.

## Decision — model alias availability is a limitation, not a question

Settled 2026-09-18. Closed as not answerable, and already handled correctly.

The per-member pins (`opus`/`sonnet`/`haiku`/`fable`) cannot be verified from here for any
account but this one, and testing cannot fix that. The design already assumes they may fail:
`council-state.sh` reports **projected** seating, and its closing note says `COLLAPSED` is only
observable after the members answer.

So it is a documented limitation, and phase 7's README list already carries it — *"Plan
dependence: the per-member model pins are not guaranteed to resolve on every plan, and what
happens when they do not."* No separate work, no open question; it is struck from the list
above and tracked as that phase 7 task.

**What this does surface is a gap in phase 5,** now live in `## Open Questions`.

Phase 5 ships the `COLLAPSED` *class* — the footer text and the classification. Nothing in the
plugin observes which model a member actually ran on, so nothing can compare an actual against
its pin, so the class can never fire. A correlation class that never triggers is worse than
none: it reads as a check that passed.

The likely mechanism is having each member state its actual model in its response and having
the reconciler compare that set against the roster's pins, but that is phase 5's decision to
make deliberately. What is settled here is only that phase 5 is incomplete without one.

## Decision — phase 9 splits at the repo boundary

Settled 2026-09-18. The cjus-dev half becomes its own ticket in that repo, blocked on this PR.

#9's phase 9 says *"Same branch, so the verification window exists but does not last."* That
cannot hold: the deletion targets `.claude/skills/council/` and `.claude/skills/council-setup/`
in **cjus-dev**, a different repository. No branch here can carry those commits, so the window
does not close at merge — it stays open for as long as nobody gets to it.

Two further reasons the split is forced rather than preferred:

- **Ordering.** Phase 9 verifies by running a real council from the *installed* plugin inside
  cjus-dev. Installation needs this merged, or a local-path install, so the verification cannot
  precede the merge it is supposed to gate.
- **The close gate cannot see it.** `/pr:close` checks artifacts in this repo. A phase whose
  completion lives in another one is a checkbox nobody here can verify, which is how a plan
  starts lying.

**Stays on this branch** — the half that lives in cjus-skills:

- [ ] Keep the generic half of the A-060 warning in `detect.sh`, dropping the attribution.
      This is phase 2 and 3 work regardless.

**Moves to a cjus-dev ticket**, blocked on this PR merging:

- [ ] Install the plugin, confirm key resolution, run one real council, then remove
      `.claude/skills/council/` and `.claude/skills/council-setup/`.
- [ ] The `CLAUDE.md` line pointing at `ASSERTIONS.md → A-060`, with the full statement
      staying in A-060.
- [ ] Check `.claude/settings.json` grants still match — `Bash(node -e:*)` does not match
      `node ${CLAUDE_PLUGIN_ROOT}/scripts/openrouter.mjs`, so OpenRouter members would quietly
      start prompting again.
- [ ] The re-sequencing correction below: create the user-level `.env` at step 3 before
      verifying, since the key is absent from all three levels on this machine.

This narrows the branch, which the ticket authorizes: it asks to *"confirm whether it should
land as its own change there."* Settling it is the answer, not scope drift. **The cjus-dev
ticket is not yet filed** — it needs the operator, since it lands in another repo.

## Correction carried forward

**Phase 9 needs re-sequencing.** Its verification step says to confirm the key "still
resolves via step 2" of the precedence chain. That is false on this machine:
`COUNCIL_OPENROUTER_API_KEY` is absent from cjus-dev's `.env`, from the environment and from
`~/.config/council/.env`, while the roster has `openrouter.enabled: true`. Those members are
consented but unseatable. The step must create the user-level file at step 3 first.

This corrects how an existing phase runs; it adds no scope.

**It now travels with the cjus-dev ticket**, not with this branch. Every step it corrects —
verifying key resolution, creating the user-level `.env`, running one real council — landed on
the far side of the split decided above. Carry this paragraph into that ticket when it is
filed, since the correction is worthless if it stays here and the work happens there.

## Relationship to #15

[#15 Harden council-state.sh's output contract and backend parity](https://github.com/cjus/cjus-skills/issues/15)
is a separate ticket and **is not in scope here**. It holds five defects in the mechanical
layer this branch builds on, classed non-blocking on #9 because nothing consumed the output.

The dependency runs one way and is worth watching: three of #15's five defects carry the
occasion *"when `skills/ask` consumes `council-state.sh`"* — which is this branch's phase 4 —
and a fourth fires *"when `detect.sh` lands"*, which is phase 3. Landing those phases is what
turns #15 from latent into live. If a phase here surfaces one of them concretely, record it
under `## Deferred` and leave the fix on #15 rather than widening this branch.

## Deferred

### The unconfirmed-diversity annotation is attached to the class, not to the cause

Found 2026-09-18 while settling the probe decision. Not among #15's five, but the same output
contract, so it likely belongs there rather than here.

`UNCONFIRMED` is appended only to the `CROSS-VENDOR` line (`council-state.sh:257-262`). A
present roster listing only Ollama members seats them as vendor `local` — one vendor, so
`HOMOGENEOUS (local)` — and when the probe was skipped that line is equally unconfirmed and
carries no annotation.

*symptom:* `--no-probe` on an Ollama-only roster reports confident `HOMOGENEOUS` seating for
members that may not be answering.
*occasion:* whenever `--no-probe` is passed, which the decision above keeps as a supported
path rather than removing.

The fix is to attach the suffix to `PROBE_SKIPPED` wherever a seated Ollama member contributed
to the class, not to the `CROSS-VENDOR` branch alone. Per #15's note on the test approach, the
input belongs in the fixture table.

`skills/status` now documents this gap rather than papering over it, so the skill does not
assert an annotation the script may not emit.

### `M=`/`P=` env prefixes defeat an `allowed-tools` prefix rule

Raised by the phase 1-2 review, 2026-09-18. **Needs an operator decision, so it is not fixed
here.**

`skills/ask` instructs `M=<model> P=<file> node "${CLAUDE_PLUGIN_ROOT}/scripts/openrouter.mjs"`.
Claude Code strips a leading assignment only for a known-safe set of variables; `M` and `P`
are not in it, so `Bash(node:*)` does not match and every OpenRouter member prompts. Nor can a
narrower rule help: `${CLAUDE_PLUGIN_ROOT}` no more expands in a permission pattern than it
does in `settings.json`.

This is the same defect class the phase 9 notes already record for cjus-dev's
`Bash(node -e:*)` grant — it reappeared one layer up, in the skill's own frontmatter.

The fix worth considering is giving `openrouter.mjs` a `--model` / `--prompt-file` interface,
which restores a plain `node …` prefix at no cost to secrecy: only the key must stay out of
argv, and it already does via the env chain. That changes a shipped interface and phase 8 is
what tests it, so the decision belongs to the operator rather than to a review follow-up.

### Pre-existing: two shipped scripts document the key chain without `$XDG_CONFIG_HOME`

Found 2026-09-18 while correcting the same wording in this branch's own files.
`council-lib.sh:131` and `env.mjs:38` both describe level 3 as `~/.config/council/.env`, while
`configDir`/`council_config_dir` resolve `$XDG_CONFIG_HOME/council` first. Both files are
pre-existing and outside this diff, so the wording was left alone rather than widening the
branch; it is the same class as #15's output-contract items and likely belongs there.

### Declared-but-uninstructed: `Bash(jq:*)` in `skills/setup`

Minor. Plausibly intended for parsing the OpenRouter catalogue the skill fetches with `curl`,
but no step actually instructs `jq`. Either instruct it at that step or drop the grant.

## About Ticket

**Issue:** [#14 Finish the council plugin port: phases 2-9](https://github.com/cjus/cjus-skills/issues/14)

Successor to #9, which delivered only the mechanical layer (`env.mjs`, `council-lib.sh`,
`roster-rows.mjs`, `council-state.sh` and their two suites) and closed on merge of PR #13.

The plugin currently ships **no skills** and is deliberately absent from
`.claude-plugin/marketplace.json`, so it is inert. The full nine-phase plan and the four
settled design decisions live in
`changelog/9-port-the-council-skills-into-a-reusable-council-plugin/PLAN.md`.

### Remaining phases

- [ ] **Phase 1 (rest)** — the three skill directories (`skills/ask`, `skills/setup`,
      `skills/status`), `reference/`, and the marketplace entry. The marketplace entry is
      held back deliberately until a skill exists.
- [ ] **Phase 2 (rest)** — strip repo-private material from the four shipped files, and move
      `council-setup` off its sibling-relative path onto `${CLAUDE_PLUGIN_ROOT}`.
- [ ] **Phase 3 (rest)** — port `detect.sh`, sourcing `council-lib.sh` so the key chain is not
      implemented a third time, and have it report which source won. Replay
      `test-env.sh`'s oracle table against it.
- [ ] **Phase 4 (rest)** — have `skills/ask` call `council-state.sh` instead of re-deriving
      seating, and ship `/council:status` as a read-only wrapper.
- [ ] **Phase 5** — `COLLAPSED` correlation class, cost statement extended to `pooled`,
      per-choice cost in `/council:setup`.
- [ ] **Phase 6** — split the reference docs out of `SKILL.md`, keeping the honesty contract
      and output contract inline.
- [ ] **Phase 7** — `plugins/council/README.md`, the repo-root README section and Layout block.
- [ ] **Phase 8 (rest)** — `detect.sh` probes and `openrouter.mjs` exit-code tests.
- [ ] **Phase 9** — retire the cjus-dev copy and relocate the A-060 warning.

### Design questions that must be settled first

- [ ] **What does an absent roster project?** `council-state.sh` reports `0 seated` and
      `correlation: NONE`, but `/council:ask` with no roster still seats four Claude members
      by default. Either those defaults belong in the join, or the wording must say it reports
      only what the roster declares. As written it is a confident claim the script has not
      established, which is the one thing it exists to prevent.
- [ ] **Will `/council:status` pass `--no-probe`?** Decision 3 notes `detect.sh`'s `curl -m 3`
      is a visible stall on a cold LAN host, which argues for it. If so, the
      unconfirmed-diversity annotation becomes the normal path rather than a defensive one.
- [ ] **Precedence between `COUNCIL_ROSTER` and `XDG_CONFIG_HOME`.** `council_roster_path`
      prefers `COUNCIL_ROSTER` unconditionally; `env.mjs:rosterPath` does not know about it.
      Harmless while nothing calls `rosterPath`.

### Correction carried forward

**Phase 9 needs re-sequencing.** Its verification step says to confirm the key "still resolves
via step 2" of the precedence chain. That is false on this machine:
`COUNCIL_OPENROUTER_API_KEY` is absent from cjus-dev's `.env`, from the environment and from
`~/.config/council/.env`, while the roster has `openrouter.enabled: true`. Those members are
consented but unseatable. The step must create the user-level file at step 3 first.
