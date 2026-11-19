#!/usr/bin/env python3
"""Check and verify a book's research ledger, `research/ledger.json`.

    research-ledger.sh check  <book-folder> [--file research/ledger-<group>.json]
    research-ledger.sh verify <book-folder> [--id N ...] [--file ...]
    research-ledger.sh list   <book-folder> [--file ...]

A primer brings in facts its context does not state, from trusted outside
sources, and cites each one with its URL (createbook/SKILL.md § Research). The
ledger is the record of those sources: which domains the operator trusts for
this book, and every outside page the book draws on, with the verbatim words on
that page that support what the book takes from it.

**The rule this script exists to enforce: a URL reaches a book only if it was
fetched and the quoted words were found on the fetched page.** A citation is
never recalled. A model asked for a source will produce a plausible URL with
total confidence, and nothing in a finished book tells that URL from a real one.
Fetching the page and finding the quote on it is what tells them apart.

## The format

    {
      "format": 1,
      "trusted": [
        {"domain": "docs.example.org", "for": "the project's own documentation"}
      ],
      "entries": [
        {
          "id": 1,
          "url": "https://docs.example.org/guide/caching",
          "title": "Caching",
          "publisher": "Example project documentation",
          "accessed": "2026-11-18",
          "chapters": [3],
          "takes": "what the book takes from the page",
          "quotes": ["a run of six to forty words copied exactly from the page"]
        }
      ]
    }

- `trusted` is the list the operator approved at the outline gate. A `domain`
  is a host (`docs.example.org`, which also admits its subdomains) or a host
  and a path prefix (`github.com/example-org`). Every entry's URL must fall
  under one.
- `id` is a whole number, unique in the file. Marks cite it as `web <id>`.
- `quotes` are the words on the page that support `takes`, each six to forty
  words, so a quote is long enough to prove the page says it and short enough
  to sit inside one sentence or paragraph.
- `page_file`, optional, names a copy of the page the operator saved by hand,
  inside the book folder, for a trusted site that answers automated fetching
  with a block. `verify` reads that file instead of fetching, and says so.

`check` is offline and is the only definition of the format. `verify` runs
`check`, then fetches each page and looks for each quote, and it is what
`recheck` means when a book is revisited: a page that is gone or no longer
carries its quote fails, because links rot.

Exit codes: 0 when everything passes, 1 when anything fails, 2 when there is
nothing to check or the command line is wrong.
"""
from __future__ import annotations

import html
import json
import pathlib
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

FILE = "research/ledger.json"
FORMAT = 1
TOP_KEYS = {"format", "trusted", "entries"}
TRUSTED_KEYS = {"domain", "for"}
ENTRY_KEYS = {"id", "url", "title", "publisher", "accessed", "chapters",
              "takes", "quotes", "page_file"}
REQUIRED = ("id", "url", "title", "publisher", "accessed", "chapters",
            "takes", "quotes")
MIN_WORDS, MAX_WORDS = 6, 40
DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
URL = re.compile(r"^https?://[^\s/]+(/\S*)?$")
# A generic client name: a request carries nothing about the book or its owner.
USER_AGENT = "Mozilla/5.0 (compatible; bookcraft-citation-check)"


def norm(text: str) -> str:
    """Text as compared: entities decoded, typographic marks folded, spaces collapsed."""
    text = html.unescape(text)
    for a, b in (("‘", "'"), ("’", "'"), ("“", '"'), ("”", '"'),
                 ("–", "-"), ("—", "-"), ("−", "-"), (" ", " "),
                 ("…", "...")):
        text = text.replace(a, b)
    text = re.sub(r"\s+", " ", text)
    # A tag removed from `<code>x</code>,` leaves "x ,". Folding the space before
    # closing punctuation, and after an opening bracket, on both sides of the
    # comparison keeps a quote copied from the rendered page matching.
    text = re.sub(r" ([,.;:!?)\]])", r"\1", text)
    text = re.sub(r"([(\[]) ", r"\1", text)
    return text.strip().lower()


def visible_text(raw: str) -> str:
    """A page's readable text: scripts and styles dropped, tags removed, normalized."""
    raw = re.sub(r"(?is)<(script|style|noscript)\b.*?</\1>", " ", raw)
    raw = re.sub(r"(?s)<!--.*?-->", " ", raw)
    return norm(re.sub(r"(?s)<[^>]+>", " ", raw))


def found(quote: str, text: str) -> bool:
    return norm(quote) in text


def _rest(url: str) -> str:
    return re.sub(r"^https?://", "", url).lower()


HOSTNAME = re.compile(r"^[a-z0-9.-]+$")


