# Add an iac plugin for inter-agent messaging over GitHub comments

Start date: 2026-10-10 14:38:24 MDT

Claude Code sessions have no way to hand work to models from other vendors. This branch adds an
`iac` plugin in which agents the operator names (Claude Code sessions, a ChatGPT dot, Codex,
Ollama and OpenRouter models) exchange append-only JSON messages as comments on issues in a
private GitHub repo, one issue per channel.

## Changes

### 2026-10-10 14:40:58 MDT: Spike set up

The ticket had already taken the dot's second review: an `ack` is not completion, requests carry
a sender `key` that retries reuse, and comments are ordered by comment ID. Set up the private
channel repo (`<operator>/iac-channels`) with issue 1 as `iac:spike`, the draft protocol card as
`docs/iac-protocol.md`, and a two-agent roster (`laptop`, `dot`). Posted one request,
`6101960408`, from `laptop` to `dot`.

### 2026-10-10 15:32:12 MDT: Spike 1 passed

The dot answered through its connector with an `ack` (`6102390383`, unfenced JSON) and a `done`
reply (`6102391552`). Both were valid, and none of the three comments was edited. The connector
reaches the private repo and returns each comment's ID and author, but returns `created_at` as
null. So ordering by comment ID is required, not a precaution. The dot posts as the operator's
account, like every agent, so GitHub's author field can't tell agents apart.

### 2026-10-10 15:41:40 MDT: Spike 2 passed; the dot is supported

`laptop` posted three requests:

- **A'**, an exact retry of spike 1's request. The dot posted nothing for it.
- **B**, asking what was skipped. The dot's reply (`6102454625`) named A' as covered by the
  earlier reply.
- **C**, an `ack` now and a reply on a later check. The dot acked on the first check
  (`6102455024`), then replied from a fresh conversation (`6102467758`), with no second `ack`.

**Decision: the dot is supported as tier B.** Limits: the restart was a fresh conversation, not a
crash partway through work, and the dot posts unfenced JSON.

### 2026-10-10 15:48:46 MDT: Local endpoints are per agent; an `openai-compatible` kind

The operator expects several local servers on one machine, such as Ollama and LM Studio.

- **No per-machine override.** Each local server is its own agent with its own `endpoint`.
  `localhost` means the machine running that agent's runner, and the same model on two machines
  gets two names.
- **A new kind, `openai-compatible`,** for any chat-completions server. `ollama` keeps its native
  `/api/chat`.
- **`openrouter` shares that client** but stays its own kind, since it spends money and reads its
  own key.
- **Endpoints carry an explicit port.** Setup probes both Ollama and LM Studio, and asks before
  adding an endpoint off the local machine.

### 2026-10-10 15:56:41 MDT: Phase 1, the reference documents

**`message.md`, the protocol card, was revised after the spike:**

- Requests match by `key`, never by `reply_to`.
- "From the recipient" is defined.
- One session per name is now a rule.
- A closed channel issue is history.
- A `notice` takes no `key`, `ack` or `reply`.
- A comment with prose around its JSON isn't a message, and an unknown `v` is skipped.
- The 65,536-character comment cap is stated.

**`roster.md`, `trust-boundary.md` and `participants.md` fixed these for Phase 2:**

- Roster writes use the SHA that was read, and retry on conflict.
- A channel repo that isn't private is refused.
- A name outside the roster can't act.
- A roster that won't parse stops every reader.
- The runner acks, saves the answer, then posts it. It never replies `blocked` and gives the model
  no tools.
- `IAC_OPENROUTER_API_KEY` resolves from the environment and then the `.env` files, never from
  `OPENROUTER_API_KEY`.

**Codex is tier C,** through `codex exec`. It sets `CLAUDE_PLUGIN_ROOT` only for hooks, its
sandbox has no network, and nothing wakes a session when a background process exits. Tier A went
to `## Deferred`.

### 2026-10-10 16:18:05 MDT: Phase 2, `scripts/iac.py`

**The commands:** `init`, `channel add`/`rotate`, `agent add`/`remove`, `roster`, `send`, `ack`,
`reply`, `wait` and `status`. It adds `notice`, and `inbox` for `/iac:check`.

**Probed against GitHub first:**

- `gh api` exits 1 on a 304, so every call passes `-i` and reads the status line.
- A stale-SHA write answers 409.
- `since` returns comments updated at or after the given time.

**Choices:**

- `wait` doesn't wake for this agent's own acked work.
- A reply goes to the outbox before it is posted.
- After a 5xx or no answer, `post` checks whether the message landed before retrying.

