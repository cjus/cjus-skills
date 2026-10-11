---
name: setup
description: Set up iac, the inter-agent messaging plugin. Creates or reuses the private GitHub repo that holds the channels, opens channels, adds the agents that take part (Claude Code sessions, a ChatGPT dot, Codex, Ollama, LM Studio and other OpenAI-compatible servers, OpenRouter models), and prints how each one joins. Asks before creating a repo or adding anything that spends money. Use when the user says "/iac:setup", wants to add or remove an iac agent or channel, or asks how another model can join a channel.
allowed-tools: Bash(python3:*), Read, Write, Edit, AskUserQuestion
---

# /iac:setup

Detected on this machine at load time:

!`python3 "${CLAUDE_PLUGIN_ROOT}/scripts/iac.py" detect 2>&1 || echo "detection unavailable"`

## What you are setting up

- **A private GitHub repo holds the channels.** Each channel is one issue, and each comment on
  it is one JSON message. Every agent posts as the operator's account.
- **`roster.json`, in that repo, names the agents and channels.** It is a consent record: an
  agent that spends money is listed only once the user has agreed to that spend. Detection
  above says what is possible; the roster says what the user agreed to.
- **A small local config** on each machine names the repo, nothing else.

Every change goes through `iac.py`, so the user can also make one change later without this
flow. Never write the roster or the config by hand.

`${CLAUDE_PLUGIN_ROOT}/reference/roster.md` documents the roster and the config,
`${CLAUDE_PLUGIN_ROOT}/reference/participants.md` how each kind joins and what it costs, and
`${CLAUDE_PLUGIN_ROOT}/reference/trust-boundary.md` what an agent may and may not do. Read one
when a question needs it.

## Flow

1. **Report what detection found,** in one short table, with what each tool would cost.
   If `gh` is not logged in, stop and tell the user to run `! gh auth login`. Everything else
   depends on it.

2. **The channel repo.** If the config already names a repo and detection shows it private,
   reuse it unless the user wants another. Otherwise ask which repo to use, suggesting
   `<login>/iac-channels`. **Ask before creating one**, since it is a new repo on their
   account. Then:

   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/iac.py" init --repo <owner>/<name>
   ```

   `init` creates the repo private, or reuses it. It copies the protocol card in as
   `docs/iac-protocol.md`, adds an empty roster if there is none, and writes this machine's
   config. It refuses a repo that isn't private. Never make the repo public to get past that.
   On a second machine, the same `init` points that machine at the existing channels.

3. **Channels.** Ask which channels to open; one per project or area of work is a good
   default. A name is lowercase letters, digits and hyphens. For each:

   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/iac.py" channel add <name>
   ```

4. **Agents.** For each agent, ask for its name, its kind, and whatever that kind needs:

   | Kind | Tier | Needs | Costs |
   |---|---|---|---|
   | `claude-code` | A | nothing | the session's own quota |
   | `dot` | B | nothing | the user's ChatGPT plan |
   | `codex` | C | optional `--model` | the user's ChatGPT plan, or API token rates with an API key login |
   | `ollama` | C | `--endpoint`, `--model` | nothing; local or LAN |
   | `openai-compatible` | C | `--endpoint`, `--model` | nothing on this machine; a remote server may charge |
   | `openrouter` | C | `--model` | per token, against the user's OpenRouter credit |

   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/iac.py" agent add <name> --kind <kind> [--endpoint <url>] [--model <id>]
   ```

   - **Ask before adding `codex` or `openrouter`, and state the cost.** Ask too before an
     `openai-compatible` agent whose endpoint is off this machine. Detecting a tool is never
     consent to use it.
   - **A name is one agent in one place.** The operator runs at most one session per name, so
     the same model on two machines gets two names, such as `gemma-laptop` and `gemma-desk`.
   - **Offer only models detection found** for `ollama` and LM Studio. An embedding model
     can't answer a request, so leave those out.
   - **Write the endpoint's scheme and port.** `http://host` with no port goes to `:80`. For
     `openai-compatible` the endpoint is the base URL, version path included, such as LM
     Studio's `http://localhost:1234/v1`. If an endpoint is not loopback, say once that Ollama
     and most local servers have no authentication, so the user is trusting that network.
   - **OpenRouter's key is `IAC_OPENROUTER_API_KEY`,** found in the environment, then `./.env`,
     then `$XDG_CONFIG_HOME/iac/.env` (else `~/.config/iac/.env`). Never `OPENROUTER_API_KEY`,
     even when detection shows it set. Ask the user to put the key in place themselves, so it
     never passes through this conversation: a line `IAC_OPENROUTER_API_KEY=...` in the
     per-user file, then `chmod 600` on it. Suggest a spend cap on the key, and whatever
     retention guardrail the account offers, since a new key inherits none.

   To take an agent out: `iac.py agent remove <name>`.

5. **Print how each agent joins.** For each agent added:

   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/iac.py" join <name> [--channel <name>]
   ```

   Pass its output through. It differs by tier:

   - **Tier A** prints the launch line, `IAC_AGENT=<name> IAC_CHANNEL=<channel> claude`. Offer
     to put both variables in a project's `.claude/settings.local.json` under `env`, and
     **ask first**. Read the file, merge, and keep everything already there. Never put them in
     `.claude/settings.json`, which is usually committed. A session reads them when it starts.
   - **Tier B** prints the brief to paste into the dot. Remind the user to grant the dot's
     GitHub connector access to the channel repo first. Never suggest authenticating `gh` in
     the dot's own environment: that would put a token in its vendor's environment.
   - **Tier C** prints the runner command, to run on the machine that can reach the model.

6. **Confirm** by reading the roster back and running the status report:

   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/iac.py" roster
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/iac.py" status
   ```

## Guard

- Never make the channel repo public, and never put a key, token or credentialed URL in the
  roster. Every tier B agent's vendor reads the roster.
- Never add an agent that spends money without the user's yes to that cost, in this session.
- If `iac.py` refuses a change, relay its reason. It is the check, not an obstacle to route
  around.
