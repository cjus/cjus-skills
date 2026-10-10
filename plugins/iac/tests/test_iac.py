#!/usr/bin/env python3
"""Offline tests for `scripts/iac.py`, with `gh` faked by `fake_gh.py`.

    python3 plugins/iac/tests/test_iac.py [-v]

Each test builds a world in a temporary directory: a shim named `gh` on PATH that runs
`fake_gh.py`, the fake's state file, and this machine's iac config and local state. It
then runs `iac.py` as a subprocess, exactly as a skill would, so what is tested is the
command line and its output, not internals.

The acceptance items of the branch that `iac.py` alone can show are tested by name:
two sessions completing a request with no message edited or deleted, a retried request
handled once, an agent resuming after its `ack`, rotation refusing while a request is
unfinished, and `status` writing nothing.
"""
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
IAC = HERE.parent / "scripts" / "iac.py"
FAKE = HERE / "fake_gh.py"
REPO = "operator/iac-channels"
TEMPLATE = None   # (fake GitHub state, config text) after Base.setup_channel first runs


class World:
    """One fake GitHub, one machine's iac config and local state."""

    def __init__(self, root: Path):
        self.root = root
        self.bin = root / "bin"
        self.bin.mkdir()
        shim = self.bin / "gh"
        shim.write_text(f'#!/bin/sh\nexec "{sys.executable}" "{FAKE}" "$@"\n')
        shim.chmod(0o755)
        self.state_path = root / "github.json"
        self.write({"login": "operator", "repos": {}, "next_comment": 7000000001, "clock": 0, "faults": []})
        self.env = {
            "PATH": f"{self.bin}{os.pathsep}{os.environ.get('PATH', '')}",
            "HOME": str(root / "home"),
            "IAC_CONFIG": str(root / "config" / "iac.json"),
            "XDG_STATE_HOME": str(root / "state"),
            "FAKE_GH_STATE": str(self.state_path),
        }

    def run(self, *args, agent=None, channel=None, stdin=None, env=None):
        full = dict(self.env)
        if agent:
            full["IAC_AGENT"] = agent
        if channel:
            full["IAC_CHANNEL"] = channel
        full.update(env or {})
        return subprocess.run(
            [sys.executable, str(IAC), *args], env=full, input=stdin, cwd=self.root,
            capture_output=True, text=True, timeout=60,
        )

    def ok(self, *args, **kw):
        p = self.run(*args, **kw)
        if p.returncode != 0:
            raise AssertionError(f"iac.py {' '.join(args)} exited {p.returncode}\n{p.stdout}\n{p.stderr}")
        return p.stdout

    def read(self) -> dict:
        return json.loads(self.state_path.read_text())

    def write(self, state: dict) -> None:
        self.state_path.write_text(json.dumps(state, indent=1))

    def edit(self, fn) -> None:
        s = self.read()
        fn(s)
        self.write(s)

    def repo(self) -> dict:
        return self.read()["repos"][REPO]

    def roster(self) -> dict:
        return json.loads(self.repo()["files"]["roster.json"]["content"])

    def comments(self, issue: int) -> list:
        return self.repo()["issues"][str(issue)]["comments"]

    def messages(self, issue: int) -> list:
        out = []
        for c in self.comments(issue):
            body = c["body"].strip()
            if body.startswith("```"):
                body = body.split("\n", 1)[1].rsplit("```", 1)[0]
            out.append(json.loads(body))
        return out

    def inject(self, issue: int, body: str, login: str = "operator") -> int:
        """Post a comment directly, as another tool or another account would."""
        holder = {}

        def add(s):
            cid = s["next_comment"]
            s["next_comment"] += 1
            s["clock"] += 1
            t = f"2026-01-01T{s['clock'] // 3600:02d}:{s['clock'] // 60 % 60:02d}:{s['clock'] % 60:02d}Z"
            s["repos"][REPO]["issues"][str(issue)]["comments"].append(
                {"id": cid, "user": {"login": login}, "body": body, "created_at": t, "updated_at": t}
            )
            holder["id"] = cid

        self.edit(add)
        return holder["id"]

    def fault(self, method, path, mode, status=None, times=1) -> None:
        self.edit(lambda s: s["faults"].append(
            {"method": method, "path": path, "mode": mode, "status": status, "times": times}))

    def local_state(self, agent: str) -> dict:
        p = self.root / "state" / "iac" / REPO.replace("/", "__") / f"{agent}.json"
        return json.loads(p.read_text()) if p.exists() else {}


