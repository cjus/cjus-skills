# Add an iac plugin for inter-agent messaging over GitHub comments

Start date: 2026-10-10 14:38:24 MDT

Claude Code sessions have no way to hand work to models from other vendors. This branch adds an
`iac` plugin in which agents the operator names (Claude Code sessions, a ChatGPT dot, Codex,
Ollama and OpenRouter models) exchange append-only JSON messages as comments on issues in a
private GitHub repo, one issue per channel.

## Changes

### 2026-10-10 14:40:58 MDT: Spike set up

Before the branch started, #77 took the dot's second review: an `ack` is no longer completion,
requests carry a sender `key` that retries reuse, and comments are ordered by comment ID because
the dot's connector returns `created_at` as null. The review comment itself was reposted without
its personal details.

- Created the private channel repo `cjus/iac-channels` and opened issue #1 there, `iac:spike`.
- Drafted `plugins/iac/reference/message.md`, the protocol card, and uploaded it to the channel
  repo as `docs/iac-protocol.md`, beside a two-agent `roster.json` (`laptop`, `dot`).
- Posted one request from `laptop` to `dot` as comment `6101960408`, key
  `6411af86-9d7a-46da-9a74-f885175c8766`. It asks for an `ack`, then a `done` reply reporting the
  comment ID, author and `created_at` the connector returned. It read back and parsed as posted.
- Waiting on the operator to grant the dot's connector access to `cjus/iac-channels` and tell the
  dot to check the channel.

### 2026-10-10 15:32:12 MDT: Spike 1 passed

The operator granted the dot's connector access to `cjus/iac-channels`. The dot answered request
`6101960408` through the connector with two comments, both valid against the protocol card:

- An `ack`, comment `6102390383` at 21:31:29Z. It was unfenced JSON with an empty `body`, which
  the card allows.
- A `done` reply, comment `6102391552` at 21:31:38Z. It reported comment ID `6101960408`, author
  `cjus` and `created_at` null. The ID and author are correct; the real `created_at` is
  20:40:51Z.

Both carry the request's `key` and `reply_to`. All three comments are kept, and none was edited.
This confirms that the connector reaches the private repo, returns each comment's ID and author,
and returns `created_at` as null, so ordering by comment ID is required, not a precaution. The
dot posts as `cjus`, like every agent, so the author check cannot tell agents apart.

### 2026-10-10 15:41:40 MDT: Spike 2 passed; the dot is supported

`laptop` posted three requests in one batch: A' (`6102412097`), an exact copy of spike 1's
request, key and all; B (`6102412373`), asking for a list of what the dot skipped; and C
(`6102412590`), asking for an `ack` only on the first check and the final `reply` on a later one.

- **First check.** The dot posted nothing for A'. Its `done` reply to B (`6102454625`) named A'
  as a retry with the same `key`, covered by the existing reply `6102391552`, and named the
  original request as already done. It posted only an `ack` for C (`6102455024`).
- **Second check, in a fresh dot conversation** that the operator opened. The dot posted one
  `done` reply to C (`6102467758`) that cites the `ack` `6102455024`, with no second `ack` and
  nothing for A' or B.
- The channel ends at nine comments, all of them parsing, and none edited.

**Decision: the dot is supported as tier B**, so the whole plugin gets built, as the ticket says.

What the spike does not show, and the dot's own reply says as much: the restart was a fresh
conversation, not a crash partway through work. The only earlier effect was the `ack`, so rule
5's check of which effects already happened was trivial. The fresh conversation is the operator's
report; nothing on GitHub records it. The dot posts unfenced JSON, so readers must accept a
comment with or without the fence, as the card already allows.

### 2026-10-10 15:48:46 MDT: Local endpoints are per agent; an `openai-compatible` kind

The operator expects several local model servers on one machine, such as Ollama and LM Studio.
That settles the open question about `localhost` in a shared roster:

- **No per-machine override.** Every local agent carries its own `endpoint`, so each server is
  its own agent. `localhost` means the machine running that agent's runner, and rule 8 (one
  session per name) makes that a single machine. The same model on two machines gets two names.
