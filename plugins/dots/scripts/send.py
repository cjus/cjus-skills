#!/usr/bin/env python3
"""Dots: send explicit messages or reviewed handoffs. No context collection or hooks."""
import argparse
import datetime as dt
import json
import os
from pathlib import Path
import ssl
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid

MAX_BYTES = 64 * 1024
FIELDS = {"schema_version", "id", "project", "recorded_at", "summary", "decisions", "pending_items", "source_links"}


def validate(payload):
    if not isinstance(payload, dict) or set(payload) != FIELDS:
        raise ValueError("Handoff must contain exactly the documented schema fields")
    if type(payload["schema_version"]) is not int or payload["schema_version"] != 1:
        raise ValueError("Unsupported schema_version")
    try:
        if str(uuid.UUID(payload["id"])) != payload["id"]:
            raise ValueError()
        stamp = dt.datetime.fromisoformat(payload["recorded_at"].replace("Z", "+00:00"))
        if stamp.tzinfo is None:
            raise ValueError()
    except (ValueError, TypeError, AttributeError):
        raise ValueError("id must be a UUID and recorded_at must include a timezone") from None
    for field, maximum in (("project", 128), ("summary", 16000)):
        if not isinstance(payload[field], str) or not payload[field].strip() or len(payload[field]) > maximum:
            raise ValueError(f"Invalid {field}")
    for field in ("decisions", "pending_items", "source_links"):
        items = payload[field]
        if not isinstance(items, list) or len(items) > 50 or any(not isinstance(x, str) or not x.strip() or len(x) > 2000 for x in items):
            raise ValueError(f"Invalid {field}")
    for url in payload["source_links"]:
        parsed = urllib.parse.urlsplit(url)
        if parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password:
            raise ValueError("Source links must be HTTPS URLs without credentials")
    raw = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode()
    if len(raw) > MAX_BYTES:
        raise ValueError("Handoff exceeds 64 KiB")
    return raw


def prepare_message(message, env=os.environ):
    """Preserve the user's exact text; never infer additional context."""
    payload = {
        "schema_version": 1, "id": str(uuid.uuid4()),
        "project": env.get("CONTEXT_BRIDGE_PROJECT", ""),
        "recorded_at": dt.datetime.now(dt.timezone.utc).isoformat(),
        "summary": message, "decisions": [], "pending_items": [], "source_links": [],
    }
    validate(payload)
    return payload


def save_prepared(path, payload):
    """Exclusive private write preserves retry identity and never overwrites a handoff."""
    raw = validate(payload)
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, "wb") as stream:
        stream.write(raw)


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def endpoint(base):
    if not isinstance(base, str) or any(ord(c) < 33 or ord(c) > 126 for c in base) or "\\" in base:
        raise ValueError("CONTEXT_BRIDGE_URL contains invalid characters")
    parsed = urllib.parse.urlsplit(base)
    if parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password or parsed.query or parsed.fragment or parsed.path not in ("", "/"):
        raise ValueError("CONTEXT_BRIDGE_URL must be an HTTPS origin without credentials, path, query or fragment")
    return base.rstrip("/") + "/handoffs"


def send(payload, env=os.environ, opener=None):
    raw = validate(payload)
    url = endpoint(env.get("CONTEXT_BRIDGE_URL", ""))
    token = env.get("CONTEXT_BRIDGE_TOKEN", "")
    if not token or any(c.isspace() for c in token):
        raise ValueError("Set a nonempty CONTEXT_BRIDGE_TOKEN in your environment")
    req = urllib.request.Request(url, data=raw, headers={"Authorization": "Bearer " + token, "Content-Type": "application/json"}, method="POST")
    opener = opener or urllib.request.build_opener(NoRedirect(), urllib.request.HTTPSHandler(context=ssl.create_default_context()))
    try:
        with opener.open(req, timeout=15) as response:
            if response.status not in (200, 201, 202):
                raise ValueError(f"Bridge rejected handoff (HTTP {response.status}); no delivery claim")
            result = json.loads(response.read(4097))
    except urllib.error.HTTPError as error:
        raise ValueError(f"Bridge rejected handoff (HTTP {error.code}); inspect configuration and retry the same handoff ID if appropriate") from None
    except (urllib.error.URLError, TimeoutError, OSError):
        raise ValueError("Bridge connection failed or timed out; receipt is uncertain. Retry only with the same handoff file and ID") from None
    except (ValueError, UnicodeError):
        raise ValueError("Bridge response was invalid; receipt is uncertain") from None
    if not isinstance(result, dict) or result.get("id") != payload["id"] or result.get("status") != "accepted":
        raise ValueError("Bridge did not confirm this handoff; receipt is uncertain")
    return {"id": payload["id"], "status": "accepted", "note": "Accepted by bridge; ChatGPT processing is not confirmed"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("file", type=Path, nargs="?", help="Existing handoff JSON file (including retries)")
    parser.add_argument("--message-file", type=Path, help="UTF-8 file containing only the literal message")
    parser.add_argument("--handoff-file", type=Path, help="New private JSON path preserving message retry identity")
    parser.add_argument("--send", action="store_true", help="Send after reviewing the preview; default performs no network call")
    args = parser.parse_args()
    try:
        if args.message_file:
            if args.file or not args.handoff_file:
                raise ValueError("Use --message-file with --handoff-file, without a positional JSON file")
            with args.message_file.open("rb") as stream:
                raw = stream.read(MAX_BYTES + 1)
            if len(raw) > MAX_BYTES:
                raise ValueError("Message file exceeds 64 KiB")
            payload = prepare_message(raw.decode("utf-8"))
            # Validate configuration before persisting; token is never written.
            if args.send:
                endpoint(os.environ.get("CONTEXT_BRIDGE_URL", ""))
            save_prepared(args.handoff_file, payload)
        else:
            if not args.file or args.handoff_file:
                raise ValueError("Provide a handoff JSON file, or --message-file with --handoff-file")
            with args.file.open("rb") as stream:
                raw = stream.read(MAX_BYTES + 1)
            if len(raw) > MAX_BYTES:
                raise ValueError("Handoff file exceeds 64 KiB")
            payload = json.loads(raw)
            validate(payload)
        if args.send:
            print(json.dumps(send(payload)))
        else:
            print(json.dumps(payload, indent=2, ensure_ascii=False))
            print("Preview only. Nothing sent. Review all content and destination before --send.", file=sys.stderr)
        return 0
    except (OSError, ValueError, TypeError) as error:
        print(f"Cannot send handoff: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
