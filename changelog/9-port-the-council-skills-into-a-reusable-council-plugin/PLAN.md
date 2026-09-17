# Port the council skills into a reusable council plugin

Start date: 2026-09-16 16:40:16 MDT

## Overview

Package the `council` and `council-setup` skills, currently project-scoped in `cjus-dev`
at `.claude/skills/`, as a third plugin in this marketplace alongside `bookcraft` and
`pr`. Three things break outside cjus-dev and must be fixed; four design decisions were
settled before the ticket was filed and are recorded in the body below.

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred`, never as new scope.

## Plan

- [ ] Phase 1: Scaffold `plugins/council/` — manifest, hoisted `scripts/` and
      `reference/`, three skill directories, marketplace entry.
- [ ] Phase 2: Fix the three blockers — self-contained `.env` reader in
      `openrouter.mjs`, strip repo-private material from all four files, move
      `council-setup` onto `${CLAUDE_PLUGIN_ROOT}`.
- [ ] Phase 3: Decision 2 — implement the three-level key precedence chain and have
      `detect.sh` report which source won.
- [ ] Phase 4: Decision 3 — extract `council-state.mjs`, have `skills/ask` call it
      instead of re-deriving seating, ship `/council:status` as a read-only wrapper.
- [ ] Phase 5: Decision 1 — `COLLAPSED` correlation class, cost statement extended to
      `pooled`, per-choice cost in `/council:setup`.
- [ ] Phase 6: Split the reference docs out of `SKILL.md`, keeping the honesty contract
      and output contract inline.
- [ ] Phase 7: `plugins/council/README.md` plus the repo-root README section and Layout
      block.
- [ ] Phase 8: Tests — `detect.sh` probes, `openrouter.mjs` exit codes,
      `council-state.mjs` join, `claude plugin validate --strict`.
- [ ] Phase 9: Decision 4 — retire the cjus-dev copy after verifying the installed
      plugin works there, and relocate the A-060 warning into cjus-dev's `CLAUDE.md`
      and `ASSERTIONS.md`.

## Status

Updated 2026-09-16. Status only; the objective and the nine phases above are unchanged.

Landed in `715e9c2` and `0b7451b` — the mechanical layer, ahead of any skill that calls it.
Close-gate review returned **APPROVE** with three non-blocking findings, now under
`## Deferred`. 127 test cases pass; `claude plugin validate --strict` passes; no CI exists in
this repo.

- **Phase 1, partial.** `plugins/council/` exists with its manifest at 0.1.0 and passes
  `claude plugin validate --strict`. Still missing: the three skill directories,
  `reference/`, and the marketplace entry. The marketplace entry is being held back
  deliberately until a skill exists, so the listing never advertises an unusable plugin.
- **Phase 2, one of three blockers closed.** `scripts/env.mjs` replaces the host-repo
  `dotenv.mjs` import. The repo-private material and the `council-setup` relative path
  are untouched.
- **Phase 3, the chain is implemented; the reporting half is not.** Precedence lives in
  `env.mjs` and `council-lib.sh`. `detect.sh` has not been ported, so nothing reports
  which source won yet.
- **Phase 4, the script exists; the two callers do not.** `council-state.sh` performs the
  seating join. `skills/ask` does not call it and `/council:status` does not exist.
- **Phase 8, two of four suites.** 46 cases for the key chain, 66 for the join and the
  two JSON backends. `openrouter.mjs` exit codes and `detect.sh` probes are not written.

**Phase 9 needs re-sequencing before it runs.** Its verification step says to confirm the
key "still resolves via step 2" of the precedence chain. Verified false on this machine:
`COUNCIL_OPENROUTER_API_KEY` is absent from cjus-dev's `.env`, from the environment, and
from `~/.config/council/.env`, while the roster has `openrouter.enabled: true`. The
members are consented but unseatable, so the step must create the user-level file at step
3 first. This corrects how an existing phase runs; it adds no scope.

## Open Questions