- **A new tier C kind, `openai-compatible`,** for LM Studio and any other server that speaks the
  OpenAI chat-completions API. Its `endpoint` is the base URL the runner appends
  `/chat/completions` to, such as LM Studio's default `http://localhost:1234/v1`. `ollama` stays
  on its native `/api/chat`, the way council calls it.
- **`openrouter` shares that client** at its fixed base URL, but stays a kind of its own, because
  it spends money and reads its own key name, as council does.
- Endpoints are written with an explicit port, the lesson council's `detect.sh` records: an
  `http://host` with no port goes to `:80`. Setup probes LM Studio's `/v1/models` as well as
  Ollama's `/api/tags`. It asks before adding an `openai-compatible` agent whose endpoint is off
  the local machine, since that server may charge.

### 2026-10-10 15:56:41 MDT: Phase 1, the reference documents

**The protocol card, `message.md`, revised after the spike:**

- Requests are matched by `key`, never by `reply_to`. Spike 2's retry gave one request two
  comment IDs, and `reply_to` names whichever copy the recipient worked from.
- "From the recipient" is defined: the request's `to` as `from`, its `from` as `to`, and its
  `key`.
- One session per name is now a rule. The ticket had it, but the spike's card did not.
- New: a closed channel issue is history and gets no new posts; a `notice` takes no `key`, `ack`
  or `reply`; a message is the whole comment, so a comment with prose around its JSON is
  skipped; a `v` the reader doesn't know is skipped; GitHub's 65,536-character cap on a comment.

The channel repo's `docs/iac-protocol.md` is still the spike version. `/iac:setup` copies the
revised card when it runs.

**New: `roster.md`, `trust-boundary.md` and `participants.md`.** Decisions in them that Phase 2
has to honour:

- `iac.py` writes the roster through the contents API with the SHA it read. On a stale-SHA
  refusal it re-reads and reapplies its change, and never overwrites one it hasn't seen.
- `iac.py` refuses to read from or post to a channel repo that isn't private.
- A name not in the roster can't send or handle anything. A roster that won't parse stops every
  reader, rather than falling back.
- The runner posts an `ack`, then saves the model's answer locally before posting it, so a
  restart posts the saved answer instead of calling the model again. It never replies
  `blocked`, and it gives the model no tools.
- `IAC_OPENROUTER_API_KEY` resolves as council's key does: the environment, then `./.env`, then
  `$XDG_CONFIG_HOME/iac/.env`, else `~/.config/iac/.env`. It never resolves from
  `OPENROUTER_API_KEY`.

**Codex is tier C.** Codex `rust-v0.162.1` (2026-10-09) loads `SKILL.md` skills and reads
Claude-compatible plugin manifests, which makes tier A plausible. But it sets
`CLAUDE_PLUGIN_ROOT` only for hooks, its writable sandbox has no network for `gh`, and nothing
wakes a session when a background process exits. None of that was tested, so `codex` ships
through `codex exec`, with council's read-only flags, and tier A went to `## Deferred`.

### 2026-10-10 16:18:05 MDT: Phase 2, `scripts/iac.py`

`iac.py` implements the tier A side: `init`, `channel add` and `rotate`, `agent add` and
`remove`, `roster`, `send`, `ack`, `reply`, `wait` and `status`. It also adds `notice`, since
the card defines one and nothing else could post it. It adds `inbox` as well, which is what
`/iac:check` will read. `inbox` also tells a sender about replies to its own requests.

Probed against GitHub before writing it, and built in:

- `gh api` exits 1 on a `304` exactly as on a failure, so every call passes `-i` and reads the
  status line. Its `-i` output ends the status line with `\n` and the headers with `\r\n`.
- A contents write with a stale SHA answers `409 Conflict`, which is what the roster's
  retry-on-conflict loop keys on. The probe sent a deliberately wrong SHA, and the roster was
  left unchanged.
- `since` on a comments list returns comments updated at or after the given time.

Choices worth knowing:

- `wait` doesn't wake for a request this agent has already acknowledged, since that is its own
  work in progress and would wake it on every poll. `inbox` still reports one, with the rule 5
  instruction to check effects before finishing.