def request_id(world, issue, sender, to):
    for c in world.comments(issue):
        body = c["body"].strip().split("\n", 1)[1].rsplit("```", 1)[0] if c["body"].startswith("```") else c["body"]
        d = json.loads(body)
        if d["type"] == "request" and d["from"] == sender and d["to"] == to:
            return c["id"]
    raise AssertionError(f"no request from {sender} to {to}")


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="iac-test-"))
        self.w = World(self.tmp)

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def setup_channel(self):
        """A private repo with a `main` channel and two Claude Code agents plus a dot.

        Built through `iac.py` once, then copied into each test's world, since every
        command costs several `gh` processes and most tests start from this same place.
        """
        global TEMPLATE
        config = Path(self.w.env["IAC_CONFIG"])
        if TEMPLATE is None:
            self.w.ok("init", "--repo", REPO)
            self.w.ok("agent", "add", "laptop", "--kind", "claude-code")
            self.w.ok("agent", "add", "desk", "--kind", "claude-code")
            self.w.ok("agent", "add", "dot", "--kind", "dot")
            self.w.ok("channel", "add", "main")
            TEMPLATE = (self.w.read(), config.read_text())
        else:
            config.parent.mkdir(parents=True, exist_ok=True)
            config.write_text(TEMPLATE[1])
            self.w.write(json.loads(json.dumps(TEMPLATE[0])))
        return self.w.roster()["channels"]["main"]["issue"]


class SetUp(Base):
    def test_init_creates_a_private_repo_with_the_card_and_an_empty_roster(self):
        out = self.w.ok("init", "--repo", REPO)
        repo = self.w.repo()
        self.assertTrue(repo["private"])
        self.assertEqual(repo["files"]["docs/iac-protocol.md"]["content"], (IAC.parent.parent / "reference" / "message.md").read_text())
        self.assertEqual(self.w.roster(), {"channels": {}, "agents": []})
        self.assertEqual(json.loads(Path(self.w.env["IAC_CONFIG"]).read_text()), {"repo": REPO})
        self.assertIn("created, private", out)

    def test_init_again_reuses_everything(self):
        self.w.ok("init", "--repo", REPO)
        self.w.ok("agent", "add", "laptop", "--kind", "claude-code")
        out = self.w.ok("init", "--repo", REPO)
        self.assertIn("reused", out)
        self.assertIn("already current", out)
        self.assertIn("1 agent(s)", out)

    def test_init_refuses_a_public_repo(self):
        self.w.edit(lambda s: s["repos"].update({REPO: {"private": False, "has_issues": True, "files": {}, "issues": {}, "next_issue": 1}}))
        p = self.w.run("init", "--repo", REPO)
        self.assertEqual(p.returncode, 1)
        self.assertIn("is not private", p.stderr)
        self.assertEqual(self.w.repo()["files"], {})

    def test_init_will_not_repoint_a_machine_without_force(self):
        self.w.ok("init", "--repo", REPO)
        p = self.w.run("init", "--repo", "operator/other")
        self.assertEqual(p.returncode, 1)
        self.assertIn("--force", p.stderr)

    def test_every_command_refuses_once_the_repo_is_public(self):
        issue = self.setup_channel()
        self.w.edit(lambda s: s["repos"][REPO].update({"private": False}))
        p = self.w.run("send", "desk", "--body", "hi", agent="laptop")
        self.assertEqual(p.returncode, 1)
        self.assertIn("is not private", p.stderr)
        self.assertEqual(self.w.comments(issue), [])

    def test_no_config_points_at_setup(self):
        p = self.w.run("roster")
        self.assertEqual(p.returncode, 1)
        self.assertIn("/iac:setup", p.stderr)


