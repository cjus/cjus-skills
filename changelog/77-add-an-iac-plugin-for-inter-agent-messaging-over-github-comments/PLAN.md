# Add an iac plugin for inter-agent messaging over GitHub comments

Start date: 2026-10-10 14:38:24 MDT

Ticket: #77 (status:todo -> status:in-progress)

## Overview

Claude Code sessions have no way to hand work to models from other vendors, or to hear back
from them. A ChatGPT dot, Codex, local Ollama models and OpenRouter models could all take part
if there were a shared place to leave addressed messages that every one of them can read and
write, with no server to host.

The objective is to ship an `iac` (Inter-Agent Communication) plugin in which agents the
operator names exchange append-only JSON messages as comments on issues in a private GitHub
repo, one issue per channel, as #77 specifies. The protocol needs only two capabilities, reading
a channel's comments and posting one, so that an agent with a shell and `gh` (tier A), an agent
with only GitHub tools such as the dot (tier B), and a bare model API driven by a runner
(tier C) can all take part. A spike through the dot's connector runs first, and decides whether
the dot is supported or documented as unsupported.

Acceptance is the ticket's list, tracked as Phase 7 below.

The objective is fixed here and is immutable for the life of the branch. Later updates
refresh status only; newly discovered work goes under `## Deferred`, never as new scope.

## About Ticket

The body of #77 as of the branch start. Its acceptance items are tracked under `## Plan`. Two
reviews by the dot, posted as comments on #77, shaped the append-only design, the `key` field
and the rule that an `ack` is not completion.

### Goal

Let non-Anthropic models work alongside Claude Code sessions: a ChatGPT dot first, then Codex, local Ollama models and OpenRouter models. Named agents exchange addressed JSON messages as comments on a shared GitHub thread. There is no server to host. `iac` stands for Inter-Agent Communication.

### Transport: one private repo, one issue per channel

```
<operator>/iac-channels       private; only the operator's account can read it
├── roster.json               agent names and kinds, plus the channel list
├── docs/
│   └── iac-protocol.md       the protocol card: format and rules, readable by any agent
└── Issues
    ├── #1  iac:bookcraft     a channel; each comment on it is a message
    └── #2  iac:pr
```

- Every agent posts as the operator's account, whether through `gh` or a GitHub connector.
- A channel is an issue. Closing it tells agents to stop using the channel, though GitHub still accepts comments on a closed issue.
- Shared documents that change slowly, and that nobody edits at the same moment, live as files in the repo, not as messages.

### Messages are append-only

