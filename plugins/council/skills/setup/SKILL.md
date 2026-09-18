---
name: setup
description: Configure which AI members the council seats. Detects installed model CLIs, asks which paid providers you consent to spend quota on, and writes the roster file /council:ask reads. Use when the user wants to add, remove, or review council members, enable external models like ChatGPT/Codex or local Ollama, or asks why the council is Claude-only.
allowed-tools: Bash(sh:*), Bash(curl:*), Bash(jq:*), Read, Write, AskUserQuestion
---

# /council:setup

Detected on this machine at load time:

!`sh "${CLAUDE_PLUGIN_ROOT}/scripts/detect.sh" 2>/dev/null || echo "detection unavailable"`

## What you are configuring

The roster file is a **consent record**, not a capability list. Detection above says
what is *possible*; the roster says what the user has *agreed to spend*. Never seat a
paid provider because it happens to be installed — a tool that auto-seats a logged-in
CLI silently starts drawing down the user's subscription, with no way to surface or
undo it.

To see the resulting seating without changing anything, use `/council:status`.

## Flow

1. **Report** what detection found, in one short table: provider, present or absent,
   and what seating it would cost: Claude models spend this session's quota;
   OpenRouter is billed per token to the user's OpenRouter credit; codex spends their
   ChatGPT plan; ollama is free.

2. **Ask, using AskUserQuestion**, only about providers that are actually reachable.
   Reachability differs per provider: `codex` and `ollama` need their binary or server
   present, while **OpenRouter needs no install at all** — it is gated only on
   `COUNCIL_OPENROUTER_API_KEY`. For anything unreachable, say so and give the one-line fix
   rather than offering it as a choice.
   - *Claude members* — how many, and which models. Default four: opus, sonnet,
     haiku, fable. This is the only group enabled by default. State what the count
     costs: one `/council:ask` is roughly Nx a normal turn for N members, and `pooled`
     doubles that because it polls twice.
   - *OpenRouter* — enable? **Lead with this one.** It is the single best fix for a
     correlated roster: one key reaches many vendors, so the council stops being
     all-Claude. Requires **`COUNCIL_OPENROUTER_API_KEY`**, resolved most-specific-first
     from the environment, then `./.env` in the current project, then
     `~/.config/council/.env` — never write the key into the roster. Ask which model IDs
     to seat; if unsure, offer to fetch the live catalogue
     (`curl -fsS https://openrouter.ai/api/v1/models`, no auth needed) and suggest two or
     three from *different* authors. Note `:free` slugs exist but are rate-limited to
     about 20 requests/minute.

     **Never propose `OPENROUTER_API_KEY` as the source, even when detection reports
     it set.** Council seats only its own key, which keeps council spend separable from
     whatever else on the machine uses OpenRouter. If that variable belongs to an
     application, keep it that way.

     Two consequences to state when the user mints a council key: give it a **spend
     cap**, because a fan-out multiplies by every member and every round; and **attach
     whatever retention guardrail the account offers**, because guardrails bind per key
     and a new key inherits none — council prompts carry repo content, so an unguarded
     key means those prompts are retained by whichever provider serves them.

     If the user wants the key available to every project, write it to
     `~/.config/council/.env` as `COUNCIL_OPENROUTER_API_KEY=...` and `chmod 600` that
     file. Never the roster, and never a project's `.claude/settings.json`.
   - *Ollama* — enable, at which `endpoint`, and which models? Free and no key.
     - Default `http://localhost:11434`. It also runs on a LAN host.
     - **Always write the port explicitly.** Bare `host` defaults to `:11434`, but
       `http://host` defaults to `:80` — a scheme without a port is the most common
       way this silently fails.
     - If the endpoint is not loopback, say plainly that Ollama has **no
       authentication of any kind**: anyone who can reach that port can run inference,
       enumerate models, pull models onto the disk, and delete existing models. Only
       proceed if the user says that network is trusted, or it is behind a proxy they
       control. Do **not** suggest `OLLAMA_ORIGINS` as a fix — it is browser CORS only
       and is not a security control.
     - Never put credentials in the endpoint URL. If a reverse proxy needs basic auth,
       point the user at `curl --netrc-file` instead.
   - *ChatGPT via Codex* — enable? Warn that it spends their ChatGPT plan.

3. **There is no CLI-based provider beyond `codex` and `ollama`.** If the user asks for
   a vendor by name, seat it through OpenRouter — a plain HTTP call, no local
   tool-permission surface to get wrong.

4. **Write** `$COUNCIL_ROSTER` if it is set, else `$XDG_CONFIG_HOME/council/roster.json`,
   else `~/.config/council/roster.json` (`mkdir -p` first, `chmod 600` after). Use the
   same path `detect.sh` resolves — writing the default while detection reads an override
   leaves the user configuring a file nothing reads.

   Write `members[]` (Claude subagents: `id`, `kind`, `model`, `stance`), the
   `external` block (`openrouter`/`ollama` each with `enabled` plus a `models[]` of
   `{id, stance}`, and `ollama` also an `endpoint`; `codex` just `enabled`), and
   `maxConcurrentExternal` — the same shape as
   `${CLAUDE_PLUGIN_ROOT}/reference/roster.example.json`. Write only what the user chose.
   **Never write an API key or a credentialed URL into this file** — `detect.sh` injects
   its first 40 lines into the model's context on every invocation.

5. **Offer the permission shortcut, only if it is actually needed.** **Read the project's
   `.claude/settings.json` and check what it already grants** before offering anything —
   proposing a grant that changes nothing trains the user to accept grants unread. If a
   grant is genuinely missing, add the narrowest entries that cover it under
   `permissions.allow`:

   ```json
   { "permissions": { "allow": [
     "Bash(codex exec *)",
     "Bash(node /abs/path/to/council/scripts/openrouter.mjs*)",
     "Bash(curl -fsS http://localhost:11434/*)"
   ] } }
   ```

   Two substitutions are mandatory, and both are silent failures if skipped:

   - **Expand the plugin path.** `${CLAUDE_PLUGIN_ROOT}` does **not** expand inside
     `settings.json`. Resolve it first and write the absolute path, or the rule matches
     nothing.
   - **Use the user's actual Ollama endpoint** in the last rule. A prefix rule written
     for `localhost` does not match a LAN host, so a moved endpoint silently starts
     prompting again.

   Read the existing file, merge, and preserve everything already there. Ask first —
   this is a standing permission grant.

6. **Confirm** by reading back the same resolved path and listing the resulting roster.
   `/council:status` is the read-only way to see that same seating later.

## Guard

If detection found nothing external and the user wants more members, do not write an
empty or speculative roster. Say plainly that a Claude-only council is what is
available, and rank what would change it: an **OpenRouter key** (one key, many vendors,
nothing to install), then `ollama` (free, local or LAN), then `codex` (uses an existing
ChatGPT plan, no API key).