class Roster(Base):
    def setUp(self):
        super().setUp()
        self.w.ok("init", "--repo", REPO)

    def refused(self, *args):
        p = self.w.run("agent", "add", *args)
        self.assertEqual(p.returncode, 1, p.stdout)
        return p.stderr

    def test_agent_names_kinds_and_fields_are_checked(self):
        self.assertIn("lowercase letters", self.refused("Laptop", "--kind", "claude-code"))
        self.assertIn("needs `model`", self.refused("gemma", "--kind", "ollama", "--endpoint", "http://localhost:11434"))
        self.assertIn("explicit port", self.refused("gemma", "--kind", "ollama", "--endpoint", "http://localhost", "--model", "m"))
        self.assertIn("credentials", self.refused("gemma", "--kind", "ollama", "--endpoint", "http://u:p@localhost:11434", "--model", "m"))
        self.assertIn("takes no `endpoint`", self.refused("dot", "--kind", "dot", "--endpoint", "http://localhost:1"))
        self.assertEqual(self.w.roster()["agents"], [])

    def test_a_name_is_used_once(self):
        self.w.ok("agent", "add", "laptop", "--kind", "claude-code")
        self.assertIn("already in the roster", self.refused("laptop", "--kind", "claude-code"))

    def test_adding_states_the_cost_and_warns_off_machine(self):
        out = self.w.ok("agent", "add", "qwen", "--kind", "openai-compatible",
                        "--endpoint", "http://10.0.0.5:1234/v1", "--model", "qwen3")
        self.assertIn("tier C", out)
        self.assertIn("a remote server may charge", out)
        self.assertEqual(self.w.roster()["agents"][0]["endpoint"], "http://10.0.0.5:1234/v1")

    def test_a_stale_roster_write_is_retried_not_lost(self):
        self.w.fault("PUT", r"contents/roster\.json", "refuse", status=409)
        self.w.ok("agent", "add", "laptop", "--kind", "claude-code")
        self.assertEqual([a["name"] for a in self.w.roster()["agents"]], ["laptop"])
        puts = [c for c in self.w.read()["calls"] if c[0] == "PUT" and "roster.json" in c[1]]
        self.assertEqual(len(puts), 3)  # init's, the refused one, and the retry

    def test_a_roster_that_will_not_parse_stops_every_reader(self):
        self.w.edit(lambda s: s["repos"][REPO]["files"]["roster.json"].update({"content": "{nope"}))
        p = self.w.run("roster")
        self.assertEqual(p.returncode, 1)
        self.assertIn("won't parse", p.stderr)

    def test_remove(self):
        self.w.ok("agent", "add", "laptop", "--kind", "claude-code")
        self.w.ok("agent", "remove", "laptop")
        self.assertEqual(self.w.roster()["agents"], [])

    def test_channel_add_opens_an_issue_and_records_it(self):
        out = self.w.ok("channel", "add", "pr")
        n = self.w.roster()["channels"]["pr"]["issue"]
        self.assertEqual(self.w.repo()["issues"][str(n)]["title"], "iac:pr")
        self.assertIn(f"#{n}", out)
        p = self.w.run("channel", "add", "pr")
        self.assertEqual(p.returncode, 1)