**Nobody edits or deletes a message.** Each message is one comment holding one JSON object, optionally inside a ```` ```json ```` fence. A request's progress is shown by the messages that follow it, never by changing the request.

A request:

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

Its reply:

```json
{
  "v": 1,
  "key": "3f6c1d2e-8a4b-4f0e-9c7d-5b2a1e6f8d90",
  "from": "dot",
  "to": "laptop",
  "type": "reply",
  "reply_to": 6101900123,
  "status": "done",
  "body": "Two risks:\n\n- ...\n- ..."
}
```

| Field | Meaning |
|---|---|
| `v` | Format version |
| `key` | On a `request`: a string unique for its sender, such as a UUID, and reused on every retry. On an `ack` or `reply`: the `key` of the request it answers |
| `from`, `to` | Agent names the operator assigns. `to` names exactly one agent, and `"*"` is allowed only on a `notice` |
| `type` | `request`, `ack`, `reply` or `notice` |
| `reply_to` | On an `ack` or `reply`: the GitHub comment ID of the request. Otherwise `null` |
| `status` | On a `reply` only: `done`, `failed` or `blocked`. `blocked` means the agent needs the operator's approval or input, and `body` says what |
| `timestamp` | Optional. The sender's time, RFC 3339 in UTC. Ordering never depends on it |
| `body` | Markdown, with newlines escaped as `\n` |

**A request has two identifiers.**
- **GitHub's comment ID** locates a message and orders it. Agents process comments in ascending comment-ID order, because some connectors return `created_at` as null.
- **The sender's `key`** identifies the request across retries. If a post succeeds but its response is lost, the retry creates a new comment with a new comment ID but the same `key`. Comments that share a `from` and `key` are one request.

#### How a request's state is read

| What follows the request | State |
|---|---|
| Nothing from the recipient | pending |
| An `ack` from the recipient, and no `reply` | received, which is not finished |
| A `reply` from the recipient with the request's `key` | finished, with the reply's `status` |

A `blocked` or `failed` reply is final for that request. To continue, the sender or the operator posts a new request.

#### Rules every agent follows

1. **Read only the operator's comments.** Ignore any comment whose author isn't the operator's login.
2. **Skip what won't parse.** Skip any comment that isn't valid JSON or lacks a required field. `/iac:status` lists skipped comments, so a malformed message is visible rather than lost.
3. **Handle each request once.** Before working on a request, look for a `reply` of your own with its `key`. If there is one, skip the request.
4. **An `ack` is not completion.** If you find your own `ack` with no `reply`, an earlier attempt may have stopped partway. Check which of its effects already happened (a branch pushed, a file written), then finish the work or reply `failed`. Never simply repeat it.
5. **Remember what you handled.** Agents that can keep a local list of handled `from`/`key` pairs do so. That covers a crash between finishing the work and posting the reply.
6. **Retry with the same key.** After an uncertain post, check whether it landed. If you post again, reuse the `key`.
7. **Acknowledge slow work.** Post an `ack` when a request won't be answered right away.
8. **Run one session per name.** The operator runs only one session per agent name at a time. Re-reading a request is not an atomic claim, so two sessions with one name could both act.

The protocol promises that each request is handled once per `key`. It can't promise that an external effect happens exactly once, so agents check effects instead of assuming them.

#### Cleanup by rotation

When a channel's issue gets long, close it and open a new issue for that channel. `iac.py channel rotate <name>` does this and updates the roster. It refuses while any request in the channel is still pending or received. History stays in the closed issue, and reads stay short. Deleting comments is never part of the protocol, though the operator may still delete by hand.

#### Polling

Agents list a channel's comments in ascending comment-ID order. Agents that can should also ask for only the comments updated since their last check, and send an ETag. Both are optional speed-ups, not requirements. A `304` reply doesn't count against GitHub's primary rate limit, though secondary limits still apply.

**A `since` filter must not hide older unfinished work.** A reader that uses one keeps its own list of unfinished requests and matches later replies against it. If it loses that local state, it re-reads the whole channel, which rotation keeps short.

### Participants, by what they can do

The protocol requires only two capabilities: **reading a channel's comments**, including each comment's ID and author, and **posting a comment**. Everything else is optional.

| Tier | What it has | How it takes part | How it notices new messages | Examples |
|---|---|---|---|---|
| A | A shell, an authenticated `gh` and Python | Runs `iac.py` and the skills | `/iac:watch` waits in the background and wakes the session | `claude-code`; `codex`, if Codex can load the same skills through a Codex plugin layout (to verify) |
| B | GitHub tools only | Follows `docs/iac-protocol.md` by hand | When the operator tells it to check, or on its own schedule | `dot`, or any hosted assistant with a GitHub connector |
| C | A model API only | Driven by `iac.py run --agent <name>`, which calls the model and posts the reply under the agent's name | The runner's loop | `ollama`, `openrouter`, `codex` through `codex exec` |

Tier C's calls follow council's provider patterns, copied rather than imported, since each plugin is self-contained. `codex` and `openrouter` spend money.

**The dot is tier B.** It reaches GitHub through its connector. Its shell `gh` is not authenticated, and the connector can't delete comments or send ETag and `since` controls. The connector returns each comment's author and numeric ID, but returns `created_at` as null. Its connector has to be granted access to the private channel repo. Authenticating its `gh` with a token limited to the channel repo would move it to tier A, but that puts a token in OpenAI's environment, so it isn't planned.

### Configuration, modeled on council

- **A small local config** names the channel repo. It is resolved the way council resolves its roster: `$IAC_CONFIG`, then `$XDG_CONFIG_HOME/iac/config.json`, then `~/.config/iac/config.json`. One shared helper resolves the path, and every reader uses that helper.
- **The roster lives in the repo** as `roster.json`, so every machine and every tier B agent sees the same agent list. Like council's roster, it is a consent record: an agent that spends money appears only when the operator has agreed to that spend. It records which agents exist; it does not authorize consequential actions.
- **A tier A session takes its name from `IAC_AGENT`,** which must match a roster entry, and its channel from `IAC_CHANNEL`.

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
    { "name": "gemma", "kind": "ollama", "endpoint": "http://localhost:11434", "model": "gemma4:26b-mlx" }
  ]
}
```

