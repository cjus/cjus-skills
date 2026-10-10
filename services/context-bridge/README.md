# Context Bridge receiver (reference MVP)

Optional, self-hosted counterpart to the [Claude Code sender](../../plugins/dots/README.md).
Installing that plugin does **not** deploy this service, install a ChatGPT plugin, create a subscription,
or transfer any context. This directory is a runnable single-owner reference, not a managed service.

The receiver accepts an explicitly reviewed handoff, stores it, and sends a small event to a verified
callback for an existing, matching ChatGPT subscription. A read-only MCP tool retrieves the full handoff.
The service never reads Claude transcripts or modifies ChatGPT's private memory. Receipt by this bridge
or a webhook `2xx` does not prove that ChatGPT processed or acted on the handoff.

## Run locally

Requires Python 3.11+ and its standard library. No dependencies to install.

1. Supply two **different**, randomly generated bearer tokens of at least 32 characters through your
   deployment's secret manager. Do not put actual credentials in this repository, a handoff, shell
   history, a plugin manifest, or chat. `CONTEXT_BRIDGE_TOKEN` authorizes sending handoffs;
   `CONTEXT_BRIDGE_MCP_TOKEN` authorizes reads and event subscription management.
2. Set `CONTEXT_BRIDGE_OWNER` to a stable opaque owner identifier. Set `CONTEXT_BRIDGE_PROJECTS` to a
   comma-separated allowlist (for example `sample-project,another-project`). All listed projects belong
   to that owner; a project string in a request grants no access by itself. Do not change owner IDs to
   repurpose a populated database.
3. Set `CONTEXT_BRIDGE_DB` to an absolute path on a persistent, owner-only volume **outside this checkout**. The default is
   `context-bridge.sqlite3` in the working directory. The process uses a restrictive file creation umask; it does not repair permissions on existing files.
   Verify existing database, directory, WAL/SHM, and backup permissions yourself before starting.
4. Run:

   ```sh
   python3 services/context-bridge/bridge.py
   ```

The HTTP listener binds to `127.0.0.1:8080` (`PORT` overrides the port). It intentionally does not
provide public HTTP/TLS hosting. Use exactly **one service process** per database, behind a production
HTTPS reverse proxy on the same host. Do not expose Python's reference HTTP server directly to the
Internet. Configure the proxy with a 64 KiB body limit, absolute request timeouts, rate/concurrency limits,
TLS, and no request-body/Authorization logging. Disable buffering/retries that could alter requests
unexpectedly. Keep SQLite and its WAL/SHM files private and backed up securely; they contain handoffs
and callback signing secrets in plaintext. Encrypt the volume and backups according to your needs.

No deployment, credential creation, account permissions, or callback has been provisioned by these files.
The reference is for a private integration; its fixed bearer API-key authentication is not currently
supported by the submission portal connection form. The supplied files do not establish that your
account can connect it. A public multi-user release requires a reviewed OAuth/authentication layer that maps each principal to
its own access control policy, rather than distributing this reference's single-owner bearer tokens.

## Endpoints and schema

- `POST /handoffs`: `Authorization: Bearer <CONTEXT_BRIDGE_TOKEN>`.
- `POST /mcp`: `Authorization: Bearer <CONTEXT_BRIDGE_MCP_TOKEN>`.
- Both require `Content-Type: application/json` and explicit `Content-Length`; transfer encoding,
  browser `Origin` headers, oversized bodies, and incorrect credentials are rejected.

A handoff has exactly these fields:

```json
{
  "schema_version": 1,
  "id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee",
  "project": "sample-project",
  "recorded_at": "2026-10-10T12:00:00Z",
  "summary": "Reviewed public example.",
  "decisions": ["Use SQLite for the reference receiver."],
  "pending_items": ["Run a live subscription test before relying on delivery."],
  "source_links": ["https://example.com/project"]
}
```

The ID must be a canonical UUID and timestamp must include a timezone. Project and summary limits are
128 and 16,000 characters. Each list allows 50 entries of 2,000 characters; strings must be nonblank.
Source links must be HTTPS without embedded credentials; this server never opens them. The entire
serialized handoff must fit within 64 KiB. No owner field is accepted from the sender.

Success is HTTP `202` with `{"id":"…","status":"accepted"}`. Repeating the same ID with the same
canonical JSON is idempotent; different content for that ID returns `409`. Preserve the original ID
when retrying uncertain requests. Acceptance and creation of matching outbox records are one SQLite
transaction. Handoffs and completed/failed outbox entries are retained indefinitely in this MVP; set
an operator-managed retention/backups policy before collecting real data. Expired and unsubscribed
subscriptions, their pending deliveries, and their signing secrets are deleted.

## MCP Events