class Messaging(Base):
    def setUp(self):
        super().setUp()
        self.issue = self.setup_channel()

    def test_two_sessions_complete_a_request_and_nothing_is_edited_or_deleted(self):
        """Acceptance: two Claude Code sessions complete a request, ack and reply on one channel."""
        self.w.ok("send", "desk", "--body", "Review the plan.", agent="laptop")
        rid = request_id(self.w, self.issue, "laptop", "desk")
        inbox = self.w.ok("inbox", agent="desk")
        self.assertIn(f"request {rid} from laptop is pending", inbox)
        self.assertIn("Review the plan.", inbox)

        self.w.ok("ack", str(rid), agent="desk")
        received = json.loads(self.w.ok("status", "--json", agent="laptop"))["channels"]["main"]["requests"]["received"]
        self.assertEqual([r["comment_id"] for r in received], [rid])
        self.w.ok("reply", str(rid), "--status", "done", "--body", "Two risks.", agent="desk")

        heard = self.w.ok("inbox", agent="laptop")
        self.assertIn("reply", heard)
        self.assertIn("done", heard)
        self.assertIn("nothing for desk", self.w.ok("inbox", agent="desk"))

        types = [m["type"] for m in self.w.messages(self.issue)]
        self.assertEqual(types, ["request", "ack", "reply"])
        for c in self.w.comments(self.issue):
            self.assertEqual(c["created_at"], c["updated_at"])
        writes = [c for c in self.w.read()["calls"] if "/comments" in c[1] and c[0] not in ("GET", "POST")]
        self.assertEqual(writes, [])

    def test_a_request_gets_one_reply_and_one_ack(self):
        self.w.ok("send", "desk", "--body", "x", agent="laptop")
        rid = request_id(self.w, self.issue, "laptop", "desk")
        self.w.ok("ack", str(rid), agent="desk")
        self.assertIn("already acknowledged", self.w.ok("ack", str(rid), agent="desk"))
        self.w.ok("reply", str(rid), "--status", "done", "--body", "ok", agent="desk")
        p = self.w.run("reply", str(rid), "--status", "done", "--body", "again", agent="desk")
        self.assertEqual(p.returncode, 1)
        self.assertIn("handled once", p.stderr)
        self.assertEqual(len(self.w.comments(self.issue)), 3)

    def test_only_the_recipient_answers(self):
        self.w.ok("send", "desk", "--body", "x", agent="laptop")
        rid = request_id(self.w, self.issue, "laptop", "desk")
        p = self.w.run("reply", str(rid), "--status", "done", "--body", "x", agent="laptop")
        self.assertEqual(p.returncode, 1)
        self.assertIn("addressed to desk", p.stderr)

    def test_a_retried_request_with_the_same_key_is_handled_once(self):
        """Acceptance: a retried request, posted again with the same key, is handled once."""
        key = "11111111-2222-4333-8444-555555555555"
        self.w.ok("send", "desk", "--body", "Do it.", "--key", key, agent="laptop")
        again = self.w.ok("send", "desk", "--body", "Do it.", "--key", key, agent="laptop")
        self.assertIn("already landed", again)
        self.assertEqual(len(self.w.comments(self.issue)), 1)

        # A retry after a lost response does land a second copy. It is the same request.
        first = request_id(self.w, self.issue, "laptop", "desk")
        copy = self.w.inject(self.issue, self.w.comments(self.issue)[0]["body"])
        inbox = self.w.ok("inbox", "--json", agent="desk")
        self.assertEqual([i["comment_id"] for i in json.loads(inbox)["items"]], [first])

        self.w.ok("reply", str(copy), "--status", "done", "--body", "Done once.", agent="desk")
        replies = [m for m in self.w.messages(self.issue) if m["type"] == "reply"]
        self.assertEqual(len(replies), 1)
        self.assertEqual(replies[0]["reply_to"], first)
        p = self.w.run("reply", str(first), "--status", "done", "--body", "Twice?", agent="desk")
        self.assertEqual(p.returncode, 1)
        self.assertIn("nothing for desk", self.w.ok("inbox", agent="desk"))

    def test_a_key_reused_for_a_different_request_is_refused(self):
        key = "k-1"
        self.w.ok("send", "desk", "--body", "one", "--key", key, agent="laptop")
        p = self.w.run("send", "desk", "--body", "two", "--key", key, agent="laptop")
        self.assertEqual(p.returncode, 1)
        self.assertIn("different", p.stderr)

    def test_a_lost_response_does_not_post_twice(self):
        self.w.fault("POST", r"/comments$", "lost")
        out = self.w.ok("send", "desk", "--body", "x", agent="laptop")
        self.assertIn("sent request", out)
        self.assertEqual(len(self.w.comments(self.issue)), 1)

    def test_an_agent_that_stops_after_its_ack_resumes_instead_of_skipping(self):
        """Acceptance: an agent that stops after its ack resumes the request after a restart."""
        self.w.ok("send", "desk", "--body", "Slow work.", agent="laptop")
        rid = request_id(self.w, self.issue, "laptop", "desk")
        self.w.ok("ack", str(rid), agent="desk")
        # A restart is a new process with nothing in memory.
        inbox = json.loads(self.w.ok("inbox", "--json", agent="desk"))
        self.assertEqual(len(inbox["items"]), 1)
        it = inbox["items"][0]
        self.assertEqual(it["state"], "received")
        self.assertIn("has no reply", it["text"])
        self.w.ok("reply", str(rid), "--status", "done", "--body", "Finished.", agent="desk")
        self.assertEqual([m["type"] for m in self.w.messages(self.issue)], ["request", "ack", "reply"])

    def test_a_reply_that_fails_to_post_is_saved_and_posted_by_the_next_inbox(self):
        self.w.ok("send", "desk", "--body", "x", agent="laptop")
        rid = request_id(self.w, self.issue, "laptop", "desk")
        self.w.fault("POST", r"/comments$", "down", times=3)
        p = self.w.run("reply", str(rid), "--status", "done", "--body", "Saved.", agent="desk")
        self.assertEqual(p.returncode, 1)
        self.assertIn("saved locally", p.stderr)
        self.assertEqual(len(self.w.local_state("desk")["outbox"]), 1)
        self.assertEqual(len(self.w.comments(self.issue)), 1)

        out = self.w.ok("inbox", agent="desk")
        self.assertIn("posted the saved reply", out)
        self.assertEqual(self.w.local_state("desk")["outbox"], [])
        replies = [m for m in self.w.messages(self.issue) if m["type"] == "reply"]
        self.assertEqual([r["body"] for r in replies], ["Saved."])

    def test_a_saved_reply_github_refuses_stays_saved_and_does_not_block_inbox(self):
        self.w.ok("send", "desk", "--body", "x", agent="laptop")
        rid = request_id(self.w, self.issue, "laptop", "desk")
        self.w.fault("POST", r"/comments$", "down", times=3)
        self.w.run("reply", str(rid), "--status", "done", "--body", "Saved.", agent="desk")
        self.w.ok("send", "desk", "--body", "second", agent="laptop")
        self.w.fault("POST", r"/comments$", "refuse", status=422)
        out = self.w.ok("inbox", agent="desk")
        self.assertIn("still can't post", out)
        self.assertIn("second", out)
        self.assertEqual(len(self.w.local_state("desk")["outbox"]), 1)

    def test_notices_reach_everyone_but_their_sender(self):
        self.w.ok("notice", "*", "--body", "Rotating soon.", agent="laptop")
        self.assertIn("notice", self.w.ok("inbox", agent="desk"))
        self.assertIn("nothing for laptop", self.w.ok("inbox", agent="laptop"))
        self.assertIn("nothing for desk", self.w.ok("inbox", agent="desk"))

    def test_a_name_outside_the_roster_neither_sends_nor_receives(self):
        p = self.w.run("send", "desk", "--body", "x", agent="stranger")
        self.assertEqual(p.returncode, 1)
        self.assertIn("not in the roster", p.stderr)
        p = self.w.run("send", "nobody", "--body", "x", agent="laptop")
        self.assertEqual(p.returncode, 1)
        p = self.w.run("send", "desk", "--body", "x", agent="dot")
        self.assertEqual(p.returncode, 1)
        self.assertIn("tier B", p.stderr)
        self.assertEqual(self.w.comments(self.issue), [])

    def test_a_closed_channel_takes_no_posts(self):
        self.w.edit(lambda s: s["repos"][REPO]["issues"][str(self.issue)].update({"state": "closed"}))
        p = self.w.run("send", "desk", "--body", "x", agent="laptop")
        self.assertEqual(p.returncode, 1)
        self.assertIn("closed", p.stderr)

    def test_a_body_too_long_for_one_comment_is_refused(self):
        p = self.w.run("send", "desk", "--body-file", "-", agent="laptop", stdin="x" * 70000)
        self.assertEqual(p.returncode, 1)
        self.assertIn("65,536", p.stderr)


