import base64
import hashlib
import hmac
import http.client
import json
import os
import socket
import sys
import tempfile
import threading
import time
import unittest
from pathlib import Path
from unittest.mock import patch, MagicMock
from http.server import HTTPServer

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from bridge import Bridge, Fault, EVENT, MAX_BODY, PinnedHTTPS, callback_parts, encoded, handler, headers, key, public_addresses, post_public

SECRET = "whsec_" + base64.b64encode(b"a" * 32).decode()
NEW_SECRET = "whsec_" + base64.b64encode(b"b" * 32).decode()


def handoff(project="sample-project"):
    return {"schema_version": 1, "id": "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee", "project": project,
            "recorded_at": "2026-10-10T12:00:00Z", "summary": "Reviewed public example.",
            "decisions": ["Use SQLite"], "pending_items": [], "source_links": ["https://example.com/project"]}


def subscription(project="sample-project", secret=SECRET):
    return {"name": EVENT, "arguments": {"project": project},
            "delivery": {"mode": "webhook", "url": "https://example.com/callback", "secret": secret}}


class LifecycleTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.path = os.path.join(self.temp.name, "bridge.sqlite3")
        self.clock = 1000
        self.calls = []
        self.status = 204
        self.bridge = self.open()

    def open(self, owner="owner-a", projects=("sample-project", "other")):
        return Bridge(self.path, owner, projects, self.transport, lambda: self.clock)

    def transport(self, url, body, hdr):
        self.calls.append((url, body, hdr))
        value = json.loads(body)
        if value.get("type") == "verification":
            return 200, encoded({"challenge": value["challenge"]})
        return self.status, b""

    def tearDown(self):
        self.bridge.close()
        self.temp.cleanup()

    def test_lifecycle_signature_idempotence_and_read(self):
        sub = self.bridge.subscribe(subscription())
        self.assertEqual(len(self.calls), 1)
        self.assertEqual(sub, self.bridge.subscribe(subscription()))
        self.assertEqual(len(self.calls), 1)
        self.bridge.accept(handoff())
        self.bridge.accept(handoff())
        self.bridge.deliver_once()
        self.assertEqual(len(self.calls), 2)
        _, body, hdr = self.calls[-1]
        event = json.loads(body)
        self.assertEqual(event["timestamp"], handoff()["recorded_at"])
        self.assertEqual(event["eventId"], hdr["webhook-id"])
        signed = f'{hdr["webhook-id"]}.{hdr["webhook-timestamp"]}.'.encode() + body
        expected = "v1," + base64.b64encode(hmac.new(b"a" * 32, signed, hashlib.sha256).digest()).decode()
        self.assertEqual(hdr["webhook-signature"], expected)
        self.assertEqual(self.bridge.read({"project": "sample-project", "id": handoff()["id"]}), handoff())
        self.bridge.deliver_once()
        self.assertEqual(len(self.calls), 2)
        changed = handoff(); changed["summary"] = "Different"
        with self.assertRaises(Fault) as error:
            self.bridge.accept(changed)
        self.assertEqual(error.exception.status, 409)

    def test_owner_and_project_isolation(self):
        self.bridge.subscribe(subscription("other"))
        self.bridge.accept(handoff())
        self.bridge.deliver_once()
        self.assertEqual(len(self.calls), 1)
        with self.assertRaises(Fault):
            self.bridge.read({"project": "other", "id": handoff()["id"]})
        second = self.open("owner-b")
        try:
            with self.assertRaises(Fault):
                second.read({"project": "sample-project", "id": handoff()["id"]})
            self.assertNotEqual(second.subscribe(subscription())["id"], self.bridge.subscribe(subscription())["id"])
        finally:
            second.close()
        with self.assertRaises(Fault):
            self.bridge.subscribe(subscription("unauthorized"))

    def test_retry_survives_restart_and_fresh_signing_time(self):
        self.bridge.subscribe(subscription())
        self.bridge.accept(handoff())
        self.status = 503
        self.bridge.deliver_once()
        first = self.calls[-1]
        self.bridge.close(); self.bridge = self.open()
        self.clock += 10
        self.status = 200
        self.bridge.deliver_once()
        second = self.calls[-1]
        self.assertEqual(first[1], second[1])
        self.assertEqual(first[2]["webhook-id"], second[2]["webhook-id"])
        self.assertNotEqual(first[2]["webhook-timestamp"], second[2]["webhook-timestamp"])
        self.assertNotEqual(first[2]["webhook-signature"], second[2]["webhook-signature"])

    def test_unsubscribe_idempotent_stops_outbox(self):
        self.bridge.subscribe(subscription())
        self.bridge.accept(handoff())
        params = subscription(); del params["delivery"]["secret"]
        self.assertEqual(self.bridge.unsubscribe(params), {})
        self.assertEqual(self.bridge.unsubscribe(params), {})
        self.bridge.deliver_once()
        self.assertEqual(len(self.calls), 1)

    def test_expiration_refresh_and_no_replay(self):
        params = subscription(); params["ttlMs"] = 1000
        old = self.bridge.subscribe(params)
        self.bridge.accept(handoff())
        self.clock += 2
        self.bridge.deliver_once()
        self.assertEqual(len(self.calls), 1)
        new = self.bridge.subscribe(params)
        self.assertEqual(old["id"], new["id"])
        self.assertNotEqual(old["refreshBefore"], new["refreshBefore"])
        self.bridge.deliver_once()
        self.assertEqual(len(self.calls), 2)  # verification only, missed event is not replayed
        params["cursor"] = "not-supported"
        with self.assertRaises(Fault):
            self.bridge.subscribe(params)

    def test_secret_rotation_dual_signature(self):
        sid = self.bridge.subscribe(subscription())["id"]
        self.assertEqual(sid, self.bridge.subscribe(subscription(secret=NEW_SECRET))["id"])
        self.bridge.accept(handoff())
        self.bridge.deliver_once()
        self.assertEqual(len(self.calls[-1][2]["webhook-signature"].split()), 2)
        self.clock += 301
        self.bridge.deliver_once()
        row = self.bridge.db.execute("SELECT old_secret FROM subscriptions").fetchone()
        self.assertIsNone(row[0])

    def test_failed_challenge_never_stores_subscription(self):
        self.bridge.transport = lambda *_: (200, b'{"challenge":"wrong"}')
        with self.assertRaises(Fault) as error:
            self.bridge.subscribe(subscription())
        self.assertEqual(error.exception.code, -32015)
        self.assertEqual(self.bridge.db.execute("SELECT count(*) FROM subscriptions").fetchone()[0], 0)

    def test_revoke_access_after_restart(self):
        self.bridge.subscribe(subscription())
        self.bridge.accept(handoff())
        self.bridge.close(); self.bridge = self.open(projects=("other",))
        self.bridge.deliver_once()
        self.assertEqual(len(self.calls), 1)

    def test_terminal_responses_and_bounded_retries(self):
        for status in (410, 413, 302, 401, 503):
            with self.subTest(status=status):
                self.bridge.unsubscribe(subscription())
                self.bridge.db.execute("DELETE FROM handoffs"); self.bridge.db.commit()
                self.bridge.subscribe(subscription())
                self.bridge.accept(handoff())
                self.status = status
                before = len(self.calls)
                for _ in range(10):
                    self.bridge.deliver_once(); self.clock += 1000
                self.assertEqual(len(self.calls) - before, 8 if status == 503 else 1)

    def test_410_stops_other_queued_events(self):
        self.bridge.subscribe(subscription())
        self.bridge.accept(handoff())
        second = handoff(); second["id"] = "11111111-2222-4333-8444-555555555555"
        self.bridge.accept(second)
        self.status = 410
        self.bridge.deliver_once()
        self.bridge.deliver_once()
        self.assertEqual(len(self.calls), 2)  # verification plus first event only

    def test_expiry_is_checked_before_each_send(self):
        params = subscription(); params["ttlMs"] = 1000
        self.bridge.subscribe(params)
        self.bridge.accept(handoff())
        second = handoff(); second["id"] = "11111111-2222-4333-8444-555555555555"
        self.bridge.accept(second)
        original = self.bridge.transport
        def slow_transport(*args):
            self.clock += 2
            return original(*args)
        self.bridge.transport = slow_transport
        self.bridge.deliver_once()
        self.bridge.deliver_once()
        self.assertEqual(len(self.calls), 2)

    def test_sender_to_delivery_to_read_integration(self):
        import importlib.util
        import io
        sender_path = Path(__file__).resolve().parents[3] / "plugins/context-bridge/scripts/send.py"
        spec = importlib.util.spec_from_file_location("context_sender", sender_path)
        sender = importlib.util.module_from_spec(spec); spec.loader.exec_module(sender)
        service = self.bridge
        class Response(io.BytesIO):
            status = 202
        class Opener:
            def open(self, request, timeout):
                self_request = json.loads(request.data)
                assert request.full_url == "https://bridge.example.com/handoffs"
                assert request.get_header("Authorization") == "Bearer " + "s" * 32
                return Response(encoded(service.accept(self_request)))
        self.bridge.subscribe(subscription())
        result = sender.send(handoff(), {"CONTEXT_BRIDGE_URL": "https://bridge.example.com",
                                        "CONTEXT_BRIDGE_TOKEN": "s" * 32}, Opener())
        self.assertEqual(result["status"], "accepted")
        self.bridge.deliver_once()
        event = json.loads(self.calls[-1][1])
        result = self.bridge.rpc({"jsonrpc": "2.0", "id": 3, "method": "tools/call",
            "params": {"name": "read_handoff", "arguments": {"id": event["data"]["handoff_id"],
                        "project": event["data"]["project"]}}})
        self.assertEqual(json.loads(result["content"][0]["text"]), handoff())

    def test_validation_and_discovery(self):
        result = self.bridge.rpc({"jsonrpc": "2.0", "id": 1, "method": "server/discover"})
        self.assertEqual(result["supportedVersions"], ["2026-07-28"])
        self.assertIn("events", result["capabilities"])
        for change in ({"schema_version": True}, {"id": "bad"}, {"recorded_at": "2026-10-10"},
                       {"summary": "x" * 16001}, {"project": "unauthorized"},
                       {"source_links": ["https://user:password@example.com"]}, {"extra": "bad"}):
            value = handoff(); value.update(change)
            with self.subTest(change=change), self.assertRaises(Fault):
                self.bridge.accept(value)


