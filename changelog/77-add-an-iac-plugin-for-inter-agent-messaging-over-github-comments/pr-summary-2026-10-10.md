# Add the iac plugin: inter-agent messaging over GitHub comments

## Overview

Claude Code sessions had no way to hand work to models from other vendors, or to hear back from
them. This PR adds `iac` (Inter-Agent Communication), the marketplace's fifth plugin. Agents the
operator names exchange append-only JSON messages as comments on issues in a private GitHub repo,
one issue per channel, with no server to host. The protocol needs only two capabilities: reading a
channel's comments and posting one. That lets three tiers of agent take part:

- **Tier A:** an agent with a shell and `gh`, such as a Claude Code session, through the skills and
  `scripts/iac.py`.
- **Tier B:** an agent with only GitHub tools. The ChatGPT dot passed a live spike through its
  GitHub connector and is supported.
- **Tier C:** a bare model API driven by `iac.py run`. The kinds are `ollama`,
  `openai-compatible` (LM Studio and other local servers), `openrouter` and `codex exec`.

The design follows the ticket, #77, and the two reviews the dot posted on it. Messages are never
edited. A request carries a sender `key` that retries reuse. An `ack` is not completion, and only
a `reply` finishes a request. Comments are ordered by comment ID, because the dot's connector
returns `created_at` as null.

## Key changes

- **`plugins/iac/reference/`:** four reference documents.
  - `message.md` is the protocol card, and `/iac:setup` copies it into the channel repo as
    `docs/iac-protocol.md`. It has 11 rules, including one session per name and a closed channel
    issue being history.
  - `roster.md` covers `roster.json`, which names the agents and maps each channel to its current
    issue.
  - `participants.md` covers the tiers: how each kind joins, how it is called, and what it costs.
  - `trust-boundary.md` covers what GitHub authenticates, which isn't the agent, and why the
    rules are shaped as they are.
- **`plugins/iac/scripts/iac.py`:** about 1,970 lines, standard library only, Python 3.9 or newer.
  It is the only writer, and every GitHub call goes through `gh api -i`.
  - Commands: `init`, `channel add`/`rotate`, `agent add`/`remove`, `roster`, `detect`, `join`,
    `send`, `notice`, `inbox`, `ack`, `reply`, `wait`, `run`, `status`.
  - It refuses a channel repo that isn't private.
  - It writes the roster with the SHA it read, and retries on `409 Conflict`.
  - It matches requests by `from` and `key`, never by `reply_to`.
  - It checks whether a message landed before posting it again.
  - It keeps per-agent local state under `$XDG_STATE_HOME/iac/`: the handled pairs, an outbox,
    and what it has seen.
- **`plugins/iac/skills/`:** `/iac:setup`, `/iac:send`, `/iac:check`, `/iac:watch` and
  `/iac:status`. Each runs `iac.py` under `Bash(python3:*)`, and passes message bodies through a
  file, never through an argument.
- **The tier C runner, `iac.py run --agent <name>`:**
  - It posts an `ack`, calls the model with no tools, saves the answer locally, then posts it.
  - Restarted, it posts a saved answer rather than calling the model again.
  - It takes a lock per name, cuts long answers to fit one comment, and accepts `--once` and
    `--call-timeout`.
- **`plugins/iac/tests/`:**
  - `fake_gh.py` fakes `gh api -i` over a JSON file, with injectable refusals, outages and lost
    responses.
  - `test_iac.py` has 58 tests. They include a local HTTP server standing in for Ollama and
    OpenAI-compatible servers, and a fake `codex`.
- **`.github/workflows/iac.yml`:** runs the suite on three legs.
  - macOS on the system `/usr/bin/python3`, blocking. It asserts 3.9, so a change to the runner
    image can't silently move the floor.
  - macOS on Python 3.14, blocking.
  - Ubuntu on Python 3.14, advisory.
- **Manifests and docs:**
  - `plugins/iac/.claude-plugin/plugin.json` at `0.1.0`.
  - An `iac` entry in `.claude-plugin/marketplace.json`.
  - `plugins/iac/README.md`.
  - The repo README gains `iac` rows in Requirements and Plugins, its plugin counts move from four
    to five, and its CI section gains an "iac's suite" subsection.
- **`changelog/77-…/`:** `PLAN.md` and `CHANGELOG.md`, with the dot spike and every live
  acceptance run recorded by comment ID.

## Code examples

**A message,** from `plugins/iac/reference/message.md` § A message. One comment holds exactly one
JSON object, bare or in a single `json` fence:

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

**Matching by key,** from `plugins/iac/scripts/iac.py`, `match()`. A retried request has more than
one comment ID, so each request is grouped by sender and key, and paired with its recipient's ack
and reply:

```python
r = reqs.get((d["to"], d["key"]))
if r is None or d["from"] != r.to or m.id < r.first.id:
    unmatched.append(m)
elif d["type"] == "ack" and r.ack is None:
    r.ack = m
elif d["type"] == "reply" and r.reply is None:
    r.reply = m
else:
    r.extra.append(m)
```

**Save before posting,** from `plugins/iac/scripts/iac.py`, `run_pass()`. A runner killed between
the model call and the post finds the answer in its outbox on restart:

```python
# Saved before posting, so a restart posts this answer rather than asking again.
state["outbox"].append({"channel": chan, "issue": issue, "message": msg})
save_state(repo.name, name, state)
try:
    cid = post(repo, issue, msg)
except (GhError, Refused) as e:
    say(f"the reply to request {r.first.id} is saved and will post on the next pass: {e}")
    continue
```

## Plan alignment

Phases 0 to 6 were completed as planned.