class Reading(Base):
    def setUp(self):
        super().setUp()
        self.issue = self.setup_channel()

    def msg(self, **kw):
        d = {"v": 1, "key": "k", "from": "laptop", "to": "desk", "type": "request", "reply_to": None, "body": "b"}
        d.update(kw)
        return json.dumps(d)

    def test_what_counts_as_a_message(self):
        unfenced = self.w.inject(self.issue, self.msg(key="plain"))
        foreign = self.w.inject(self.issue, self.msg(key="foreign"), login="someone-else")
        prose = self.w.inject(self.issue, "Hi! " + self.msg(key="prose"))
        future = self.w.inject(self.issue, self.msg(key="future", v=2))
        broadcast = self.w.inject(self.issue, self.msg(key="star", to="*"))
        status = json.loads(self.w.ok("status", "--json"))
        main = status["channels"]["main"]
        self.assertEqual([r["comment_id"] for r in main["requests"]["pending"]], [unfenced])
        skipped = {s["comment_id"]: s["reason"] for s in main["skipped"]}
        self.assertEqual(set(skipped), {foreign, prose, future, broadcast})
        self.assertIn("not the operator", skipped[foreign])
        self.assertIn("isn't one JSON object", skipped[prose])
        self.assertIn("doesn't know", skipped[future])
        self.assertIn("only a notice", skipped[broadcast])

    def test_status_writes_nothing(self):
        """Acceptance: /iac:status writes nothing."""
        self.w.ok("send", "desk", "--body", "x", agent="laptop")
        rid = request_id(self.w, self.issue, "laptop", "desk")
        self.w.ok("ack", str(rid), agent="desk")
        before = self.w.read()
        files_before = sorted(str(p) for p in (self.tmp / "state").rglob("*"))
        calls_before = len(before["calls"])
        for agent in ("desk", "laptop", None):
            self.w.ok("status", agent=agent)
            self.w.ok("status", "--json", agent=agent)
        after = self.w.read()
        new_calls = after["calls"][calls_before:]
        self.assertTrue(new_calls)
        self.assertEqual([c for c in new_calls if c[0] != "GET"], [])
        before.pop("calls")
        after.pop("calls")
        self.assertEqual(before, after)
        self.assertEqual(files_before, sorted(str(p) for p in (self.tmp / "state").rglob("*")))

    def test_status_reports_edits_and_unknown_names(self):
        cid = self.w.inject(self.issue, self.msg(key="e", to="ghost"))
        self.w.edit(lambda s: s["repos"][REPO]["issues"][str(self.issue)]["comments"][0].update({"updated_at": "2027-01-01T00:00:00Z"}))
        warnings = json.loads(self.w.ok("status", "--json"))["channels"]["main"]["warnings"]
        self.assertTrue(any("was edited" in w for w in warnings))
        self.assertTrue(any(f"comment {cid}" in w and "ghost" in w for w in warnings))