- A reply is written to the outbox before it is posted. `inbox` posts anything left there, and
  a saved reply GitHub keeps refusing stays saved without blocking the rest of `inbox`.
- After a post fails with no answer or a 5xx, `post` reads the channel to see whether the
  message landed, and posts again only if it didn't. A 4xx is GitHub refusing, so nothing
  landed.

**Tests.** `tests/fake_gh.py` fakes `gh api -i` and the REST calls iac makes against a JSON
file, with injectable refusals, outages and lost responses. `tests/test_iac.py` runs `iac.py`
as a subprocess against it. Its 35 tests pass on Python 3.14 and on macOS's system Python 3.9.
They include, by name, the acceptance items `iac.py` alone can show: two sessions completing a
request with nothing edited or deleted, a retry handled once, resuming after an `ack`, rotation
refusing, and `status` writing nothing.

**Run read-only against the real channel repo.** `roster` and `status` read the spike channel
correctly: three requests, with the A' retry folded into the first by its `key`, all `done`.
The repo's head commit and comment count were unchanged afterwards. The one file that appeared
locally was `gh`'s own `device-id`, which `gh` writes under `XDG_STATE_HOME`.

### 2026-10-10 16:47:12 MDT: Phase 3, the skills

`/iac:setup`, `/iac:send`, `/iac:check`, `/iac:watch` and `/iac:status` are in
`plugins/iac/skills/`. Each one runs `iac.py`, and every command begins with `python3`, so
`Bash(python3:*)` in `allowed-tools` matches it. Message bodies go through a file written with
the Write tool, never through an argument.

Two read-only subcommands were added to `iac.py`, so `/iac:setup` reads facts instead of
working them out:

- **`detect`** reports the `gh` login, the config and repo, whether Ollama and LM Studio
  answer and with which models, whether `codex` is installed, and where
  `IAC_OPENROUTER_API_KEY` resolves from. It never prints the key. `/iac:setup` injects it
  when it loads. On this machine it found Ollama up with no models pulled, and LM Studio up
  with only an embedding model, which is why setup offers only models detection found and
  leaves embedding models out.
- **`join <agent>`** prints how one agent joins: the launch line for tier A, the brief to
  paste for tier B, and the runner command for tier C. Run against the real roster, it
  produced the dot's brief.

The key lookup that the Phase 4 runner will use, `openrouter_key()`, landed with `detect`.
`send` now puts the generated key in its error when a post fails outright, so a retry can
reuse it.

How `/iac:check` handles approval: it acknowledges first, then asks the operator in-session.
Approval means carry on. A refusal means a `failed` reply. "Not now" means a `blocked` reply,
which is final, so the sender or operator posts a new request to continue. Approval never
comes from a message on the channel.

Skills cite references as `reference/<file>.md § <section>` and say once that `reference/` is
under `${CLAUDE_PLUGIN_ROOT}`, which lets the citation checker resolve them. Written with the
`${CLAUDE_PLUGIN_ROOT}` prefix inside the backticks, a citation goes unchecked.

The skills haven't run yet. They load only once the plugin is installed, which needs
Phase 6's manifest, and they get their first run in Phase 7. The tests went from 35 to 44.

### 2026-10-10 17:01:35 MDT: Phase 6, ahead of Phase 4

The operator asked for Phase 6 before the runner, so the skills can be tried from this branch
with `claude --plugin-dir plugins/iac`.

- `plugins/iac/.claude-plugin/plugin.json` at `0.1.0`, and an `iac` entry in
  `.claude-plugin/marketplace.json` between `explain` and `pr`. Both pass
  `claude plugin validate --strict`.
- `plugins/iac/README.md`, laid out like council's. It covers what each kind costs, install,
  the three tiers with the dot spike's results, one section per skill, setup and the roster,
  the message format, limitations, and what ships here.
- The repo README gains an `iac` row in Requirements and in Plugins. Its plugin counts go from
  four to five.

The README and `reference/participants.md` describe the runner as designed, so a Phase 4 item
now re-checks them against the runner as built. The repo README's claim that a bare skill
name doesn't resolve is the open `## Deferred` item, so the iac README neither repeats nor
contradicts it.
