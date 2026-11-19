#!/usr/bin/env bash
#
# research-ledger.sh, held to its format and to the rule it exists for.
#
# The rule: a URL reaches a book only if it was fetched and its quoted words
# were found on the page. `verify` is the half that fetches, and a fixture that
# fetched would fail whenever a site was slow, so this exercises it through
# entry 3's operator-supplied page instead: the same matching, with no network.
# The fetch itself, and the redirect check after it, are not exercised here.
#
#   check       the fixture's ledger passes; each malformed copy below fails
#               with the message that names its fault
#   verify      entry 3's quote is found in its saved page, whatever its HTML,
#               entities and typographic quotes; a quote the page does not carry
#               fails; a page too short to search fails with the remedy
#   trusted     a host, a subdomain and a host-and-path prefix each admit what
#               they should and refuse a look-alike
#
# check-provenance.sh's side of the ledger (web marks, links) is asserted by the
# manifest row in scripts/test-fixtures.sh.
#
# Usage: ./run.sh          (from anywhere; paths are resolved from the script)
# Exits 0 when every assertion holds, 1 otherwise.

set -uo pipefail
export LC_ALL=C

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
tool="$here/../../scripts/research-ledger.sh"

python3 - "$here" "$tool" <<'PY'
import importlib.machinery, importlib.util, json, pathlib, shutil, subprocess, sys, tempfile

here, tool = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
fails = 0


def report(ok, what):
    global fails
    print(f"{'ok   ' if ok else 'FAIL '} {what}")
    if not ok:
        fails = 1


def run(*args):
    r = subprocess.run([str(tool), *map(str, args)], capture_output=True, text=True)
    return r.returncode, r.stdout + r.stderr


rc, out = run("check", here)
report(rc == 0 and "3 entries, 0 problem(s)" in out, f"check: the fixture's ledger passes (exit {rc})")

tmp = pathlib.Path(tempfile.mkdtemp())
try:
    def mutated(change, label, expect):
        book = tmp / label
        shutil.copytree(here, book, ignore=shutil.ignore_patterns("run.sh"))
        path = book / "research" / "ledger.json"
        doc = json.loads(path.read_text())
        change(doc)
        path.write_text(json.dumps(doc))
        rc, out = run("check", book)
        report(rc == 1 and expect in out, f"check: {label} fails naming it (exit {rc})")

    mutated(lambda d: d["entries"][0].update(note="x"), "an unknown key", "unknown key 'note'")
    mutated(lambda d: d["entries"][1].update(id=1), "a reused id", "the id is used twice")
    mutated(lambda d: d["entries"][0].update(url="https://docs.example.org.evil.test/x"),
            "a look-alike domain", "is not under a trusted domain")
    mutated(lambda d: d["entries"][0].update(quotes=["too short"]), "a short quote", "a quote runs 2 words")
    mutated(lambda d: d["entries"][0].update(accessed="18 Nov 2026"), "a bad date", "must be a date")
    mutated(lambda d: d["entries"][2].update(page_file="research/pages/gone.html"),
            "a missing page file", "is not on disk")
    mutated(lambda d: d["entries"][2].update(page_file="../../outside.html"),
            "a page file outside the book", "must be inside the book folder")
    mutated(lambda d: d.update(trusted=[]), "an empty trusted list", "must list at least one domain")
    mutated(lambda d: d["entries"][0].pop("quotes"), "an entry with no quotes", "missing quotes")
    mutated(lambda d: d.update(trusted=["docs.example.org"]), "a trusted list of plain strings",
            "trusted[0] must be an object")
    mutated(lambda d: d["entries"][0].update(url="https://docs.example.org@evil.test/x"),
            "a URL hiding its host behind a user name", "carries a user name before its host")

    rc, out = run("verify", here, "--id", "99")
    report(rc == 1 and "has no entry 99" in out, f"verify: an id the ledger lacks fails (exit {rc})")

    book = tmp / "own-file"
    shutil.copytree(here, book, ignore=shutil.ignore_patterns("run.sh"))
    (book / "research" / "ledger.json").rename(book / "research" / "ledger-group-a.json")
    rc, out = run("check", book, "--file", "research/ledger-group-a.json")
    report(rc == 0 and "research/ledger-group-a.json: 3 entries" in out,
           f"check --file: an agent's own ledger file is checked before the merge (exit {rc})")
    rc, out = run("check", book, "--file", "../ledger.json")
    report(rc == 2, f"check --file: a path out of the book folder is refused (exit {rc})")

    rc, out = run("verify", here, "--id", "3")
    report(rc == 0 and "1 quote(s) found" in out and "operator-supplied copy" in out,
           f"verify: entry 3's quote is found in its saved page, and the run says how it read it (exit {rc})")

    book = tmp / "wrong-quote"
    shutil.copytree(here, book, ignore=shutil.ignore_patterns("run.sh"))
    path = book / "research" / "ledger.json"
    doc = json.loads(path.read_text())
    doc["entries"][2]["quotes"] = ["When the cache is full, the newest entries are evicted first"]
    path.write_text(json.dumps(doc))
    rc, out = run("verify", book, "--id", "3")
    report(rc == 1 and "quote not on the page" in out,
           f"verify: a quote the page does not carry fails (exit {rc})")

    (book / "research" / "pages" / "3.html").write_text("<html><body>Access denied.</body></html>")
    rc, out = run("verify", book, "--id", "3")
    report(rc == 1 and "too little to search" in out,
           f"verify: a page too short to search fails with the remedy (exit {rc})")
finally:
    shutil.rmtree(tmp, ignore_errors=True)

loader = importlib.machinery.SourceFileLoader("research_ledger", str(tool))
spec = importlib.util.spec_from_loader(loader.name, loader)
mod = importlib.util.module_from_spec(spec)
loader.exec_module(mod)
tl = [{"domain": "docs.example.org", "for": "x"}, {"domain": "github.com/example-org", "for": "y"}]
cases = [
    ("https://docs.example.org/guide", True),
    ("https://api.docs.example.org/v1", True),
    ("https://docs.example.org.evil.test/", False),
    ("https://notdocs.example.org/", False),
    ("https://github.com/example-org/tool/blob/main/README.md", True),
    ("https://github.com/example-org", True),
    ("https://github.com/example-orgs/tool", False),
    ("https://github.com/other/tool", False),
    ("https://evil.test?.docs.example.org", False),
    ("https://evil.test#.docs.example.org", False),
    ("https://evil.test\\.docs.example.org/", False),
    ("https://github.com/example-org/../other/tool", False),
    ("https://docs.example.org:8443/guide", True),
]
for url, want in cases:
    got = mod.trusted(url, tl)
    report(got == want, f"trusted: {url} -> {got}")

text = mod.visible_text("<p>Set <code>cache_dir</code>, then run it (see <em>Keys</em>).</p>")
report(mod.found("Set cache_dir, then run it (see Keys).", text),
       f"matching closes the space a removed inline tag leaves before punctuation (got {text!r})")
text = mod.visible_text("<p>It&rsquo;s &ldquo;fast&rdquo;&nbsp;&mdash; really</p>")
report(mod.found("It's \"fast\" - really", text), f"matching folds entities and typographic marks (got {text!r})")

sys.exit(fails)
PY
