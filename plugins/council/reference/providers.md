# Calling external members

Reference for `/council:ask`. The skill decides *who* is seated by reading the join; this
file is how to *call* them once seated, and what each one costs.

Every external provider is **opt-in and off by default**. A skill has no Configure UI, no
persistent tier state and no quota-warning surface, so a tool that auto-seats a logged-in
CLI starts drawing down the user's subscription on first use with no way to surface or
undo it. Installed-and-detected is never sufficient; the roster's `enabled` flag is the
consent, and the join is what checks it.

## What each one spends

| Provider | Cost |
|---|---|
| Claude members | this session's quota, billed to the user's own session |
| OpenRouter | per token, against the user's OpenRouter credit |
| Codex | the user's ChatGPT plan |
| Ollama | free; local or LAN |


## Before any call

Write the prompt to a file first. **Never interpolate a prompt into argv** — build the
JSON body with `jq -n --rawfile` so quotes, `$`, backticks and newlines need no escaping,
and send it with `--data-binary @-` (plain `-d @-` strips newlines and silently mangles a
multi-line prompt while leaving the JSON valid).

## Per provider

**OpenRouter** — one key, many vendors. The call goes through a script, so the key never
reaches argv, a command line, or stdout. Model IDs are `<author>/<slug>` from the roster:

```bash
M=openai/gpt-5.5 P=./prompt.txt node "${CLAUDE_PLUGIN_ROOT}/scripts/openrouter.mjs"
```

The script reads **`COUNCIL_OPENROUTER_API_KEY`** through its own self-contained reader
(`scripts/env.mjs`), resolving most-specific-first:

```
1. $COUNCIL_OPENROUTER_API_KEY in the environment   (per-invocation)
2. ./.env in the current project                     (per-project)
3. $XDG_CONFIG_HOME/council/.env, else ~/.config/council/.env   (per-user default)
```

It sends `model` explicitly (OpenRouter treats it as optional and silently falls back to
the account default), and posts to `/api/v1/...`, not `/v1/...`. Its exit codes are
`3` no key configured, `4` HTTP or empty-content failure, `5` bad usage.

**Read only `COUNCIL_OPENROUTER_API_KEY`, never `OPENROUTER_API_KEY`.** Council seats
only its own key, which keeps council spend separable from whatever else on the machine
uses OpenRouter. If `OPENROUTER_API_KEY` is set and belongs to an application, keep it
that way.

Two things to state when a user mints a council key: give it a **spend cap**, because a
fan-out multiplies by every member and every round; and **attach whatever retention
guardrail the account offers**, because guardrails bind per key and a new key inherits
none — council prompts carry repo content, so an unguarded key means those prompts are
retained by whichever provider serves them.

**Ollama** — local or LAN, no key. Substitute the exact `ollama-endpoint:` value printed
in the availability block above (it already resolves roster > `$OLLAMA_HOST` > default
and normalises the port). Never hardcode `localhost`, and if that line carried a
`[WARNING: no port ...]`, fix the endpoint before calling rather than probing `:80`:

```bash
jq -n --rawfile p ./prompt.txt \
  '{model:"qwen3", messages:[{role:"user",content:$p}], stream:false}' \
| curl -fsS -m 600 "<ollama-endpoint>/api/chat" \
    -H 'Content-Type: application/json' --data-binary @- \
| jq -r '.message.content'
```

**Codex** — ChatGPT on the user's own plan, read-only sandbox, never auto-approving:

```bash
codex exec --sandbox read-only --skip-git-repo-check --ephemeral \
  -c approval_policy=never --color never -C "$(mktemp -d)" -o out.txt < prompt.txt
```

Rules, not suggestions:

- Always pass `curl -fsS` so a proxy's HTML error page becomes a non-zero exit instead
  of garbage parsed as an answer.
- Foreground `Bash` calls cap at **10 minutes**, and a cold model load on a remote box
  can take minutes. Use `run_in_background` for a heavy member and tell the user there is
  no deadline enforcement, or decline the member.
- Nothing rate-limits these against the user's quota. Honour `maxConcurrentExternal`
  (default 2). On a 429, back off exponentially and honour `Retry-After`; do not retry a
  quota refusal.
- An Ollama endpoint has **no authentication of any kind.** If the resolved endpoint is
  not loopback, say so once — the user is trusting their whole network segment.