- ~~**Is `council-state.mjs` the right runtime?**~~ **Resolved: `sh` plus jq.** A
  Claude-only council needs no Node and must not acquire the dependency to read its own
  status. The roster is parsed by jq *or* Node, whichever is present, because nothing is
  installed when a plugin is installed — verified against `claude plugin validate
  --strict`, where `requires` and `postInstall` are ignored at load time.
- ~~**Starting version for `plugin.json`.**~~ **Resolved: 0.1.0**, the conventional start
  for a new plugin. `bookcraft` at 1.0.2 and `pr` at 0.2.0 imply nothing for a third.
- **Model alias availability.** The per-member pins (`opus`/`sonnet`/`haiku`/`fable`)
  are assumed to resolve; nothing verifies this, and the `COLLAPSED` class exists
  precisely because they may not. No way to test other plans from here. Still open.
- Phase 9 touches a second repo (`cjus-dev`). It is in scope as the retirement half of
  this port, but confirm whether it should land as its own change there. Still open, and
  now carries the re-sequencing noted above.

## About Ticket

**Issue:** [#9 Port the council skills into a reusable council plugin](https://github.com/cjus/cjus-skills/issues/9)

Package the `council` and `council-setup` skills, currently project-scoped in `cjus-dev` at `.claude/skills/`, as a third plugin in this marketplace alongside `bookcraft` and `pr`.

`council` fans one question out to N independent members (four Claude subagents by default, optionally OpenRouter / Ollama / Codex members) and reconciles their answers in three modes — `individual`, `categorized`, `pooled`. Its design already separates availability (`detect.sh`) from consent (`~/.config/council/roster.json`), which is the part that ports cleanly.

### Blockers — these break outside cjus-dev

- [ ] **`openrouter.mjs` depends on cjus-dev's `scripts/dotenv.mjs`.** `repoRoot()` walks three levels up from `.claude/skills/council/`; under any plugin layout that path is wrong, and the fallback to `process.cwd()` lands in a project that has no such file. The `await import(...)` is top-level with no `try`/`catch`, so it throws `ERR_MODULE_NOT_FOUND` and exits `1` — an undocumented code, since the skill only handles `3` (no key), `4` (HTTP), `5` (usage). Replace with a self-contained `.env` reader.
- [ ] **Repo-private material is baked into shipped files.** `detect.sh` prints `note: OPENROUTER_API_KEY is also set. That is sb's PRODUCTION key (ASSERTIONS.md A-060).` into any installing user's context — false on their machine, and it names an internal product, an internal assertion ID, and the fact that a production key is exported into the shell Claude Code runs under. Same material appears in `SKILL.md`, `README.md`, `roster.example.json` and `council-setup/SKILL.md`. Generalize the rule, drop the attribution.
- [ ] **`council-setup` reaches its sibling by relative path** (`${CLAUDE_SKILL_DIR}/../council/detect.sh`) and asserts a cjus-dev fact: *"In the cjus.dev repo `.claude/settings.json` already allows `Bash(curl:*)` and `Bash(node -e:*)`"*. Move to `${CLAUDE_PLUGIN_ROOT}`, and have it read the actual settings file instead.

### Layout

- [ ] Create `plugins/council/` following the `pr` shape — hoisted `scripts/` and `reference/`, every path via `${CLAUDE_PLUGIN_ROOT}`:

```
plugins/council/
  .claude-plugin/plugin.json
  README.md
  scripts/detect.sh              hoisted; both skills cite one copy
  scripts/openrouter.mjs         self-contained dotenv
  scripts/council-state.mjs      resolved seating + correlation (see below)
  scripts/test-detect.sh
  reference/providers.md         openrouter/ollama/codex invocation, exit codes, rate limits
  reference/trust-boundary.md    MEMBER/JUDGE split, the two notices, attachment caps, git filter check
  reference/roster.md            schema, consent model, roster.example.json
  skills/ask/SKILL.md
  skills/setup/SKILL.md
  skills/status/SKILL.md
```

- [ ] Rename for namespacing: `/council` → `/council:ask`, `/council-setup` → `/council:setup`. Update every prose reference.
- [ ] **Keep the honesty contract and output contract inline in `skills/ask/SKILL.md`.** They apply to every invocation, unlike `pr`'s reference docs which are cited at a decision point. Extracting them would make them skippable. Only providers / trust-boundary / roster-schema move out; that takes SKILL.md from 323 lines to roughly 180.
- [ ] Add the `council` entry to `.claude-plugin/marketplace.json`.
- [ ] Honor `XDG_CONFIG_HOME` for the roster path, matching how `bookcraft` honors `XDG_CACHE_HOME`.
- [ ] Narrow `allowed-tools` from bare `Bash`. Actual needs: `node`, `curl`, `jq`, `codex exec`, `sh`, `seq`, `sort`, `git diff`, `git config`.

### Decision 1 — cost is stated, not capped

Keep four Claude members as the default. Trimming to two or three buys back a little quota and makes `categorized` worse: a 2-1 split across three buckets reads like consensus, which is what the honesty contract exists to prevent. Make the cost legible instead.

- [ ] README gets a **What it costs** block before the quick start. State the structural multiplier — one `/council:ask` is roughly 4x a normal turn, `pooled` roughly 8x because it polls twice. No dollar figure and no token estimate: the same reasoning that makes the skill refuse a consensus percentage argues against a number implying precision it cannot have.
- [ ] Add a third correlation class to the output contract. Today the footer enumerates `HOMOGENEOUS` and `CROSS-VENDOR`; the case where every model override fails and all members land on the session model is handled only as prose in the seating section, and prose instructions are the ones that get skipped. Name it, so it is as hard to omit as `DEGRADED`:

```
COLLAPSED — model overrides did not resolve; every member ran on
<model>. This is one model wearing N hats. Agreement here is not
evidence of anything.
```

- [ ] Extend the existing pre-fan-out cost statement to trigger on `pooled` regardless of member count. Doubling a four-member council costs the same as an eight-member one, and the current rule only fires on size.
- [ ] `/council:setup` should state what each choice costs at the point it is offered. It already does this for external providers; the Claude member count is the one place it does not, and it is the one enabled by default.

### Decision 2 — key resolution precedence

Most-specific wins, the shape `git config` uses. Same `KEY=VALUE` format at every level, so one parser serves all three.

```
1. $COUNCIL_OPENROUTER_API_KEY in the environment   (per-invocation)
2. ./.env in the current project                     (per-project)
3. ~/.config/council/.env                            (per-user default)
```

- [ ] Implement the chain in the self-contained reader that replaces `dotenv.mjs`. This falls out of the blocker fix for free — that parser is being written anyway.
- [ ] Make `detect.sh` report **which source won**, mirroring what it already does for the Ollama endpoint (`(from roster)`): `openrouter: COUNCIL_OPENROUTER_API_KEY present (from ~/.config/council/.env)`. Presence only, never the value.
- [ ] `chmod 600` the user-level file. The existing rules hold unchanged: never the roster, never project `.claude/settings.json`.

Backward compatible for cjus-dev, which has the key in its `.env` and is served at step 2 before the user file is consulted. First install anywhere works once a key is dropped at step 3, which matches the roster already being user-scoped.

### Decision 3 — extract seating into a script, then ship `/council:status`

- [ ] Add `scripts/council-state.mjs`, called as `node "${CLAUDE_PLUGIN_ROOT}/scripts/council-state.mjs" --text`, directly mirroring `pr-lifecycle-state.mjs`. It performs the join the user currently does by hand across two sources: given detection **and** the roster's `enabled` flags, which members get seated, on which models, and what correlation class results.

```
key:      COUNCIL_OPENROUTER_API_KEY (from ~/.config/council/.env)
roster:   ~/.config/council/roster.json
seating:  4 claude  + 2 openrouter  + 0 ollama  + 0 codex
  risk-first        claude      opus
  simplicity-first  claude      sonnet
  ...
  contrarian        openrouter  deepseek/deepseek-v4-pro
projected correlation: CROSS-VENDOR (anthropic, deepseek)
```

- [ ] Say **projected** correlation. `COLLAPSED` is only observable after the subagents land, so a script genuinely cannot predict it.
- [ ] Have `skills/ask/SKILL.md` call the script rather than re-deriving seating. This replaces a skippable prose warning — *"the detection block is a 40-line summary and is not the source of truth"* — with a mechanical one.
- [ ] Ship `/council:status` as a thin read-only wrapper. Named `status`, not `roster`, because it reports detection, key resolution and seating, and because `/pr:status` already establishes the pattern here as *"a 20-second read that writes nothing."* The separation earns its keep through `allowed-tools`: `/council:setup` needs `Write` and `AskUserQuestion` to rewrite the consent record, and someone asking "why is this still HOMOGENEOUS" should not have to invoke that. `/council:status` gets `Bash(node:*), Read` and nothing else.

### Decision 4 — retire the cjus-dev copy, relocate the warning

Two diverging copies of the same logic is a worse outcome than anything the local copy protects against.

- [ ] Sequence: install the plugin, confirm inside cjus-dev that the key still resolves via step 2 of the precedence chain, run one real council, **then** remove `.claude/skills/council/` and `.claude/skills/council-setup/`. Same branch, so the verification window exists but does not last.
- [ ] Keep the generic half of the warning in `detect.sh`. The detection ports; only the attribution is local:

```
note: OPENROUTER_API_KEY is also set. Council does not read it —
      it seats only COUNCIL_OPENROUTER_API_KEY. If that key belongs
      to an application, keep it that way.
```

- [ ] In cjus-dev: one line in `CLAUDE.md` pointing at `ASSERTIONS.md → A-060`, with the full statement staying in A-060. `CLAUDE.md` loads every session, so the warning keeps the property that mattered — ambient, unprompted, every turn — and now covers anything that might seat that key, not just council. A general-purpose tool was carrying one repo's secret-management policy in its detection script; packaging exposed that rather than caused it.
- [ ] In cjus-dev: check `.claude/settings.json` grants still match. `Bash(node -e:*)` does not match `node ${CLAUDE_PLUGIN_ROOT}/scripts/openrouter.mjs`, so OpenRouter members would quietly start prompting again.

### README

`plugins/council/README.md`, adapted from the existing 459-line `council/README.md`, which mostly transfers once the cjus-dev material is stripped.

- [ ] **What it costs**, before the quick start (decision 1).
- [ ] Quick start, the three modes, and why `pooled` is the one that gains value from a homogeneous roster.
- [ ] How to read the footer — `seated/answered`, `Roster`, and all three correlation classes including the new `COLLAPSED`.
- [ ] The three-layer opt-in model: availability (`detect.sh`) / consent (roster) / permission (`settings.json`).
- [ ] Key resolution: the precedence chain from decision 2, and the standing rules about where a key must never go.
- [ ] Adding external members: OpenRouter first as the only one that makes a roster genuinely cross-vendor, then Ollama, then Codex. Carry over the existing Ollama port-and-auth warnings verbatim — `http://host` defaulting to `:80` rather than `:11434`, and Ollama having no authentication of any kind.
- [ ] Requirements table, limitations, troubleshooting. Retire the troubleshooting entries that `/council:status` now answers directly.
- [ ] Plan dependence: the per-member model pins (`opus`/`sonnet`/`haiku`/`fable`) are not guaranteed to resolve on every plan, and what happens when they do not.
- [ ] Note that `detect.sh` runs on every skill load and does a `curl -m 3` against the resolved Ollama endpoint — a visible stall on a cold LAN host, and a silent outbound probe each invocation. Acceptable, but stated rather than discovered.
- [ ] Add the `council` section to the repo-root `README.md`, matching the `bookcraft` and `pr` entries, and extend its **Layout** block.

### Tests

`pr` ships an acceptance suite and a hook probe suite, and its README says to point them at an *installed* copy because that is what catches packaging defects. `council` currently ships none, and its mechanical substrate is exactly where the packaging bugs will be.

- [ ] `detect.sh`: port normalization (bare `host` → `:11434`, `http://host` → the `:80` warning, `host:port`, trailing slashes), userinfo redaction, roster absent / unreadable / present, and something-answering-that-is-not-Ollama.
- [ ] `openrouter.mjs`: exit codes `3`/`4`/`5` against a stub endpoint. This is what proves the blocker fix rather than asserting it.
- [ ] `council-state.mjs`: the roster → members → correlation join, which is the logic most likely to break in packaging and is currently prose a model executes.
- [ ] `claude plugin validate --strict .` and `claude plugin validate --strict plugins/council` both pass.

## Deferred

Raised by the `/pr:pre-test` review and the `/pr:close` review gate on 2026-09-16. Triaged at
`/pr:close`; most of these are expected to DROP. Recorded here so the decision is made once,
not rediscovered.

### From the close-gate review (VERDICT: APPROVE, none blocking)

- **An empty middle TSV field collapses and shifts the whole seating row.** Tab is IFS
  *whitespace*, so consecutive tabs are treated as one delimiter: a roster with
  `"stance": ""` yields `{"stance":"opus","kind":"claude","model":"","vendor":"anthropic"}`.
  Confirmed on `/bin/sh` and `dash`. The backends default only a *missing* field to `-`, not
  an empty string.
- **Three `--json` fields are interpolated without escaping** while their siblings are
  escaped: `vendors`, `roster.path` and `key.source`. A model id containing a quote makes the
  tool's own `--json` unparseable.
- **The two roster backends disagree at the refusal boundary.** jq refuses an ill-typed
  `external`/`members`/`models`; Node coerces and reports confident seating. An object-keyed
  `members` gives jq `2 seated HOMOGENEOUS` and Node `0 seated NONE`. This extends the
  existing backend-parity entry below into a class that entry did not name.

- **Roster-shape backend parity.** jq's `//` and JS's `??` diverge on a `false`-valued
  field (`{"maxConcurrentExternal": false}` → `2` under jq, `false` under Node); a
  non-scalar value diverges too (`"model": ["opus","sonnet"]` → jq keeps the array text,
  Node joins with a comma). Symptom: the two backends print different seating for one
  file. Occasion: next time the roster schema gains a field.
- **TSV-contract injection.** A tab or newline inside a roster string can inject a
  synthetic `member` row. Both backends behave identically, and the roster is
  self-authored, so this is self-inflicted only.
- **Endpoint normalization edge cases.** `myserver/ollama` becomes
  `http://myserver/ollama:11434`, and IPv6 `::1` is not bracketed. Occasion: when
  `detect.sh` lands, since it shares `council_normalize_endpoint`.
- **Whitespace-class drift between the two key chains.** JS `trim()` covers all Unicode
  whitespace; the sh side handles space and tab. A value that is a lone vertical tab or
  NBSP resolves to different levels. Low realism, but it is live drift on an input the
  oracle table does not cover.
- **`displayPath` prefix asymmetry.** `env.mjs` uses a bare `startsWith(home)` while the
  sh side requires a `/` boundary, so `HOME=/tmp/hm` with a project at `/tmp/hmore`
  renders differently.
- **A vendor slug containing a space** makes the `wc -w` count over-report and yields
  CROSS-VENDOR for a single vendor.
- **`COUNCIL_ROSTER` is undocumented** in the library header although it is a production
  override, not a test-only knob.
- **Backend-dependent refusal text.** The Node backend's message on an unreadable or
  invalid roster is terser than the jq branch's, so the user-facing wording depends on
  which backend ran.

### Needs an operator decision, not triage

- **What does an absent roster project?** The script reports `0 seated` and
  `correlation: NONE`, but `/council:ask` with no roster still seats four Claude members
  by default. Either the four defaults belong in this join, or they stay in
  `skills/ask/SKILL.md` and this script's wording must say it is reporting only what the
  roster declares. The current text is a confident claim about the next council that the
  script has not established, which is the one thing it exists to prevent.
- **Will `/council:status` pass `--no-probe`?** Decision 3 notes that `detect.sh`'s
  `curl -m 3` is a visible stall on a cold LAN host, which argues for it. If yes, the
  unconfirmed-diversity annotation becomes the normal path rather than a defensive one.
- **Precedence between `COUNCIL_ROSTER` and `XDG_CONFIG_HOME`.** `council_roster_path`
  prefers `COUNCIL_ROSTER` unconditionally; `env.mjs:rosterPath` does not know about it.
  Harmless today because nothing calls `rosterPath`, worth settling before something does.
