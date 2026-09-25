#!/usr/bin/env python3
"""Write a book's assertions.json, list it, and define its format.

    assertions.sh {init,add,supersede,retire,correct,expect,list,check} <book-folder> [options]

A book rests on its sources and on everything it was told or settled along the
way. `book.json` records the sources, and any later run can open them again.
The rest had no home. It lived in chapter prose, in `OUTLINE.md` revision notes
keyed by paragraph tag, and in commit history, so a recreate from the outline
and the sources dropped it. `assertions.json`, beside `book.json`, is its home:
every claim the book stands behind that a fresh /createbook run would not
reproduce from the brief and the sources alone.

**This script is the file's only writer and the only definition of its
format.** No JSON Schema ships beside it and no validator library is added to
the venv. `check` is the format, and any other reader imports `load` from here
instead of parsing the file itself, so the file is never read two different
ways. The import is by path, the way check-provenance.sh borrows from
check-references.sh, and the entry point below is guarded so it runs nothing. createbook/SKILL.md § The assertions
file describes the fields for a person. Where the two disagree, this is right.

**Every write validates the whole file twice.** Before, it refuses to write
onto a file that already fails, because a change layered on a broken file
hides the break. After, it refuses to write a file that would fail. So the
helper cannot leave behind a file `check` rejects, and a flag left off a command
is reported as the key it would have written: `add --kind premise` with no
`--search` is refused because "a premise needs search".

## The commands

  init <book> --how createbook --argument TEXT --reader TEXT
       --reader-origin O --profile-origin O [--reader-inferred TEXT] [--date D]
  init <book> --how backfill --from WHAT [--from WHAT ...]
       --candidates N --confirmed N --reader TEXT --reader-origin O
       --profile-origin O [--argument TEXT] [--reader-inferred TEXT] [--date D]

      Creates the file with its `created` and `brief` blocks and no entries,
      and refuses a folder that already has one. A backfill may leave
      --argument off, which writes it as null, and may give an origin as
      `unrecorded`. A book written before this file existed never saved its
      /createbook argument, and a paraphrase recorded as the verbatim argument
      is exactly what the field exists to prevent.

  add <book> --kind K --statement TEXT --by B [--how TEXT] [--date D]
      --applies-to prose|book [--citation expected|legacy]
      [--reaches TEXT --search PHRASE [--search PHRASE ...]]    a premise
      [--ran TEXT --on TEXT --result TEXT]                      a measured
      [--acted-on TEXT]                                         an adopted
      [--corrects TEXT] [--answer ITEM ANSWER ...]              a settled

      Appends one entry under the next ID. A prose entry's citation defaults
      to `expected`. A backfill passes `--citation legacy`.

  supersede <book> <id> --statement TEXT --by B [--how TEXT] [--date D]
      [--kind K] [--applies-to A] [--citation C] [--reaches TEXT]
      [--search PHRASE ...] [the kind's own flags]

      Appends the replacement and writes both links in one step: the old
      entry becomes `superseded` with `superseded_by`, and the new one
      carries `supersedes`. The kind, applies_to and a premise's `reaches`
      carry over unless given again. A premise's `search` never carries over,
      because those phrases find prose built on the OLD value, and the sweep
      for a superseded premise depends on the two sets differing.

  retire <book> <id> --reason TEXT

  correct <book> <id> --item ITEM --answer ANSWER [--date D]

      Changes one answer in a settled entry's `answers` set in place, and
      stamps `corrected` with the date and `was` with the answer it replaces.
      Superseding the whole set to change one answer would copy every other
      answer for no reason. A backfill replays a correction the same way: add
      the entry with the answer as first derived, then `correct` it with
      --date set to the day of the commit that fixed it.

  expect <book> <id> [<id> ...]
  expect <book> --all

      Turns a `legacy` entry into `expected`, once every paragraph resting on
      it carries a mark citing it. --all does it for every holding legacy
      entry, which is what a recreate does, because it rewrites every mark.

  list <book>     The table to show the operator at a gate, in place of the
                  raw JSON.
  check <book>    Every rule below.

A value that begins with a hyphen is passed as --flag=value. Dates are
YYYY-MM-DD and default to today.

## What check enforces

  * The file is one JSON object, and no object in it repeats a key. Python's
    parser keeps the last of two repeated keys and drops the first without a
    word, so a hand-merged file could lose an entry's status and still parse.
  * `format` is 1. A newer number stops every command with a message to update
    bookcraft, because a newer file is never guessed at.
  * No key is unknown anywhere in the file. A misspelt key is the likeliest
    error, so the failure names the nearest key that exists, or the kind a key
    belongs to when it sits on an entry of another kind.
  * `created` says how the file came to exist: `createbook`, or `backfill` with
    what was read and how many candidates were confirmed. It is required even
    with no entries, because it is the only thing telling a file that searched
    and found nothing from one written to get past a presence check.
  * `brief` holds the argument verbatim, the persona, and where each came from.
    Only a backfill may leave the argument null or an origin `unrecorded`.
  * Every ID from 1 to `next_id - 1` is present exactly once. Entries are
    retired, never deleted, and `next_id` is the high-water mark. Without it,
    deleting the newest entry would hand its ID to the next one added, and a
    mark citing the old ID would resolve cleanly to a different claim.
  * Kinds, origins, statuses, `applies_to` and `citation` come from fixed sets.
    A `given` entry is by the operator. `measurement` is the origin of a
    `measured` entry and of no other kind.
  * `citation` appears on a prose entry and never on a book one, and `legacy`
    appears only in a backfilled file: a file /createbook started predates
    every paragraph, so none can have been written before it.
  * A supersession's two links agree, and an entry supersedes only an older
    one, which rules out a cycle. `superseded_by` appears only on a superseded
    entry and `retired_reason` only on a retired one.
  * A premise carries `reaches` and `search`, a measured entry `measurement`,
    an adopted one `acted_on`. A settled entry's `answers`, where it has one,
    is not empty, no item appears twice, and `corrected` and `was` come as a
    pair.

## Exit codes

0 when the command did what it says. 1 when it refused, which for `check`
means the file fails. 2 on bad usage, or when there is nothing to work on: no
such folder, no assertions.json, or a format newer than this script knows.
"""
import sys, os, re, json, pathlib, argparse, datetime, difflib, tempfile

