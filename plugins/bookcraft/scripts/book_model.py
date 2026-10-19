#!/usr/bin/env python3
"""What each file in a book folder is, decided once for every bookcraft tool.

    book_model.py [--json | --tsv] <book-folder>

The binder and the three checkers each used to carry their own copy of the
rules that say what a file is: which files are chapters, which are appendices,
what number each one has, which files are not part of the book at all. The
copies drifted. The appendix filename rule alone existed four times and no two
copies agreed, so a book could bind a file as a chapter that every checker
graded as an appendix, and that shipped. Every tool now asks this module
instead, so a rule about what a file is gets written once.

It answers at the file level, each `.md` file's kind, number, label, part and
title, plus two rules every reader of a line shares: what a fence is (`Fence`)
and what a whole-line provenance mark is (`MARK_LINE`). What else sits inside a
chapter (paragraph tags, which paragraph a mark covers) is still each tool's
own business; #72 settled that as D1 (`changelog/72-*/CHANGELOG.md`).

The rules, as settled on #82 (`changelog/82-*/CHANGELOG.md`, R1 to R10):

  Kind and number come from the opening of the name (R1, R2). An appendix opens
  `<book-slug>-appendix-<N>-` and a chapter `<book-slug>-<NN>-`, where the book
  slug is lowercase ASCII letters and dashes. The appendix opening is tried
  first, because a chapter opening would also match `bk-appendix-10-` and read
  it as chapter 10. A chapter whose name carries no number is numbered by its
  position among the chapters, which is what lets the binder bind a plain
  folder of notes.

  Whether the name conforms is a separate question, answered by the whole name
  (`createbook/SKILL.md § Filenames`). A malformed name keeps the kind and
  number its opening gives it: `bk-appendix-1-Answer-Key.md` is appendix 1 with
  a malformed name, never chapter 5.

  Numbers count within each kind, and the reading order is the chapters, then
  the appendices, each in filename order.

  Skipped, never chapters (R3): `OUTLINE.md`, book.json's `description_file`,
  its `glossary_file` (default `glossary.md`) and `front_matter_file` (default
  `about-this-book.md`), and everything in its `exclude`.

  A `sections` part holds chapters by number, never an appendix (R5).

  The title is line 1 once whole-line provenance marks are stripped, when that
  line is an H1, and otherwise comes from the filename (R10).

Python consumers load this file by path and call `read` or `classify`.
`check-book.sh` runs it with `--tsv` and reads tab-separated rows, which is why
it also hands back the book.json declarations that script used to read through
jq. `--json` prints the whole model for a person to read.

The standard library only, and Python 3.9: the checkers run under whatever
`python3` is on PATH, and on a stock Mac that is 3.9.

Exits 0 with the model, 2 when the folder or book.json cannot be read.
"""
from __future__ import annotations

import json
import pathlib
import re
import sys

OUTLINE = "OUTLINE.md"
DEFAULT_GLOSSARY = "glossary.md"
DEFAULT_FRONT_MATTER = "about-this-book.md"

# The opening of a name, which settles its kind and its number. ASCII by
# construction: `[0-9]` rather than `\d`, which in Python also matches digits
# from other scripts, and the shell checkers never could.
APPENDIX_OPENING = re.compile(r"[a-z]+(?:-[a-z]+)*-appendix-([0-9]+)-")
CHAPTER_OPENING = re.compile(r"[a-z]+(?:-[a-z]+)*-([0-9]{2,})-")

# The whole name, which settles whether it conforms. These are the two patterns
# check-book.sh enforced, unchanged.
APPENDIX_NAME = re.compile(r"[a-z]+(?:-[a-z]+)*-appendix-[0-9]+-[a-z0-9]+(?:-[a-z0-9]+)*\.md")
CHAPTER_NAME = re.compile(r"[a-z]+(?:-[a-z]+)*-[0-9]{2,}-[a-z0-9]+(?:-[a-z0-9]+)*\.md")

CHAPTER_KINDS = ("chapter", "appendix")

# A provenance mark is working metadata on a line of its own, stripped before
# the title is read so a mark above the H1 does not hide it. The binder strips
# the same lines from the page with this same pattern.
MARK_LINE = re.compile(r"^[ \t]*<!--[ \t]*src:.*?-->[ \t]*$\n?", re.M)

