# context-bridge

An explicit, preview-first Claude Code handoff sender. It shares selected project context with **your own** authenticated bridge, which can deliver subscribed MCP Events into ChatGPT, including a dot conversation.

This is two integrations, not a magic link to an existing chat:

1. This Claude Code plugin prepares and sends a handoff.
2. The separately hosted [reference bridge](../../services/context-bridge/README.md) exposes a ChatGPT MCP plugin endpoint, with a separate [receiving-plugin template](../../integrations/chatgpt-context-bridge/README.md). The user connects that plugin and asks their target chat to subscribe.

Installing the sender does not host the bridge, connect an account, subscribe a chat or grant permission for the receiving assistant to act. An OpenAI API key alone does not grant access to an existing ChatGPT conversation. No direct private ChatGPT endpoints or browser credentials are used.

## Install and invoke

```sh
claude plugin marketplace add cjus/cjus-skills
claude plugin install context-bridge@cjus-skills
```

Restart Claude Code, then use:

```text
/context-bridge:send demo — summarize the integration decisions for my connected assistant
```

Requires Python 3.12+; no third-party Python dependencies. Plugin installation does not install Python. The sender is Linux-tested in this initial contribution; a real Claude Code/macOS integration test remains required before claiming macOS support for this new plugin.

## Configure

Configure `CONTEXT_BRIDGE_URL` to your trusted HTTPS bridge **origin**, with no path, query string or embedded credentials. Configure `CONTEXT_BRIDGE_TOKEN` securely outside the repository using your normal secret-management workflow. It is a sender credential for your bridge, not an OpenAI API key. Do not paste tokens into chat, commit them, or pass them as command-line arguments. Do not grant the sender callback-signing secrets or the ChatGPT-side MCP credential.

Setup of hosting, credentials and account connections is a separate explicit user action. The bridge documentation describes the reference implementation; it has no managed hosting service.

## Handoff format

Use one JSON file, selected explicitly, outside the repository:

```json
{
  "schema_version": 1,
  "id": "00000000-0000-4000-8000-000000000001",
  "project": "demo",
  "recorded_at": "2026-10-10T12:00:00Z",
  "summary": "Implemented a mock integration; real account delivery is not tested.",
  "decisions": ["Use explicit handoffs rather than exporting transcripts"],
  "pending_items": ["Review the draft"],
  "source_links": ["https://example.com/demo"]
}
```

Generate a new UUID for each new handoff. Keep the ID and exact content unchanged when retrying the same handoff. No date or project is inferred by the sender. Payload maximum is 64 KiB UTF-8; project 128 characters, summary 16,000 characters, each list at most 50 strings of at most 2,000 characters. Links must be HTTPS with no embedded credentials. Links can still contain sensitive query data: inspect them manually.

Preview locally:

```sh
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/send.py" /path/to/handoff.json
```

After reviewing the complete content and confirming the receiving origin, send:

```sh
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/send.py" /path/to/handoff.json --send
```

Default preview never makes a network request. `--send` posts to `/handoffs`, with a 15-second timeout and redirects disabled. It performs no automatic retries. On uncertain receipt, retry only the same file and ID; the bridge deduplicates identical submissions. The sender does not collect transcripts, run background hooks, search your workspace or scan environment variables for context.

`accepted` means the bridge accepted that handoff. It does **not** mean ChatGPT received it, processed it, responded, or permanently remembered it. No active subscription may exist yet. A real end-to-end check must confirm the distinct stages separately.

## Privacy and authority

Only send content the user explicitly chose to share with the configured service. Review context and links for secrets and unnecessary private/proprietary data. There is no automatic detector that can guarantee a payload is safe. Keep examples, logs, test fixtures and PR descriptions generic. Event payloads are contextual data, not trusted commands or a way to bypass the receiving assistant's permissions.

## Checks

From the repository root:

```sh
python3 -m unittest discover -s plugins/context-bridge/tests -v
python3 scripts/check-citations.py
claude plugin validate --strict .
claude plugin validate --strict plugins/context-bridge
```

The final two checks require Claude Code. Do not call them passed if that CLI is unavailable. See the reference bridge's README for its separate tests and deployment limitations.
