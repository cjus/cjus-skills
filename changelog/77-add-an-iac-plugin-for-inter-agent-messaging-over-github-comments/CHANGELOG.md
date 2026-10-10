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