FILE = "assertions.json"
FORMAT = 1

KINDS = ("given", "ruling", "premise", "adopted", "measured", "settled")
STATUSES = ("holds", "superseded", "retired")
BY = ("operator", "book", "measurement")
APPLIES = ("prose", "book")
CITATIONS = ("expected", "legacy")
HOWS = ("createbook", "backfill")
ORIGINS = ("argument", "operator", "inferred", "unrecorded")

# Key order is fixed, so that every write of an unchanged entry is byte-identical
# and a change shows in a diff as the lines of the entry it touched.
TOP_KEYS = ("format", "created", "brief", "next_id", "entries")
CREATED_KEYS = {
    "createbook": ("date", "how"),
    "backfill": ("date", "how", "from", "candidates", "confirmed"),
}
BRIEF_KEYS = ("argument", "reader", "reader_origin", "reader_inferred",
              "profile_origin")
ORIGIN_KEYS = ("by", "how", "date")
MEASUREMENT_KEYS = ("ran", "on", "result")
ANSWER_KEYS = ("item", "answer", "corrected", "was")
ENTRY_HEAD = ("id", "kind", "statement", "origin")
KIND_KEYS = {
    "given": (),
    "ruling": (),
    "premise": ("reaches", "search"),
    "adopted": ("acted_on",),
    "measured": ("measurement",),
    "settled": ("corrects", "answers"),
}
REQUIRED_KIND_KEYS = {
    "premise": ("reaches", "search"),
    "adopted": ("acted_on",),
    "measured": ("measurement",),
}
ENTRY_TAIL = ("applies_to", "citation", "status", "supersedes",
              "superseded_by", "retired_reason")
ENTRY_KEYS = (ENTRY_HEAD
              + tuple(k for ks in KIND_KEYS.values() for k in ks)
              + ENTRY_TAIL)
OWNER = {k: kind for kind, ks in KIND_KEYS.items() for k in ks}

DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


class TooNew(Exception):
    """The file declares a format newer than this script knows."""


def too_new(path, fmt):
    """What every reader says on a newer file. One wording, so none drifts."""
    return (f"{path} is format {fmt}, and this bookcraft reads format {FORMAT}. "
            f"Update bookcraft; a newer file is never guessed at")


# --------------------------------------------------------------------------
# Reading
# --------------------------------------------------------------------------

def _no_repeated_keys(pairs):
    out = {}
    for k, v in pairs:
        if k in out:
            raise ValueError(f"the key {json.dumps(k)} appears twice in one "
                             f"object, and JSON keeps only the last of them")
        out[k] = v
    return out


def load(path):
    """Read one assertions.json and return (doc, problems).

    `doc` is None when the text is not a JSON object, and `problems` then holds
    the one reason. Raises FileNotFoundError when there is no file, and TooNew
    when it declares a newer format than FORMAT.
    """
    text = pathlib.Path(path).read_text(encoding="utf-8")
    try:
        doc = json.loads(text, object_pairs_hook=_no_repeated_keys)
    except ValueError as e:
        # JSONDecodeError is a ValueError, and so is the repeated-key refusal.
        return None, [f"the file is not valid JSON: {e}"]
    if not isinstance(doc, dict):
        return None, ["the file is not a JSON object"]
    return doc, problems_in(doc)


# --------------------------------------------------------------------------
# The format
# --------------------------------------------------------------------------

def _int(x):
    # bool is a subclass of int, and `true` is not an ID.
    return type(x) is int


def _text(x):
    return isinstance(x, str) and x.strip() != ""


def _date(x):
    if not isinstance(x, str) or not DATE.match(x):
        return False
    try:
        datetime.date.fromisoformat(x)
    except ValueError:
        return False
    return True


