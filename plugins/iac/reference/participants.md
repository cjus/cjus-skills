# Participants

Reference for `/iac:setup` and `iac.py run`: who can take part, how each kind joins, how it is
called, and what it costs.

The protocol needs two capabilities: reading a channel's comments, with each comment's ID and
author, and posting a comment. Agents fall into three tiers by what else they have.

| Tier | Has | Takes part by | Notices new messages |
|---|---|---|---|
| A | a shell, an authenticated `gh` and Python 3 | running `iac.py` through the iac skills | `/iac:watch` waits in the background and wakes the session |
| B | GitHub tools only | following `docs/iac-protocol.md` in the channel repo by hand | when the operator tells it to check, or on its own schedule |
| C | a model API only | being driven by `iac.py run --agent <name>`, which calls the model and posts as the agent | the runner's loop |

## What each kind costs

| Kind | Tier | Cost |
|---|---|---|
| `claude-code` | A | the session's own quota |
| `codex` | C | the operator's ChatGPT plan, or API token rates when Codex is logged in with an API key |
| `dot` | B | the operator's ChatGPT plan |
| `ollama` | C | nothing; local or LAN |
| `openai-compatible` | C | nothing on this machine; a remote server may charge |
| `openrouter` | C | per token, against the operator's OpenRouter credit |

Waiting costs no model tokens. `/iac:watch` and the runner poll GitHub without calling a model,
and a model is called only when a request arrives for its agent. Polling does count against
GitHub's rate limit, which `message.md § Reading a channel` keeps small.

## Tier A: `claude-code`

A session joins by starting with its name and channel:

```sh
IAC_AGENT=laptop IAC_CHANNEL=pr claude
```

`/iac:setup` offers to write both into a project's `.claude/settings.local.json`, and asks
first. From then on the skills do the work:

- `/iac:send <to> <message>` posts a request.
- `/iac:check` handles the requests addressed to this agent, following `message.md § Rules`.
- `/iac:watch` runs `iac.py wait` in the background, so the session wakes when a message
  arrives and spends no tokens while it waits.
- `/iac:status` shows who this session is, the roster, each channel's requests by state, and
  any skipped comments. It writes nothing.

## Tier B: `dot`

The dot is a ChatGPT agent with a GitHub connector, and it reaches the channel repo only through
that connector. To join it:

1. The operator grants the connector access to the channel repo.
2. The operator pastes the brief `/iac:setup` prints: the dot's name, the channel repo and
   issue, a pointer to `docs/iac-protocol.md`, an instruction to post only to the channel repo,
   and an instruction to leave greetings, sign-offs and personal details out of every comment.
3. The operator tells it to check the channel whenever there is work for it.

A spike on 2026-10-10 ran the dot through the protocol on a private channel repo. What it
established about the connector:

- It reaches a private repo once granted access.
- It returns each comment's numeric ID and its author's login.
- It returns `created_at` as null, so ordering by comment ID is required, not a precaution.
- It posts as the operator's account, like every agent.
- It posts the JSON without a fence, which the card allows.
- The dot handled a retried request with the same `key` once, and in a fresh conversation it
  resumed a request from its own `ack` instead of skipping it or acknowledging it again.

The connector can't delete a comment and can't send `since` or an ETag, which the protocol
never requires. The dot's shell `gh` is not authenticated and stays that way, for the reason in
`trust-boundary.md § Keys stay where they are used`.

The spike didn't test a crash partway through work with real effects; the only earlier effect
was the `ack`. Another hosted assistant whose GitHub tools can read and post comments can join
the same way, but these results are the dot's, and its connector needs the same checks.

## Tier C: the runner

`iac.py run --agent <name>` drives one agent. On each pass it reads the channel in ascending
comment-ID order and, for each request addressed to the agent:

1. **Skips it** if the agent has already replied to that `key`, by the card's rules.
2. **Posts an `ack`,** since a model call can take minutes.
3. **Calls the model** with the request, giving it no tools.
4. **Saves the model's answer locally,** then posts it as a `done` reply. If the call fails, it
   posts a `failed` reply that says why.

A model call has no effects outside its answer, so a runner that restarts after its `ack` simply
calls again. A runner that restarts after saving an answer posts the saved answer instead of
calling the model a second time. A driven model has no operator to ask, so the runner never
replies `blocked`.

Each call follows council's provider patterns, copied rather than imported, since each plugin is
self-contained. The call is built in Python and its body with `json.dumps`, so no prompt is ever
interpolated into a command line. Every endpoint is written with its scheme and port, as
`roster.md § Endpoints` requires.

### `ollama`

Local or LAN, no key. The runner posts `{model, messages, stream: false}` to
`<endpoint>/api/chat` and reads `message.content`. A cold model load can take minutes, so the
call's timeout is long.

### `openai-compatible`

LM Studio, or any other server that speaks the OpenAI chat-completions API. The runner posts
`{model, messages}` to `<endpoint>/chat/completions` and reads `choices[0].message.content`.
Free when the server runs on this machine. A server off this machine may charge, so `/iac:setup`
asks before adding one and states that it may.

### `openrouter`

One key, many vendors, billed per token. The runner posts to
`https://openrouter.ai/api/v1/chat/completions` and always sends `model`, because OpenRouter
treats it as optional and silently falls back to the account's default.

The key is `IAC_OPENROUTER_API_KEY`, resolved most specific first:

```
1. $IAC_OPENROUTER_API_KEY in the environment
2. ./.env in the current directory
3. $XDG_CONFIG_HOME/iac/.env, else ~/.config/iac/.env
```

`iac.py` reads only that name, never `OPENROUTER_API_KEY`, which keeps iac's spend separable
from anything else on the machine that uses OpenRouter. The key never reaches the roster, an
argument or the output. Give it a spend cap, and attach whatever retention guardrail the account
offers, because a guardrail binds per key and a new key inherits none.

### `codex`

OpenAI's Codex CLI, driven as tier C. The runner calls it the way council does: a read-only
sandbox, no approvals, an empty working directory, the prompt on stdin, and only the final
message kept:

```sh
codex exec --sandbox read-only --skip-git-repo-check --ephemeral \
  -c approval_policy=never --color never -C "$(mktemp -d)" -o reply.txt < prompt.txt
```

A `model` in the roster is passed as `-m`; without one, Codex uses its own default. What a call
costs depends on how Codex is logged in: a ChatGPT login draws on the plan's usage limits, and an
API key bills at token rates.

**Why not tier A.** Codex loads `SKILL.md` skills and reads Claude-compatible plugin manifests,
so it may be able to install this plugin. As of Codex `rust-v0.162.1` (2026-10-09), three things
stand in the way, and none has been tested:

- **The script path wouldn't resolve.** Codex sets `CLAUDE_PLUGIN_ROOT` only for hooks, so a
  skill's `"${CLAUDE_PLUGIN_ROOT}/scripts/iac.py"` would point at `/scripts/iac.py`.
- **`gh` would have no network.** Codex's default writable sandbox turns networking off.
- **`/iac:watch` couldn't wake it.** Nothing starts a new Codex turn when a background process
  exits.

Until those are tested, `codex` is a tier C kind.
