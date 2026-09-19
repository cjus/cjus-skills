# The roster, the join, and the pins

Reference for `/council:ask` and `/council:setup`. The skill carries the action; this
file carries the contract behind it. Read it when you are changing the roster, reading
the join's JSON, or deciding what a pin result means.

## The roster file

One JSON object, at `$COUNCIL_ROSTER` if set, else `$XDG_CONFIG_HOME/council/roster.json`,
else `~/.config/council/roster.json`. `scripts/council-lib.sh:council_roster_path`
resolves it, and anything that writes a roster must resolve it the same way or the user
configures a file nothing reads.

**It is a consent record, not a capability list.** A member listed here is explicit
consent to spend that provider's quota. Detection says what is *possible*; this file says
what the user has *agreed to*. Never put an API key or a credentialed URL in it —
`detect.sh` injects its first 40 lines into the model's context on every invocation.

```json
{
  "members": [
    { "id": "opus", "kind": "claude", "model": "opus", "stance": "risk-first" }
  ],
  "external": {
    "openrouter": { "enabled": false, "models": [ { "id": "<author>/<slug>", "stance": "..." } ] },
    "ollama":     { "enabled": false, "endpoint": "http://localhost:11434",
                    "models": [ { "id": "<model>", "stance": "..." } ] },
    "codex":      { "enabled": false }
  },
  "maxConcurrentExternal": 2
}
```

Two independent halves, and the council is the union of both:

- **`members[]`** — Claude subagents. Being listed *is* the consent; they carry no
  `enabled` flag. `kind` is always `"claude"` and exists so the file is self-describing.
- **`external.<provider>`** — one member per entry in that provider's `models[]`, and
  **only when that provider's `enabled` is `true`.** `codex` seats a single member and
  carries no model list.

`maxConcurrentExternal` defaults to `2`. Nothing in the harness enforces it.

### An absent roster is not an empty one

No roster file means a **Claude-only council**, which is the documented normal case and
not a fault. The join seats the four defaults and projects `HOMOGENEOUS (anthropic)`.

A roster that is *present* and declares no members is a different thing: it seats nobody
and the class is `NONE`. That is a decision the user made, and nothing should override it
by falling back to the defaults.

A roster that exists but will not parse is a third thing again, and the join **refuses**
rather than reporting seating — because a roster that fails to parse and a roster with no
external members otherwise produce an identical Claude-only answer, and one of those is a
file the user believes is in effect.

## The default council

Declared exactly once, in `scripts/council-lib.sh:council_default_members`:

| Stance | Model |
|---|---|
| `risk-first` | `opus` |
| `simplicity-first` | `sonnet` |
| `long-horizon` | `haiku` |
| `contrarian` | `fable` |

Both readers take them from there — the join seats them like any other member, and
`skills/ask` seats whatever the join returns. A second copy of this list is how the
status report and the council end up disagreeing about who is in the room.

Four is the default because trimming to two or three buys back a little quota and makes
`categorized` worse: a 2-1 split across three buckets reads like consensus, which is what
the honesty contract exists to prevent. Make the cost legible instead of cutting members.

## Model pins

`model` on a Claude member is the subagent `model` parameter, and the harness accepts
**exactly four values**: `opus`, `sonnet`, `haiku`, `fable`. That is a closed enum;
anything else returns an `InputValidationError` before a model runs.

The roster's `model` field is free-form JSON, so `"opus-4.5"` is easy to write and
nothing in the schema rejects it. The join catches it instead: an unacceptable pin is
unseated with a reason naming the accepted set, the same way a missing key unseats an
OpenRouter member. `scripts/council-lib.sh:COUNCIL_ACCEPTED_PINS` is the declaration; if
the harness ever widens the enum, that list is what goes stale.

Omitting `model` entirely is **not** the same mistake. That member seats with `-`, spawns
with no override, and runs on the session model — a roster that did not ask for a pin,
rather than a pin that failed. It contributes no model diversity, which is worth saying
out loud, since decorrelation is the reason the pins exist.

## The join's JSON contract

`sh "${CLAUDE_PLUGIN_ROOT}/scripts/council-state.sh" --json`

| Field | Meaning |
|---|---|
| `.seated[]` | `{stance, kind, model, vendor}` — seat exactly these |
| `.notSeated[]` | `{stance, kind, model, reason}` — consented in the roster, unavailable here |
| `.seating` | per-kind counts plus `.total` |
| `.projectedCorrelation` | `NONE`, `HOMOGENEOUS` or `CROSS-VENDOR` |
| `.vendors` | the vendor names behind that class |
| `.roster.path` / `.roster.state` | the resolved path, and `present` or `absent` |
| `.key.present` / `.key.source` | whether `COUNCIL_OPENROUTER_API_KEY` resolved, and from where |
| `.ollamaProbed` | `false` when the endpoint was not confirmed |
| `.maxConcurrentExternal` | the fan-out cap |

Exit `2` means the roster exists and could not be read or parsed; no seating is printed.
Exit `3` means neither `jq` nor Node is available to read the roster.

**Correlation is always PROJECTED.** The script runs before anyone answers, so it cannot
see which model a member really ran on. That is what `## Did the pins resolve?` in the
skill exists to check, afterwards.

## Stances

`stance` is free text. The skill maps the four default labels to member prompts and
phrases any other label from the label itself; that mapping lives in `skills/ask` under
*Stances*, because it is needed on every run and is not a property of the file format.

## Pins, after the fact

`skills/ask` checks whether the pins actually resolved once the members land, and
classifies the result as confirmed distinct, `COLLAPSED`, or unverified. The rules are
there, beside the check. What belongs here is why the check is shaped that way.

### Why self-report carries only the full-collapse case

Probing the live Agent tool on 2026-09-19 returned four distinct, correctly-named models
for the four pins, and one member cited its own system prompt as the source — which
suggests the harness *tells* a subagent its model rather than leaving it to infer. That is
closer to reading a supplied fact than to guessing, which is why a full collapse is
trusted: every member independently agreeing it is the session model is hard to get wrong
in the same direction.

It is still not an observation the skill made itself, and one loose self-description is
far likelier than a genuine half-collapse. So a partial mismatch stays `unverified`.

### What is still unknown

That probe established what happens to an **unacceptable** pin: `InputValidationError`,
before a model runs. It did not establish what happens to a pin that is *valid but
unavailable on the plan* — error, or silent substitution — because all four values
resolve on the account it ran on. Nothing in the plugin assumes an answer either way, and
`COLLAPSED` is reported from member self-report rather than from an assumption about that
behaviour.