def _fold(s):
    return " ".join(s.split()).casefold()


def _q(x):
    return json.dumps(x, ensure_ascii=False)


def _is(obj, key):
    """What a message says a key holds: its value, or that it is missing."""
    return _q(obj[key]) if key in obj else "missing"


def problems_in(doc):
    """Every way `doc` departs from the format. An empty list means it passes.

    Raises TooNew before looking at anything else, because the rest of these
    rules describe format 1 and would misreport a newer file's new keys.
    """
    out = []
    bad = out.append

    fmt = doc.get("format")
    if _int(fmt) and fmt > FORMAT:
        raise TooNew(fmt)

    def unknown(obj, allowed, where, entry=False):
        for k in obj:
            if k in allowed:
                continue
            msg = f"{where}: unknown key {_q(k)}"
            if k in OWNER and entry:
                msg += f"; that is a {OWNER[k]}'s key"
            else:
                near = difflib.get_close_matches(k, list(allowed), n=1)
                if near:
                    msg += f" (did you mean {_q(near[0])}?)"
            bad(msg)

    unknown(doc, TOP_KEYS, "the file")
    for k in TOP_KEYS:
        if k not in doc and k != "created":
            bad(f"the file has no {_q(k)}")

    if "format" in doc and not (_int(fmt) and fmt == FORMAT):
        bad(f"format is {_q(fmt)}; this bookcraft reads format {FORMAT}")

    entries = doc.get("entries")
    if "entries" in doc and not isinstance(entries, list):
        bad("entries is not a list")
        entries = []
    entries = entries or []

    # created
    how = None
    c = doc.get("created")
    if "created" not in doc:
        if entries:
            bad("the file has no \"created\" block saying how it came to exist")
        else:
            bad("the file has no \"created\" block. With no entries, that block "
                "is the only thing telling a file that searched and found "
                "nothing from one written to get past the presence check")
    elif not isinstance(c, dict):
        bad("created is not an object")
    else:
        how = c.get("how")
        if how not in HOWS:
            bad(f"created.how is {_is(c, 'how')}; it is one of "
                f"{', '.join(HOWS)}")
            how = None
            unknown(c, CREATED_KEYS["backfill"], "created")
        else:
            if how == "createbook":
                for k in CREATED_KEYS["backfill"]:
                    if k in c and k not in CREATED_KEYS["createbook"]:
                        bad(f"created.{k} records what a backfill read, and "
                            f"/createbook started this file")
            unknown(c, CREATED_KEYS["backfill"] if how == "createbook"
                    else CREATED_KEYS[how], "created")
        if not _date(c.get("date")):
            bad(f"created.date is {_is(c, 'date')}, not a YYYY-MM-DD date")
        if how == "backfill":
            src = c.get("from")
            if not (isinstance(src, list) and src and all(_text(s) for s in src)):
                bad("created.from must list what the backfill read, one or "
                    "more non-empty strings")
            cand, conf = c.get("candidates"), c.get("confirmed")
            for name, v in (("candidates", cand), ("confirmed", conf)):
                if not (_int(v) and v >= 0):
                    bad(f"created.{name} is {_is(c, name)}, not a whole number "
                        f"from 0")
            if _int(cand) and _int(conf) and conf > cand:
                bad(f"created.confirmed is {conf}, more than the {cand} "
                    f"candidates")

    backfill = how == "backfill"

    # brief
    b = doc.get("brief")
    if "brief" in doc and not isinstance(b, dict):
        bad("brief is not an object")
    elif isinstance(b, dict):
        unknown(b, BRIEF_KEYS, "brief")
        if "argument" not in b:
            bad("brief has no \"argument\"")
        elif b["argument"] is None:
            if not backfill:
                bad("brief.argument is null, which only a backfilled file may "
                    "write; a file /createbook started has the argument in hand")
        elif not _text(b["argument"]):
            bad("brief.argument must be the /createbook argument, verbatim")
        if not _text(b.get("reader")):
            bad("brief.reader must be the persona, as one sentence")
        for key in ("reader_origin", "profile_origin"):
            v = b.get(key)
            if v not in ORIGINS:
                bad(f"brief.{key} is {_is(b, key)}; it is one of "
                    f"{', '.join(ORIGINS)}")
            elif v == "unrecorded" and not backfill:
                bad(f"brief.{key} is \"unrecorded\", which only a backfilled "
                    f"file may write")
        if "reader_inferred" in b:
            if not _text(b["reader_inferred"]):
                bad("brief.reader_inferred must name the part of the persona "
                    "that was inferred")
            elif b.get("reader_origin") not in ("argument", "operator"):
                bad("brief.reader_inferred names the inferred part of a "
                    "persona that was otherwise given, and this one's origin is "
                    f"{_q(b.get('reader_origin'))}")

    # next_id
    nid = doc.get("next_id")
    if "next_id" in doc and not (_int(nid) and nid >= 1):
        bad(f"next_id is {_q(nid)}, not a whole number from 1")
        nid = None

    # entries, one at a time
    by_id = {}
    for n, e in enumerate(entries):
        if not isinstance(e, dict):
            bad(f"entries[{n}] is not an object")
            continue
        eid = e.get("id")
        if not (_int(eid) and eid >= 1):
            bad(f"entries[{n}]: id is {_is(e, 'id')}, not a whole number from 1")
            where = f"entries[{n}]"
            eid = None
        else:
            where = f"entry {eid}"
            if eid in by_id:
                bad(f"{where}: the ID is used twice")
            else:
                by_id[eid] = e

        kind = e.get("kind")
        if kind not in KINDS:
            bad(f"{where}: kind is {_is(e, 'kind')}; it is one of "
                f"{', '.join(KINDS)}")
            kind = None
        allowed = ENTRY_HEAD + ENTRY_TAIL + (KIND_KEYS[kind] if kind else
                                             tuple(OWNER))
        unknown(e, allowed, where, entry=True)

        if not _text(e.get("statement")):
            bad(f"{where}: statement must be the claim, in one sentence")

        o = e.get("origin")
        if not isinstance(o, dict):
            bad(f"{where}: origin must be an object with by and date")
        else:
            unknown(o, ORIGIN_KEYS, f"{where} origin")
            by = o.get("by")
            if by not in BY:
                bad(f"{where}: origin.by is {_is(o, 'by')}; it is one of "
                    f"{', '.join(BY)}")
            elif kind == "measured" and by != "measurement":
                bad(f"{where}: a measured entry's origin.by is \"measurement\"")
            elif kind and kind != "measured" and by == "measurement":
                bad(f"{where}: origin.by is \"measurement\", which belongs to a "
                    f"measured entry, and this is a {kind}")
            elif kind == "given" and by != "operator":
                bad(f"{where}: a given entry is a fact the operator supplied, so "
                    f"origin.by is \"operator\"")
            if "how" in o and not _text(o["how"]):
                bad(f"{where}: origin.how, where present, must say how")
            if not _date(o.get("date")):
                bad(f"{where}: origin.date is {_is(o, 'date')}, not a "
                    f"YYYY-MM-DD date")

        applies = e.get("applies_to")
        if applies not in APPLIES:
            bad(f"{where}: applies_to is {_is(e, 'applies_to')}; it is prose "
                f"or book")
        cit = e.get("citation")
        if applies == "prose":
            if cit not in CITATIONS:
                bad(f"{where}: a prose entry's citation is expected or legacy, "
                    f"and it is {_is(e, 'citation')}")
            elif cit == "legacy" and how == "createbook":
                bad(f"{where}: citation is legacy, but /createbook started this "
                    f"file, so no paragraph was written before it")
        elif applies == "book" and "citation" in e:
            bad(f"{where}: citation is for a prose entry; this one governs the "
                f"whole book, so no mark cites it")

        status = e.get("status")
        if status not in STATUSES:
            bad(f"{where}: status is {_is(e, 'status')}; it is one of "
                f"{', '.join(STATUSES)}")
        if status == "superseded":
            if not _int(e.get("superseded_by")):
                bad(f"{where}: a superseded entry names its replacement in "
                    f"superseded_by")
        elif "superseded_by" in e:
            bad(f"{where}: superseded_by {_q(e['superseded_by'])}, but its "
                f"status is {_q(status)}")
        if status == "retired":
            if not _text(e.get("retired_reason")):
                bad(f"{where}: a retired entry says why in retired_reason")
        elif "retired_reason" in e:
            bad(f"{where}: retired_reason is given, but its status is "
                f"{_q(status)}")
        if "supersedes" in e:
            sp = e["supersedes"]
            if not _int(sp):
                bad(f"{where}: supersedes is {_q(sp)}, not an ID")
            elif eid is not None and sp >= eid:
                bad(f"{where}: supersedes {sp}, and a replacement is always "
                    f"newer than the entry it replaces")

        for k in REQUIRED_KIND_KEYS.get(kind, ()):
            if k not in e:
                bad(f"{where}: a {kind} needs {k}")
        if "reaches" in e and not _text(e["reaches"]):
            bad(f"{where}: reaches must say what the premise reaches")
        if "search" in e:
            s = e["search"]
            if not (isinstance(s, list) and s and all(_text(x) for x in s)):
                bad(f"{where}: search must list one or more phrases that find "
                    f"prose built on the premise")
            elif len({_fold(x) for x in s}) != len(s):
                bad(f"{where}: search lists the same phrase twice")
        if "acted_on" in e and not _text(e["acted_on"]):
            bad(f"{where}: acted_on must say what the operator did with it")
        if "measurement" in e:
            m = e["measurement"]
            if not isinstance(m, dict):
                bad(f"{where}: measurement must be an object with ran, on and "
                    f"result")
            else:
                unknown(m, MEASUREMENT_KEYS, f"{where} measurement")
                for k in MEASUREMENT_KEYS:
                    if not _text(m.get(k)):
                        bad(f"{where}: measurement.{k} is missing or empty")
        if "corrects" in e and not _text(e["corrects"]):
            bad(f"{where}: corrects must hold the reading the entry replaces")
        if "answers" in e:
            a = e["answers"]
            if not isinstance(a, list) or not a:
                bad(f"{where}: answers must list one or more items; leave the "
                    f"key out of an entry that settles a single fact")
            else:
                seen = set()
                for i, x in enumerate(a):
                    w = f"{where} answers[{i}]"
                    if not isinstance(x, dict):
                        bad(f"{w} is not an object")
                        continue
                    unknown(x, ANSWER_KEYS, w)
                    if not _text(x.get("item")):
                        bad(f"{w}: item is missing or empty")
                    else:
                        f = _fold(x["item"])
                        if f in seen:
                            bad(f"{where}: the item {_q(x['item'])} appears "
                                f"twice in its answers")
                        seen.add(f)
                    if not _text(x.get("answer")):
                        bad(f"{w}: answer is missing or empty")
                    if ("corrected" in x) != ("was" in x):
                        bad(f"{w}: corrected and was come together, the date "
                            f"and the answer it replaced")
                    if "corrected" in x and not _date(x["corrected"]):
                        bad(f"{w}: corrected is {_q(x['corrected'])}, not a "
                            f"YYYY-MM-DD date")
                    if "was" in x:
                        if not _text(x["was"]):
                            bad(f"{w}: was is empty")
                        elif x["was"] == x.get("answer"):
                            bad(f"{w}: was and answer are the same, so nothing "
                                f"was corrected")

    # entries, against each other
    for eid in sorted(by_id):
        e = by_id[eid]
        sb = e.get("superseded_by")
        if e.get("status") == "superseded" and _int(sb):
            t = by_id.get(sb)
            if t is None:
                bad(f"entry {eid}: superseded_by {sb}, and there is no entry {sb}")
            elif t.get("supersedes") != eid:
                said = ("supersedes nothing" if "supersedes" not in t
                        else f"supersedes {_q(t['supersedes'])}")
                bad(f"entry {eid}: superseded_by {sb}, but entry {sb} {said}")
        sp = e.get("supersedes")
        if _int(sp) and sp < eid:
            t = by_id.get(sp)
            if t is None:
                bad(f"entry {eid}: supersedes {sp}, and there is no entry {sp}")
            elif t.get("status") != "superseded":
                bad(f"entry {eid}: supersedes {sp}, but entry {sp} is "
                    f"{_q(t.get('status'))}")
            elif "superseded_by" not in t:
                bad(f"entry {eid}: supersedes {sp}, but entry {sp} names no "
                    f"superseded_by")
            elif t["superseded_by"] != eid:
                bad(f"entry {eid}: supersedes {sp}, but entry {sp} is "
                    f"superseded_by {_q(t['superseded_by'])}")

    if nid is not None:
        past = [i for i in sorted(by_id) if i >= nid]
        if past:
            bad(f"next_id is {nid}, and entries {', '.join(map(str, past))} are "
                f"at or past it, so the next add would reuse an ID")
        gone = [i for i in range(1, nid) if i not in by_id]
        if gone:
            bad(f"no entry carries ID {', '.join(map(str, gone))}. An entry is "
                f"retired, never deleted, so a mark citing its ID keeps "
                f"resolving to the claim it meant")
    return out