def trusted(url: str, trusted_list) -> bool:
    """True when the URL falls under a domain, or a domain and path prefix, on the list.

    The host and path come from a real URL parse, never from the string, so a
    query or fragment that looks like a host (`evil.test?.docs.example.org`), a
    user name before the host, a backslash and a `..` path segment cannot pass
    as the trusted site.
    """
    try:
        parts = urllib.parse.urlsplit(url)
        host = (parts.hostname or "").lower()
    except ValueError:
        return False
    if parts.scheme not in ("http", "https") or not HOSTNAME.match(host):
        return False
    segments = [s for s in parts.path.split("/") if s]
    if ".." in segments or "." in segments:
        return False
    path = "/" + "/".join(segments)
    for t in trusted_list or []:
        if not isinstance(t, dict):
            continue
        d = str(t.get("domain", "")).lower().strip().strip("/")
        if not d:
            continue
        dhost, _, dpath = d.partition("/")
        if dpath:
            prefix = "/" + dpath.strip("/")
            if host == dhost and (path == prefix or path.startswith(prefix + "/")):
                return True
        elif host == dhost or host.endswith("." + dhost):
            return True
    return False


def load(book, file: str = FILE) -> tuple[dict | None, list[str]]:
    """The ledger and every problem `check` finds; (None, []) when there is no ledger.

    `file` names another ledger file in the book folder, for a research agent
    writing its own while others run, before the files are merged.
    """
    path = pathlib.Path(book) / file
    if not path.is_file():
        return None, []
    try:
        doc = json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, UnicodeDecodeError) as exc:
        return None, [f"{file} is not valid JSON ({exc})"]
    return doc, validate(doc, pathlib.Path(book), file)


def validate(doc, book: pathlib.Path, file: str = FILE) -> list[str]:
    FILE = file  # noqa: N806, so every message names the file being checked
    problems: list[str] = []
    if not isinstance(doc, dict):
        return [f"{FILE} must hold a JSON object"]
    for k in sorted(set(doc) - TOP_KEYS):
        problems.append(f"{FILE}: unknown key {k!r}")
    if doc.get("format") != FORMAT:
        problems.append(f"{FILE}: \"format\" must be {FORMAT}")
    tl = doc.get("trusted")
    if not isinstance(tl, list) or not tl:
        problems.append(f"{FILE}: \"trusted\" must list at least one domain the operator approved")
        tl = []
    for i, t in enumerate(tl):
        if not isinstance(t, dict):
            problems.append(f"{FILE}: trusted[{i}] must be an object")
            continue
        for k in sorted(set(t) - TRUSTED_KEYS):
            problems.append(f"{FILE}: trusted[{i}] has unknown key {k!r}")
        if not isinstance(t.get("domain"), str) or not t["domain"].strip():
            problems.append(f"{FILE}: trusted[{i}] needs a \"domain\"")
        elif "://" in t["domain"]:
            problems.append(f"{FILE}: trusted[{i}] \"domain\" names a host, not a URL: {t['domain']!r}")
        if not isinstance(t.get("for"), str) or not t["for"].strip():
            problems.append(f"{FILE}: trusted[{i}] needs a \"for\": what the domain is trusted for")
    entries = doc.get("entries")
    if not isinstance(entries, list):
        problems.append(f"{FILE}: \"entries\" must be a list")
        return problems
    seen: set[int] = set()
    for e in entries:
        if not isinstance(e, dict):
            problems.append(f"{FILE}: every entry must be an object")
            continue
        eid = e.get("id")
        label = f"web {eid}" if isinstance(eid, int) else "an entry"
        for k in sorted(set(e) - ENTRY_KEYS):
            problems.append(f"{label}: unknown key {k!r}")
        missing = [k for k in REQUIRED if e.get(k) in (None, "", [])]
        if missing:
            problems.append(f"{label}: missing {', '.join(missing)}")
        if not isinstance(eid, int) or isinstance(eid, bool) or eid < 1:
            problems.append(f"{label}: \"id\" must be a whole number from 1")
        elif eid in seen:
            problems.append(f"{label}: the id is used twice")
        else:
            seen.add(eid)
        url = e.get("url")
        if isinstance(url, str) and url:
            if not URL.match(url):
                problems.append(f"{label}: \"url\" is not an http or https URL: {url!r}")
            elif "@" in _rest(url).split("/", 1)[0]:
                problems.append(f"{label}: \"url\" carries a user name before its host, "
                                f"which hides the real host: {url!r}")
            elif not trusted(url, tl):
                problems.append(f"{label}: {url} is not under a trusted domain")
        if isinstance(e.get("accessed"), str) and e["accessed"] and not DATE.match(e["accessed"]):
            problems.append(f"{label}: \"accessed\" must be a date, YYYY-MM-DD")
        ch = e.get("chapters")
        if ch not in (None, []) and (not isinstance(ch, list)
                                     or not all(isinstance(c, int) and not isinstance(c, bool) for c in ch)):
            problems.append(f"{label}: \"chapters\" must be a list of chapter numbers")
        quotes = e.get("quotes")
        if quotes not in (None, []):
            if not isinstance(quotes, list) or not all(isinstance(q, str) for q in quotes):
                problems.append(f"{label}: \"quotes\" must be a list of strings")
            else:
                for q in quotes:
                    n = len(q.split())
                    if n < MIN_WORDS or n > MAX_WORDS:
                        problems.append(f"{label}: a quote runs {n} words, outside "
                                        f"{MIN_WORDS} to {MAX_WORDS}: {q[:60]!r}")
        pf = e.get("page_file")
        if pf is not None:
            target = (book / str(pf)).resolve()
            if not str(target).startswith(str(book.resolve()) + "/"):
                problems.append(f"{label}: \"page_file\" must be inside the book folder")
            elif not target.is_file():
                problems.append(f"{label}: \"page_file\" {pf} is not on disk")
    return problems