**The spike came first and decided the dot's tier.** The dot answered through its connector with
an `ack` and a `done` reply. Its connector reached the private repo and returned each comment's ID
and author, with `created_at` null. In a second spike it handled three things:

- It skipped a retry posted with the same `key`.
- It reported what it had skipped.
- It finished a request in a fresh conversation, after acknowledging it in an earlier one.

The dot is supported as tier B.

**Decisions made during the branch:**

- **No per-machine override for local endpoints.** Each local server is its own agent with its own
  `endpoint`. `localhost` means the machine running that agent's runner, and the same model on two
  machines gets two names.
- **One general `openai-compatible` kind** covers LM Studio and other servers that speak the
  OpenAI chat API. `openrouter` shares its client but stays a kind of its own, because it spends
  money and reads its own key, `IAC_OPENROUTER_API_KEY`.
- **Codex ships as tier C** through `codex exec`. Codex sets `CLAUDE_PLUGIN_ROOT` only for hooks,
  its writable sandbox has no network, and nothing wakes a session when a background process
  exits.

**Deviations:**

- **Phase 6 ran before Phase 4,** at the operator's request, so the skills could be tried with
  `claude --plugin-dir`. Phase 4 then re-checked the README and `participants.md` against the
  runner as built.
- **`iac.py` gained four subcommands the plan didn't name.** `notice` and `inbox` are what
  `/iac:check` reads. `detect` and `join` let `/iac:setup` read facts instead of working them out.

**Phase 7, acceptance: six of nine items verified live,** against the private channel repo:

- The dot completed a request and reply.
- An Ollama agent (`qwen3:0.6b`) answered through the runner.
- A retry with the same `key`, including a duplicate copy that landed anyway, got one ack and one
  reply.
- A runner killed with SIGKILL right after its `ack` resumed on restart, and replied with no
  second `ack`.
- `channel rotate` refused while a request was `received`, and again while one was `pending`.
  Then it rotated the channel.
- The marketplace and README entries are in.

**Moved to post-deploy testing, by the operator's decision at close:** the three items that run
the skills inside Claude Code.

- `/iac:setup` creating the repo, card, channel and agents.
- Two Claude Code sessions completing a request on one channel.
- `/iac:status` writing nothing.

Offline, `iac.py` already covers the script side of each: the two-session exchange, and
`Reading.test_status_writes_nothing`. The skills themselves have not run inside Claude Code yet.
The plan is to test them through the deployed plugin and file tickets for what turns up.

## Testing

**Automated:**

```sh
python3 plugins/iac/tests/test_iac.py            # 58 tests, about 140 s
/usr/bin/python3 plugins/iac/tests/test_iac.py   # the same on macOS's Python 3.9.6
python3 scripts/check-citations.py               # 212 citations resolve
claude plugin validate --strict . && claude plugin validate --strict plugins/iac
```

All pass locally on Python 3.14.2 and 3.9.6. `.github/workflows/iac.yml` gets its first GitHub run
with this PR.

**Edge cases covered offline:**

- A repo that isn't private, at `init` and again once a repo turns public.
- A roster write that hits a stale SHA, and a roster that won't parse.
- A lost response, which doesn't post twice.
- A retry with the same key, and a key reused for a different request.
- A name outside the roster.
- A closed channel issue.
- What counts as a message: an unfenced object, a comment by another account, prose around the
  JSON, a `v` the reader doesn't know, and a request addressed to everyone.
- A body over GitHub's 65,536-character cap.
- A reply that fails to post, which is saved and posted later, and a saved reply GitHub keeps
  refusing, which doesn't block the rest.
- A runner restarted after its `ack`, and one restarted with a saved answer.
- A second runner for the same name.
- A model call that fails, and a server that can't be reached.
- A missing `IAC_OPENROUTER_API_KEY`, with `OPENROUTER_API_KEY` set and ignored, and a missing
  `codex`.
- Rotation while a request is pending or received.

**By hand, after installing the plugin:**

1. Run `/iac:setup` against a private repo, adding two `claude-code` agents.
2. Start two sessions with `IAC_AGENT=<each name>` and the same `IAC_CHANNEL`.
3. Run `/iac:watch` in one, then `/iac:send <the other> <something harmless>` in the first.
4. `/iac:status` should show one request, one ack and one reply. Compare the repo's head commit and
   the comment counts before and after it ran: neither should change.

## Impact assessment

- **19 files changed, 5,188 insertions, 4 deletions.** Almost all of it is new, under
  `plugins/iac/`. The only edits to existing files are the marketplace entry and the README rows.
- **No new dependencies.** `iac.py` uses only the standard library. It needs `gh`, authenticated,
  and Python 3.9 or newer. The tier C kinds additionally need a reachable model server, an
  `IAC_OPENROUTER_API_KEY`, or `codex` on `PATH`.
- **No breaking changes.** No existing plugin's behaviour changes.
- **CI gains a workflow.** It triggers on pull requests and on pushes to `main`. Its 3.9 leg fails
  on purpose if the macOS runner's `/usr/bin/python3` is no longer 3.9.

## Deferred work

- **Bare skill names.** The repo README and the council README both say a bare plugin skill name
  does not resolve. Current Claude Code documentation says the bare name works unless another
  command already uses it. Found while reviewing #76.
- **Codex as a tier A agent.** That would mean:
  - testing an install through `codex plugin marketplace add`
  - having the skills find `iac.py` without `CLAUDE_PLUGIN_ROOT`
  - turning on sandbox network access for `gh`
  - giving `/iac:watch` a Codex form, since nothing wakes a Codex session when a background
    process exits
- **The three skill-run acceptance items above:** `/iac:setup`, two Claude Code sessions, and
  `/iac:status` writing nothing. They are moved to testing through the deployed plugin, with
  tickets for whatever that finds.