# A fence opening, by CommonMark's rule as #82's R9 settled it: three or more
# backticks or tildes. Indentation is not measured. CommonMark measures it
# against the enclosing list item, which a line reader cannot see, and every
# checker has always accepted an indented fence so that one inside a list item
# counts.
FENCE_OPENING = re.compile(r"[ \t]*(`{3,}|~{3,})(.*)")

# A name or a key that holds one of these cannot travel in a --tsv row.
UNSAFE = re.compile(r"[\t\n\r]")


class ModelError(Exception):
    """The folder or its book.json cannot be read into a model."""


class Fence:
    """Which lines, fed in order, belong to a fenced code block.

        fence = Fence()
        for line in lines:
            if fence.step(line):
                continue    # an opening line, a closing line, or a line inside

    Only a run of the opening's character at least as long as the opening, with
    nothing else on its line, closes a fence, and a backtick opening's info
    string may not hold a backtick, so a line reading ```x``` is inline code
    rather than a fence. A fence nothing closes runs to the end of the file, as
    in CommonMark, so a caller reading several files makes one per file: an
    unclosed fence in one chapter must not swallow the next.

    Every fence reader in the checkers calls this, so they agree on what a fence
    is by construction rather than by review. Before it each toggled on a line
    starting with three backticks: a `~~~` block was read as prose, and a
    ```` ``` ```` line inside a four-backtick fence closed it.
    """

    def __init__(self):
        self.opening = None     # the run that opened the fence now open, e.g. "```"
        self.line = 0           # how many lines have been read
        self.opened_at = 0      # the line that opened the fence now open

    def step(self, line: str) -> bool:
        """Read the next line; True when it opens, closes or sits inside a fence."""
        self.line += 1
        if self.opening is not None:
            run = line.strip()
            if len(run) >= len(self.opening) and not run.strip(self.opening[0]):
                self.opening = None
            return True
        m = FENCE_OPENING.fullmatch(line.rstrip("\r\n"))
        if m and not (m.group(1)[0] == "`" and "`" in m.group(2)):
            self.opening, self.opened_at = m.group(1), self.line
            return True
        return False


def load_config(folder: pathlib.Path) -> dict:
    """book.json as a dict, or {} when the folder has none."""
    path = folder / "book.json"
    if not path.is_file():
        return {}
    try:
        cfg = json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, UnicodeDecodeError) as exc:
        raise ModelError(f"{path} is not valid JSON ({exc})")
    if not isinstance(cfg, dict):
        raise ModelError(f"{path} must hold a JSON object")
    return cfg


def _file_key(cfg: dict, key: str, default: str | None) -> str | None:
    val = cfg.get(key)
    if val is None:
        return default
    if not isinstance(val, str) or not val or UNSAFE.search(val):
        raise ModelError(f'book.json "{key}" must name a file, not: {val!r}')
    return val


def glossary_file(cfg: dict) -> str:
    return _file_key(cfg, "glossary_file", DEFAULT_GLOSSARY)


def front_matter_file(cfg: dict) -> str:
    return _file_key(cfg, "front_matter_file", DEFAULT_FRONT_MATTER)


def skipped(cfg: dict) -> dict[str, dict]:
    """Every name that is never a chapter, with what it is instead.

    The glossary and the front matter are skipped by name whether or not
    `exclude` lists them, and so is `OUTLINE.md`: left to `exclude`, a forgotten
    line binds the file as a chapter, which reads like an editorial choice
    rather than a mistake.
    """
    exclude = cfg.get("exclude", [])
    if not isinstance(exclude, list) or not all(isinstance(e, str) for e in exclude):
        raise ModelError('book.json "exclude" must be a list of filenames')
    out: dict[str, dict] = {}
    out.setdefault(glossary_file(cfg), {"kind": "glossary"})
    out.setdefault(front_matter_file(cfg), {"kind": "front_matter"})
    out.setdefault(OUTLINE, {"kind": "excluded", "why": "outline"})
    desc = _file_key(cfg, "description_file", None)
    if desc:
        out.setdefault(desc, {"kind": "excluded", "why": "description_file"})
    for name in exclude:
        out.setdefault(name, {"kind": "excluded", "why": "exclude"})
    return out


def _sections(cfg: dict) -> list[dict]:
    sections = cfg.get("sections") or []
    if not isinstance(sections, list) or not all(isinstance(s, dict) for s in sections):
        raise ModelError('book.json "sections" must be a list of objects')
    return sections


