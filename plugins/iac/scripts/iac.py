#!/usr/bin/env python3
"""The tier A side of the iac protocol, and the commands that set a channel repo up.

    iac.py init --repo <owner>/<name> [--force]
    iac.py channel add <name>
    iac.py channel rotate <name>
    iac.py agent add <name> --kind <kind> [--endpoint <url>] [--model <id>]
    iac.py agent remove <name>
    iac.py roster [--json]
    iac.py send <to> (--body-file <path> | --body <text>) [--key <key>] [--channel <name>] [--json]
    iac.py notice <to|*> (--body-file <path> | --body <text>) [--channel <name>]
    iac.py inbox [--channel <name>] [--json]
    iac.py ack <request-comment-id> [--channel <name>]
    iac.py reply <request-comment-id> --status done|failed|blocked
                 (--body-file <path> | --body <text>) [--channel <name>]
    iac.py wait [--channel <name>] [--interval <seconds>] [--timeout <seconds>] [--json]
    iac.py status [--channel <name>] [--json]

`reference/message.md` is the protocol this implements. `reference/roster.md`,
`reference/trust-boundary.md` and `reference/participants.md` say why it is shaped the
way it is, and this file cites them rather than repeating them.

Every GitHub call goes through `gh api` on the operator's existing `gh` login, and every
message is built with `json.dumps`. Python's standard library only.

**The channel is the source of truth.** A request's state is derived on every read from
the messages that follow it, so nothing local can disagree with what every other agent
sees. The local state file, under `$XDG_STATE_HOME/iac/`, holds only what the channel
can't show: the `from`/`key` pairs this agent has replied to, and an outbox. A reply is
saved to the outbox before it is posted, so a crash between finishing the work and
posting the reply loses nothing: the next `inbox` posts the saved reply.

**`status` writes nothing,** not to GitHub and not to local state, so it is safe to run
at any moment, including while another command is partway through.

A tier A session is `IAC_AGENT`, which must be a tier A agent in the roster. Its channel
is `--channel`, else `IAC_CHANNEL`, else the roster's only channel when it has just one.

Exits 0 on success, 1 when a command is refused or GitHub fails, 2 on bad usage, and 3
when `wait` times out with nothing for this agent.
"""
from __future__ import annotations

import argparse
import base64
import json
import os
import re
import subprocess
import sys
import time
import uuid
from dataclasses import dataclass, field
from pathlib import Path
from urllib.parse import urlsplit

VERSION = 1
TYPES = ("request", "ack", "reply", "notice")
STATUSES = ("done", "failed", "blocked")

# Each kind's tier and cost. participants.md is the prose behind both tables.
KINDS = {
    "claude-code": "A",
    "dot": "B",
    "codex": "C",
    "ollama": "C",
    "openai-compatible": "C",
    "openrouter": "C",
}
COST = {
    "claude-code": "the session's own quota",
    "dot": "the operator's ChatGPT plan",
    "codex": "the operator's ChatGPT plan, or API token rates when Codex is logged in with an API key",
    "ollama": "nothing; local or LAN",
    "openai-compatible": "nothing on this machine; a remote server may charge",
    "openrouter": "per token, against the operator's OpenRouter credit",
}
NEEDS = {
    "ollama": ("endpoint", "model"),
    "openai-compatible": ("endpoint", "model"),
    "openrouter": ("model",),
}
TAKES_ENDPOINT = ("ollama", "openai-compatible")

NAME = re.compile(r"[a-z0-9][a-z0-9-]*\Z")
REPO = re.compile(r"[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9._-]+\Z")
SECRET_FIELD = re.compile(r"key|token|secret|password", re.I)
FENCE = re.compile(r"\A```(?:json)?[ \t]*\n(.*?)\n[ \t]*```\Z", re.S)

COMMENT_LIMIT = 65536      # GitHub's cap on one comment, in characters
PAGE = 100                 # GitHub's largest page
HANDLED_KEEP = 2000        # handled pairs kept locally; rotation keeps channels shorter
MIN_INTERVAL = 10          # seconds; `wait` polls no faster than this

CARD = Path(__file__).resolve().parent.parent / "reference" / "message.md"
CARD_PATH = "docs/iac-protocol.md"
ROSTER_PATH = "roster.json"
CHANNEL_BODY = (
    "An iac channel. Each comment on this issue is one JSON message, and "
    "`docs/iac-protocol.md` in this repo is the protocol. Never edit or delete a comment."
)


class Refused(Exception):
    """A command that can't go ahead. main() prints the reason and exits 1."""


class GhError(Exception):
    """A `gh api` call that failed. `status` is None when GitHub never answered."""

    def __init__(self, status: int | None, message: str):
        super().__init__(message)
        self.status = status


# ── gh ──────────────────────────────────────────────────────────────────────────


def gh(method: str, path: str, body=None, headers=()):
    """Make one `gh api` call and return (status, headers, parsed JSON or None).

    `-i` is always passed. gh exits 1 on a 304 exactly as it does on a failure, so the
    status line it prints is the only way to tell an unchanged channel from an error.
    A JSON body goes on stdin, never into an argument.
    """
    args = ["gh", "api", "-i", "-X", method, path]
    for h in headers:
        args += ["-H", h]
    stdin = None
    if body is not None:
        args += ["--input", "-"]
        stdin = json.dumps(body)
    try:
        proc = subprocess.run(args, input=stdin, capture_output=True, text=True)
    except FileNotFoundError:
        raise Refused("gh is not installed, and iac makes every GitHub call through `gh api`.")
    status, hdrs, text = split_response(proc.stdout)
    if status is None:
        raise GhError(None, proc.stderr.strip() or f"no response to {method} {path}")
    data = None
    if text.strip():
        try:
            data = json.loads(text)
        except json.JSONDecodeError:
            data = None
    if status >= 400:
        detail = data.get("message") if isinstance(data, dict) else None
        raise GhError(status, f"HTTP {status} from {method} {path}: {detail or proc.stderr.strip()}")
    return status, hdrs, data


def split_response(out: str):
    """Split `gh api -i` output into (status, lowercased headers, body)."""
    head, sep, body = out.partition("\r\n\r\n")
    if not sep:
        head, sep, body = out.partition("\n\n")
    lines = head.splitlines()
    m = re.match(r"HTTP/\S+\s+(\d{3})", lines[0]) if lines else None
    if not m:
        return None, {}, ""
    hdrs = {}
    for line in lines[1:]:
        k, _, v = line.partition(":")
        hdrs[k.strip().lower()] = v.strip()
    return int(m.group(1)), hdrs, body