def fetch(url: str) -> tuple[str, str]:
    """(the page, the URL it was finally served from, after any redirect)."""
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=40) as resp:
        return resp.read().decode("utf-8", "replace"), resp.geturl()


def verify_entry(e: dict, book: pathlib.Path, trusted_list) -> tuple[str, list[str]]:
    """(how the page was read, problems) for one entry."""
    if e.get("page_file"):
        raw = (book / e["page_file"]).read_text(encoding="utf-8", errors="replace")
        how = f"operator-supplied copy {e['page_file']}"
    else:
        try:
            raw, final = fetch(e["url"])
        except (urllib.error.URLError, OSError, ValueError) as exc:
            return "fetch", [f"could not fetch the page ({exc})"]
        how = "fetched"
        # A redirect off the trusted list means the words were found on a page
        # the operator never approved, whatever the ledger's URL says.
        if not trusted(final, trusted_list):
            return how, [f"the page redirected to {final}, which is not under a trusted domain"]
    text = visible_text(raw)
    if len(text) < 500:
        return how, [f"the page read as {len(text)} characters, too little to search; "
                     "a site that blocks automated fetching needs an operator-supplied "
                     "page_file"]
    return how, [f"quote not on the page: {q[:70]!r}" for q in e["quotes"] if not found(q, text)]


def cmd_check(book: pathlib.Path, file: str) -> int:
    doc, problems = load(book, file)
    if doc is None and not problems:
        print(f"nothing to check: {book} has no {file}")
        return 2
    for p in problems:
        print(f"FAIL  {p}")
    n = len(doc.get("entries") or []) if isinstance(doc, dict) else 0
    print(f"{'OK  ' if not problems else 'FAIL'}  {file}: {n} entries, {len(problems)} problem(s)")
    return 1 if problems else 0


def cmd_verify(book: pathlib.Path, ids: set[int], file: str) -> int:
    rc = cmd_check(book, file)
    if rc:
        return rc
    doc, _ = load(book, file)
    have = {e["id"] for e in doc["entries"]}
    unknown = sorted(ids - have)
    for i in unknown:
        print(f"FAIL  web {i}: {file} has no entry {i}")
    bad = len(unknown)
    for e in doc["entries"]:
        if ids and e["id"] not in ids:
            continue
        how, problems = verify_entry(e, book, doc.get("trusted"))
        if problems:
            bad += 1
            print(f"FAIL  web {e['id']}  {e['url']}  ({how})")
            for p in problems:
                print(f"      {p}")
        else:
            print(f"ok    web {e['id']}  {len(e['quotes'])} quote(s) found  {e['url']}  ({how})")
    print(f"\nverified {'the named' if ids else 'every'} entry: {bad} failing")
    return 1 if bad else 0


def cmd_list(book: pathlib.Path, file: str) -> int:
    doc, problems = load(book, file)
    if doc is None:
        print(problems[0] if problems else f"nothing to list: {book} has no {file}")
        return 2
    if not isinstance(doc, dict):
        print(f"{file} must hold a JSON object; run check")
        return 1
    print("trusted:")
    for t in doc.get("trusted") or []:
        if isinstance(t, dict):
            print(f"  {t.get('domain')}  for {t.get('for')}")
    print("entries:")
    for e in doc.get("entries") or []:
        if not isinstance(e, dict):
            continue
        ch = ", ".join(str(c) for c in e.get("chapters") or [])
        print(f"  web {e.get('id')}  ch. {ch}  {e.get('url')}\n      {e.get('takes')}")
    return 0


def main(argv) -> int:
    if len(argv) < 3 or argv[1] not in ("check", "verify", "list") or argv[1] in ("-h", "--help"):
        print(__doc__.strip().splitlines()[0])
        print(__doc__.strip().split("\n\n")[1])
        return 2
    book = pathlib.Path(argv[2])
    if not book.is_dir():
        print(f"error: no such folder: {book}", file=sys.stderr)
        return 2
    ids: set[int] = set()
    file = FILE
    rest = argv[3:]
    while rest:
        if rest[0] == "--id" and len(rest) > 1 and rest[1].isdigit():
            ids.add(int(rest[1]))
            rest = rest[2:]
        elif rest[0] == "--file" and len(rest) > 1 and not rest[1].startswith("/") \
                and ".." not in pathlib.PurePath(rest[1]).parts:
            file = rest[1]
            rest = rest[2:]
        else:
            print(f"error: unknown or unsafe argument {rest[0]}", file=sys.stderr)
            return 2
    if argv[1] == "check":
        return cmd_check(book, file)
    if argv[1] == "verify":
        return cmd_verify(book, ids, file)
    return cmd_list(book, file)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
