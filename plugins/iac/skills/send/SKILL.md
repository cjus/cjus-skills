---
name: send
description: Send a request to another agent on an iac channel, as this session's agent (IAC_AGENT). Writes the message body to a file, posts it with iac.py, and reports its comment ID and key. Use when the user says "/iac:send", or asks to hand a task to, ask, or message another agent over iac, such as the dot, Codex or a local model.
argument-hint: "<to> <message>"
allowed-tools: Bash(python3:*), Bash(mktemp:*), Write
---

# /iac:send

Post one request from this session's agent to another agent on the channel.

The first word of the arguments is the recipient's name, and the rest is the message:
`$ARGUMENTS`

## Steps

1. **Who is sending, and where.** This session is `IAC_AGENT`, on `IAC_CHANNEL`. If either is
   missing, or the recipient isn't in the roster, `iac.py` says so. Relay that and stop. To see
   the names, run `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/iac.py" roster`.

2. **Write the body.** It is Markdown, and it is everything the recipient will see.
   - Make it stand alone. The recipient has none of this conversation, only the body and what
     it can reach itself, such as a repo by name.
   - Say what done looks like, so the reply can say `done` or `failed` without guessing.
   - If the user's message already is the request, send it as written.
   - Leave out secrets, keys, tokens and personal details. Every vendor whose agent reads
     the channel receives the body: `reference/trust-boundary.md § Where a channel's text goes`,
     in `${CLAUDE_PLUGIN_ROOT}`.

3. **Put the body in a file,** using the Write tool, in a new directory from `mktemp -d`. Never
   pass a body as an argument: quotes, backticks and `$` would be mangled or run.

4. **Post it:**

   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/iac.py" send <to> --body-file <path> --json
   ```

   Add `--channel <name>` to post to a channel other than `IAC_CHANNEL`.

5. **Report** the comment ID, the key and the channel in one line. Then say how the reply
   will arrive: `/iac:watch` wakes this session when it lands, and `/iac:check` looks now.

## If it fails

`iac.py` checks whether a failed post landed before trying again, so a request is never posted
twice by accident. If it still fails, its message gives the key. Retry with the same body and
`--key <key>`, which posts the request only if no copy of it has landed. Never retry with a new
key, because that makes a second request.
