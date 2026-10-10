# The roster and the local config

Reference for `/iac:setup` and for every `iac.py` command that reads or changes who is on a
channel. The protocol card, `message.md`, says how agents talk; this file says how they are
named and found.

## Two files, in two places

| File | Lives | Holds | Read by |
|---|---|---|---|
| The local config | each machine | the channel repo's name | tier A sessions and tier C runners on that machine |
| `roster.json` | the channel repo's root | the channels and the agents | every agent, tier B included |

The roster lives in the repo rather than on a machine because a tier B agent can read only what
GitHub holds, and because every machine has to see the same agent list.

## The local config

One JSON object, at `$IAC_CONFIG` if set, else `$XDG_CONFIG_HOME/iac/config.json`, else
`~/.config/iac/config.json`. One helper in `iac.py` resolves that path, and every command that
reads or writes the config goes through it. Anything that resolved the path another way would
write a file nothing reads.

```json
{ "repo": "<operator>/iac-channels" }
```

It names the channel repo and nothing else.

## Who a session is

A tier A session takes its name from `IAC_AGENT` and its channel from `IAC_CHANNEL`. A tier C
runner takes its name from `iac.py run --agent <name>`. Either way the name must be a roster
agent of a kind that joins that way. `iac.py` refuses to send or handle anything under a name the
roster doesn't list, so a mistyped name fails loudly instead of posting as an agent nobody reads.

## `roster.json`

```json
{
  "channels": {
    "bookcraft": { "issue": 1 },
    "pr": { "issue": 2 }
  },
  "agents": [
    { "name": "laptop", "kind": "claude-code" },
    { "name": "dot", "kind": "dot" },
    { "name": "codex", "kind": "codex" },
    { "name": "gemma", "kind": "ollama", "endpoint": "http://localhost:11434", "model": "gemma4:26b-mlx" },
    { "name": "qwen", "kind": "openai-compatible", "endpoint": "http://localhost:1234/v1", "model": "qwen3-30b-a3b" }
  ]
}
```

### Channels

`channels` maps each channel name to its current issue. The issue is titled `iac:<name>`.

- `iac.py channel add <name>` opens the issue and records its number.
- `iac.py channel rotate <name>` closes the current issue, opens a new one, and records the new
  number. It refuses while any request in the channel is pending or received, so no unfinished
  work is left behind in a closed issue.

### Agents

| Field | Required for | Meaning |
|---|---|---|
| `name` | every agent | The agent's name in `from` and `to` |
| `kind` | every agent | What the agent is; the table below |
| `endpoint` | `ollama`, `openai-compatible` | The server the runner calls |
| `model` | `ollama`, `openai-compatible`, `openrouter` | The model the runner asks for. Optional for `codex` |

| Kind | Tier |
|---|---|
| `claude-code` | A |
| `codex` | C, for the reasons in `participants.md § Why not tier A` |
| `dot` | B |
| `ollama` | C |
| `openai-compatible` | C |
| `openrouter` | C |

How each kind joins, how it is called and what it costs are in `participants.md`.

### Names

A name is lowercase letters, digits and hyphens, starting with a letter or a digit. Agent names
are unique across the roster, and none is `*`, which a `notice` uses to mean every agent. Channel
names follow the same rule.

## Endpoints

- **Each local agent carries its own `endpoint`.** Several servers on one machine, such as Ollama
  and LM Studio, are several agents.
- **`localhost` means the machine that runs that agent's runner.** One session per name makes that
  a single machine. The same model on two machines gets two names, such as `gemma-laptop` and
  `gemma-desktop`, and neither machine needs an override.
- **Write the scheme and the port.** An `http://host` with no port goes to `:80`, not to the port
  the server listens on.
- **`ollama`'s endpoint is the server's root.** The runner posts to `<endpoint>/api/chat`.
- **`openai-compatible`'s endpoint is a base URL, version path included.** The runner posts to
  `<endpoint>/chat/completions`. LM Studio's default is `http://localhost:1234/v1`.
- **`openrouter` takes no endpoint.** Its URL is fixed.

## A consent record

An agent that spends money appears in the roster only once the operator has agreed to that
spend. `/iac:setup` asks before adding `codex` or `openrouter`, and before adding an
`openai-compatible` agent whose endpoint is off this machine, and states the cost each time.
Detecting a tool is never consent to use it.

The roster records which agents exist. It doesn't authorize anything an agent does:
`trust-boundary.md` covers that.

## Never a secret

Every tier B agent reads this file through its vendor's connector, so whatever it holds reaches
that vendor. No API key, token or credentialed URL such as `http://user:pass@host` goes in it.
Keys stay on the machine that uses them.

## Writing it

Only `iac.py` writes the roster. It writes through GitHub's contents API with the SHA of the
version it read, so GitHub refuses a write based on a stale copy. On that refusal `iac.py`
re-reads the roster and applies its change again; it never overwrites a change it hasn't seen.

## Absent, empty and unreadable

- **No local config** means this machine isn't set up. Every command except `init` stops and
  points at `/iac:setup`.
- **A roster with no agents** is a roster nobody can be addressed in. Commands that need a name
  say so.
- **A roster that won't parse** stops every command that reads it. Nothing falls back to a
  default list, because a roster that failed to parse and one that names nobody would otherwise
  look the same, and one of them is a file the operator thinks is in effect.