def classify(names, cfg: dict) -> dict:
    """The model from a list of filenames and a config, touching no file.

    Kept apart from `read` so a name can be classified without the file
    existing: check-references.sh classifies a baseline commit's names from
    `git ls-tree`, and the agreement fixture classifies names a case-insensitive
    disk could not hold side by side.
    """
    skip = skipped(cfg)
    sections = _sections(cfg)
    kinds: dict[str, list[dict]] = {k: [] for k in CHAPTER_KINDS}
    others: list[dict] = []
    for name in sorted(n for n in names if n.endswith(".md")):
        if UNSAFE.search(name):
            raise ModelError(f"{name!r}: a filename holding a tab or a line break "
                             "cannot be read")
        if name in skip:
            others.append({"name": name, **skip[name]})
            continue
        m = APPENDIX_OPENING.match(name)
        kind = "appendix" if m else "chapter"
        if not m:
            m = CHAPTER_OPENING.match(name)
        kinds[kind].append({"name": name, "kind": kind,
                            "digits": m.group(1) if m else None})

    problems: list[dict] = []
    for kind, recs in kinds.items():
        whole = APPENDIX_NAME if kind == "appendix" else CHAPTER_NAME
        for pos, rec in enumerate(recs, 1):
            name, digits = rec["name"], rec.pop("digits")
            named = int(digits) if digits is not None else None
            number = pos if named is None else named
            rec.update({
                "number": number,
                "name_number": named,
                "position": pos,
                "conforms": bool(whole.fullmatch(name)),
                "label": f"{'Appendix' if kind == 'appendix' else 'Chapter'} {number}",
                "unit": f"A{number}" if kind == "appendix" else str(number),
                "part": None if kind == "appendix" else next(
                    (s.get("title") for s in sections
                     if number in (s.get("chapters") or [])), None),
            })
            problems.extend(_name_problems(rec, digits))
    files = kinds["chapter"] + kinds["appendix"] + others
    return {"files": files, "problems": problems,
            "glossary_file": glossary_file(cfg),
            "front_matter_file": front_matter_file(cfg)}


def _name_problems(rec: dict, digits: str | None) -> list[dict]:
    """What is wrong with one chapter-kind file's name, as check-book.sh words it.

    A malformed name reports only that: its position is not graded, since its
    content is not examined either. A leading zero on an appendix number
    replaces the position check, as it always has.
    """
    name, kind = rec["name"], rec["kind"]
    if not rec["conforms"]:
        shape = ("<book-slug>-appendix-<N>-<slug>.md" if kind == "appendix"
                 else "<book-slug>-<NN>-<chapter-slug>.md")
        return [{"file": name, "rule": "name",
                 "text": f"{name}: filename does not match {shape} "
                         "(lowercase and dashes; no digit in the book slug)"}]
    if kind == "appendix" and digits != str(int(digits)):
        return [{"file": name, "rule": "zero",
                 "text": f"{name}: appendix numbers carry no leading zeros"}]
    if rec["number"] != rec["position"]:
        where = ("among the appendices" if kind == "appendix"
                 else "in filename sort order")
        return [{"file": name, "rule": "position",
                 "text": f"{name}: is {kind} {rec['number']} but sits at position "
                         f"{rec['position']} {where}"}]
    return []


def prettify(stem: str) -> str:
    """Turn '03-why-models-matter' into 'Why Models Matter'."""
    s = re.sub(r"^[\W_]*\d+[\W_]+", "", stem)
    s = re.sub(r"[-_]+", " ", s).strip()
    return s[:1].upper() + s[1:] if s else stem


def title_of(path: pathlib.Path) -> tuple[str, str, int, str | None]:
    """(title, where it came from, the H1's line number or 0, problem).

    The title is the first line that is not a whole-line provenance mark, when
    that line is an H1, and otherwise the prettified filename. The line number
    is the H1's in the file as written, so check-book.sh can start the body
    below it even when a mark sits above it.
    """
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return prettify(path.stem), "filename", 0, f"{path.name}: is not UTF-8"
    for n, line in enumerate(text.splitlines(keepends=True), 1):
        if MARK_LINE.fullmatch(line):
            continue
        line = line.rstrip("\r\n")
        if line.startswith("# "):
            return line[2:].strip(), "h1", n, None
        break
    return prettify(path.stem), "filename", 0, None


