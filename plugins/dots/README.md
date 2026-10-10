# Dots

Send the text after `/dots` to your configured dot, such as Solrac. No other conversation, files or repository context is collected or appended.

```text
/dots I finished the parser tests. Next I need to review the draft PR.
```

The command puts that exact text in the handoff `summary`; decisions, pending items and source links remain empty. Its invocation is the request to send to your already selected destination, so ordinary messages do not need an extra confirmation. Host permissions and sensitive-data rules still apply.

## Install and command name

```sh
claude plugin marketplace add cjus/cjus-skills
claude plugin install dots@cjus-skills
```

Restart Claude Code and type `/dots <message>`. Current [official Claude Code documentation](https://code.claude.com/docs/en/skills#how-a-skill-gets-its-command-name) supports a bare plugin skill name when it is unambiguous. This plugin is named `dots` and its skill is also `dots`, so the collision-safe invocation is `/dots:dots <message>`. If another command owns `/dots`, use that namespaced form. We do not override an existing command or install an uppercase alias. Command discovery in a real Claude Code session remains unverified here.

Requires Python 3.12+; no third-party Python dependencies. Installation does not install Python.

## Select the destination first

There are two separate integrations:

1. This Claude Code plugin sends an explicitly provided message.
2. A separately hosted [reference bridge](../../services/context-bridge/README.md) and [ChatGPT receiving-plugin template](../../integrations/chatgpt-context-bridge/README.md) deliver updates through an established subscription in the intended dot conversation.

Configure `CONTEXT_BRIDGE_URL` to your trusted HTTPS bridge origin and `CONTEXT_BRIDGE_PROJECT` to the project subscribed by the intended dot. Configure `CONTEXT_BRIDGE_TOKEN` securely outside the repository. It is the sender credential for your bridge, not an OpenAI API key. Do not paste it into chat, commit it, or pass it as a command-line argument. The sender does not choose a private chat ID; the receiving chat's subscription establishes routing. Ensure only the intended chat is subscribed to this project if you want a single recipient.

Installing Dots does not host a service, connect an account, select a dot, or subscribe a conversation. The reference receiver's fixed-bearer authentication has account/setup restrictions detailed in its README. Actual delivery into an existing dot is not yet verified.

## Literal-message CLI

The skill first creates a mode-0700 temporary directory outside the repo, then saves the supplied text inside it. The private parent protects the text even if the file-writing tool uses broader default file permissions. The CLI prepares a handoff with a UUID, current timezone-qualified timestamp and configured project, preserving the message text exactly:

```sh
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/send.py" --message-file /path/to/message.txt --handoff-file /path/to/new-handoff.json --send
```

The JSON file is created with owner-only permissions and exclusive creation; an existing file is never overwritten. This persists the ID before attempting delivery. Blank messages, a missing configured project and oversized text fail validation. Omit `--send` for a no-network preview. The default CLI behavior remains preview-only even though explicitly invoking `/dots` instructs the skill to use `--send`.

If receipt is uncertain, retry the **existing JSON**, not the message-preparation command:

```sh
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/send.py" /path/to/new-handoff.json --send
```

No automatic retries are performed. `accepted` means bridge receipt, not that the dot read, processed or permanently remembered the message. The prepared files contain message content; keep them outside Git, protected, and remove them when no longer needed under your own retention policy.

## Advanced reviewed handoffs

The existing JSON-file mode also accepts structured handoffs when the user explicitly approves the extra content. `/dots` itself never invents these additional fields.

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
python3 -m unittest discover -s plugins/dots/tests -v
python3 scripts/check-citations.py
claude plugin validate --strict .
claude plugin validate --strict plugins/dots
```

The final two checks require Claude Code. Do not call them passed if that CLI is unavailable. See the reference bridge's README for its separate tests and deployment limitations.