**Tests:** `tests/fake_gh.py` fakes `gh` with refusals, outages and lost responses, and 35 tests
pass on Python 3.14 and 3.9. Read-only runs of `roster` and `status` against the real repo changed
nothing there.

### 2026-10-10 16:47:12 MDT: Phase 3, the skills

**The skills:** `/iac:setup`, `/iac:send`, `/iac:check`, `/iac:watch` and `/iac:status`. Each runs
`iac.py` under `Bash(python3:*)`, and message bodies go through a file.

**Two subcommands for setup:**

- `detect` reports the `gh` login, the config, the local servers and their models, `codex`, and
  where the OpenRouter key resolves from, never printing the key.
- `join <agent>` prints how one agent joins.

**Approval in `/iac:check`:** it acks first, then asks the operator in the session.

- Yes carries on.
- No gets a `failed` reply.
- "Not now" gets a final `blocked` reply.

Approval never comes from a message on the channel. The tests went from 35 to 44.

### 2026-10-10 17:01:35 MDT: Phase 6, ahead of Phase 4

At the operator's request, so the skills can be tried with `--plugin-dir`:

- `plugin.json` at `0.1.0`.
- The marketplace entry. Both it and `plugin.json` pass `claude plugin validate --strict`.
- `plugins/iac/README.md`.
- The repo README's `iac` rows, with its plugin counts going from four to five.

### 2026-10-10 17:11:50 MDT: Phase 4, the tier C runner

**`iac.py run --agent <name>`, on each pass:**

1. It posts any saved reply.
2. It acks each new request.
3. It calls the model with no tools.
4. It saves the answer, then posts it, or posts a `failed` reply saying why.

**Around the passes:**

- `wait`'s loop moved into a shared `poll()`.
- Prerequisites are checked before the channel is touched.
- There is one lock per name on each machine.
- Long answers are cut to fit one comment.
- `--once` and `--call-timeout` were added.

**Bugs fixed:**

- The loop read `Request` objects as dicts. The loop test caught it.
- `inbox` and `wait` treated a request whose reply was saved but not posted as pending.

**Runs against the real local servers,** posting nothing, turned their errors into usable `failed`
reasons. The docs were re-checked against the runner as built. The suite reached 58 tests.

### 2026-10-10 17:27:33 MDT: Phase 5, the suite in CI

`.github/workflows/iac.yml` runs the 58 tests on pull requests and on pushes to `main`, with three
legs:

- macOS on the system `/usr/bin/python3`, blocking. It asserts 3.9.
- macOS on 3.14, blocking.
- Linux on 3.14, advisory.

Its first run comes with the PR.

### 2026-10-10 17:36:23 MDT: Acceptance, an Ollama agent answers through the runner

With `qwen3:0.6b` pulled and a scratch config:

1. Added agent `qwen`, and opened `iac:acceptance` as issue 2.
2. `laptop` sent request `6103371124`.
3. One `--once` pass posted ack `6103372190` and reply `6103372365`, "The capital of France is
   Paris.", in about 5 seconds.

Nothing was edited.

### 2026-10-10 17:39:49 MDT: Acceptance, retry, resume and rotation against the real repo

- **Retry.** A second `send` with the same key posted nothing. A copy posted anyway
  (`6103386180`) still got one ack and one reply (`6103386867`).
- **Resume.** A SIGKILL right after ack `6103391105` left the request `received`. The restart
  replied `6103394644` with no second ack.
- **Rotation.** It refused at `received` (`6103390666`) and at `pending` (`6103396326`), then
  closed issue 2, at 13 comments, none edited, and opened issue 3.

Three acceptance items were left needing the operator's own Claude Code sessions.

### 2026-10-10 17:45:11 MDT: Context rehydrated after compacting

### 2026-10-10 18:00:35 MDT: Close

**The operator chose to close now and test through the deployed plugin,** filing tickets for what
turns up. That moves three acceptance items to post-deploy testing: `/iac:setup`, two Claude Code
sessions completing a request, and `/iac:status` writing nothing.

**The close review returned `APPROVE`.**

- The changelog had named the private channel repo by owner and name, and now names it
  generically.
- Its other findings, two `/iac:watch` gaps and six smaller suggestions, are parked under
  `PLAN.md` § Deferred for triage.

**Triage.** One follow-up issue, #79, holds the post-deploy acceptance items, both `/iac:watch`
gaps, the `--channel` carry-through, the watch's network resilience, and the endpoint query
string. Four items were dropped.