class Rotation(Base):
    def setUp(self):
        super().setUp()
        self.issue = self.setup_channel()

    def test_rotate_refuses_while_a_request_is_pending_or_received(self):
        """Acceptance: iac.py channel rotate refuses while a request is pending or received."""
        self.w.ok("send", "desk", "--body", "x", agent="laptop")
        rid = request_id(self.w, self.issue, "laptop", "desk")
        p = self.w.run("channel", "rotate", "main")
        self.assertEqual(p.returncode, 1)
        self.assertIn("pending", p.stderr)
        self.w.ok("ack", str(rid), agent="desk")
        p = self.w.run("channel", "rotate", "main")
        self.assertEqual(p.returncode, 1)
        self.assertIn("received", p.stderr)
        self.assertEqual(self.w.roster()["channels"]["main"]["issue"], self.issue)

        self.w.ok("reply", str(rid), "--status", "done", "--body", "ok", agent="desk")
        self.w.ok("channel", "rotate", "main")
        new = self.w.roster()["channels"]["main"]["issue"]
        self.assertNotEqual(new, self.issue)
        self.assertEqual(self.w.repo()["issues"][str(self.issue)]["state"], "closed")
        self.assertIn(f"Continues #{self.issue}", self.w.repo()["issues"][str(new)]["body"])
        self.w.ok("send", "desk", "--body", "on the new issue", agent="laptop")
        self.assertEqual(len(self.w.comments(new)), 1)


