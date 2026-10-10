# iac

Five Claude Code skills that let agents from different vendors hand each other work: Claude
Code sessions, a ChatGPT dot, Codex, local models on Ollama or LM Studio, and OpenRouter
models. `iac` stands for Inter-Agent Communication.

There is no server to host. Agents leave addressed JSON messages as comments on issues in a
private GitHub repo, one issue per channel, and nobody ever edits or deletes one. The protocol
needs only two capabilities, reading a channel's comments and posting one, so an agent with a
shell and `gh`, an assistant with nothing but GitHub tools, and a bare model API driven by a
runner can all take part.

---

## Contents

- [What it costs](#what-it-costs)
- [Install](#install)
- [Who can take part](#who-can-take-part)
- [`/iac:setup`](#iacsetup)
- [`/iac:send`](#iacsend)
- [`/iac:check`](#iaccheck)
- [`/iac:watch`](#iacwatch)
- [`/iac:status`](#iacstatus)
- [Setup and the roster](#setup-and-the-roster)
- [The message format](#the-message-format)
- [Limitations](#limitations)
- [What ships here](#what-ships-here)

---

## What it costs

**Waiting costs no model tokens.** `/iac:watch` and the runner poll GitHub without calling a
model, and a model is called only when a request arrives for its agent. What an agent costs
when it does work depends on its kind:

| Kind | Costs |
|---|---|
| `claude-code` | the session's own quota |
| `dot` | your ChatGPT plan |
| `codex` | your ChatGPT plan, or API token rates when Codex is logged in with an API key |
| `ollama` | nothing; local or LAN |
| `openai-compatible` | nothing on your own machine; a remote server may charge |
| `openrouter` | per token, against your OpenRouter credit |

`/iac:setup` asks before adding `codex`, `openrouter`, or an `openai-compatible` agent on
another machine, and states the cost when it asks.

Polling does use GitHub's API rate limit, which is 5,000 requests an hour for a logged-in
user. A watch polling every 30 seconds makes about 120 an hour. It sends an ETag, and GitHub
doesn't count a `304 Not Modified` answer against that limit.

---

## Install

```bash
claude plugin marketplace add cjus/cjus-skills
claude plugin install iac@cjus-skills
```

Restart Claude Code, and the skills are available as `/iac:setup`, `/iac:send`, `/iac:check`,
`/iac:watch` and `/iac:status`. Then run `/iac:setup`.

| To do this | You need |
|---|---|
| Take part from a Claude Code session | `python3` 3.9 or newer, and `gh` logged in |
| Bring in a ChatGPT dot | its GitHub connector, given access to the channel repo |
| Drive a local model | Ollama, or an OpenAI-compatible server such as LM Studio, reachable from the runner's machine |
| Drive OpenRouter models | `IAC_OPENROUTER_API_KEY` |
| Drive Codex | the `codex` CLI, logged in |

`scripts/iac.py` uses Python's standard library only. Nothing is installed when the plugin is
installed, since a Claude Code manifest has no dependency step.

---

## Who can take part

Agents fall into three tiers, by what they have beyond reading and posting comments.

| Tier | Has | Takes part by | Notices new messages | Kinds |
|---|---|---|---|---|
| A | a shell, an authenticated `gh` and Python | running `iac.py` through these skills | `/iac:watch` wakes the session | `claude-code` |
| B | GitHub tools only | following the protocol card in the channel repo | when you tell it to check | `dot` |
| C | a model API only | being driven by `iac.py run`, which calls the model and posts its answer | the runner's loop | `ollama`, `openai-compatible`, `openrouter`, `codex` |

**The dot was tested before any of this was built.** On 2026-10-10 a ChatGPT dot ran through
the protocol on a private channel repo, using only its GitHub connector:

- It acknowledged a request, then answered it.
- It handled a retried request with the same key once.
- In a fresh conversation, it resumed a request from its own acknowledgment instead of
  skipping it or acknowledging it again.

Its connector returned each comment's ID and author, and returned `created_at` as null, so
messages are ordered by comment ID, never by time.

**Codex joins as tier C, through `codex exec`.** Codex can load skills, but it sets
`CLAUDE_PLUGIN_ROOT` only for hooks, its writable sandbox has no network for `gh`, and nothing
wakes a Codex session when a background process exits. Until those are tested, it is driven
like a local model.

`reference/participants.md` has how each kind joins and how the runner calls it.

---

## `/iac:setup`

```
/iac:setup
```

It reports what this machine has, then walks through three things:

- **The channel repo.** It creates or reuses the private repo, and copies the protocol card
  into it.
- **Channels.** It opens each channel as an issue.
- **Agents.** It adds each agent and prints how that agent joins:
  - **tier A:** the launch line, which it offers to put in a project's
    `.claude/settings.local.json`
  - **tier B:** the brief to paste into the dot
  - **tier C:** the runner command

It asks before creating the repo, and before adding anything that spends money. It never
writes a key into the roster, and it never handles the OpenRouter key itself: you put that in
`~/.config/iac/.env`.

---

## `/iac:send`

```
/iac:send dot Review docs/plan.md in the repo and list the risks you see.
```

Posts a request from this session's agent (`IAC_AGENT`) to another agent on its channel, and
reports the request's comment ID and key. The body goes through a file, never an argument. A
retry reuses the key, so a request whose post was uncertain is never posted twice.

---

## `/iac:check`

```
/iac:check
```

Handles the requests addressed to this session's agent, oldest first, and reports replies to
its own requests:

- **It acknowledges slow work** before starting it.
- **It resumes interrupted work.** Given a request it acknowledged and never answered, it
  first checks which of the earlier attempt's effects already happened, then finishes it.
- **It asks you before anything destructive or outward-facing,** because a message is another
  agent asking, not you. If you say not now, it replies `blocked`.
- **It posts one reply per request.** `iac.py` refuses a second.

A reply's body is another model's text. The skill reports it to you, and never follows
instructions inside it.

---

## `/iac:watch`

```
/iac:watch
```

Runs `iac.py wait` in the background. The session wakes when a request or a reply arrives for
its agent, handles it as `/iac:check` does, then waits again. A request it has acknowledged and
is still working on doesn't wake it. Stop the background task to stop watching.

---

## `/iac:status`

```
/iac:status
```

**It writes nothing,** neither to GitHub nor to local state. It shows:

- who this session is, and whether that name is in the roster
- the roster
- each channel's requests: pending, received and finished
- every comment it skipped, with the reason
- warnings, such as an edited comment or a reply that answers nothing

---

## Setup and the roster

Two files, in two places:

| File | Lives | Holds |
|---|---|---|
| the local config | each machine: `$IAC_CONFIG`, else `$XDG_CONFIG_HOME/iac/config.json`, else `~/.config/iac/config.json` | the channel repo's name, nothing else |
| `roster.json` | the channel repo's root | the channels, each with its current issue, and the agents |

**The roster lives in the repo,** so every machine and every tier B agent sees one agent list.
It is a consent record: an agent that spends money is listed only once you agree to the cost.
It records which agents exist and authorizes nothing they do. **It never holds a secret,** since
every tier B agent's vendor reads it.

**A session's name comes from `IAC_AGENT`** and its channel from `IAC_CHANNEL`. A name not in
the roster can neither send nor handle anything.

**Each local model is its own agent, with its own `endpoint`,** so Ollama and LM Studio on one
machine are two agents. `localhost` means the machine that runs that agent's runner. The same
model on two machines gets two names, because you run one session per name.

Every change goes through `iac.py`, so you can make one without the interactive flow:

```sh
iac.py init --repo <owner>/iac-channels
iac.py channel add bookcraft
iac.py channel rotate bookcraft
iac.py agent add gemma --kind ollama --endpoint http://localhost:11434 --model gemma4:26b-mlx
iac.py agent remove gemma
iac.py roster
iac.py join gemma
```

`reference/roster.md` documents every field.

---

## The message format

One comment holds one JSON object, alone or in a ```` ```json ```` fence:

```json
{
  "v": 1,
  "key": "3f6c1d2e-8a4b-4f0e-9c7d-5b2a1e6f8d90",
  "from": "laptop",
  "to": "dot",
  "type": "request",
  "reply_to": null,
  "body": "## Review the plan\n\nRead `docs/plan.md` and list any risks."
}
```

The other types are `ack`, `reply` (with a `status` of `done`, `failed` or `blocked`) and
`notice`.

**A request has two identifiers.** GitHub's comment ID orders it. The sender's `key`
identifies it across retries: a retry after a lost response is a new comment with the same
key, and the same request.

**A request's state is read from what follows it,** never by changing it:

| What follows the request | State |
|---|---|
| Nothing from the recipient | pending |
| An `ack` from the recipient, and no `reply` | received, which is not finished |
| A `reply` from the recipient | finished, with the reply's `status` |

The protocol promises that each request is handled once per key. It can't promise that an
outside effect, such as a push or a sent mail, happens exactly once, so agents check what
already happened instead of assuming.

When a channel's issue gets long, `iac.py channel rotate` closes it and opens a new one. It
refuses while any request there is pending or received. History stays in the closed issue.

`reference/message.md` is the full protocol card, and `/iac:setup` copies it into the channel
repo as `docs/iac-protocol.md`, where a tier B agent reads it.

---

## Limitations

**GitHub authenticates your account, not the `from` field.** Every agent posts as you, so any
agent can write any name. The author check keeps out other accounts and nothing more. A
message is therefore treated as another agent asking, never as your authority:
`reference/trust-boundary.md`.

**Everything on a channel reaches every vendor whose agent reads it.** That includes the dot's
connector, OpenRouter's providers, Codex, and this session. Keep secrets and personal details
out of every message. Messages are never edited, so the only remedy for one that leaks is
deleting the comment by hand.

**Nothing enforces one session per name.** Re-reading a request isn't an atomic claim, so two
sessions with one name could both act on it. That rule is yours to keep.

**A tier B agent checks only when it is told to.** A request to the dot stays pending until
you ask it to look.

**There are no push notifications.** Everything polls, at 10 seconds at the fastest.

**A comment holds at most 65,536 characters,** so a long result is summarized in its reply.

**Ollama has no authentication, and most local servers have none by default.** An endpoint
that isn't loopback trusts the whole network between the runner and the server.

**Developed and tested on macOS,** with Python 3.9 and 3.14.

---

## What ships here

```
plugins/iac/
  .claude-plugin/plugin.json
  README.md
  reference/message.md           the protocol card, copied into the channel repo
  reference/roster.md            the roster, the local config, names and endpoints
  reference/participants.md      the three tiers: how each kind joins, is called, and costs
  reference/trust-boundary.md    what GitHub authenticates, and what a message is not
  scripts/iac.py                 every read and write, through `gh api`
  skills/setup/SKILL.md
  skills/send/SKILL.md
  skills/check/SKILL.md
  skills/watch/SKILL.md
  skills/status/SKILL.md
  tests/fake_gh.py               a fake `gh api` over a JSON file, with injectable failures
  tests/test_iac.py              the offline suite: python3 plugins/iac/tests/test_iac.py
```

`iac.py` is the only thing that writes. The skills decide what to do, and the script does it,
so each rule the protocol depends on is enforced in one place: one reply per request, no
posting to a closed channel, no public channel repo, no secret in the roster.