# --------------------------------------------------------------------------
# Writing
# --------------------------------------------------------------------------

def _ordered(obj, order):
    return {k: obj[k] for k in order if k in obj}


def dump(doc):
    """The one layout this script writes: fixed key order, two-space indent.

    Only a document that passed problems_in reaches here, so no key outside
    the orders below can be dropped by them.
    """
    out = _ordered(doc, TOP_KEYS)
    out["created"] = _ordered(doc["created"], CREATED_KEYS["backfill"])
    out["brief"] = _ordered(doc["brief"], BRIEF_KEYS)
    entries = []
    for e in sorted(doc["entries"], key=lambda x: x["id"]):
        x = _ordered(e, ENTRY_KEYS)
        x["origin"] = _ordered(e["origin"], ORIGIN_KEYS)
        if "measurement" in x:
            x["measurement"] = _ordered(e["measurement"], MEASUREMENT_KEYS)
        if "answers" in x:
            x["answers"] = [_ordered(a, ANSWER_KEYS) for a in e["answers"]]
        entries.append(x)
    out["entries"] = entries
    return json.dumps(out, indent=2, ensure_ascii=False) + "\n"


def _write(path, doc):
    # Through a temporary file in the same folder and a rename, so an
    # interrupted write leaves the old file whole rather than half a new one.
    fd, tmp = tempfile.mkstemp(dir=str(path.parent), prefix=".assertions.",
                               suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(dump(doc))
        os.replace(tmp, str(path))
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


class Refused(Exception):
    def __init__(self, msg, detail=(), code=1):
        super().__init__(msg)
        self.detail = list(detail)
        self.code = code


def _path(book):
    if not book.is_dir():
        raise Refused(f"no such folder: {book}", code=2)
    return book / FILE


def _read(book, writing=True):
    """The book's document, valid, or Refused saying why not."""
    path = _path(book)
    if not path.exists():
        raise Refused(f"{book} has no {FILE}; create it with init", code=2)
    try:
        doc, probs = load(path)
    except TooNew as e:
        raise Refused(too_new(path, e.args[0]), code=2)
    if doc is None or probs:
        said = ("already fails check, so nothing was written" if writing
                else "fails check, so it is not listed")
        raise Refused(f"{path} {said}. Fix these first:", probs)
    return path, doc


def _commit(path, doc, said):
    probs = problems_in(doc)
    if probs:
        raise Refused("refused, because the file would then fail check. Each "
                      "key is set by the flag of the same name, with a hyphen "
                      "for the underscore:", probs)
    _write(path, doc)
    print(said)


def _by_id(doc, eid):
    for e in doc["entries"]:
        if e["id"] == eid:
            return e
    raise Refused(f"there is no entry {eid}")


def _status_line(e):
    if e["status"] == "superseded":
        return f"superseded by {e['superseded_by']}"
    return e["status"]


def _today():
    return datetime.date.today().isoformat()


def _entry(args, eid, kind):
    e = {"id": eid, "kind": kind, "statement": args.statement}
    o = {"by": args.by}
    if args.how is not None:
        o["how"] = args.how
    o["date"] = args.date or _today()
    e["origin"] = o
    if args.reaches is not None:
        e["reaches"] = args.reaches
    if args.search:
        e["search"] = args.search
    if any(v is not None for v in (args.ran, args.on, args.result)):
        e["measurement"] = {k: v for k, v in (("ran", args.ran), ("on", args.on),
                                              ("result", args.result))
                            if v is not None}
    if args.acted_on is not None:
        e["acted_on"] = args.acted_on
    if args.corrects is not None:
        e["corrects"] = args.corrects
    if args.answer:
        e["answers"] = [{"item": i, "answer": a} for i, a in args.answer]
    return e


def _finish(e, applies, citation):
    e["applies_to"] = applies
    # Written on a book entry too when it was asked for, so that check refuses
    # it by name rather than the flag vanishing without a word.
    if applies == "prose" or citation is not None:
        e["citation"] = citation or "expected"
    e["status"] = "holds"


def cmd_init(args):
    book = pathlib.Path(args.book)
    path = _path(book)
    if path.exists():
        raise Refused(f"{path} already exists; init starts a file and never "
                      f"replaces one")
    created = {"date": args.date or _today(), "how": args.how}
    if args.how == "backfill" or args.sources or args.candidates is not None \
            or args.confirmed is not None:
        if args.sources:
            created["from"] = args.sources
        if args.candidates is not None:
            created["candidates"] = args.candidates
        if args.confirmed is not None:
            created["confirmed"] = args.confirmed
    brief = {"argument": args.argument, "reader": args.reader,
             "reader_origin": args.reader_origin}
    if args.reader_inferred is not None:
        brief["reader_inferred"] = args.reader_inferred
    brief["profile_origin"] = args.profile_origin
    doc = {"format": FORMAT, "created": created, "brief": brief,
           "next_id": 1, "entries": []}
    _commit(path, doc, f"{path}: started by {args.how}, with no entries")


def cmd_add(args):
    path, doc = _read(pathlib.Path(args.book))
    eid = doc["next_id"]
    e = _entry(args, eid, args.kind)
    _finish(e, args.applies_to, args.citation)
    doc["entries"].append(e)
    doc["next_id"] = eid + 1
    _commit(path, doc, f"{path}: added {eid} ({args.kind})")


def cmd_supersede(args):
    path, doc = _read(pathlib.Path(args.book))
    old = _by_id(doc, args.id)
    if old["status"] != "holds":
        raise Refused(f"entry {args.id} is {_status_line(old)}; only an entry "
                      f"that holds can be superseded")
    eid = doc["next_id"]
    kind = args.kind or old["kind"]
    if args.reaches is None and kind == "premise" and "reaches" in old:
        args.reaches = old["reaches"]
    e = _entry(args, eid, kind)
    _finish(e, args.applies_to or old["applies_to"], args.citation)
    e["supersedes"] = old["id"]
    old["status"] = "superseded"
    old["superseded_by"] = eid
    doc["entries"].append(e)
    doc["next_id"] = eid + 1
    _commit(path, doc, f"{path}: added {eid} ({kind}), superseding {args.id}")


def cmd_retire(args):
    path, doc = _read(pathlib.Path(args.book))
    e = _by_id(doc, args.id)
    if e["status"] != "holds":
        raise Refused(f"entry {args.id} is {_status_line(e)}; only an entry "
                      f"that holds can be retired")
    e["status"] = "retired"
    e["retired_reason"] = args.reason
    _commit(path, doc, f"{path}: retired {args.id}")


def cmd_correct(args):
    path, doc = _read(pathlib.Path(args.book))
    e = _by_id(doc, args.id)
    if e["kind"] != "settled" or "answers" not in e:
        raise Refused(f"entry {args.id} is a {e['kind']} entry with no answers; "
                      f"correct changes one answer in a settled entry's set")
    if e["status"] != "holds":
        raise Refused(f"entry {args.id} is {_status_line(e)}; only an entry "
                      f"that holds can be corrected")
    hits = [a for a in e["answers"] if _fold(a["item"]) == _fold(args.item)]
    if not hits:
        raise Refused(f"entry {args.id} has no item {_q(args.item)}; list "
                      f"shows its items")
    a = hits[0]
    if a["answer"] == args.answer:
        raise Refused(f"{_q(a['item'])} already has the answer "
                      f"{_q(args.answer)}")
    a["was"] = a["answer"]
    a["answer"] = args.answer
    a["corrected"] = args.date or _today()
    _commit(path, doc, f"{path}: corrected {_q(a['item'])} in {args.id}, "
                       f"{_q(a['was'])} to {_q(a['answer'])}")


def cmd_expect(args):
    path, doc = _read(pathlib.Path(args.book))
    if args.all == bool(args.ids):
        raise Refused("name the entries to change or pass --all, one or the "
                      "other", code=2)
    if args.all:
        todo = [e for e in doc["entries"] if e["status"] == "holds"
                and e.get("citation") == "legacy"]
        if not todo:
            print(f"{path}: no entry that holds is legacy; nothing changed")
            return
    else:
        todo = []
        for eid in args.ids:
            e = _by_id(doc, eid)
            if e.get("citation") != "legacy":
                raise Refused(f"entry {eid} is not legacy; its citation is "
                              f"{_q(e.get('citation'))}")
            if e["status"] != "holds":
                raise Refused(f"entry {eid} is {_status_line(e)}, and nothing "
                              f"should cite it now")
            todo.append(e)
    for e in todo:
        e["citation"] = "expected"
    _commit(path, doc, f"{path}: now expected: "
                       f"{', '.join(str(e['id']) for e in todo)}")


def _cell(s):
    return " ".join(str(s).split()).replace("|", "\\|")


def cmd_list(args):
    path, doc = _read(pathlib.Path(args.book), writing=False)
    c, b = doc["created"], doc["brief"]
    line = f"{FILE}: started {c['date']} by {c['how']}"
    if c["how"] == "backfill":
        line += (f" from {', '.join(c['from'])}; {c['confirmed']} of "
                 f"{c['candidates']} candidates confirmed")
    print(line)
    if b["argument"] is None:
        print("Argument: unrecorded")
    else:
        print(f"Argument: {b['argument']}")
    origin = f"from the {b['reader_origin']}" if b["reader_origin"] in (
        "argument", "operator") else b["reader_origin"]
    if "reader_inferred" in b:
        origin += f", with this part inferred: {b['reader_inferred']}"
    print(f"Reader: {b['reader']} ({origin})")
    profile = b["profile_origin"]
    if profile in ("argument", "operator"):
        profile = f"from the {profile}"
    print(f"Profile: {profile}; its value is in book.json")
    print()

    entries = sorted(doc["entries"], key=lambda e: e["id"])
    if not entries:
        print("No entries.")
        return
    print("| # | Kind | Statement | By | Date | Applies to | Status |")
    print("|---|---|---|---|---|---|---|")
    details = []
    for e in entries:
        o = e["origin"]
        applies = e["applies_to"]
        if applies == "prose":
            applies += f", {e['citation']}"
        status = _status_line(e)
        if e["status"] == "retired":
            status += f": {e['retired_reason']}"
        if "supersedes" in e:
            status += f"; supersedes {e['supersedes']}"
        print(f"| {e['id']} | {e['kind']} | {_cell(e['statement'])} | "
              f"{o['by']} | {o['date']} | {applies} | {_cell(status)} |")

        more = []
        if "how" in o:
            more.append(f"how: {o['how']}")
        if "reaches" in e:
            more.append(f"reaches: {e['reaches']}")
        if "search" in e:
            more.append("search: " + ", ".join(_q(s) for s in e["search"]))
        if "measurement" in e:
            m = e["measurement"]
            more.append(f"ran `{m['ran']}` on {m['on']}: {m['result']}")
        if "acted_on" in e:
            more.append(f"acted on: {e['acted_on']}")
        if "corrects" in e:
            more.append(f"corrects: {e['corrects']}")
        if "answers" in e:
            parts = []
            for a in e["answers"]:
                p = f"{a['item']} = {a['answer']}"
                if "corrected" in a:
                    p += f" (corrected {a['corrected']}, was {a['was']})"
                parts.append(p)
            more.append("answers: " + "; ".join(parts))
        if more:
            details.append(f"- **{e['id']}**: " + ". ".join(more))
    if details:
        print()
        print("\n".join(details))
    n = {s: sum(1 for e in entries if e["status"] == s) for s in STATUSES}
    print()
    print(f"{len(entries)} entries: {n['holds']} hold, {n['superseded']} "
          f"superseded, {n['retired']} retired.")


def cmd_check(args):
    book = pathlib.Path(args.book)
    path = _path(book)
    if not path.exists():
        print(f"note: {book} has no {FILE}. Nothing was asserted.")
        return 2
    try:
        doc, probs = load(path)
    except TooNew as e:
        raise Refused(too_new(path, e.args[0]), code=2)
    for p in probs:
        print(f"FAIL  {p}")
    if probs:
        print()
        print(f"{len(probs)} failure(s). {path} does not pass, and no skill "
              f"should read or write it until it does.")
        return 1
    n = {s: sum(1 for e in doc["entries"] if e["status"] == s) for s in STATUSES}
    print(f"OK    {path} passes: format {FORMAT}, {len(doc['entries'])} "
          f"entries ({n['holds']} hold, {n['superseded']} superseded, "
          f"{n['retired']} retired), next ID {doc['next_id']}.")
    return 0


# --------------------------------------------------------------------------
# The command line
# --------------------------------------------------------------------------

def _date_arg(s):
    if not _date(s):
        raise argparse.ArgumentTypeError(f"{s!r} is not a YYYY-MM-DD date")
    return s


def _entry_flags(p, supersede):
    p.add_argument("--kind", choices=KINDS, required=not supersede)
    p.add_argument("--statement", required=True)
    p.add_argument("--by", choices=BY, required=True)
    p.add_argument("--how", help="origin.how: how the claim was come by")
    p.add_argument("--date", type=_date_arg, help="origin.date; default today")
    p.add_argument("--applies-to", choices=APPLIES, required=not supersede)
    p.add_argument("--citation", choices=CITATIONS,
                   help="a prose entry's; default expected")
    p.add_argument("--reaches")
    p.add_argument("--search", action="append", metavar="PHRASE")
    p.add_argument("--ran")
    p.add_argument("--on")
    p.add_argument("--result")
    p.add_argument("--acted-on")
    p.add_argument("--corrects")
    p.add_argument("--answer", nargs=2, action="append",
                   metavar=("ITEM", "ANSWER"))


def parser():
    top = argparse.ArgumentParser(
        prog="assertions.sh",
        description="Write a book's assertions.json, list it, and check it.")
    sub = top.add_subparsers(dest="command", metavar="command")
    sub.required = True

    p = sub.add_parser("init", help="create the file, with no entries")
    p.add_argument("book")
    p.add_argument("--how", choices=HOWS, required=True)
    p.add_argument("--argument", help="the /createbook argument, verbatim")
    p.add_argument("--reader", required=True, help="the persona, one sentence")
    p.add_argument("--reader-origin", choices=ORIGINS, required=True)
    p.add_argument("--reader-inferred",
                   help="the part of a given persona that was inferred")
    p.add_argument("--profile-origin", choices=ORIGINS, required=True)
    p.add_argument("--from", dest="sources", action="append", metavar="WHAT",
                   help="what a backfill read; repeat for each")
    p.add_argument("--candidates", type=int)
    p.add_argument("--confirmed", type=int)
    p.add_argument("--date", type=_date_arg, help="created.date; default today")
    p.set_defaults(run=cmd_init)

    p = sub.add_parser("add", help="append one entry under the next ID")
    p.add_argument("book")
    _entry_flags(p, supersede=False)
    p.set_defaults(run=cmd_add)

    p = sub.add_parser("supersede",
                       help="append a replacement and link the two")
    p.add_argument("book")
    p.add_argument("id", type=int)
    _entry_flags(p, supersede=True)
    p.set_defaults(run=cmd_supersede)

    p = sub.add_parser("retire", help="take an entry out of force")
    p.add_argument("book")
    p.add_argument("id", type=int)
    p.add_argument("--reason", required=True)
    p.set_defaults(run=cmd_retire)

    p = sub.add_parser("correct",
                       help="change one answer in a settled entry's set")
    p.add_argument("book")
    p.add_argument("id", type=int)
    p.add_argument("--item", required=True)
    p.add_argument("--answer", required=True)
    p.add_argument("--date", type=_date_arg, help="default today")
    p.set_defaults(run=cmd_correct)

    p = sub.add_parser("expect", help="turn legacy entries into expected")
    p.add_argument("book")
    p.add_argument("ids", type=int, nargs="*", metavar="id")
    p.add_argument("--all", action="store_true",
                   help="every legacy entry that holds")
    p.set_defaults(run=cmd_expect)

    p = sub.add_parser("list", help="the table to show the operator")
    p.add_argument("book")
    p.set_defaults(run=cmd_list)

    p = sub.add_parser("check", help="every rule of the format")
    p.add_argument("book")
    p.set_defaults(run=cmd_check)
    return top


def main(argv):
    args = parser().parse_args(argv[1:])
    try:
        return args.run(args) or 0
    except Refused as r:
        print(f"error: {r}", file=sys.stderr)
        for d in r.detail:
            print(f"  {d}", file=sys.stderr)
        return r.code


if __name__ == "__main__":
    sys.exit(main(sys.argv))