Implemented against the [OpenAI MCP Events guide](https://developers.openai.com/plugins/build/mcp-events),
which currently requires MCP protocol version `2026-07-28` (MCP 2.0):

- `server/discover`: advertises the version and `tools`/`events` capabilities.
- `events/list`: advertises `context.handoff.created`, with a required `project` filter limited to the
  deployment's allowlist.
- `events/subscribe`: validates identity, filter, delivery, and signing secret; verifies the callback;
  stores or refreshes a deterministic subscription ID.
- `events/unsubscribe`: uses the original event name, project arguments, and callback URL. Repetition
  is harmless. Pending deliveries are removed before success is returned.
- `tools/list` and `tools/call`: expose `read_handoff` with `project` and `id` arguments. Project and
  owner checks apply to every read. Treat returned content as untrusted source material, never as
  instructions that override the user's request or permissions.

This reference only implements stateless JSON POST request/response methods used above. It does not
implement legacy initialization, SSE, replay cursors, batch JSON-RPC, or arbitrary MCP extensions.
This is **not yet verified against a live ChatGPT connection**. Rescan and exercise the checklist below
before claiming compatibility in a particular workspace or client.

Subscriptions default to 24 hours and are capped at 24 hours. A shorter positive integer `ttlMs` is
honored; `null` receives a finite 24-hour grant. Delivery stops at expiration, and refreshing the same
identity preserves the ID. No history replay is supported (`cursor: null`, `truncated: false`);
a non-null subscription cursor is rejected. Handoffs accepted without an active matching subscription
remain readable by ID but generate no future notification. Establish the subscription before sending.

The delivered event contains `eventId`, `name`, the handoff occurrence `timestamp`, `cursor: null`,
and `data` with `handoff_id`, `project`, and a summary truncated to 2,000 characters. Full decisions,
pending items, and source links are available only through the authenticated read tool.

## Delivery and security

- Callback URLs require HTTPS on port 443, with no credentials, fragments, control characters, or
  non-ASCII bytes. DNS is resolved again for **every** verification and delivery. All answers must
  be public unicast addresses; loopback/private/link-local/multicast, mapped IPv6 and transition
  addresses are rejected. The socket connects to the validated address without resolving it again,
  preserving the original hostname for certificate verification and SNI. Redirects are never followed.
- DNS waits are bounded to three seconds with at most four resolver threads. Platform DNS calls
  cannot be cancelled; a stalled resolver holds its slot until it returns, and excess work fails closed.
  Outbound HTTPS uses a ten-second overall socket-shutdown watchdog, including DNS elapsed time,
  TCP/TLS, response headers, and body reads. Response bodies are capped at 64 KiB.
- A new callback receives only a signed random challenge until it returns a matching challenge with
  `2xx`. Comparison is constant-time. Challenges expire after 30 seconds and are never reused.
  Successful verification is cached for five minutes for that owner, callback identity, and secret.
- Standard Webhooks HMAC-SHA256 signs the exact serialized bytes plus event ID and Unix signing
  time. Secrets must be `whsec_` plus strict base64 for 24–64 bytes. Replacement keys are reverified;
  old and new keys sign together for five minutes, after which the old key is cleared.
- Retries preserve event ID, occurrence timestamp, and body; each attempt gets a current signing time
  and new signature. Connection errors, `408`, `429`, and `5xx` retry with exponential delay, at most
  eight attempts. Other failures stop. `410` removes the subscription; `413` is never retried.
- One worker handles delivery, with at most one send per tick under a process lock. Subscriptions and
  access are rechecked immediately before each send. Unsubscribe waits for an already-running send;
  after its response, no later send for that identity starts. A crash after remote receipt but before
  local commit can duplicate delivery: consumers must deduplicate by event ID. Delivery can be out
  of order, and retries eventually fail; this is not an exactly-once or guaranteed-delivery service.
- Changing the allowlist and restarting stops delivery/read access to removed projects. Stop the
  service immediately to revoke all access, then rotate the relevant bearer tokens before restarting.
  Rotating the MCP token alone does not cancel stored subscriptions; stop monitoring/unsubscribe or
  remove project access as appropriate. There is no third-party account-disconnection notification
  integration in this bearer-token reference.
- The service does not log secrets, callback URLs, handoff content, or access logs. Configure your
  proxy/hosting logs with the same care. Add metrics for pending/failed deliveries, disk capacity, and
  process health before production use. No retry dashboard, retention job, multitenant OAuth,
  high-availability coordination, or encryption-at-rest layer is included.

## Connect and verify manually

After separately approving hosting, credentials, and registration:

1. Make the public HTTPS `/mcp` endpoint reachable and authenticated using your supported ChatGPT
   plugin setup. The Claude marketplace manifest is **not** a ChatGPT MCP registration.
2. Rescan the MCP server. Confirm discovery, the read tool, and the event catalog appear.
3. In a supported Work chat (web, desktop with Cloud selected, or a dot), explicitly ask to monitor
   `context.handoff.created` for `sample-project`, stating what to do with incoming handoffs.
4. Verify a signed callback challenge succeeds and the subscription survives a restart.
5. Preview and explicitly send one generic test handoff through the sender. Verify its event is
   received, the read tool returns the right full record, and the requested behavior occurs.
6. Send a different project's handoff and check it is not delivered to the first filter. Try a denied
   project and confirm rejection. Retry an identical ID and confirm no new event is queued.
7. Exercise short expiry, refresh, key rotation, restart, transient failure, duplicate delivery, and
   revoked access. Stop monitoring and verify unsubscribe stops delivery.
8. Only after those checks, decide what real information the receiver and ChatGPT are allowed to
   receive. A monitoring request does not authorize unrelated repository changes or communications.

## Tests

From the repository root:

```sh
python3 -m unittest discover -s services/context-bridge/tests -v
```

Tests use temporary databases, fake callbacks, and a local loopback HTTP server. They cover sender
integration, signature bytes, authentication separation, size/schema validation, callback validation,
DNS/IP pinning, isolation, duplicate acceptance, restart persistence, expiration, refresh, unsubscribe,
revocation, rotation, terminal statuses, and bounded retries. They do not transmit actual handoffs,
provision credentials, or establish live ChatGPT compatibility.