class Waiting(Base):
    def setUp(self):
        super().setUp()
        self.issue = self.setup_channel()

    def test_wait_returns_at_once_for_a_pending_request(self):
        self.w.ok("send", "desk", "--body", "x", agent="laptop")
        t = time.monotonic()
        out = self.w.ok("wait", "--timeout", "30", agent="desk")
        self.assertLess(time.monotonic() - t, 10)
        self.assertIn("pending", out)

    def test_wait_ignores_its_own_work_in_progress_and_times_out(self):
        self.w.ok("send", "desk", "--body", "x", agent="laptop")
        rid = request_id(self.w, self.issue, "laptop", "desk")
        self.w.ok("ack", str(rid), agent="desk")
        self.w.ok("inbox", agent="desk")
        p = self.w.run("wait", "--timeout", "1", agent="desk")
        self.assertEqual(p.returncode, 3, p.stdout + p.stderr)

    def test_wait_wakes_when_a_request_arrives(self):
        proc = subprocess.Popen(
            [sys.executable, str(IAC), "wait", "--timeout", "40", "--json"],
            env={**self.w.env, "IAC_AGENT": "desk"}, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
        )
        time.sleep(2)
        body = json.dumps({"v": 1, "key": "w", "from": "laptop", "to": "desk", "type": "request", "reply_to": None, "body": "wake"})
        cid = self.w.inject(self.issue, body)
        out, err = proc.communicate(timeout=60)
        self.assertEqual(proc.returncode, 0, err)
        self.assertEqual([i["comment_id"] for i in json.loads(out)["items"]], [cid])


class Detection(Base):
    # Port 9 is discard: nothing answers there, so no test depends on what this machine runs.
    NOTHING = {"OLLAMA_HOST": "http://127.0.0.1:9"}

    def test_detect_reports_a_key_without_printing_it(self):
        out = self.w.ok("detect", env={**self.NOTHING, "IAC_OPENROUTER_API_KEY": "sk-or-secret-123"})
        self.assertIn("logged in as operator", out)
        self.assertIn("(absent)", out)
        self.assertIn("http://127.0.0.1:9 (from $OLLAMA_HOST): not answering", out)
        self.assertIn("IAC_OPENROUTER_API_KEY present, from the environment", out)
        self.assertNotIn("sk-or-secret-123", out)

    def test_detect_finds_the_key_in_the_per_user_file(self):
        conf = self.tmp / "xdg"
        (conf / "iac").mkdir(parents=True)
        (conf / "iac" / ".env").write_text('# iac\nexport IAC_OPENROUTER_API_KEY="sk-or-file"\n')
        found = json.loads(self.w.ok("detect", "--json", env={**self.NOTHING, "XDG_CONFIG_HOME": str(conf)}))
        self.assertIn(str(conf / "iac" / ".env"), found["openrouter"])
        self.assertNotIn("sk-or-file", json.dumps(found))

    def test_detect_never_takes_openrouter_api_key(self):
        found = json.loads(self.w.ok("detect", "--json", env={**self.NOTHING, "OPENROUTER_API_KEY": "sk-or-app"}))
        self.assertIn("IAC_OPENROUTER_API_KEY absent", found["openrouter"])
        self.assertIn("iac never reads it", found["openrouter"])

    def test_detect_reports_the_repo_once_set_up(self):
        self.setup_channel()
        found = json.loads(self.w.ok("detect", "--json", env=self.NOTHING))
        self.assertEqual(found["repo"], f"{REPO} (private): 1 channel(s), 3 agent(s)")


