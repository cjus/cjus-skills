#!/usr/bin/env python3
"""A fake `gh` for iac's offline tests: just enough of `gh api -i` and GitHub's REST API.

    FAKE_GH_STATE=<state.json> fake_gh.py api -i -X <METHOD> <path> [-H <header>]... [--input -]

The tests put a shim named `gh` on PATH that runs this file, so `iac.py` runs unchanged.
Everything GitHub would hold lives in the JSON file `$FAKE_GH_STATE` names, which the
tests read and edit directly: the logged-in user, each repo's visibility, files, issues and
comments, and a log of every call.

It copies the behaviour of the real thing that iac depends on, each probed against GitHub
on 2026-10-10:

- `-i` output is the status line, the headers, a blank line, then the body, and gh exits
  1 on any status of 300 or more, a 304 included.
- A contents write with a stale `sha` answers 409, and one with no `sha` for a file that
  exists answers 422.
- A comments list honours `per_page`, `page` and `since`, and answers 304 to an
  `If-None-Match` carrying its current ETag.

`faults` in the state injects failures. Each entry is
`{"method", "path" (a regex), "mode", "status", "times"}`, where `mode` is `refuse`
(answer `status` and change nothing), `down` (change nothing and answer nothing, as when
the network is down), or `lost` (make the change, then answer nothing, as when a response
is lost on the way back).
"""
import base64
import datetime
import hashlib
import json
import os
import re
import sys
from urllib.parse import parse_qs, urlsplit

REASONS = {
    200: "OK", 201: "Created", 304: "Not Modified", 404: "Not Found",
    409: "Conflict", 422: "Unprocessable Entity", 500: "Internal Server Error", 502: "Bad Gateway",
}
EPOCH = datetime.datetime(2026, 1, 1, tzinfo=datetime.timezone.utc)


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def save(path, state):
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(state, f, indent=1)
    os.replace(tmp, path)


def now(state):
    """A fake clock that moves one second per write, so every timestamp is distinct."""
    state["clock"] = state.get("clock", 0) + 1
    t = EPOCH + datetime.timedelta(seconds=state["clock"])
    return t.strftime("%Y-%m-%dT%H:%M:%SZ")


def sha_of(text):
    return hashlib.sha1(text.encode("utf-8")).hexdigest()


def etag_of(data):
    return '"' + hashlib.sha256(json.dumps(data, sort_keys=True).encode()).hexdigest() + '"'


def take_fault(state, method, path):
    for f in state.get("faults", []):
        if f.get("times", 1) > 0 and f["method"] == method and re.search(f["path"], path):
            f["times"] = f.get("times", 1) - 1
            return f
    return None


def page(items, q):
    per = int(q.get("per_page", 30))
    n = int(q.get("page", 1))
    return items[(n - 1) * per: n * per]


def new_repo(private, has_issues):
    return {"private": private, "has_issues": has_issues, "files": {}, "issues": {}, "next_issue": 1}


def issue_json(number, issue):
    return {
        "number": number, "title": issue["title"], "body": issue["body"],
        "state": issue["state"], "created_at": issue["created_at"],
    }