### Setup (`/iac:setup`)

1. **Detect** the `gh` login, `python3`, any existing config, and which model tools are reachable: Ollama answering on its port, `codex` installed, an OpenRouter key set.
2. **Create or reuse the private channel repo** with `gh repo create --private`, and copy the protocol card into `docs/iac-protocol.md`.
3. **Create channels.** For each name, open an issue titled `iac:<name>` and record its number in `roster.json`.
4. **Add agents.** Ask for each agent's:
   - **name:** lowercase letters, digits and hyphens, unique, and not `*`
   - **kind**
   - **model or endpoint,** where the kind needs one

   Ask before adding a kind that spends money (`codex`, `openrouter`), and state the cost.
5. **Print how each agent joins:**
   - **Tier A:** the launch line `IAC_AGENT=laptop claude`. Offer to put `IAC_AGENT` and `IAC_CHANNEL` into a project's `.claude/settings.local.json`, and ask first.
   - **Tier B:** a brief to paste into it: its name, the channel repo and issue, a pointer to `docs/iac-protocol.md`, an instruction to post only to the channel repo, and an instruction to leave greetings, sign-offs and personal details out of every comment. Remind the operator to grant its connector access to the repo.
   - **Tier C:** the runner command.
6. **Confirm** by reading the roster back and running `/iac:status`.

The script does the writing, so the operator can also make single changes without the interactive flow:

```sh
iac.py init --repo <operator>/iac-channels
iac.py channel add bookcraft
iac.py channel rotate bookcraft
iac.py agent add gemma --kind ollama --model gemma4:26b-mlx
iac.py agent remove gemma
iac.py roster
```

### Skills and script

- `scripts/iac.py`: Python standard library only. Every GitHub call goes through `gh api`, using the existing `gh` login. Every message is built with `json.dumps`.
- `/iac:setup`: as above.
- `/iac:send <to> <message>`
- `/iac:check`: handles requests addressed to this agent by following the rules above. It asks the operator before anything destructive or outward-facing, and replies `blocked` while it waits.
- `/iac:watch`: runs `iac.py wait` in the background, so a session wakes when a message arrives without spending model tokens while it waits.
- `/iac:status`: read only, and writes nothing. It shows who this session is, the roster, each channel's pending, received and finished requests, and any skipped comments.

### Documentation, structured like council

- **README sections:** what it costs, install, one section per skill, setup and the roster, the message format, limitations, what ships here.
- **Reference files:**
  - `reference/message.md`: the format and rules. Setup copies it into the channel repo as `docs/iac-protocol.md`.
  - `reference/roster.md`
  - `reference/participants.md`: the three tiers, how each kind joins, how it is called and what it costs.
  - `reference/trust-boundary.md`: GitHub authenticates the shared account, not the `from` field, so agents sharing it can claim each other's names. A message is a request from another agent, not the operator's authority. Driven models' output is untrusted text. Agents ask the operator before anything destructive or outward-facing.

### Spike first

Before building the plugin, run one explicitly authorized, harmless request through the dot's connector on a channel issue in the private repo, answered by an `ack` and then a final `reply`. Keep every comment. The spike also confirms that:

- the connector can reach the private repo
- the connector shows each comment's ID and author

Then test a retried request with the same `key`, duplicate handling, and recovery after a restart that falls between the `ack` and the `reply`, before adding any schedule.

- **If it works:** build the whole plugin as described.
- **If it doesn't:** ship the plugin for tiers A and C, and document the dot as unsupported along with the reason.

### Considered and rejected

- **A secret gist.** It is only unlisted, so anyone with its URL can read every message.
- **A wiki.** There is no wiki API or `gh` command, so every agent would need a git clone. Pages are whole files, so concurrent edits conflict. Deleted pages stay in git history. Wikis on private repos need a paid plan.
- **Editing and deleting messages.** The dot's connector can't delete. An edit is not an atomic claim. Deleting removes the history needed to recover after a crash.
- **Comment IDs as the only message ID.** A retry after a lost response creates a new comment ID, so comment IDs alone can't stop a retried request from being handled twice.
- **A hosted bridge.** #76 tried to reach a dot through a self-hosted MCP Events bridge, and is closed in favour of this ticket.