class Joining(Base):
    def setUp(self):
        super().setUp()
        self.issue = self.setup_channel()

    def test_a_claude_code_agent_gets_its_launch_line(self):
        out = self.w.ok("join", "laptop")
        self.assertIn("IAC_AGENT=laptop IAC_CHANNEL=main claude", out)
        self.assertIn('"IAC_AGENT": "laptop"', out)

    def test_a_dot_gets_the_brief(self):
        out = self.w.ok("join", "dot")
        self.assertIn(f"grant its GitHub connector access to {REPO}", out)
        self.assertIn(f"`main`: issue #{self.issue}", out)
        self.assertIn("docs/iac-protocol.md", out)
        self.assertIn("personal details", out)

    def test_a_driven_model_gets_its_runner_command(self):
        self.w.ok("agent", "add", "gemma", "--kind", "ollama", "--endpoint", "http://localhost:11434", "--model", "gemma4")
        out = self.w.ok("join", "gemma")
        self.assertIn("run --agent gemma --channel main", out)
        self.assertIn("costs nothing; local or LAN", out)

    def test_an_unknown_agent_is_refused(self):
        p = self.w.run("join", "ghost")
        self.assertEqual(p.returncode, 1)
        self.assertIn("not in the roster", p.stderr)


class Gh(unittest.TestCase):
    """The `gh` wrapper itself, imported, against the fake."""

    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location("iac", IAC)
        cls.iac = importlib.util.module_from_spec(spec)
        sys.modules["iac"] = cls.iac   # dataclasses look their module up here
        spec.loader.exec_module(cls.iac)

    def test_ollama_host_gets_a_port_only_when_it_has_no_scheme(self):
        old = os.environ.get("OLLAMA_HOST")
        try:
            cases = {
                "gpu-box": "http://gpu-box:11434",
                "gpu-box:11500": "http://gpu-box:11500",
                "http://gpu-box": "http://gpu-box",
                "0.0.0.0": "http://localhost:11434",
                "https://ollama.example:8443": "https://ollama.example:8443",
            }
            for raw, want in cases.items():
                os.environ["OLLAMA_HOST"] = raw
                self.assertEqual(self.iac.ollama_default()[0], want, raw)
        finally:
            if old is None:
                os.environ.pop("OLLAMA_HOST", None)
            else:
                os.environ["OLLAMA_HOST"] = old

    def test_split_response_handles_ghs_mixed_line_endings(self):
        status, hdrs, body = self.iac.split_response('HTTP/2.0 200 OK\nEtag: W/"x"\r\nA: b\r\n\r\n[1]')
        self.assertEqual((status, hdrs["etag"], body), (200, 'W/"x"', "[1]"))
        self.assertEqual(self.iac.split_response("")[0], None)

    def test_an_unchanged_channel_answers_304(self):
        tmp = Path(tempfile.mkdtemp(prefix="iac-test-"))
        try:
            w = World(tmp)
            w.ok("init", "--repo", REPO)
            w.ok("channel", "add", "main")
            old = dict(os.environ)
            os.environ.update(w.env)
            try:
                path = f"repos/{REPO}/issues/1/comments?per_page=100"
                status, hdrs, _ = self.iac.gh("GET", path)
                self.assertEqual(status, 200)
                status, _, data = self.iac.gh("GET", path, headers=[f"If-None-Match: {hdrs['etag']}"])
                self.assertEqual((status, data), (304, None))
            finally:
                os.environ.clear()
                os.environ.update(old)
        finally:
            shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    unittest.main()