def route(state, method, path, body, headers):
    u = urlsplit(path)
    p = u.path.strip("/")
    q = {k: v[0] for k, v in parse_qs(u.query).items()}

    if p == "user" and method == "GET":
        return 200, {"login": state["login"]}, {}

    if method == "POST" and (p == "user/repos" or re.fullmatch(r"orgs/[^/]+/repos", p)):
        owner = state["login"] if p == "user/repos" else p.split("/")[1]
        full = f"{owner}/{body['name']}"
        if full in state["repos"]:
            return 422, {"message": "name already exists on this account"}, {}
        state["repos"][full] = new_repo(bool(body.get("private")), body.get("has_issues", True))
        return 201, {"full_name": full, "private": bool(body.get("private"))}, {}

    m = re.fullmatch(r"repos/([^/]+/[^/]+)(/.*)?", p)
    repo = state["repos"].get(m.group(1)) if m else None
    if repo is None:
        return 404, {"message": "Not Found"}, {}
    full, rest = m.group(1), m.group(2) or ""

    if rest == "" and method == "GET":
        return 200, {"full_name": full, "private": repo["private"], "has_issues": repo["has_issues"]}, {}

    mm = re.fullmatch(r"/contents/(.+)", rest)
    if mm:
        name = mm.group(1)
        f = repo["files"].get(name)
        if method == "GET":
            if f is None:
                msg = "This repository is empty." if not repo["files"] else "Not Found"
                return 404, {"message": msg}, {}
            b64 = base64.encodebytes(f["content"].encode("utf-8")).decode("ascii")
            return 200, {"path": name, "sha": f["sha"], "content": b64, "encoding": "base64"}, {}
        if method == "PUT":
            text = base64.b64decode(body["content"]).decode("utf-8")
            if f is not None:
                if "sha" not in body:
                    return 422, {"message": "Invalid request.\n\n\"sha\" wasn't supplied."}, {}
                if body["sha"] != f["sha"]:
                    return 409, {"message": f"{name} does not match {body['sha']}"}, {}
            repo["files"][name] = {"content": text, "sha": sha_of(text), "message": body.get("message")}
            return (200 if f else 201), {"content": {"path": name, "sha": sha_of(text)}}, {}

    if rest == "/issues" and method == "POST":
        n = repo["next_issue"]
        repo["next_issue"] += 1
        repo["issues"][str(n)] = {
            "title": body["title"], "body": body.get("body", ""), "state": "open",
            "created_at": now(state), "comments": [],
        }
        return 201, issue_json(n, repo["issues"][str(n)]), {}

    if rest == "/issues" and method == "GET":
        want = q.get("state", "open")
        rows = [issue_json(int(n), i) for n, i in sorted(repo["issues"].items(), key=lambda x: int(x[0]))
                if want == "all" or i["state"] == want]
        return 200, page(rows, q), {}

    mm = re.fullmatch(r"/issues/(\d+)", rest)
    if mm:
        issue = repo["issues"].get(mm.group(1))
        if issue is None:
            return 404, {"message": "Not Found"}, {}
        if method == "PATCH":
            if "state" in body:
                issue["state"] = body["state"]
            return 200, issue_json(int(mm.group(1)), issue), {}
        return 200, issue_json(int(mm.group(1)), issue), {}

    mm = re.fullmatch(r"/issues/(\d+)/comments", rest)
    if mm:
        issue = repo["issues"].get(mm.group(1))
        if issue is None:
            return 404, {"message": "Not Found"}, {}
        if method == "POST":
            t = now(state)
            c = {
                "id": state["next_comment"], "user": {"login": state["login"]},
                "body": body["body"], "created_at": t, "updated_at": t,
            }
            state["next_comment"] += 1
            issue["comments"].append(c)
            return 201, c, {}
        rows = sorted(issue["comments"], key=lambda c: c["created_at"])
        if "since" in q:
            rows = [c for c in rows if c["updated_at"] >= q["since"]]
        rows = page(rows, q)
        tag = etag_of(rows)
        sent = [h.split(":", 1)[1].strip() for h in headers if h.lower().startswith("if-none-match:")]
        if sent and sent[0].removeprefix("W/") == tag:
            return 304, None, {"ETag": tag}
        return 200, rows, {"ETag": "W/" + tag}

    return 404, {"message": "Not Found"}, {}


def respond(status, data, extra):
    out = f"HTTP/2.0 {status} {REASONS.get(status, '')}\n"
    hdrs = {"Content-Type": "application/json; charset=utf-8", **extra}
    out += "".join(f"{k}: {v}\r\n" for k, v in hdrs.items()) + "\r\n"
    if data is not None:
        out += json.dumps(data)
    sys.stdout.write(out)
    if status >= 300:
        msg = data.get("message", "") if isinstance(data, dict) else ""
        print(f"gh: {msg} (HTTP {status})", file=sys.stderr)
        return 1
    return 0


def main(argv):
    args = argv[1:]
    if not args or args[0] != "api":
        print("fake gh: only `gh api` is implemented", file=sys.stderr)
        return 2
    method, path, headers, use_stdin = "GET", None, [], False
    i = 1
    while i < len(args):
        a = args[i]
        if a == "-X":
            method, i = args[i + 1], i + 2
        elif a == "-H":
            headers.append(args[i + 1])
            i += 2
        elif a == "--input":
            use_stdin, i = args[i + 1] == "-", i + 2
        elif a == "-i":
            i += 1
        else:
            path, i = a, i + 1
    body = json.loads(sys.stdin.read()) if use_stdin else None

    state_path = os.environ["FAKE_GH_STATE"]
    state = load(state_path)
    state.setdefault("calls", []).append([method, path])
    fault = take_fault(state, method, path)
    if fault and fault["mode"] in ("refuse", "down"):
        save(state_path, state)
        if fault["mode"] == "down":
            print("gh: connection reset by peer", file=sys.stderr)
            return 1
        return respond(fault.get("status", 500), {"message": "injected"}, {})
    status, data, extra = route(state, method, path, body, headers)
    save(state_path, state)
    if fault and fault["mode"] == "lost":
        print("gh: connection reset by peer", file=sys.stderr)
        return 1
    return respond(status, data, extra)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