class Repo:
    """The operator's channel repo, as this machine's `gh` login sees it."""

    def __init__(self, name: str):
        self.name = name
        self._login = None
        self.meta = None

    def login(self) -> str:
        """The operator's login: the account `gh` is logged in as, which every agent posts as."""
        if self._login is None:
            try:
                _, _, data = gh("GET", "user")
            except GhError as e:
                raise Refused(f"gh can't reach GitHub as a logged-in user ({e}). Run `gh auth login`.")
            self._login = data["login"]
        return self._login

    def check(self) -> None:
        """Refuse a channel repo that isn't private: trust-boundary.md § What GitHub authenticates."""
        if self.meta is not None:
            return
        try:
            _, _, data = gh("GET", f"repos/{self.name}")
        except GhError as e:
            if e.status == 404:
                raise Refused(f"{self.name} doesn't exist, or this gh login can't see it.")
            raise
        if not data.get("private"):
            raise Refused(
                f"{self.name} is not private. iac refuses to read from or post to a public "
                "channel repo, because every message on it would be public."
            )
        if not data.get("has_issues", True):
            raise Refused(f"{self.name} has issues turned off, and every channel is an issue.")
        self.meta = data


def get_file(repo: str, path: str):
    """Return (text, sha), or (None, None) when the file doesn't exist."""
    try:
        _, _, data = gh("GET", f"repos/{repo}/contents/{path}")
    except GhError as e:
        if e.status == 404:
            return None, None
        raise
    return base64.b64decode(data["content"]).decode("utf-8"), data["sha"]


def put_file(repo: str, path: str, text: str, message: str, sha: str | None = None) -> None:
    body = {"message": message, "content": base64.b64encode(text.encode("utf-8")).decode("ascii")}
    if sha:
        body["sha"] = sha
    gh("PUT", f"repos/{repo}/contents/{path}", body)


def issue_meta(repo: str, number: int) -> dict:
    _, _, data = gh("GET", f"repos/{repo}/issues/{number}")
    return data


def create_issue(repo: str, title: str, body: str) -> int:
    _, _, data = gh("POST", f"repos/{repo}/issues", {"title": title, "body": body})
    return data["number"]


def find_open_issue(repo: str, title: str) -> int | None:
    page = 1
    while True:
        _, _, data = gh("GET", f"repos/{repo}/issues?state=open&per_page={PAGE}&page={page}")
        for issue in data or []:
            if issue.get("title") == title and "pull_request" not in issue:
                return issue["number"]
        if len(data or []) < PAGE:
            return None
        page += 1


def list_comments(repo: str, issue: int, since: str | None = None) -> list:
    """Every comment on the issue, in ascending comment-ID order: message.md § Identifiers."""
    out, page = [], 1
    while True:
        query = f"per_page={PAGE}&page={page}" + (f"&since={since}" if since else "")
        _, _, data = gh("GET", f"repos/{repo}/issues/{issue}/comments?{query}")
        out += data or []
        if len(data or []) < PAGE:
            break
        page += 1
    return sorted(out, key=lambda c: c["id"])


# ── the local config and the roster ─────────────────────────────────────────────


def config_path() -> Path:
    """The one place the local config's path is resolved: roster.md § The local config."""
    if os.environ.get("IAC_CONFIG"):
        return Path(os.environ["IAC_CONFIG"]).expanduser()
    base = os.environ.get("XDG_CONFIG_HOME") or str(Path.home() / ".config")
    return Path(base) / "iac" / "config.json"