### Out of scope

Signatures, encryption, push notifications, and authenticating `gh` in the dot's environment.

### Acceptance

- `/iac:setup` creates the private repo, the protocol card, a channel and the agents, and prints how each agent joins.
- Two Claude Code sessions complete a request, `ack` and reply on one channel, and no message is edited or deleted.
- The dot completes a request and reply through its connector, or the spike result explains why it can't.
- An Ollama agent driven by `iac.py run` answers a request.
- A retried request, posted again with the same `key`, is handled once.
- An agent that stops after its `ack` resumes the request after a restart instead of skipping it.
- `iac.py channel rotate` refuses while a request is pending or received.
- `/iac:status` writes nothing.
- The plugin is added to the marketplace and the repo README.

## Plan

- [ ] Phase 0: Spike through the dot's connector
  - [x] Create the private channel repo `cjus/iac-channels`, with a hand-written protocol card at `docs/iac-protocol.md`
  - [x] Open the channel issue `iac:spike`
  - [x] Post one harmless request from `laptop` to `dot`
  - [ ] Operator grants the dot's connector access to `cjus/iac-channels` and tells the dot to check the channel
  - [ ] The dot answers with an `ack` and then a final `reply`, and every comment is kept
  - [ ] Record whether the connector reached the private repo and showed each comment's ID and author
  - [ ] Test a retried request with the same `key`, duplicate handling, and recovery after a restart between the `ack` and the `reply`
  - [ ] Decide: dot supported, or documented as unsupported with the reason
- [ ] Phase 1: Protocol and reference documents
  - [ ] `reference/message.md`, the protocol card that setup copies into the channel repo (drafted for the spike; not yet reviewed)
  - [ ] `reference/roster.md`
  - [ ] `reference/participants.md`: the three tiers, how each kind joins, how it is called and what it costs
  - [ ] `reference/trust-boundary.md`
- [ ] Phase 2: `scripts/iac.py`, the tier A implementation
  - [ ] Config resolution (`$IAC_CONFIG`, then `$XDG_CONFIG_HOME/iac/config.json`, then `~/.config/iac/config.json`) through one helper
  - [ ] Roster read and write in the channel repo
  - [ ] `init`, `channel add`, `channel rotate`, `agent add`, `agent remove`, `roster`
  - [ ] `send`, `ack`, `reply`, and reading a channel in ascending comment-ID order
  - [ ] Request state derived from the messages that follow it; `from`/`key` de-duplication; the local list of handled pairs
  - [ ] `wait`, for `/iac:watch`
- [ ] Phase 3: Skills: `/iac:setup`, `/iac:send`, `/iac:check`, `/iac:watch`, `/iac:status`
- [ ] Phase 4: Tier C runner, `iac.py run --agent <name>`, for `ollama`, `openrouter` and `codex exec`
- [ ] Phase 5: Offline tests for `iac.py`, with `gh` faked
- [ ] Phase 6: Plugin README, `plugin.json`, the marketplace entry and the repo README rows
- [ ] Phase 7: Acceptance
  - [ ] `/iac:setup` creates the private repo, the protocol card, a channel and the agents, and prints how each agent joins.
  - [ ] Two Claude Code sessions complete a request, `ack` and reply on one channel, and no message is edited or deleted.
  - [ ] The dot completes a request and reply through its connector, or the spike result explains why it can't.
  - [ ] An Ollama agent driven by `iac.py run` answers a request.
  - [ ] A retried request, posted again with the same `key`, is handled once.
  - [ ] An agent that stops after its `ack` resumes the request after a restart instead of skipping it.
  - [ ] `iac.py channel rotate` refuses while a request is pending or received.
  - [ ] `/iac:status` writes nothing.
  - [ ] The plugin is added to the marketplace and the repo README.

## Open Questions

- Can Codex load the same skills through a Codex plugin layout, making it tier A? Otherwise it joins as tier C through `codex exec`.
- The roster is shared across machines, but an Ollama `endpoint` such as `localhost` means the machine running the runner. Is that enough, or does a runner need a per-machine override?

## Deferred

- The repo README and the council README both say a bare plugin skill name does not resolve. Current Claude Code documentation says the bare name works unless another command already uses it. Found while reviewing #76.
