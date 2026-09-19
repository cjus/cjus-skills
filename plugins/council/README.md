# council

Three Claude Code skills that put one question to several independent members and reconcile their answers **without manufacturing consensus**.

A single model asked a hard question gives you one draw from one error distribution. Asking it three times gives you three draws from the same one. This plugin exists for the cases where that difference matters — an architecture call, an irreversible migration, a security judgement — and its whole design is arranged around not overstating what it found. It will not compute a consensus percentage, it will not call four Claude members agreeing "verified", and when a round loses a member it says so and credits no agreement from it.

---

## Contents

- [What it costs](#what-it-costs)
- [Install](#install)
- [`/council:ask`](#councilask)
- [`/council:setup`](#councilsetup)
- [`/council:status`](#councilstatus)
- [The roster](#the-roster)
- [What agreement is worth](#what-agreement-is-worth)
- [Limitations](#limitations)
- [What ships here](#what-ships-here)

---

## What it costs

Read this before the quick start, because the multiplier is structural rather than incidental.

| Mode | Roughly |
|---|---|
| `individual` or `categorized`, N members | **Nx** a normal turn |
| `pooled`, N members | **2Nx** — it polls twice by design |

With the default four members, one `/council:ask` is about **4x** a normal turn and one `pooled` round about **8x**. External members bill separately: OpenRouter per token against your own credit, Codex against your ChatGPT plan, Ollama not at all.

No dollar figure and no token estimate appear anywhere in this plugin, and that is deliberate. The same reasoning that makes the skills refuse a consensus percentage argues against a number implying precision they cannot have. What you get instead is the multiplier, stated before the spend.

The skills state the cost themselves before fanning out — on any council larger than the four defaults, and on `pooled` at any size, because doubling a four-member council costs what an eight-member single round does.

---

## Install

```bash
claude plugin marketplace add cjus/cjus-skills
claude plugin install council@cjus-skills
```

Restart Claude Code and the three commands become available. **Plugin skills are namespaced by their plugin**, so they are `/council:ask`, `/council:setup` and `/council:status`; a bare `/ask` does not resolve.

**There is nothing to configure to start.** With no roster file, the council is four Claude members on distinct models, which needs no key, no Node and no `jq`. Everything beyond that is opt-in through `/council:setup`.

What each extra capability needs:

| To do this | You need |
|---|---|
| Run a Claude-only council | nothing |
| Read a roster file | `jq` **or** Node — either, not both |
| Probe an Ollama endpoint | `curl` |
| Seat OpenRouter members | Node, and `COUNCIL_OPENROUTER_API_KEY` |
| Seat a Codex member | the `codex` CLI, logged in |

Nothing is installed when a plugin is installed — a Claude Code manifest has no dependency-resolution step — so every binary here is one you already have or one the plugin does without. That is why the roster is read through either parser rather than requiring one.

---

## `/council:ask`

```
/council:ask should we move the job queue off Postgres
/council:ask pooled which of these two migration plans is safer
/council:ask individual review this design doc
```

Three modes, and the argument is optional — `categorized` is the default.

| Mode | What it does |
|---|---|
| `individual` | Each answer verbatim under its member label. No reconciliation, no judge step. |
| `categorized` | **Default.** Sorts the answers into common agreement, complementary angles, and genuine conflicts, naming which member held what. |
| `pooled` | Delphi. Fans out, distils a neutral pool with no attribution and no counts, shuffles it, re-polls every member, then shows the before and after — and **declares no winner**. |

`pooled` is the mode worth having. Its purpose is stripping social proof out of the second round, so it is the one mode that *gains* value from a homogeneous roster. If positions still diverge after the pool, that divergence is the finding, and preserving it is the point.

A few rules that shape what comes back:

- **Conflicts are resolved pessimistically.** When it is unclear whether two positions genuinely conflict, they are reported as conflicting. A false conflict costs you a paragraph; a false agreement costs you the decision.
- **A tiebreak appears only when the positions differ in verifiable backing** — one cites a source and the other does not, or their sources actually disagree. Equally-backed positions get no tiebreak, because a judge asked to pick will always produce a confident-sounding one, and that is the cheapest way to make a council look authoritative while adding nothing.
- **The judge gets no tools and never sees your attachments.** It reconciles member answers, not source material, so repo content never reaches it in a trust-affirming position.

---

## `/council:setup`

```
/council:setup
```

Writes the roster, which is a **consent record** rather than a capability list. It reports what is installed, then asks — provider by provider — what you agree to spend, stating each choice's cost at the point it offers it.

It will not seat a paid provider because that provider happens to be installed. A skill has no settings UI and no quota-warning surface, so a tool that auto-seats a logged-in CLI starts drawing down your subscription on first use with no way to see it or undo it. Every external provider is off until you say otherwise.

It never writes a key into the roster, and it never writes one into a project's `.claude/settings.json`.

---

## `/council:status`

```
/council:status
```

A read-only, 20-second answer to "what would the council actually seat right now, and why is it still HOMOGENEOUS". **It writes nothing, anywhere.** It reports key resolution and where the key came from, the roster path and state, per-member seating, anything consented-but-unavailable with the reason, and the correlation class that projects.

Use it to check a roster edit took effect *before* spending a fan-out finding out.

---

## The roster

One JSON file, at `$COUNCIL_ROSTER` if set, else `$XDG_CONFIG_HOME/council/roster.json`, else `~/.config/council/roster.json`. `/council:setup` writes it; `reference/roster.md` documents every field.

**Seating is a join, not a lookup.** A member needs two independent things: the roster's consent, and availability on this machine. The case that motivates the whole design is not hypothetical — a roster can enable OpenRouter with four vetted models while no key resolves anywhere, and those four are then silently absent while the council still runs, still agrees with itself, and reports a class that reads like a roster problem rather than a key problem.

Three roster states, deliberately reported differently:

| State | Means |
|---|---|
| **absent** | Claude-only, on the four defaults. The normal case, not a fault. |
| **present, no members** | Seats nobody. A decision you made, and nothing overrides it. |
| **present, unparseable** | **Refuses.** Prints no seating at all. |

That third one matters more than it looks. A roster that fails to parse and a roster with no external members otherwise produce an identical Claude-only answer — and one of them is a file you believe is in effect. So it refuses instead of falling back.

**Never put an API key or a credentialed URL in the roster.** The capability probe injects its first 40 lines into the model's context on every invocation.

---

## What agreement is worth

Every answer carries a correlation class, and the class is the part to read first.

| Class | Meaning |
|---|---|
| `HOMOGENEOUS` | Every seated member came from one vendor. Errors are correlated, so **agreement is weak evidence**. |
| `CROSS-VENDOR` | Members span vendors. Errors are far less correlated, so agreement is meaningfully stronger. |
| `NONE` | The roster declares no members. |
| `COLLAPSED` | The model pins did not resolve and every member ran on one model. **This is one model wearing N hats, and agreement here is not evidence of anything.** |

The first three are *projected* — computed from the roster and the key chain before anyone answers. `COLLAPSED` is the one that can only be known afterwards, and it is checked after the round lands rather than assumed either way.

The default roster is `HOMOGENEOUS`, and the plugin says so every time rather than letting four Claude members agreeing read as corroboration. Pinning distinct models buys real error diversity, but they share a vendor and an overlapping training lineage. The single best fix is one OpenRouter key: it reaches many vendors at once, so the council stops being all-Claude.

---

## Limitations

**The model pins are not guaranteed to resolve on every plan.** The four Claude members are pinned to `opus`, `sonnet`, `haiku` and `fable`, and that is the only real decorrelation an internal council has. Whether your plan serves all four cannot be checked from inside the plugin, so seating is always reported as *projected*.

What happens when a pin does not resolve is **partly established**. A pin that is not one of those four values fails loudly, before any model runs, and the join catches it and unseats that member with a reason. A pin that is a valid name your plan cannot serve is the case that is *not* established — whether the harness reports an error or quietly substitutes the session model was not determined. The plugin therefore does not assume: it asks each member to state the model it ran on, and reports `COLLAPSED` only when every member names the same one. Anything less consistent is reported as unverified rather than as confirmed either way.

**A member's model report is its own.** It is good evidence and it is not an observation the plugin made. A full collapse is trusted because every member independently agreeing is hard to get wrong in the same direction; a partial mismatch is not.

**Ollama has no authentication of any kind.** If your endpoint is not loopback, anyone who can reach that port can run inference, enumerate models, pull models onto the disk and delete existing ones. `OLLAMA_ORIGINS` is browser CORS and is not a security control.

**Always write the Ollama port explicitly.** A bare `host` defaults to `:11434`, but `http://host` is a URL and defaults to `:80` — the most common way to point this at nothing. The capability probe warns when it sees a scheme with no port.

**Nothing rate-limits a fan-out against your quota.** `maxConcurrentExternal` is honoured by the skills, not enforced by the harness.

---

## What ships here

```
plugins/council/
  .claude-plugin/plugin.json
  README.md
  reference/roster.example.json      a commented roster to copy
  reference/roster.md                roster format, join contract, pin rules
  reference/providers.md             how to call each external member
  reference/trust-boundary.md        member vs judge, and attachment limits
  scripts/council-lib.sh             shared sh helpers: key chain, paths, defaults
  scripts/council-state.sh           the seating join, --text or --json
  scripts/detect.sh                  capability probe, injected at skill load
  scripts/env.mjs                    the key chain for the Node side
  scripts/openrouter.mjs             one OpenRouter member call
  scripts/roster-rows.mjs            the Node roster parser, when jq is absent
  scripts/test-council-state.sh      probe suite: the key chain and the join
  scripts/test-detect.sh             probe suite: what the capability block prints
  scripts/test-env.sh                probe suite: the Node key chain, value-exact
  skills/ask/SKILL.md
  skills/setup/SKILL.md
  skills/status/SKILL.md
```

The key chain has two implementations and no more — `env.mjs` for the Node side that needs the key's value, and `council-lib.sh` for the `sh` side that must not require a Node install. They are held to an oracle table that fails a case when they *disagree* and also when they agree on a wrong answer. Same discipline for the two roster parsers, which are diffed against each other on every fixture.
