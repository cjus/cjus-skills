#!/usr/bin/env bash
#
# Every bookcraft tool classifies every file the same way.
#
# The binder and the three checkers each used to carry their own copy of the
# rules that say what a file is, and the copies drifted. The appendix filename
# rule existed four times and no two agreed: bk-appendix-1-Answer-Key.md bound
# as a chapter while two checkers graded it as an appendix and the third
# rejected it, and sql-02-appendix-1-of-the-standard.md once bound as Appendix 1
# while every checker read it as chapter 2. Each tool now asks the plugin's book
# model (scripts/book_model.py) instead, and this fixture is what keeps it so.
#
# Three parts:
#
#   the model      its own table, from names alone, touching no file. That is
#                  also how the ticket's four appendix names get checked side by
#                  side: a case-insensitive disk, macOS's default, cannot hold
#                  bk-appendix-1-answer-key.md and bk-appendix-1-Answer-Key.md
#                  in one folder.
#   every tool     the same names, one folder each, handed to the binder,
#                  check-provenance.sh, check-references.sh and check-book.sh.
#                  Each is read through what it actually produces: the binder's
#                  chapter records, the worklist index render-report.py reads,
#                  the unit map check-references.sh resolves citations against,
#                  and check-book.sh's own verdicts. The binder half needs
#                  install.sh's venv and prints skip without it.
#   no copies      no tool carries a filename rule of its own again.
#
# Usage: ./run.sh          (from anywhere; paths are resolved from the script)
# Exits 0 when every tool agrees with the model, 1 otherwise.

set -uo pipefail
export LC_ALL=C

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
plugin=$(cd "$here/../../../.." && pwd)
venv="${XDG_CACHE_HOME:-$HOME/.cache}/bookcraft/venv/bin/python"

python3 - "$plugin" "$venv" <<'PY'
import atexit, importlib.machinery, importlib.util, json, pathlib, re, shutil, subprocess, sys, tempfile

plugin, venv = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
scripts = plugin / "skills" / "createbook" / "scripts"
binder = plugin / "skills" / "makebook" / "scripts" / "build-book.py"
fails = 0


def report(ok, what):
    global fails
    print(f"{'ok   ' if ok else 'FAIL '} {what}")
    if not ok:
        fails = 1