class NetworkTests(unittest.TestCase):
    def test_callback_url_validation(self):
        for url in ("http://example.com", "https://user:pass@example.com", "https://example.com:444/",
                    "https://example.com/#fragment", "https://example.com/\r\nfoo", "https://[::1%25lo]/"):
            with self.subTest(url=url), self.assertRaises(Fault):
                callback_parts(url)
        self.assertEqual(callback_parts("https://example.com/callback?a=1").hostname, "example.com")

    def test_dns_blocks_nonpublic_and_mixed_answers(self):
        for host in ("127.0.0.1", "10.0.0.1", "169.254.169.254", "192.168.0.1", "::1", "fc00::1", "::ffff:8.8.8.8", "224.0.0.1"):
            answers = [(socket.AF_INET, socket.SOCK_STREAM, 6, "", (host, 443))]
            with self.subTest(host=host), patch("bridge.socket.getaddrinfo", return_value=answers), self.assertRaises(Fault):
                public_addresses("example.com")
        answers = [(socket.AF_INET, socket.SOCK_STREAM, 6, "", (ip, 443)) for ip in ("8.8.8.8", "127.0.0.1")]
        with patch("bridge.socket.getaddrinfo", return_value=answers), self.assertRaises(Fault):
            public_addresses("example.com")

    def test_pinned_connection_no_second_dns_and_hostname_tls(self):
        address = (socket.AF_INET, socket.SOCK_STREAM, 6, "", ("8.8.8.8", 443))
        connection = PinnedHTTPS("example.com", address)
        connection._context = MagicMock()
        with patch("bridge.socket.socket") as factory, patch("bridge.socket.getaddrinfo") as resolve:
            connection.connect()
            factory.return_value.connect.assert_called_once_with(("8.8.8.8", 443))
            connection._context.wrap_socket.assert_called_once_with(factory.return_value, server_hostname="example.com", do_handshake_on_connect=False)
            resolve.assert_not_called()

    def test_deadline_cancellation_during_tls_wrapping(self):
        connection = PinnedHTTPS("example.com", (socket.AF_INET, socket.SOCK_STREAM, 6, "", ("8.8.8.8", 443)))
        secured = MagicMock()
        def wrap(*args, **kwargs):
            connection.cancelled.set()
            return secured
        connection._context = MagicMock(); connection._context.wrap_socket.side_effect = wrap
        with patch("bridge.socket.socket"), self.assertRaises(TimeoutError):
            connection.connect()
        secured.close.assert_called_once()
        secured.do_handshake.assert_not_called()

    def test_overall_deadline_interrupts_slow_response(self):
        left, right = socket.socketpair()
        class SlowResponse:
            status = 200
            def read(self, size):
                return left.recv(size)
        class Connection:
            def __init__(self, *args):
                self.sock = left
                self.cancelled = threading.Event()
            def connect(self):
                pass
            def request(self, *args):
                pass
            def getresponse(self):
                self.sock = None  # http.client can detach socket on Connection: close
                return SlowResponse()
            def close(self):
                left.close()
        started = time.monotonic()
        try:
            with patch("bridge.public_addresses", return_value=[None]), patch("bridge.PinnedHTTPS", Connection), patch("bridge.OUTBOUND_TIMEOUT", 0.05):
                with self.assertRaises((TimeoutError, OSError)):
                    post_public("https://example.com/callback", b"{}", {})
            self.assertLess(time.monotonic() - started, 1)
        finally:
            left.close(); right.close()

    def test_signing_secret_bounds(self):
        for secret in ("bad", "whsec_invalid!", "whsec_" + base64.b64encode(b"a" * 23).decode(),
                       "whsec_" + base64.b64encode(b"a" * 65).decode()):
            with self.assertRaises(Fault):
                key(secret)


