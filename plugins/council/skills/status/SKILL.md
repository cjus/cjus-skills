---
name: status
description: Report what the council would actually seat right now — key resolution, roster path, per-member seating, and the correlation class that projects. A 20-second read that writes nothing. Use when the user says "/council:status", asks why the council is Claude-only or still HOMOGENEOUS, or wants to check a roster change took effect before spending a fan-out on it.
allowed-tools: Bash(sh:*), Read
---

# /council:status

A read-only report on what `/council:ask` would seat. **This skill writes nothing,
anywhere** — not the roster, not settings, not a config file. Use `/council:setup` to
change any of it.

## Run it

```bash
sh "${CLAUDE_PLUGIN_ROOT}/scripts/council-state.sh" --text
```

That is the whole mechanism. The script performs the join the user would otherwise do
by hand across two sources — availability (does the key resolve, does the endpoint
answer) and consent (the roster's `enabled` flags) — and a member needs **both**.

Add `--json` when a caller needs to parse it. Add `--no-probe` only when asked, or when
the caller already knows the Ollama endpoint is unreachable; see *The probe* below.

## Report it

Pass the script's output through, then add at most two sentences of plain-language
reading. Do not restate the table in prose — the operator can read a table. What they
cannot read off it is which single fact explains the seating they did not expect.

Lead with whichever of these applies:

- **`0 seated`, roster present** — the roster declares no members. `/council:setup`.
- **`0 seated`, roster absent** — no roster file exists. Say explicitly that `/council:ask`
  still seats the four Claude defaults, because the script reports only what a roster
  declares and the two therefore disagree in the default configuration. Leaving this
  unsaid reads as "the council is broken" when it is the documented default.
- **`HOMOGENEOUS`** — every seated member is one vendor, so agreement among them is
  weak evidence. The fix is an OpenRouter key: one key reaches many vendors and needs
  nothing installed.
- **Members under `not seated`** — these are *consented but unavailable*. The `(reason)`
  column is the whole answer; quote it. A member here is a fixable configuration
  problem, not a failure.
- **Key absent while OpenRouter members are consented** — the most common surprise. The
  roster says yes and the key chain says no, so those members silently never run. The
  script reports only that the key is absent, not which level it looked in, so do not name
  one — say the chain found nothing and point at `/council:setup`.

## The probe

`/council:status` **probes by default.** Do not pass `--no-probe` unless the user asks.

The probe is a `curl -m 3` against the resolved Ollama endpoint, and it decides seating
rather than decorating it:

```
up      → ollama members seated
down    → unseated, "endpoint not answering"
unknown → seated anyway, and a CROSS-VENDOR line is marked unconfirmed
```

Note the gap in that third row: the unconfirmed suffix attaches only to `CROSS-VENDOR`, so
an Ollama-only roster classed `HOMOGENEOUS (local)` carries no annotation even though it is
equally unconfirmed. Do not add the caveat yourself — pass the script's output through, and
if the operator asks, say the uncertainty is currently attached to the class rather than to
the cause.

`--no-probe` collapses `down` into `unknown`, which reports a seat that may not exist —
an over-claim in exactly the direction the honesty contract exists to prevent. The
three-second cost only applies when Ollama is *enabled in the roster* and the endpoint
does not answer; a Claude-only council never probes at all.

Where `--no-probe` is right: a scripted or CI caller that wants only the roster join, or
a user who already knows the LAN host is down and does not want to wait for it.

`${CLAUDE_PLUGIN_ROOT}/reference/roster.md` carries the join's full JSON contract, the
roster format and the pin rules, if a question needs more than this report gives.

## What this skill must not claim

The script says **projected**, and so should you. `COLLAPSED` — every model override
failing onto one session model — is only observable after members actually answer, so
neither the script nor this skill can predict it. Report what the roster and the key
chain establish, and nothing beyond that.

Point at `/council:ask` for the part this cannot answer: it collects each member's own
model report and classifies the spread as confirmed, `COLLAPSED` or unverified once the
round lands. Saying "projected, and `/council:ask` confirms it" is honest. Implying this
report already confirmed it is not.

One thing this skill *can* state, because the join checks it: a member listed under
`not seated` with a reason naming `opus|sonnet|haiku|fable` has a pin the harness will
not accept. That is a roster typo, fixable with `/council:setup`, and it is worth calling
out plainly rather than leaving as a generic unavailability.
