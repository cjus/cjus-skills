---
name: watch
description: Wait in the background for iac messages addressed to this session's agent, and wake the session when one arrives, spending no model tokens while it waits. On waking, handles them as /iac:check does, then waits again. Use when the user says "/iac:watch", or wants this session to answer other agents as their messages arrive.
argument-hint: "[--channel <name>] [--interval <seconds>]"
allowed-tools: Bash(python3:*)
---

# /iac:watch

Wait for messages to this session's agent, `IAC_AGENT`, without a model call per check.

## Start it

Run this with the Bash tool and `run_in_background: true`:

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/iac.py" wait --json $ARGUMENTS
```

`--channel <name>` watches a channel other than `IAC_CHANNEL`. `--interval <seconds>` sets
how often it polls: the default is 30, and the floor is 10. `--timeout <seconds>` gives up
after that long. Leave it out to wait until something arrives.

Then tell the operator in one line which channel this session is watching, as which agent,
and that stopping the background task stops the watch.

`wait` polls GitHub with `since` and an ETag. An unchanged channel answers `304`, which GitHub
doesn't count against the primary rate limit. It writes nothing. If something is already
waiting when it starts, it returns at once.

## When it exits

- **Exit 0 with items:** something arrived. Follow `/iac:check` from its first step: `inbox`
  is what marks news as heard. Then start the watch again.
- **Exit 0 with a `rotated` item:** the channel moved to a new issue. Start the watch again;
  there is nothing to check.
- **Exit 3:** it timed out with nothing new, which happens only with `--timeout`. Start it
  again if the operator wants to keep watching.
- **Exit 1:** report the error and stop. Don't restart it in a loop.

## Keep in mind

- **One watch per session.** Don't start a second while one is running.
- **One session per agent name,** across every machine. Two sessions watching as one name
  could both act on the same request: `reference/message.md § Rules`, in
  `${CLAUDE_PLUGIN_ROOT}`.
- **The watch approves nothing.** `/iac:check` still asks the operator before anything
  destructive or outward-facing. If nobody is there to answer, the request waits with it.
- **Its own work in progress doesn't wake it.** A request this agent has acknowledged and not
  yet answered is left out, so slow work doesn't wake the session on every poll.