class HTTPTests(unittest.TestCase):
    def setUp(self):
        self.bridge = Bridge(":memory:", "owner", ["sample-project"])
        self.server = HTTPServer(("127.0.0.1", 0), handler(self.bridge, "s" * 32, "m" * 32))
        self.thread = threading.Thread(target=self.server.serve_forever); self.thread.start()

    def tearDown(self):
        self.server.shutdown(); self.thread.join(); self.server.server_close(); self.bridge.close()

    def request(self, path, payload, token, extra=None):
        connection = http.client.HTTPConnection(*self.server.server_address)
        hdr = {"Authorization": "Bearer " + token, "Content-Type": "application/json"}
        hdr.update(extra or {})
        connection.request("POST", path, payload, hdr)
        response = connection.getresponse(); status, body = response.status, response.read()
        connection.close()
        return status, json.loads(body)

    def test_auth_separation_and_transport_validation(self):
        self.assertEqual(self.request("/handoffs", encoded(handoff()), "m" * 32)[0], 401)
        self.assertEqual(self.request("/mcp", b"{}", "s" * 32)[0], 401)
        self.assertEqual(self.request("/handoffs", encoded(handoff()), "s" * 32)[0], 202)
        self.assertEqual(self.request("/handoffs", b"x" * (MAX_BODY + 1), "s" * 32)[0], 413)
        self.assertEqual(self.request("/handoffs", b"{}", "s" * 32, {"Origin": "https://example.com"})[0], 403)
        self.assertEqual(self.request("/handoffs", b"{}", "s" * 32, {"Content-Type": "text/plain"})[0], 415)

    def test_jsonrpc_errors(self):
        status, body = self.request("/mcp", b"invalid", "m" * 32)
        self.assertEqual(status, 200); self.assertEqual(body["error"]["code"], -32700)
        status, body = self.request("/mcp", encoded({"jsonrpc": "2.0", "id": 1, "method": "unknown"}), "m" * 32)
        self.assertEqual(body["error"]["code"], -32601)
        status, body = self.request("/mcp", encoded({"jsonrpc": "2.0", "id": 1, "method": "events/list"}), "m" * 32)
        self.assertEqual(body["result"]["events"][0]["name"], EVENT)


if __name__ == "__main__":
    unittest.main()
