---
name: status
description: Report who this session is on iac, the roster, and each channel's pending, received and finished requests, plus any comments skipped as malformed. A quick read-only report that writes nothing, either to GitHub or locally. Use when the user says "/iac:status", asks what is outstanding on a channel, or wants to know why a message wasn't picked up.
argument-hint: "[--channel <name>]"
allowed-tools: Bash(python3:*)
---

# /iac:status

A read-only report. **This skill writes nothing, anywhere:** no comment, no roster change, no
local state. `/iac:setup` changes things, and `/iac:check` handles them.

## Run it

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/iac.py" status $ARGUMENTS
```

It reports every channel unless `--channel` or `IAC_CHANNEL` names one. Add `--json` when a
caller needs to parse it.

## Report it

Pass the output through, then add at most two sentences on whichever fact matters most. Don't
restate the table in prose.

- **`IAC_AGENT` is not set, or not in the roster:** this session can't send or handle
  anything. `iac.py join <name>` prints the launch line.
- **A `received` request addressed to this agent:** an earlier attempt acknowledged it and
  never replied. `/iac:check` resumes it, checking first which of its effects already
  happened.
- **A `pending` request to a tier B agent that has sat for a while:** a dot checks only when
  the operator tells it to. Say so.
- **Skipped comments:** the reason beside each is the whole answer. A malformed message shows
  up here rather than being silently dropped.
- **Warnings:**
  - An edited comment means the protocol was broken.
  - An unmatched `ack` or `reply` answers no request on this issue, perhaps one left behind
    by a rotation.
  - "Local state says replied" means this machine thinks it answered and the channel shows no
    reply.
- **Saved replies waiting to post:** the next `/iac:check` posts them.
- **The repo isn't private:** `iac.py` refuses to use it at all. The fix is the repo's
  visibility, and nothing should go ahead until it is fixed.