def read(folder) -> dict:
    """The model of a book folder: book.json, every `.md` file one level down,
    and each chapter-kind file's title."""
    folder = pathlib.Path(folder)
    if not folder.is_dir():
        raise ModelError(f"{folder} is not a directory")
    cfg = load_config(folder)
    names = [p.name for p in folder.iterdir() if p.name.endswith(".md") and p.is_file()]
    book = classify(names, cfg)
    book["folder"] = str(folder)
    book["config"] = cfg
    for rec in chapters(book):
        (rec["title"], rec["title_from"], rec["title_line"],
         problem) = title_of(folder / rec["name"])
        if problem:
            book["problems"].append({"file": rec["name"], "rule": "encoding",
                                     "text": problem})
    return book


def chapters(book: dict) -> list[dict]:
    """The chapter-kind files in reading order: chapters, then appendices."""
    return [f for f in book["files"] if f["kind"] in CHAPTER_KINDS]


def chapter_numbers(book: dict) -> set[int]:
    """The numbers a `ch. N` or a glossary's `(ch. N)` may name: chapters only,
    since an appendix never teaches (`createbook/reference/guide.md § Appendices`)."""
    return {f["number"] for f in book["files"] if f["kind"] == "chapter"}


# ---------------------------------------------------------------------------
# --tsv, for check-book.sh
# ---------------------------------------------------------------------------

# One row per line, fields split by tabs. bash's `read` treats a tab as
# whitespace and collapses a run of them, so an empty field would shift every
# field after it: no field is ever empty except a row's last. A declaration that
# would print as the empty string is left out, which check-book.sh reads exactly
# as it read jq's empty output, as absent.
#
#   decl     <key> <value>
#   setting  glossary_file|front_matter_file <name>
#   source   <key> <1 when it has a display name, else 0>
#   file     <kind> <number> <position> <1|0 conforms> <h1|filename>
#            <the H1's line, or 0> <name> <title>
#   problem  <name> <name|zero|position|encoding> <text>
#
# The declarations check-book.sh validates itself. Each is handed over as jq's
# `tostring` printed it, so the script's validation reads the value it always
# read: true as "true", a string as the string, an object as compact JSON.
DECLARATIONS = ("glossary", "tags", "provenance", "suggested_reading", "overview")


def _tostring(val) -> str:
    out = val if isinstance(val, str) else json.dumps(val, separators=(",", ":"),
                                                      ensure_ascii=False)
    return UNSAFE.sub(" ", out)


def tsv_rows(book: dict) -> list[list[str]]:
    cfg = book.get("config", {})
    rows = []
    for key in DECLARATIONS:
        if key in cfg and _tostring(cfg[key]):
            rows.append(["decl", key, _tostring(cfg[key])])
    # `.profile // empty` was the read: null and false meant absent, and nothing
    # else did. Tested by identity, since `0 in (None, False)` is true in Python
    # and would read "profile": 0 as absent rather than refuse it.
    profile = cfg.get("profile")
    if profile is not None and profile is not False and _tostring(profile):
        rows.append(["decl", "profile", _tostring(profile)])
    rows.append(["setting", "glossary_file", book["glossary_file"]])
    rows.append(["setting", "front_matter_file", book["front_matter_file"]])
    sources = cfg.get("sources")
    if isinstance(sources, dict):
        for key in sorted(k for k in sources if k):
            if UNSAFE.search(key):
                raise ModelError(f"book.json source key {key!r} holds a tab or a "
                                 "line break")
            val = sources[key]
            display = (isinstance(val, dict) and isinstance(val.get("display"), str)
                       and len(val["display"]) > 0)
            rows.append(["source", key, "1" if display else "0"])
    for f in chapters(book):
        rows.append(["file", f["kind"], str(f["number"]), str(f["position"]),
                     "1" if f["conforms"] else "0", f["title_from"],
                     str(f["title_line"]), f["name"],
                     UNSAFE.sub(" ", f["title"])])
    for p in book["problems"]:
        rows.append(["problem", p["file"], p["rule"], p["text"]])
    return rows


def main(argv: list[str]) -> int:
    args = argv[1:]
    mode = "--json"
    if args and args[0] in ("--json", "--tsv"):
        mode = args.pop(0)
    if len(args) != 1:
        print(__doc__.strip().splitlines()[2].strip(), file=sys.stderr)
        return 2
    try:
        book = read(args[0])
        if mode == "--tsv":
            out = "".join("\t".join(r) + "\n" for r in tsv_rows(book))
        else:
            out = json.dumps(book, indent=2, ensure_ascii=False) + "\n"
    except ModelError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    sys.stdout.write(out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