def load(path, name):
    loader = importlib.machinery.SourceFileLoader(name, str(path))
    spec = importlib.util.spec_from_loader(name, loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


model = load(plugin / "scripts" / "book_model.py", "book_model")
refs = load(scripts / "check-references.sh", "check_references")

# ---------------------------------------------------------------------------
# One: the model, from names alone.
# ---------------------------------------------------------------------------
CHAPTER_KIND = [
    # the ticket's four, and the look-alike that once bound as Appendix 1
    ("bk-appendix-1-answer-key.md", "appendix", 1, True),
    ("bk-appendix-1-Answer-Key.md", "appendix", 1, False),
    ("bk-appendix-1-answer--key.md", "appendix", 1, False),
    ("bk-appendix-1-answer_key.md", "appendix", 1, False),
    ("sql-02-appendix-1-of-the-standard.md", "chapter", 2, True),
    ("guide-07-the-appendix-2-problem.md", "chapter", 7, True),
    # a two-digit appendix, which a chapter opening would read as chapter 10
    ("bk-appendix-10-ten.md", "appendix", 10, True),
    ("bk-appendix-01-zero.md", "appendix", 1, True),
    ("bk-03-three.md", "chapter", 3, True),
    ("bk-07-from-1nf-to-bcnf.md", "chapter", 7, True),
    # a name carrying no number by the rule is numbered by its position
    ("bk2-07-slug-digit.md", "chapter", 1, False),
    ("notes-v2.md", "chapter", 1, False),
    ("01-intro.md", "chapter", 1, False),
    ("bk-1-one-digit.md", "chapter", 1, False),
]
for name, kind, number, conforms in CHAPTER_KIND:
    f = model.classify([name], {})["files"][0]
    got = (f["kind"], f["number"], f["conforms"])
    report(got == (kind, number, conforms),
           f"model: {name} is {kind} {number}, {'conforming' if conforms else 'malformed'} (got {got})")

SKIPPED = [
    ("OUTLINE.md", {}, "excluded"),
    ("glossary.md", {}, "glossary"),
    ("about-this-book.md", {}, "front_matter"),
    ("terms.md", {"glossary_file": "terms.md"}, "glossary"),
    ("preface.md", {"front_matter_file": "preface.md"}, "front_matter"),
    ("blurb.md", {"description_file": "blurb.md"}, "excluded"),
    ("notes-draft.md", {"exclude": ["notes-draft.md"]}, "excluded"),
]
for name, cfg, kind in SKIPPED:
    f = model.classify([name], cfg)["files"][0]
    report(f["kind"] == kind, f"model: {name} under {cfg or 'no book.json'} is {kind} (got {f['kind']})")


def problems(names, cfg=None):
    return [(p["file"], p["rule"]) for p in model.classify(names, cfg or {})["problems"]]


report(problems(["bk-01-a.md", "bk-03-c.md"]) == [("bk-03-c.md", "position")],
       "model: a gap is a position problem on the file after it")
report(problems(["bk-appendix-01-zero.md"]) == [("bk-appendix-01-zero.md", "zero")],
       "model: an appendix number with a leading zero is its own problem")
report(problems(["bk-appendix-1-Answer-Key.md"]) == [("bk-appendix-1-Answer-Key.md", "name")],
       "model: a malformed appendix name is a name problem")
order = [f["name"] for f in model.chapters(model.classify(
    ["aa-appendix-1-key.md", "bk-01-one.md", "bk-02-two.md"], {}))]
report(order == ["bk-01-one.md", "bk-02-two.md", "aa-appendix-1-key.md"],
       f"model: the chapters come before an appendix that sorts first (got {order})")
parts = {f["name"]: f["part"] for f in model.chapters(model.classify(
    ["bk-01-one.md", "bk-02-two.md", "bk-appendix-1-key.md"],
    {"sections": [{"title": "Part One", "chapters": [1, 2, 3]}]}))}
report(parts == {"bk-01-one.md": "Part One", "bk-02-two.md": "Part One",
                 "bk-appendix-1-key.md": None},
       f"model: a part never takes in an appendix, whatever its range spans (got {parts})")

tmp = pathlib.Path(tempfile.mkdtemp())
atexit.register(shutil.rmtree, tmp, True)
marked = tmp / "bk-01-marked.md"
marked.write_text("<!-- src: notes -->\n# Intro\n\nBody.\n")
got = model.title_of(marked)[:3]
report(got == ("Intro", "h1", 2), f"model: a mark above the H1 does not hide the title (got {got})")

# ---------------------------------------------------------------------------
# Two: every tool, the same names.
#
# Each folder holds chapter 1 and one name under test, tagged with the unit the
# model gives it, under the guide profile, so an appendix is a kind every tool
# has. Expected numbers are the ones the name gets beside chapter 1: a name with
# no number by the rule is chapter 2 by position there.
# ---------------------------------------------------------------------------
CASES = [
    ("bk-appendix-1-answer-key.md", "appendix", 1, True),
    ("bk-appendix-1-Answer-Key.md", "appendix", 1, False),
    ("bk-appendix-1-answer--key.md", "appendix", 1, False),
    ("bk-appendix-1-answer_key.md", "appendix", 1, False),
    ("sql-02-appendix-1-of-the-standard.md", "chapter", 2, True),
    ("bk-appendix-10-ten.md", "appendix", 10, True),
    ("bk2-07-slug-digit.md", "chapter", 2, False),
    ("notes-v2.md", "chapter", 2, False),
]
BOOK = {"profile": "guide", "tags": True, "provenance": True,
        "sources": {"notes": "sources/notes.md"}}


def unit(kind, number):
    return f"A{number}" if kind == "appendix" else str(number)


def make_book(folder, files, cfg):
    (folder / "sources").mkdir(parents=True)
    (folder / "sources" / "notes.md").write_text("# Notes\n\nThe subject, in a sentence.\n")
    (folder / "book.json").write_text(json.dumps(cfg))
    for name, text in files.items():
        (folder / name).write_text(text)


def tagged(title, u):
    return f"# {title}\n\n[{u}-1] A sentence about the subject.\n<!-- src: notes -->\n"


folders = {}
for i, (name, kind, number, _) in enumerate(CASES):
    folders[name] = tmp / f"case-{i}"
    make_book(folders[name], {"bk-01-intro.md": tagged("Intro", "1"),
                              name: tagged("Case", unit(kind, number))}, BOOK)

# The skip list: one chapter, and every kind of file that is never one.
skips = tmp / "skips"
make_book(skips, {
    "bk-01-intro.md": tagged("Intro", "1"),
    "OUTLINE.md": "# Outline\n\nThe plan.\n",
    "blurb.md": "The book's description.\n",
    "terms.md": "# Glossary\n\n**subject** (ch. 1) What the book is about.\n",
    "preface.md": "# About this book\n\nWhere it came from.\n",
    "notes-draft.md": "# Draft\n\nNot a chapter.\n",
}, dict(BOOK, glossary=True, glossary_file="terms.md", front_matter_file="preface.md",
        description_file="blurb.md", exclude=["notes-draft.md"]))


def by_provenance(folder):
    out = tmp / ("wl-" + folder.name)
    subprocess.run([str(scripts / "check-provenance.sh"), "--emit-worklist", str(out),
                    str(folder)], capture_output=True, text=True)
    index = json.loads((out / "index.json").read_text())
    return {c["file"]: (c["kind"], c["number"]) for c in index["chapters"]}


def by_references(folder):
    held, _ = refs.units_of(refs.book_model.read(folder))
    return {name: (("appendix", int(u[1:])) if u.startswith("A") else ("chapter", int(u)))
            for u, name in held.items()}


def check_book(folder):
    return subprocess.run([str(scripts / "check-book.sh"), str(folder)],
                          capture_output=True, text=True).stdout


# A mark above the H1, for the title checks below.
title = tmp / "title"
make_book(title, {"bk-01-intro.md": "<!-- src: notes -->\n" + tagged("Intro", "1")}, BOOK)

# The binder, read through its own chapter records, in one venv process for
# every folder at once.
bound = None
if not venv.is_file():
    print(f"skip  binder: no venv at {venv}; run scripts/install.sh to compare the binder")
else:
    probe = tmp / "binder_probe.py"
    probe.write_text(
        "import importlib.machinery, importlib.util, json, pathlib, sys\n"
        "loader = importlib.machinery.SourceFileLoader('bb', sys.argv[1])\n"
        "spec = importlib.util.spec_from_loader('bb', loader)\n"
        "bb = importlib.util.module_from_spec(spec); loader.exec_module(bb)\n"
        "out = {}\n"
        "for d in sys.argv[2:]:\n"
        "    src = pathlib.Path(d)\n"
        "    out[d] = {ch['path'].name: ['appendix' if ch['appendix'] else 'chapter',\n"
        "              ch['label_num'], ch['title']]\n"
        "              for ch in bb.load_chapters(src, bb.book_model.read(src))}\n"
        "print(json.dumps(out))\n")
    r = subprocess.run([str(venv), "-I", str(probe), str(binder)]
                       + [str(f) for f in list(folders.values()) + [skips, title]],
                       capture_output=True, text=True)
    if r.returncode != 0:
        report(False, f"binder: its chapter records could not be read: {r.stderr.strip()[-300:]}")
        bound = {}
    else:
        bound = json.loads(r.stdout)

for name, kind, number, conforms in CASES:
    folder = folders[name]
    want = (kind, number)
    if bound is not None:
        got = tuple(bound.get(str(folder), {}).get(name, [None, None])[:2])
        report(got == want, f"binder: {name} binds as {kind} {number} (got {got})")
    got = by_provenance(folder).get(name)
    report(got == want, f"check-provenance.sh: {name} is {kind} {number} in the worklist index (got {got})")
    got = by_references(folder).get(name)
    report(got == want, f"check-references.sh: {name} is {kind} {number} (got {got})")
    out = check_book(folder)
    mine = [ln for ln in out.splitlines() if ln.startswith(f"FAIL  {name}:")]
    rejected = any("filename does not match" in ln for ln in mine)
    misread = [ln for ln in mine if re.search(
        r"but this is (chapter|appendix)|only an appendix carries|an appendix tags its", ln)]
    if conforms:
        report(not rejected and not misread,
               f"check-book.sh: {name} is graded as {kind} {number} {mine if mine else ''}".rstrip())
    else:
        report(rejected, f"check-book.sh: {name} is rejected by name, as the model calls it malformed")

# The skip list, as each tool sees it: one chapter, nothing else.
one = {"bk-01-intro.md": ("chapter", 1)}
if bound is not None:
    got = {n: tuple(v[:2]) for n, v in bound.get(str(skips), {}).items()}
    report(got == one, f"binder: binds only the chapter, skipping the outline, glossary, front matter, description and exclusions (got {sorted(got)})")
got = by_provenance(skips)
report(got == one, f"check-provenance.sh: emits only the chapter (got {sorted(got)})")
got = by_references(skips)
report(got == one, f"check-references.sh: reads only the chapter (got {sorted(got)})")
out = check_book(skips)
report("chapters: 1 " in out and "glossary: 1 terms" in out,
       "check-book.sh: grades only the chapter, and reads the renamed glossary as the glossary")

# Under narration the binder still binds an appendix as one, so check-book.sh
# names it as an appendix rather than grading it as a chapter.
narr = tmp / "narration"
make_book(narr, {"bk-01-intro.md": tagged("Intro", "1"),
                 "bk-appendix-10-ten.md": tagged("Ten", "A10")},
          {k: v for k, v in BOOK.items() if k != "profile"})
out = check_book(narr)
report("FAIL  bk-appendix-10-ten.md: is an appendix, which the narration profile has none of" in out
       and "is chapter 10" not in out,
       "check-book.sh: under narration an appendix is named as one, never graded as chapter 10")
got = by_provenance(narr).get("bk-appendix-10-ten.md")
report(got == ("appendix", 10), f"check-provenance.sh: under narration it is still appendix 10 (got {got})")

# A mark above the H1: the binder and check-book.sh both take the H1 as the title.
if bound is not None:
    got = bound.get(str(title), {}).get("bk-01-intro.md", [None, None, None])[2]
    report(got == "Intro", f"binder: a mark above the H1 does not cost the chapter its title (got {got!r})")
out = check_book(title)
report("first line is not an H1" not in out,
       "check-book.sh: a mark above the H1 does not cost the chapter its title")

# ---------------------------------------------------------------------------
# Three: no tool carries a filename rule of its own.
#
# A regex that reads an appendix number or a chapter number out of a filename,
# or a walk of the folder for chapters, is the copy this fixture exists to stop.
# A sweep that deliberately reads every markdown file, chapters or not, is not
# a classification and is not matched.
# ---------------------------------------------------------------------------
COPY = re.compile(r"appendix-(\(\\d|\[0-9\]|\(\[0-9\])|\\d\{2,\}|\[0-9\]\{2,\}"
                  r"|-name '\*\.md'|re\.search\(r\"\\d\+\", name\)")
for tool in (binder, scripts / "check-book.sh", scripts / "check-provenance.sh",
             scripts / "check-references.sh"):
    text = tool.read_text(encoding="utf-8")
    hits = [f"{n}: {ln.strip()}" for n, ln in enumerate(text.splitlines(), 1) if COPY.search(ln)]
    report(not hits, f"{tool.name}: carries no filename rule of its own {hits if hits else ''}".rstrip())
    report("book_model" in text, f"{tool.name}: reads the book model")

print()
print("OK    every tool classifies every file the way the model does" if not fails
      else "FAIL  a tool has drifted from the book model")
sys.exit(fails)
PY