def read_config() -> str:
    p = config_path()
    if not p.exists():
        raise Refused(f"no iac config at {p}. Run /iac:setup, or `iac.py init --repo <owner>/<name>`.")
    try:
        cfg = json.loads(p.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as e:
        raise Refused(f"{p} can't be read as JSON: {e}")
    repo = cfg.get("repo") if isinstance(cfg, dict) else None
    if not isinstance(repo, str) or not REPO.match(repo):
        raise Refused(f'{p} must name the channel repo, as {{"repo": "<owner>/<name>"}}.')
    return repo


def write_config(repo: str) -> Path:
    p = config_path()
    p.parent.mkdir(parents=True, exist_ok=True)
    tmp = p.with_name(p.name + ".tmp")
    tmp.write_text(json.dumps({"repo": repo}, indent=2) + "\n", encoding="utf-8")
    os.replace(tmp, p)
    return p


def dump_roster(roster: dict) -> str:
    return json.dumps(roster, indent=2) + "\n"


def endpoint_problem(url: str) -> str | None:
    u = urlsplit(url)
    if u.scheme not in ("http", "https") or not u.hostname:
        return f"endpoint {url!r} needs a scheme and a host, such as http://localhost:11434"
    if u.username or u.password:
        return "the endpoint carries credentials, and every tier B agent's vendor reads the roster"
    try:
        port = u.port
    except ValueError:
        return f"endpoint {url!r} has an invalid port"
    if port is None:
        default = 80 if u.scheme == "http" else 443
        return f"endpoint {url!r} needs an explicit port; with none, {u.scheme}:// goes to :{default}"
    return None


def is_loopback(url: str) -> bool:
    host = (urlsplit(url).hostname or "").lower()
    return host == "localhost" or host == "::1" or host.startswith("127.")


def roster_problems(r) -> list:
    """Everything wrong with a roster, as sentences. Empty means it is valid."""
    if not isinstance(r, dict):
        return ["the roster is not a JSON object"]
    out = []
    channels = r.get("channels")
    if not isinstance(channels, dict):
        out.append('`channels` must be an object mapping each name to {"issue": <number>}')
    else:
        for name, c in channels.items():
            if not NAME.match(name):
                out.append(f"channel {name!r}: a name is lowercase letters, digits and hyphens")
            if not isinstance(c, dict) or not is_int(c.get("issue")) or c["issue"] < 1:
                out.append(f'channel {name!r}: needs {{"issue": <number>}}')
    agents = r.get("agents")
    if not isinstance(agents, list):
        out.append("`agents` must be a list")
        return out
    seen = set()
    for i, a in enumerate(agents, 1):
        if not isinstance(a, dict):
            out.append(f"agent #{i} is not an object")
            continue
        name = a.get("name")
        label = f"agent {name!r}" if isinstance(name, str) else f"agent #{i}"
        if not isinstance(name, str) or not NAME.match(name):
            out.append(f"{label}: a name is lowercase letters, digits and hyphens, starting with a letter or digit")
        elif name in seen:
            out.append(f"{label}: the name is used twice")
        else:
            seen.add(name)
        for f in a:
            if SECRET_FIELD.search(f):
                out.append(
                    f"{label}: `{f}` looks like a secret, and every tier B agent's vendor reads the "
                    "roster. Keys stay on the machine that uses them."
                )
        kind = a.get("kind")
        if kind not in KINDS:
            out.append(f"{label}: kind {kind!r} is not one of {', '.join(KINDS)}")
            continue
        for f in NEEDS.get(kind, ()):
            if not isinstance(a.get(f), str) or not a[f].strip():
                out.append(f"{label}: kind {kind} needs `{f}`")
        if "endpoint" in a:
            if kind not in TAKES_ENDPOINT:
                out.append(f"{label}: kind {kind} takes no `endpoint`")
            elif isinstance(a["endpoint"], str):
                problem = endpoint_problem(a["endpoint"])
                if problem:
                    out.append(f"{label}: {problem}")
    return out


def read_roster(repo: str):
    """Return (roster, sha). A roster that won't parse stops the command: roster.md § Absent, empty and unreadable."""
    text, sha = get_file(repo, ROSTER_PATH)
    if text is None:
        raise Refused(f"{repo} has no {ROSTER_PATH}. Run `iac.py init --repo {repo}`.")
    try:
        roster = json.loads(text)
    except json.JSONDecodeError as e:
        raise Refused(
            f"{ROSTER_PATH} in {repo} won't parse ({e.msg}, line {e.lineno}). Nothing falls back "
            "to a default roster; fix the file."
        )
    problems = roster_problems(roster)
    if problems:
        raise Refused(f"{ROSTER_PATH} in {repo} is invalid:\n  " + "\n  ".join(problems))
    return roster, sha


def update_roster(repo: str, change, message: str):
    """Read the roster, apply `change`, and write it back with the SHA that was read.

    GitHub answers a write based on a stale copy with 409. Then the roster is read again
    and the change applied again, so a change made in between is never overwritten:
    roster.md § Writing it. `change` therefore has to be safe to apply to a fresh copy.
    """
    for _ in range(5):
        roster, sha = read_roster(repo)
        result = change(roster)
        problems = roster_problems(roster)
        if problems:
            raise Refused("that change would make the roster invalid:\n  " + "\n  ".join(problems))
        try:
            put_file(repo, ROSTER_PATH, dump_roster(roster), message, sha)
            return result
        except GhError as e:
            if e.status != 409:
                raise
    raise Refused(f"{ROSTER_PATH} changed underneath this command five times running. Try again.")


def find_agent(roster: dict, name: str) -> dict | None:
    return next((a for a in roster["agents"] if a["name"] == name), None)


def agent_names(roster: dict) -> str:
    return ", ".join(a["name"] for a in roster["agents"]) or "nobody"


def context():
    """The channel repo, checked as private, and its roster."""
    repo = Repo(read_config())
    repo.check()
    roster, _ = read_roster(repo.name)
    return repo, roster


def whoami(roster: dict) -> str:
    """This session's agent name: roster.md § Who a session is."""
    name = os.environ.get("IAC_AGENT", "").strip()
    if not name:
        raise Refused(
            "IAC_AGENT is not set. Start the session as `IAC_AGENT=<name> claude`, with a "
            "claude-code agent's name from the roster."
        )
    agent = find_agent(roster, name)
    if agent is None:
        raise Refused(
            f"IAC_AGENT={name} is not in the roster, which names {agent_names(roster)}. iac sends "
            "and handles nothing under a name the roster doesn't list."
        )
    tier = KINDS[agent["kind"]]
    if tier != "A":
        raise Refused(f"{name} is a {agent['kind']} agent, which is tier {tier}; this command is for tier A sessions.")
    return name


def pick_channel(roster: dict, flag: str | None):
    """Return (name, issue) for --channel, else IAC_CHANNEL, else the only channel."""
    channels = roster["channels"]
    name = flag or os.environ.get("IAC_CHANNEL", "").strip()
    if not name:
        if len(channels) == 1:
            name = next(iter(channels))
        else:
            listed = ", ".join(channels) or "none yet"
            raise Refused(f"no channel given. Pass --channel or set IAC_CHANNEL; the roster's channels are: {listed}.")
    if name not in channels:
        listed = ", ".join(channels) or "none yet"
        raise Refused(f"channel {name!r} is not in the roster, whose channels are: {listed}.")
    return name, channels[name]["issue"]


def require_open(repo: str, chan: str, issue: int) -> None:
    """A closed channel issue is history and takes no new posts: message.md § Channels and agents."""
    if issue_meta(repo, issue).get("state") != "open":
        raise Refused(
            f"channel {chan}'s issue #{issue} is closed, and a closed channel issue takes no new "
            "posts. The roster should name the channel's new issue."
        )


# ── messages and requests ───────────────────────────────────────────────────────


def is_int(x) -> bool:
    return isinstance(x, int) and not isinstance(x, bool)


def message_problem(d: dict) -> str | None:
    """Why a parsed object isn't a message, or None: message.md § A message."""
    if "v" not in d:
        return "lacks `v`"
    if not is_int(d["v"]) or d["v"] != VERSION:
        return f"has `v` {d['v']!r}, which this reader doesn't know"
    t = d.get("type")
    if t not in TYPES:
        return f"has `type` {t!r}, not one of {', '.join(TYPES)}"
    for f in ("from", "to"):
        if not isinstance(d.get(f), str) or not d[f]:
            return f"lacks `{f}`"
    if d["to"] == "*" and t != "notice":
        return "addresses `*`, which only a notice may"
    if not isinstance(d.get("body"), str):
        return "lacks `body`"
    if t != "notice" and (not isinstance(d.get("key"), str) or not d["key"]):
        return "lacks `key`"
    if t in ("ack", "reply") and not is_int(d.get("reply_to")):
        return "lacks `reply_to`"
    if t == "reply" and d.get("status") not in STATUSES:
        return f"has `status` {d.get('status')!r}, not one of {', '.join(STATUSES)}"
    return None


def parse_message(text: str) -> dict:
    """One comment's message. Raises ValueError, with the reason, when it isn't one."""
    t = text.strip()
    m = FENCE.match(t)
    if m:
        t = m.group(1).strip()
    try:
        data = json.loads(t)
    except json.JSONDecodeError:
        raise ValueError("not a message: the comment isn't one JSON object, alone or in a ```json fence")
    if not isinstance(data, dict):
        raise ValueError("not a message: the JSON isn't an object")
    problem = message_problem(data)
    if problem:
        raise ValueError(problem)
    return data


def render(msg: dict) -> str:
    return "```json\n" + json.dumps(msg, indent=2, ensure_ascii=False) + "\n```\n"


@dataclass
class Msg:
    id: int
    created_at: str | None
    edited: bool
    data: dict


@dataclass
class Request:
    """One request, every copy of it, and what its recipient has posted since."""

    first: Msg
    copies: list = field(default_factory=list)
    differs: bool = False
    ack: Msg | None = None
    reply: Msg | None = None
    extra: list = field(default_factory=list)

    @property
    def sender(self) -> str:
        return self.first.data["from"]

    @property
    def to(self) -> str:
        return self.first.data["to"]

    @property
    def key(self) -> str:
        return self.first.data["key"]

    @property
    def finished(self) -> bool:
        return self.reply is not None

    @property
    def state(self) -> str:
        """message.md § The state of a request."""
        if self.reply is not None:
            return self.reply.data["status"]
        return "received" if self.ack is not None else "pending"


@dataclass
class Channel:
    name: str
    issue: int
    msgs: list
    skipped: list       # (comment id, reason)
    requests: list
    unmatched: list     # acks and replies that answer no request on this issue
    last_id: int
    last_created: str | None


def match(msgs: list):
    """Group requests by `from` and `key`, and pair each with its recipient's ack and reply.

    Matching is by `key`, never `reply_to`, because a retried request has more than one
    comment ID: message.md § Identifiers. An ack or reply that comes before the request's
    first copy, or that matches no request at all, is set aside as unmatched.
    """
    reqs = {}
    for m in msgs:
        d = m.data
        if d["type"] != "request":
            continue
        r = reqs.get((d["from"], d["key"]))
        if r is None:
            reqs[(d["from"], d["key"])] = Request(first=m, copies=[m.id])
            continue
        r.copies.append(m.id)
        if d["to"] != r.to or d["body"] != r.first.data["body"]:
            r.differs = True
    unmatched = []
    for m in msgs:
        d = m.data
        if d["type"] not in ("ack", "reply"):
            continue
        r = reqs.get((d["to"], d["key"]))
        if r is None or d["from"] != r.to or m.id < r.first.id:
            unmatched.append(m)
        elif d["type"] == "ack" and r.ack is None:
            r.ack = m
        elif d["type"] == "reply" and r.reply is None:
            r.reply = m
        else:
            r.extra.append(m)
    return sorted(reqs.values(), key=lambda r: r.first.id), unmatched


def read_channel(repo: Repo, name: str, issue: int) -> Channel:
    """Read a channel: rules 2 and 3 of message.md § Rules decide what counts as a message."""
    comments = list_comments(repo.name, issue)
    login = repo.login().lower()
    msgs, skipped = [], []
    for c in comments:
        author = (c.get("user") or {}).get("login") or "?"
        if author.lower() != login:
            skipped.append((c["id"], f"posted by {author}, not the operator's login"))
            continue
        try:
            data = parse_message(c.get("body") or "")
        except ValueError as e:
            skipped.append((c["id"], str(e)))
            continue
        edited = bool(c.get("updated_at")) and c.get("updated_at") != c.get("created_at")
        msgs.append(Msg(c["id"], c.get("created_at"), edited, data))
    requests, unmatched = match(msgs)
    last = comments[-1] if comments else None
    return Channel(
        name, issue, msgs, skipped, requests, unmatched,
        last["id"] if last else 0, last.get("created_at") if last else None,
    )


def request_by_id(chan: Channel, comment_id: int, me: str) -> Request:
    r = next((r for r in chan.requests if comment_id in r.copies), None)
    if r is None:
        raise Refused(f"comment {comment_id} is not a request on channel {chan.name}.")
    if r.to != me:
        raise Refused(f"request {comment_id} is addressed to {r.to}, not to {me}.")
    return r


def check_size(msg: dict) -> None:
    n = len(render(msg))
    if n > COMMENT_LIMIT:
        raise Refused(
            f"that message is {n:,} characters, and GitHub caps a comment at {COMMENT_LIMIT:,}. "
            "Summarize the body."
        )


def find_landed(repo: Repo, issue: int, msg: dict) -> int | None:
    login = repo.login().lower()
    for c in list_comments(repo.name, issue):
        if ((c.get("user") or {}).get("login") or "").lower() != login:
            continue
        try:
            if parse_message(c.get("body") or "") == msg:
                return c["id"]
        except ValueError:
            continue
    return None


def post(repo: Repo, issue: int, msg: dict) -> int:
    """Post one message and return its comment ID.

    After a failure GitHub may or may not have recorded, read the channel to see whether
    the message landed before posting it again, with the same content and so the same
    `key`: rule 7 of message.md § Rules. A 4xx is GitHub refusing, so nothing landed.
    """
    check_size(msg)
    for attempt in range(3):
        try:
            _, _, data = gh("POST", f"repos/{repo.name}/issues/{issue}/comments", {"body": render(msg)})
            return data["id"]
        except GhError as e:
            if e.status is not None and e.status < 500:
                raise
            try:
                landed = find_landed(repo, issue, msg)
            except GhError:
                landed = None
            if landed is not None:
                return landed
            if attempt == 2:
                raise
            time.sleep(2 * (attempt + 1))


def read_body(a) -> str:
    if a.body_file == "-":
        text = sys.stdin.read()
    elif a.body_file:
        try:
            text = Path(a.body_file).read_text(encoding="utf-8")
        except OSError as e:
            raise Refused(f"can't read {a.body_file}: {e.strerror}")
    else:
        text = a.body
    return text.rstrip("\n")


# ── local state ─────────────────────────────────────────────────────────────────


def state_file(repo: str, agent: str) -> Path:
    base = os.environ.get("XDG_STATE_HOME") or str(Path.home() / ".local" / "state")
    return Path(base) / "iac" / repo.replace("/", "__") / f"{agent}.json"


def load_state(repo: str, agent: str) -> dict:
    """Read this agent's local state. Reading never creates the file, so `status` stays read-only."""
    p = state_file(repo, agent)
    try:
        s = json.loads(p.read_text(encoding="utf-8"))
    except FileNotFoundError:
        s = {}
    except (OSError, json.JSONDecodeError) as e:
        raise Refused(
            f"local state {p} can't be read ({e}). Move it aside to start fresh; the channel "
            "still holds every message."
        )
    s.setdefault("handled", [])
    s.setdefault("outbox", [])
    s.setdefault("seen", {})
    return s


def save_state(repo: str, agent: str, s: dict) -> None:
    p = state_file(repo, agent)
    p.parent.mkdir(parents=True, exist_ok=True)
    s["handled"] = s["handled"][-HANDLED_KEEP:]
    tmp = p.with_name(p.name + ".tmp")
    tmp.write_text(json.dumps(s, indent=2) + "\n", encoding="utf-8")
    os.replace(tmp, p)


def handled_pairs(state: dict) -> set:
    return {tuple(p) for p in state["handled"]}


def flush_outbox(repo: Repo, me: str, state: dict) -> list:
    """Post every saved reply that isn't on its channel yet. Returns one line per entry."""
    lines, keep, views = [], [], {}
    for entry in state["outbox"]:
        msg, issue = entry["message"], entry["issue"]
        if issue not in views:
            views[issue] = read_channel(repo, entry["channel"], issue)
        r = next((r for r in views[issue].requests if (r.sender, r.key) == (msg["to"], msg["key"])), None)
        if r is not None and r.reply is not None:
            state["handled"].append([msg["to"], msg["key"]])
            lines.append(f"saved reply to {msg['to']}'s request {r.first.id} was already posted, as {r.reply.id}")
            continue
        if issue_meta(repo.name, issue).get("state") != "open":
            keep.append(entry)
            lines.append(
                f"saved reply to {msg['to']} ({msg['key']}) can't post: #{issue} is closed. "
                "It stays saved; ask the sender to post the request again on the new issue."
            )
            continue
        try:
            cid = post(repo, issue, msg)
        except (GhError, Refused) as e:
            # One reply GitHub won't take must not stop inbox from reporting everything else.
            keep.append(entry)
            lines.append(f"saved reply to {msg['to']} ({msg['key']}) still can't post, and stays saved: {e}")
            continue
        state["handled"].append([msg["to"], msg["key"]])
        lines.append(f"posted the saved reply to {msg['to']}'s request, as comment {cid}")
    state["outbox"] = keep
    return lines


def news_for(m: Msg, me: str) -> bool:
    """A message this agent should hear about that isn't a request: an ack or reply to it, or a notice."""
    d = m.data
    if d["from"] == me:
        return False
    if d["type"] in ("ack", "reply"):
        return d["to"] == me
    return d["type"] == "notice" and d["to"] in (me, "*")


def describe(m: Msg) -> str:
    d = m.data
    if d["type"] == "reply":
        return f"reply {m.id} from {d['from']} to request {d['reply_to']}: {d['status']}"
    if d["type"] == "ack":
        return f"ack {m.id} from {d['from']} for request {d['reply_to']}"
    return f"notice {m.id} from {d['from']} to {d['to']}"


def item(kind: str, m: Msg | None, text: str, **extra) -> dict:
    out = {"kind": kind, "comment_id": m.id if m else None, "text": text}
    if m is not None:
        out["message"] = m.data
    out.update(extra)
    return out


# ── commands: setting up ────────────────────────────────────────────────────────


def cmd_init(a) -> int:
    if not REPO.match(a.repo):
        raise Refused("--repo takes <owner>/<name>.")
    p = config_path()
    if p.exists():
        try:
            old = json.loads(p.read_text(encoding="utf-8")).get("repo")
        except (OSError, json.JSONDecodeError, AttributeError):
            old = None
        if old and old != a.repo and not a.force:
            raise Refused(f"{p} already names {old}. Pass --force to point this machine at {a.repo} instead.")
    repo = Repo(a.repo)
    login = repo.login()
    try:
        gh("GET", f"repos/{a.repo}")
        made = "reused"
    except GhError as e:
        if e.status != 404:
            raise
        owner, name = a.repo.split("/")
        path = "user/repos" if owner.lower() == login.lower() else f"orgs/{owner}/repos"
        gh("POST", path, {
            "name": name, "private": True, "has_issues": True, "has_wiki": False,
            "has_projects": False,
            "description": "iac channels: one issue per channel, one JSON message per comment",
        })
        made = "created, private"
    repo.check()

    card = CARD.read_text(encoding="utf-8")
    text, sha = get_file(a.repo, CARD_PATH)
    if text == card:
        card_note = "already current"
    else:
        put_file(a.repo, CARD_PATH, card, "update the iac protocol card" if sha else "add the iac protocol card", sha)
        card_note = "updated" if sha else "added"

    text, _ = get_file(a.repo, ROSTER_PATH)
    if text is None:
        put_file(a.repo, ROSTER_PATH, dump_roster({"channels": {}, "agents": []}), "add an empty iac roster")
        roster_note = "added, empty"
    else:
        roster, _ = read_roster(a.repo)
        roster_note = f"kept, with {len(roster['channels'])} channel(s) and {len(roster['agents'])} agent(s)"

    where = write_config(a.repo)
    print(f"repo     {a.repo} ({made})")
    print(f"card     {CARD_PATH} ({card_note})")
    print(f"roster   {ROSTER_PATH} ({roster_note})")
    print(f"config   {where}")
    return 0


def cmd_channel_add(a) -> int:
    repo, roster = context()
    name = a.name
    if not NAME.match(name):
        raise Refused("a channel name is lowercase letters, digits and hyphens, starting with a letter or digit.")
    if name in roster["channels"]:
        raise Refused(f"channel {name} already exists, as issue #{roster['channels'][name]['issue']}.")
    title = f"iac:{name}"
    issue = find_open_issue(repo.name, title)
    how = "reused the open issue"
    if issue is None:
        issue = create_issue(repo.name, title, CHANNEL_BODY)
        how = "opened"

    def change(r):
        if name in r["channels"]:
            raise Refused(f"channel {name} was added by someone else meanwhile, as #{r['channels'][name]['issue']}.")
        r["channels"][name] = {"issue": issue}

    update_roster(repo.name, change, f"add channel {name} as #{issue}")
    print(f"channel {name}: {how} #{issue}, titled {title}")
    return 0


def cmd_channel_rotate(a) -> int:
    """roster.md § Channels: rotation refuses while a request is pending or received."""
    repo, roster = context()
    name = a.name
    if name not in roster["channels"]:
        raise Refused(f"channel {name!r} is not in the roster.")
    old = roster["channels"][name]["issue"]
    chan = read_channel(repo, name, old)
    unfinished = [r for r in chan.requests if not r.finished]
    if unfinished:
        lines = "\n  ".join(f"{r.first.id}  {r.sender} -> {r.to}  {r.state}  key {r.key}" for r in unfinished)
        raise Refused(
            f"channel {name} has {len(unfinished)} unfinished request(s), and rotating would leave "
            f"them in a closed issue:\n  {lines}\nWait for their replies, or have their recipients "
            "reply `failed`."
        )
    new = create_issue(repo.name, f"iac:{name}", f"{CHANNEL_BODY}\n\nContinues #{old}.")

    def change(r):
        current = r["channels"].get(name, {}).get("issue")
        if current != old:
            raise Refused(
                f"channel {name} moved to #{current} while this rotated it. Issue #{new} was "
                "opened and is unused; close it by hand."
            )
        r["channels"][name] = {"issue": new}

    update_roster(repo.name, change, f"rotate channel {name} from #{old} to #{new}")
    gh("PATCH", f"repos/{repo.name}/issues/{old}", {"state": "closed", "state_reason": "completed"})
    print(f"channel {name}: closed #{old}; #{new} is current")
    late = [c for c in list_comments(repo.name, old) if c["id"] > chan.last_id]
    if late:
        ids = ", ".join(str(c["id"]) for c in late)
        print(
            f"iac: {len(late)} comment(s) reached #{old} while it rotated ({ids}). Their senders "
            f"should post them again on #{new}, with the same key.",
            file=sys.stderr,
        )
        return 1
    return 0


def cmd_agent_add(a) -> int:
    repo, _ = context()
    agent = {"name": a.name, "kind": a.kind}
    if a.endpoint:
        agent["endpoint"] = a.endpoint
    if a.model:
        agent["model"] = a.model

    def change(r):
        if find_agent(r, a.name):
            raise Refused(f"{a.name} is already in the roster.")
        r["agents"].append(dict(agent))

    update_roster(repo.name, change, f"add agent {a.name} ({a.kind})")
    print(f"added {a.name}: kind {a.kind}, tier {KINDS[a.kind]}, costs {COST[a.kind]}")
    if a.endpoint and not is_loopback(a.endpoint):
        note = (
            f"{a.endpoint} is off this machine. Unless its server adds authentication, this trusts "
            "the whole network between the runner and it"
        )
        if a.kind == "openai-compatible":
            note += ", and a remote server may charge"
        print(f"note: {note}.")
    return 0


def cmd_agent_remove(a) -> int:
    repo, _ = context()

    def change(r):
        if not find_agent(r, a.name):
            raise Refused(f"{a.name} is not in the roster.")
        r["agents"] = [x for x in r["agents"] if x["name"] != a.name]

    update_roster(repo.name, change, f"remove agent {a.name}")
    print(f"removed {a.name}")
    return 0


def cmd_roster(a) -> int:
    repo, roster = context()
    if a.json:
        print(json.dumps(roster, indent=2))
        return 0
    print(f"repo      {repo.name}")
    chans = ", ".join(f"{n} #{c['issue']}" for n, c in roster["channels"].items()) or "none"
    print(f"channels  {chans}")
    if not roster["agents"]:
        print("agents    none")
    for i, ag in enumerate(roster["agents"]):
        extra = "  ".join(f"{k}={ag[k]}" for k in ("endpoint", "model") if k in ag)
        lead = "agents   " if i == 0 else "         "
        print(f"{lead} {ag['name']:<16} {ag['kind']:<18} tier {KINDS[ag['kind']]}  {extra}".rstrip())
    return 0


# ── commands: talking ───────────────────────────────────────────────────────────


def cmd_send(a) -> int:
    repo, roster = context()
    me = whoami(roster)
    chan, issue = pick_channel(roster, a.channel)
    if a.to == me:
        raise Refused(f"{me} is this session's own name.")
    if not find_agent(roster, a.to):
        raise Refused(
            f"{a.to} is not in the roster, which names {agent_names(roster)}. A request to any "
            "other name stays pending for good."
        )
    body = read_body(a)
    if not body.strip():
        raise Refused("a request needs a body.")
    require_open(repo.name, chan, issue)
    key = a.key or str(uuid.uuid4())
    msg = {"v": VERSION, "key": key, "from": me, "to": a.to, "type": "request", "reply_to": None, "body": body}
    check_size(msg)
    cid = None
    if a.key:
        # A retry: check whether the request already landed before posting it again.
        prior = next((r for r in read_channel(repo, chan, issue).requests if (r.sender, r.key) == (me, key)), None)
        if prior is not None:
            if prior.to != a.to or prior.first.data["body"] != body:
                raise Refused(
                    f"key {key} is already request {prior.first.id} on {chan}, with a different "
                    "recipient or body. A retry reuses a key only for the same request."
                )
            cid = prior.first.id
    posted = cid is None
    if posted:
        cid = post(repo, issue, msg)
    if a.json:
        print(json.dumps({"comment_id": cid, "key": key, "channel": chan, "issue": issue, "posted": posted}))
    elif posted:
        print(f"sent request {cid} to {a.to} on {chan} (#{issue}), key {key}")
    else:
        print(f"request {key} already landed as comment {cid}; not posted again")
    return 0


def cmd_notice(a) -> int:
    repo, roster = context()
    me = whoami(roster)
    chan, issue = pick_channel(roster, a.channel)
    if a.to != "*" and not find_agent(roster, a.to):
        raise Refused(f"{a.to} is not in the roster, which names {agent_names(roster)}. Use * for every agent.")
    body = read_body(a)
    if not body.strip():
        raise Refused("a notice needs a body.")
    require_open(repo.name, chan, issue)
    cid = post(repo, issue, {"v": VERSION, "from": me, "to": a.to, "type": "notice", "reply_to": None, "body": body})
    print(f"sent notice {cid} to {a.to} on {chan} (#{issue})")
    return 0


def cmd_inbox(a) -> int:
    """What this agent has to handle, and what it hasn't heard yet. Posts any saved replies first."""
    repo, roster = context()
    me = whoami(roster)
    chan, issue = pick_channel(roster, a.channel)
    state = load_state(repo.name, me)
    flushed = flush_outbox(repo, me, state) if state["outbox"] else []
    view = read_channel(repo, chan, issue)
    handled = handled_pairs(state)
    items = []
    for r in view.requests:
        if r.to != me or r.finished or (r.sender, r.key) in handled:
            continue
        if r.ack is not None:
            text = (
                f"request {r.first.id} from {r.sender} is received, not finished: your ack "
                f"{r.ack.id} has no reply. Check which of its effects already happened, then "
                "finish it or reply failed."
            )
        else:
            text = f"request {r.first.id} from {r.sender} is pending"
        items.append(item("request", r.first, text, state=r.state, key=r.key, sender=r.sender))
    seen = state["seen"].get(str(issue), 0)
    for m in view.msgs:
        if m.id > seen and news_for(m, me):
            items.append(item(m.data["type"], m, describe(m)))
    state["seen"][str(issue)] = max(seen, view.last_id)
    save_state(repo.name, me, state)
    if a.json:
        print(json.dumps({"agent": me, "channel": chan, "issue": issue, "flushed": flushed, "items": items}, indent=2))
        return 0
    for line in flushed:
        print(line)
    if not items:
        print(f"nothing for {me} on {chan} (#{issue})")
    for it in items:
        print(it["text"])
        if it["kind"] in ("request", "reply") and it["message"]["body"]:
            print("    " + it["message"]["body"].replace("\n", "\n    "))
    return 0


def cmd_ack(a) -> int:
    repo, roster = context()
    me = whoami(roster)
    chan, issue = pick_channel(roster, a.channel)
    require_open(repo.name, chan, issue)
    r = request_by_id(read_channel(repo, chan, issue), a.request, me)
    if r.reply is not None:
        raise Refused(f"request {r.first.id} is already finished: reply {r.reply.id}, {r.state}.")
    if r.ack is not None:
        print(f"request {r.first.id} was already acknowledged, as comment {r.ack.id}; not posted again")
        return 0
    cid = post(repo, issue, {
        "v": VERSION, "key": r.key, "from": me, "to": r.sender, "type": "ack",
        "reply_to": r.first.id, "body": "",
    })
    print(f"acknowledged request {r.first.id} from {r.sender}, as comment {cid}")
    return 0


def cmd_reply(a) -> int:
    """Rule 4 of message.md § Rules: a request gets one reply. It is saved locally before it posts."""
    repo, roster = context()
    me = whoami(roster)
    chan, issue = pick_channel(roster, a.channel)
    body = read_body(a)
    if not body.strip():
        raise Refused("a reply needs a body; say what was done, or why it failed or is blocked.")
    require_open(repo.name, chan, issue)
    r = request_by_id(read_channel(repo, chan, issue), a.request, me)
    if r.reply is not None:
        raise Refused(
            f"request {r.first.id} already has your reply, comment {r.reply.id} ({r.state}). "
            "Each request is handled once."
        )
    state = load_state(repo.name, me)
    if any((e["message"]["to"], e["message"]["key"]) == (r.sender, r.key) for e in state["outbox"]):
        raise Refused(
            f"a reply to request {r.first.id} is already saved locally and waiting to post. "
            "`iac.py inbox` posts it."
        )
    msg = {
        "v": VERSION, "key": r.key, "from": me, "to": r.sender, "type": "reply",
        "reply_to": r.first.id, "status": a.status, "body": body,
    }
    check_size(msg)
    state["outbox"].append({"channel": chan, "issue": issue, "message": msg})
    save_state(repo.name, me, state)
    try:
        cid = post(repo, issue, msg)
    except (GhError, Refused) as e:
        raise Refused(f"the reply is saved locally, and the next `iac.py inbox` posts it. Posting failed: {e}")
    state["outbox"] = [e for e in state["outbox"] if e["message"] != msg]
    state["handled"].append([r.sender, r.key])
    save_state(repo.name, me, state)
    print(f"replied {a.status} to request {r.first.id} from {r.sender}, as comment {cid}")
    return 0


def waiting(view: Channel, me: str, state: dict) -> list:
    """What should wake this agent: new requests, news, and saved replies.

    A received request is left out. It is this agent's own work in progress, and counting
    it would wake a session that acknowledged slow work on every poll. `inbox` reports it.
    """
    handled = handled_pairs(state)
    items = [
        item("request", r.first, f"request {r.first.id} from {r.sender} is pending", key=r.key, sender=r.sender)
        for r in view.requests
        if r.to == me and r.state == "pending" and (r.sender, r.key) not in handled
    ]
    seen = state["seen"].get(str(view.issue), 0)
    items += [item(m.data["type"], m, describe(m)) for m in view.msgs if m.id > seen and news_for(m, me)]
    items += [
        item("outbox", None, f"a reply to {e['message']['to']} is saved locally and waiting to post; run inbox")
        for e in state["outbox"]
    ]
    return items


def cmd_wait(a) -> int:
    """Block until something arrives for this agent, without calling a model.

    It polls with `since` and an ETag, and an unchanged channel answers 304, which
    GitHub doesn't count against the primary rate limit. Every 10th poll re-reads the
    roster, so a rotated channel ends the wait instead of watching a closed issue.
    `wait` writes nothing; the `inbox` that follows a wake marks what was heard.
    """
    repo, roster = context()
    me = whoami(roster)
    chan, issue = pick_channel(roster, a.channel)
    interval = max(MIN_INTERVAL, a.interval)
    state = load_state(repo.name, me)

    def wake(items) -> int:
        if a.json:
            print(json.dumps({"agent": me, "channel": chan, "issue": issue, "items": items}, indent=2))
        else:
            for it in items:
                print(it["text"])
        return 0

    view = read_channel(repo, chan, issue)
    ready = waiting(view, me, state)
    if ready:
        return wake(ready)
    baseline = view.last_id
    since = view.last_created or issue_meta(repo.name, issue).get("created_at")
    etag, polls, failures = None, 0, 0
    deadline = time.monotonic() + a.timeout if a.timeout > 0 else None

    def nap(seconds: float) -> None:
        if deadline is not None:
            seconds = min(seconds, deadline - time.monotonic())
        time.sleep(max(0, seconds))

    while True:
        if deadline is not None and time.monotonic() >= deadline:
            print(f"nothing new for {me} on {chan} (#{issue}) after {a.timeout}s")
            return 3
        nap(interval)
        polls += 1
        try:
            if polls % 10 == 0:
                roster, _ = read_roster(repo.name)
                current = roster["channels"].get(chan, {}).get("issue")
                if current != issue:
                    return wake([item("rotated", None, f"channel {chan} moved from #{issue} to #{current}; watch it again")])
            headers = [f"If-None-Match: {etag}"] if etag else []
            query = f"per_page={PAGE}&since={since}" if since else f"per_page={PAGE}"
            status, hdrs, data = gh("GET", f"repos/{repo.name}/issues/{issue}/comments?{query}", headers=headers)
            failures = 0
        except GhError as e:
            failures += 1
            if failures >= 10:
                raise
            print(f"iac: poll failed ({e}); trying again", file=sys.stderr)
            nap(min(300, interval * 2 ** failures))
            continue
        if status == 304:
            continue
        etag = hdrs.get("etag")
        if not any(c["id"] > baseline for c in data or []):
            continue
        # Something new: re-read the whole channel, since a request's state depends on
        # everything before it, then check whether any of it is for this agent.
        # Local state is read again because an `inbox` run meanwhile may have marked
        # some of it heard.
        view = read_channel(repo, chan, issue)
        ready = waiting(view, me, load_state(repo.name, me))
        if ready:
            return wake(ready)
        baseline = view.last_id
        since = view.last_created or since
        etag = None


# ── status ──────────────────────────────────────────────────────────────────────


def cmd_status(a) -> int:
    """Who this session is, the roster, and each channel's requests by state. Writes nothing."""
    report = {"config": str(config_path())}
    lines = ["iac status (writes nothing)", f"  config    {report['config']}"]
    repo_name = read_config()
    repo = Repo(repo_name)
    report["repo"] = repo_name
    try:
        repo.check()
        report["visibility"] = "private"
    except Refused as e:
        report["visibility"] = str(e)
        lines.append(f"  repo      {repo_name}: {e}")
        print("\n".join(lines))
        return 1
    login = repo.login()
    lines += [f"  repo      {repo_name} (private)", f"  operator  {login}"]
    roster, _ = read_roster(repo_name)
    report["roster"] = roster

    me = os.environ.get("IAC_AGENT", "").strip() or None
    agent = find_agent(roster, me) if me else None
    if me is None:
        who = "IAC_AGENT is not set"
    elif agent is None:
        who = f"IAC_AGENT={me}, which is NOT in the roster"
    else:
        who = f"IAC_AGENT={me} ({agent['kind']}, tier {KINDS[agent['kind']]})"
    chan_env = os.environ.get("IAC_CHANNEL", "").strip()
    report["session"] = {"agent": me, "in_roster": agent is not None, "channel": chan_env or None}
    lines.append(f"  session   {who}; IAC_CHANNEL={chan_env or '(not set)'}")

    lines.append("")
    lines.append("roster")
    lines.append("  channels  " + (", ".join(f"{n} #{c['issue']}" for n, c in roster["channels"].items()) or "none"))
    for i, ag in enumerate(roster["agents"]):
        lead = "  agents    " if i == 0 else "            "
        lines.append(f"{lead}{ag['name']:<16} {ag['kind']:<18} tier {KINDS[ag['kind']]}")
    if not roster["agents"]:
        lines.append("  agents    none")

    names = {ag["name"] for ag in roster["agents"]}
    if a.channel and a.channel not in roster["channels"]:
        raise Refused(f"channel {a.channel!r} is not in the roster.")
    wanted = a.channel or (chan_env if chan_env in roster["channels"] else None)
    if chan_env and chan_env not in roster["channels"]:
        lines.append(f"  warning   IAC_CHANNEL={chan_env} is not in the roster; showing every channel")
    state = load_state(repo_name, me) if agent is not None else None
    handled = handled_pairs(state) if state is not None else set()
    report["channels"] = {}
    for name, c in roster["channels"].items():
        if wanted and name != wanted:
            continue
        issue = c["issue"]
        meta = issue_meta(repo_name, issue)
        view = read_channel(repo, name, issue)
        by_state = {"pending": [], "received": [], "finished": []}
        for r in view.requests:
            by_state["finished" if r.finished else r.state].append(r)
        warnings = []
        if meta.get("state") != "open":
            warnings.append(f"#{issue} is closed, but the roster still names it as current")
        for r in view.requests:
            if r.differs:
                warnings.append(f"request {r.first.id}: a copy with the same key has a different recipient or body")
            for m in r.extra:
                warnings.append(f"request {r.first.id}: extra {m.data['type']} {m.id} from {m.data['from']}")
            if r.to == me and not r.finished and (r.sender, r.key) in handled:
                warnings.append(f"request {r.first.id}: local state says {me} replied, but no reply is on this issue")
        for m in view.unmatched:
            warnings.append(f"{m.data['type']} {m.id} from {m.data['from']} answers no request on this issue")
        for m in view.msgs:
            if m.edited:
                warnings.append(f"comment {m.id} was edited, and messages are never edited")
            for f in ("from", "to"):
                if m.data[f] != "*" and m.data[f] not in names:
                    warnings.append(f"comment {m.id}: `{f}` {m.data[f]!r} is not in the roster")
        report["channels"][name] = {
            "issue": issue,
            "issue_state": meta.get("state"),
            "messages": len(view.msgs),
            "requests": {
                s: [{"comment_id": r.first.id, "from": r.sender, "to": r.to, "key": r.key, "state": r.state,
                     "ack": r.ack.id if r.ack else None, "reply": r.reply.id if r.reply else None} for r in rs]
                for s, rs in by_state.items()
            },
            "skipped": [{"comment_id": cid, "reason": why} for cid, why in view.skipped],
            "warnings": warnings,
        }
        lines.append("")
        lines.append(f"channel {name} (#{issue}, {meta.get('state')}): {len(view.msgs)} messages, {len(view.requests)} requests")
        for s, rs in by_state.items():
            if not rs:
                lines.append(f"  {s:<9} none")
            for i, r in enumerate(rs):
                lead = f"  {s:<9} " if i == 0 else "            "
                tail = f"reply {r.reply.id}" if r.reply else (f"ack {r.ack.id}" if r.ack else "")
                lines.append(f"{lead}{r.first.id}  {r.sender} -> {r.to}  {r.state:<8} {tail}".rstrip())
        for i, (cid, why) in enumerate(view.skipped):
            lines.append(f"  {'skipped' if i == 0 else '':<9} {cid}  {why}")
        for i, w in enumerate(warnings):
            lines.append(f"  {'warning' if i == 0 else '':<9} {w}")

    if state is not None:
        report["local"] = {"outbox": state["outbox"], "handled": len(state["handled"])}
        lines.append("")
        lines.append(
            f"local state for {me}: {len(state['outbox'])} saved repl{'y' if len(state['outbox']) == 1 else 'ies'} "
            f"waiting to post, {len(state['handled'])} handled"
        )
    if a.json:
        print(json.dumps(report, indent=2))
    else:
        print("\n".join(lines))
    return 0


# ── main ────────────────────────────────────────────────────────────────────────


def add_body(s) -> None:
    g = s.add_mutually_exclusive_group(required=True)
    g.add_argument("--body-file", metavar="PATH", help="read the body from a file, or - for stdin")
    g.add_argument("--body", help="the body as text")


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="iac.py", description="The iac protocol's tier A tool.")
    sub = p.add_subparsers(dest="command", required=True)

    s = sub.add_parser("init", help="create or reuse the channel repo, and point this machine at it")
    s.add_argument("--repo", required=True, metavar="OWNER/NAME")
    s.add_argument("--force", action="store_true", help="replace a config that names another repo")
    s.set_defaults(fn=cmd_init)

    c = sub.add_parser("channel", help="add or rotate a channel").add_subparsers(dest="action", required=True)
    s = c.add_parser("add")
    s.add_argument("name")
    s.set_defaults(fn=cmd_channel_add)
    s = c.add_parser("rotate")
    s.add_argument("name")
    s.set_defaults(fn=cmd_channel_rotate)

    g = sub.add_parser("agent", help="add or remove an agent").add_subparsers(dest="action", required=True)
    s = g.add_parser("add")
    s.add_argument("name")
    s.add_argument("--kind", required=True, choices=list(KINDS))
    s.add_argument("--endpoint")
    s.add_argument("--model")
    s.set_defaults(fn=cmd_agent_add)
    s = g.add_parser("remove")
    s.add_argument("name")
    s.set_defaults(fn=cmd_agent_remove)

    s = sub.add_parser("roster", help="print the roster")
    s.add_argument("--json", action="store_true")
    s.set_defaults(fn=cmd_roster)

    s = sub.add_parser("send", help="post a request")
    s.add_argument("to")
    add_body(s)
    s.add_argument("--key", help="reuse a key, to retry a request that may already have landed")
    s.add_argument("--channel")
    s.add_argument("--json", action="store_true")
    s.set_defaults(fn=cmd_send)

    s = sub.add_parser("notice", help="post a notice, to one agent or to *")
    s.add_argument("to")
    add_body(s)
    s.add_argument("--channel")
    s.set_defaults(fn=cmd_notice)

    s = sub.add_parser("inbox", help="list what this agent has to handle; posts saved replies first")
    s.add_argument("--channel")
    s.add_argument("--json", action="store_true")
    s.set_defaults(fn=cmd_inbox)

    s = sub.add_parser("ack", help="acknowledge a request")
    s.add_argument("request", type=int, metavar="REQUEST_COMMENT_ID")
    s.add_argument("--channel")
    s.set_defaults(fn=cmd_ack)

    s = sub.add_parser("reply", help="post the final reply to a request")
    s.add_argument("request", type=int, metavar="REQUEST_COMMENT_ID")
    s.add_argument("--status", required=True, choices=STATUSES)
    add_body(s)
    s.add_argument("--channel")
    s.set_defaults(fn=cmd_reply)

    s = sub.add_parser("wait", help="block until something arrives for this agent")
    s.add_argument("--channel")
    s.add_argument("--interval", type=int, default=30, help=f"seconds between polls, at least {MIN_INTERVAL}")
    s.add_argument("--timeout", type=int, default=0, help="give up after this many seconds; 0 waits forever")
    s.add_argument("--json", action="store_true")
    s.set_defaults(fn=cmd_wait)

    s = sub.add_parser("status", help="report who this session is and each channel's requests; writes nothing")
    s.add_argument("--channel")
    s.add_argument("--json", action="store_true")
    s.set_defaults(fn=cmd_status)
    return p


def main(argv) -> int:
    args = build_parser().parse_args(argv[1:])
    try:
        return args.fn(args) or 0
    except Refused as e:
        print(f"iac: {e}", file=sys.stderr)
        return 1
    except GhError as e:
        print(f"iac: a GitHub call failed: {e}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        return 130


if __name__ == "__main__":
    sys.exit(main(sys.argv))
