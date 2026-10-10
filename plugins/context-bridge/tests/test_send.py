import importlib.util
import io
import json
from pathlib import Path
import unittest
import urllib.error

spec = importlib.util.spec_from_file_location("send", Path(__file__).parents[1] / "scripts/send.py")
send = importlib.util.module_from_spec(spec)
spec.loader.exec_module(send)


def handoff():
    return dict(schema_version=1, id="00000000-0000-4000-8000-000000000001", project="demo", recorded_at="2026-10-10T12:00:00Z", summary="Completed a mock integration.", decisions=[], pending_items=["Review the draft"], source_links=["https://example.com/demo"])


class Response(io.BytesIO):
    status = 202


class Opener:
    def open(self, request, timeout):
        self.request, self.timeout = request, timeout
        payload = json.loads(request.data)
        return Response(json.dumps({"id": payload["id"], "status": "accepted"}).encode())


class SenderTests(unittest.TestCase):
    def test_valid(self):
        self.assertEqual(json.loads(send.validate(handoff())), handoff())

    def test_rejects_invalid_fields(self):
        for key, value in [("schema_version", True), ("id", "bad"), ("recorded_at", "2026-10-10"), ("project", ""), ("summary", "x"*16001), ("decisions", "bad"), ("pending_items", [""]*51), ("source_links", ["https://user:secret@example.com/"])]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                send.validate({**handoff(), key: value})
        with self.assertRaises(ValueError):
            send.validate({**handoff(), "extra": 1})

    def test_byte_size_not_character_size(self):
        with self.assertRaises(ValueError):
            send.validate({**handoff(), "summary": "\U0001f600"*16000, "decisions": ["x"*2000]})

    def test_destination(self):
        for base in ["http://example.com", "https://user:secret@example.com", "https://example.com/a", "https://example.com?token=secret", "https://example.com#fragment", ""]:
            with self.subTest(base=base), self.assertRaises(ValueError):
                send.endpoint(base)
        self.assertEqual(send.endpoint("https://example.com/"), "https://example.com/handoffs")

    def test_send_acceptance_only(self):
        opener = Opener()
        result = send.send(handoff(), {"CONTEXT_BRIDGE_URL": "https://example.com", "CONTEXT_BRIDGE_TOKEN": "test-only-token"}, opener)
        self.assertEqual(result["status"], "accepted")
        self.assertIn("not confirmed", result["note"])
        self.assertEqual(opener.request.get_header("Authorization"), "Bearer test-only-token")
        self.assertEqual(opener.timeout, 15)

    def test_no_redirect(self):
        self.assertIsNone(send.NoRedirect().redirect_request(None, None, 302, "", {}, "https://other.example"))

    def test_bad_token(self):
        with self.assertRaises(ValueError):
            send.send(handoff(), {"CONTEXT_BRIDGE_URL": "https://example.com", "CONTEXT_BRIDGE_TOKEN": "bad\nvalue"}, Opener())

    def test_uncertain_receipt_redacts_error(self):
        class FailingOpener:
            def open(self, *args, **kwargs):
                raise urllib.error.URLError("secret URL or token")
        with self.assertRaises(ValueError) as result:
            send.send(handoff(), {"CONTEXT_BRIDGE_URL": "https://example.com", "CONTEXT_BRIDGE_TOKEN": "test-only-token"}, FailingOpener())
        self.assertNotIn("secret", str(result.exception))
        self.assertIn("uncertain", str(result.exception))

    def test_mismatched_receipt(self):
        class WrongOpener:
            def open(self, *args, **kwargs):
                return Response(b'{"id":"other","status":"accepted"}')
        with self.assertRaises(ValueError):
            send.send(handoff(), {"CONTEXT_BRIDGE_URL": "https://example.com", "CONTEXT_BRIDGE_TOKEN": "test-only-token"}, WrongOpener())

if __name__ == "__main__":
    unittest.main()
