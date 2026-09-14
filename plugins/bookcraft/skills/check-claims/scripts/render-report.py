#!/usr/bin/env python3
"""Render the per-chapter findings of a /check-claims run into one report.

    render-report.py <findings-dir> <book-folder> [--worklist <dir>] [--command "<the command>"]

Reads every `findings-*.json` in the findings directory, checks each against the
shape `reference/judgement.md` asks for AND against the run's own `index.json`,
and writes
`<book-folder>/claim-checks/<YYYY-MM-DD>.md`, or `-roundN` when that file
already exists.

**A script renders this rather than the calling session, and the reason is the
same one that governs the rest of this family: a number retyped out of an
agent's reply is a number nobody can check.** The findings files are the
evidence; this reads them and does arithmetic, so the report's counts are the
agents' counts by construction rather than by care.

It refuses to paper over a chapter it could not use. A findings file that is
missing, unparseable, that names a chapter this run did not emit, that reports a
`units_checked` outside 0..the worklist's count, that uses a verdict word the
spec does not define, whose counts do not sum to its own `units_checked`, or
whose counts and findings disagree is named in the report itself, under "What
was not reached". A total assembled over a silently-dropped chapter reads
exactly like a total over a complete run.

**A chapter that examined FEWER units than its worklist is kept, marked partial,
and still fails the run.** Its row reads `10 of 36`, its findings are rendered,
and "What was not reached" names it. Dropping it instead was this script's own
first fix and was wrong: `SKILL.md` documents resuming a stalled agent so it
writes what it has, so a short chapter is a supported shape, and its findings are
the half worth keeping.

`index.json` is the authority on which chapters the run covered and how many
units each was given; `--worklist` says where it is when the findings were
written somewhere other than beside it.

Exits 0 only when every chapter in the index produced a complete, well-formed
findings file. 1 when any was missing, unusable, or partial. 2 on bad usage.
"""
import sys, json, pathlib, datetime, collections

# Most severe first. This is the order the report lists findings in, and it is
# the order `reference/judgement.md` defines: what teaches a room something
# false comes before what merely could not be settled.
ORDER = ["unsupported", "overstated", "misstated", "unclear", "unreadable"]
ALL_VERDICTS = ["supported"] + ORDER

HEADLINE = {
    "unsupported": "The source does not carry the claim",
    "overstated": "The sentence claims more than the source says",
    "misstated": "The sentence disagrees with the source",
    "unclear": "Read, and not decidable",
    "unreadable": "Could not be read",
}


def load(findings_dir, want):
    """Every findings file, plus the ones that were not usable and why.

    `want` maps chapter number to the unit count the worklist gave it, read from
    the run's own `index.json`. **Every check below except that one is internal
    to a findings file, which is not enough**, and the gap is the script's own
    docstring one level down: a total assembled over a silently-dropped chapter
    reads exactly like a complete run, and so does a chapter that examined 10 of
    its 33 units and reported `units_checked: 10` with counts that sum. Its row
    renders indistinguishable from a complete one. Checking against the index is
    what makes `units_checked` an assertion rather than a value taken on trust.

    It also settles a second case the internal checks cannot see. The glob has
    no tie to the run, so a scoped second round emitted into a directory that
    still holds a full round's files would otherwise pick up 16 stale chapters
    and render them as this run's. A findings file whose chapter is not in this
    run's index is left over, and is reported rather than counted.
    """
    chapters, broken = [], []
    for path in sorted(pathlib.Path(findings_dir).glob("findings-*.json")):
        try:
            d = json.loads(path.read_text())
        except (json.JSONDecodeError, OSError) as e:
            broken.append((path.name, f"could not be read: {e}"))
            continue
        # Typed before it is used as a dict key. `in` on an unhashable value
        # raises rather than answering False, and the chapter worklist writes
        # `"chapter": {"number": 7, "file": "..."}` while `judgement.md`'s output
        # example writes `"chapter": 5`, so the two shapes sit on either side of
        # one agent. An uncaught TypeError here also exits 1, which is the code
        # the docstring promises for "some chapters were unusable, the report was
        # written" — so the one input that drops all eighteen chapters would
        # report itself as the ordinary partial-success case.
        ch = d.get("chapter")
        if not isinstance(ch, int) or isinstance(ch, bool):
            broken.append((path.name,
                           f"names chapter {ch!r}, which is not a chapter "
                           f"number; `chapter` is the number alone, not the "
                           f"worklist's {{number, file}} object"))
            continue
        if ch not in want:
            broken.append((path.name,
                           f"names chapter {ch}, which this run's index.json "
                           f"does not list, so it is left over from an earlier "
                           f"run"))
            continue
        checked_n = d.get("units_checked")
        if not isinstance(checked_n, int) or isinstance(checked_n, bool) \
                or checked_n < 0 or checked_n > want[ch]:
            broken.append((path.name,
                           f"reports units_checked {checked_n!r}, which is not a "
                           f"count between 0 and the {want[ch]} unit(s) the "
                           f"worklist gave chapter {ch}"))
            continue
        counts = d.get("counts") or {}
        unknown = [k for k in counts if k not in ALL_VERDICTS]
        if unknown:
            broken.append((path.name,
                           f"uses verdict word(s) the spec does not define: "
                           f"{', '.join(sorted(unknown))}"))
            continue
        total = sum(counts.get(v, 0) for v in ALL_VERDICTS)
        if total != d.get("units_checked"):
            broken.append((path.name,
                           f"counts sum to {total} but units_checked is "
                           f"{d.get('units_checked')}, so the chapter's own "
                           f"totals disagree"))
            continue
        # A finding whose verdict is `supported` is a spec violation; so is a
        # findings list shorter than the non-supported counts imply. Both mean
        # the report would under-state what the run found.
        listed = collections.Counter(f.get("verdict") for f in d.get("findings", []))
        if listed.get("supported"):
            broken.append((path.name, "lists a `supported` unit as a finding"))
            continue
        mismatch = [v for v in ORDER if listed.get(v, 0) != counts.get(v, 0)]
        if mismatch:
            broken.append((path.name,
                           f"counts and findings disagree for: "
                           f"{', '.join(mismatch)}"))
            continue
        # **A chapter shorter than its worklist is kept and marked, not dropped.**
        # `SKILL.md` documents resuming a stalled agent so it writes what it has,
        # and root `CLAUDE.md` records that path being taken for real during
        # an early revision, so a partial chapter is a supported shape rather than a
        # defect. Rejecting the file threw away the half that matters: an
        # `unsupported` finding in unit 4 of 36 is the verdict this skill
        # escalates unconditionally, and it would have reached the report as a
        # single rejection line. The total still refuses to call the run
        # complete, which was the point of checking against the index.
        if checked_n < want[ch]:
            d["partial_of"] = want[ch]
        chapters.append(d)
    return chapters, broken


def quote(s, indent="  "):
    """A block quote that survives a sentence containing newlines or pipes."""
    s = (s or "").strip()
    return "\n".join(indent + "> " + ln for ln in s.splitlines()) if s else ""


def render(chapters, broken, book, command, expected):
    today = datetime.date.today().isoformat()
    out = []
    out.append(f"# Claim check: {pathlib.Path(book).name}")
    out.append("")
    out.append(f"Run {today}. Every unit that rests on an external source, read "
               f"against that source by one agent per chapter.")
    out.append("")
    out.append("**Advisory.** Nothing gates on a finding. `reference/judgement.md` "
               "defines the verdicts; `supported` means the source carries the "
               "claim, and the five others each name a different reason it may "
               "not. Triage against `CLAUDE.md § Plans`' three bins.")
    out.append("")

    totals = collections.Counter()
    for d in chapters:
        for v in ALL_VERDICTS:
            totals[v] += (d.get("counts") or {}).get(v, 0)
    checked = sum(d.get("units_checked", 0) for d in chapters)

    out.append("## Counts")
    out.append("")
    out.append("| Chapter | Units | " + " | ".join(ALL_VERDICTS) + " |")
    out.append("|---:|---:|" + "---:|" * len(ALL_VERDICTS))
    for d in sorted(chapters, key=lambda x: x.get("chapter") or 0):
        c = d.get("counts") or {}
        units = (f"{d.get('units_checked')} of {d['partial_of']}"
                 if d.get("partial_of") else str(d.get("units_checked")))
        out.append(f"| {d.get('chapter')} | {units} | "
                   + " | ".join(str(c.get(v, 0)) for v in ALL_VERDICTS) + " |")
    out.append(f"| **{len(chapters)} chapters** | **{checked}** | "
               + " | ".join(f"**{totals[v]}**" for v in ALL_VERDICTS) + " |")
    out.append("")
    if expected and len(chapters) != expected:
        out.append(f"**{len(chapters)} of {expected} chapters are in this table.** "
                   f"The rest are under *What was not reached*; the totals above "
                   f"describe only the chapters listed.")
        out.append("")

    n_findings = sum(totals[v] for v in ORDER)
    if not n_findings:
        out.append("## Findings")
        out.append("")
        out.append("None. Every unit checked was `supported`.")
        out.append("")
    for verdict in ORDER:
        items = [(d, f) for d in sorted(chapters, key=lambda x: x.get("chapter") or 0)
                 for f in d.get("findings", []) if f.get("verdict") == verdict]
        if not items:
            continue
        out.append(f"## {verdict} ({len(items)})")
        out.append("")
        out.append(f"*{HEADLINE[verdict]}.*")
        out.append("")
        for d, f in items:
            tag = f.get("tag") or f"line {f.get('line')}"
            out.append(f"### ch. {d.get('chapter')} {tag} against `{f.get('source')}`")
            out.append("")
            out.append("The book says:")
            out.append("")
            out.append(quote(f.get("sentence")))
            out.append("")
            if f.get("source_says"):
                out.append("The source says:")
                out.append("")
                out.append(quote(f.get("source_says")))
                out.append("")
            if f.get("gap"):
                out.append(f"**The gap.** {f['gap'].strip()}")
                out.append("")
            if f.get("read"):
                out.append(f"**Read.** {f['read'].strip()}")
                out.append("")
            out.append(f"`{d.get('file')}:{f.get('line')}`")
            out.append("")

    notes = [(d.get("chapter"), n) for d in sorted(chapters, key=lambda x: x.get("chapter") or 0)
             for n in (d.get("notes") or [])]
    if notes:
        out.append("## Chapter notes")
        out.append("")
        out.append("Things true of a whole chapter rather than of one unit: a "
                   "shorthand sampled rather than read whole, a source that would "
                   "not open, a pattern seen repeatedly.")
        out.append("")
        for ch, n in notes:
            out.append(f"- **ch. {ch}.** {n.strip()}")
        out.append("")

    out.append("## What was not reached")
    out.append("")
    partials = [d for d in chapters if d.get("partial_of")]
    for d in sorted(partials, key=lambda x: x.get("chapter") or 0):
        out.append(f"- **ch. {d['chapter']} is partial**: {d['units_checked']} of "
                   f"{d['partial_of']} units examined. Its findings are in this "
                   f"report; the units it did not reach were not checked by "
                   f"anything.")
    if broken:
        for name, why in broken:
            out.append(f"- `{name}`: {why}")
    if expected and len(chapters) + len(broken) < expected:
        out.append(f"- {expected - len(chapters) - len(broken)} chapter(s) produced "
                   f"no findings file at all.")
    if not broken and not partials and (not expected or len(chapters) == expected):
        out.append("Every chapter produced a well-formed findings file, and each "
                   "chapter's verdict counts sum to the units it was given.")
    out.append("")
    out.append("A `supported` verdict is bounded by what the agent read, which "
               "each finding records in its **Read** line. A claim against a "
               "shorthand naming many files is weaker than one against a single "
               "page unless every file was opened.")
    out.append("")

    out.append("## Reproducing this")
    out.append("")
    out.append("```bash")
    out.append(command or "/check-claims <book-folder>")
    out.append("```")
    out.append("")
    return "\n".join(out)


def main(argv):
    # Parsed in one pass, with every option consuming its own value. The first
    # version filtered `--`-prefixed items out of a positional list and then
    # removed the option VALUES by matching them back by string, which made a
    # value that happened to equal a path remove the wrong element, and let
    # `--expect` as the final argument silently leave the count unset. That last
    # one was the dangerous shape: `--expect` was the only thing that caught a
    # chapter which produced no findings file at all, so dropping its value
    # turned a run that saw 2 of 18 chapters into a printed all-clear.
    positional, command, worklist_dir = [], None, None
    args = argv[1:]
    i = 0
    while i < len(args):
        a = args[i]
        if a in ("--command", "--worklist"):
            if i + 1 >= len(args):
                print(f"error: {a} needs a value", file=sys.stderr)
                return 2
            i += 1
            if a == "--command":
                command = args[i]
            else:
                worklist_dir = args[i]
        elif a.startswith("--"):
            print(f"error: unknown option: {a}", file=sys.stderr)
            return 2
        else:
            positional.append(a)
        i += 1
    if len(positional) != 2:
        print(__doc__.strip().splitlines()[2].strip(), file=sys.stderr)
        return 2

    findings_dir, book = pathlib.Path(positional[0]), pathlib.Path(positional[1])
    if not findings_dir.is_dir():
        print(f"error: no such folder: {findings_dir}", file=sys.stderr)
        return 2
    if not book.is_dir():
        print(f"error: no such folder: {book}", file=sys.stderr)
        return 2

    # **The run's own index.json is what the findings are checked against, and
    # there is no flag for it.** `--expect <n>` used to carry the chapter count
    # by hand, which meant a missing or wrong value weakened the check silently.
    # The index is written by the same `--emit-worklist` run that produced the
    # worklists, so it already knows both the chapter list and the unit count
    # each chapter was given. Deriving from it cannot disagree with the run.
    index_path = pathlib.Path(worklist_dir or findings_dir) / "index.json"
    try:
        index = json.loads(index_path.read_text())
    except (json.JSONDecodeError, OSError) as e:
        print(f"error: could not read {index_path}: {e}", file=sys.stderr)
        print("       it is written beside the worklists by "
              "`check-provenance.sh --emit-worklist`; pass --worklist if the "
              "findings were written somewhere else.", file=sys.stderr)
        return 2
    # The `try` above catches a file that will not parse. A file that parses
    # into the wrong shape reaches here instead, and raised an AttributeError
    # past both handlers before this guard existed.
    if not isinstance(index, dict) or not isinstance(index.get("chapters"), list) \
            or not all(isinstance(c, dict) for c in index["chapters"]):
        print(f"error: {index_path} is not the shape --emit-worklist writes",
              file=sys.stderr)
        return 2
    # Built entry by entry rather than by comprehension, because a dict
    # comprehension silently collapses a duplicate chapter number and happily
    # keys on `None` for a filename that carried no digit. Either would make
    # `expected` smaller than the run without saying so, which is the same
    # "a weaker check that looks like the strong one" fault the rest of this
    # file refuses.
    want = {}
    for c in index["chapters"]:
        n, u = c.get("number"), c.get("units")
        if not isinstance(n, int) or isinstance(n, bool) or n in want:
            print(f"error: {index_path} lists chapter number {n!r} "
                  f"{'more than once' if n in want else 'which is not a number'}",
                  file=sys.stderr)
            return 2
        if not isinstance(u, int) or isinstance(u, bool) or u < 0:
            print(f"error: {index_path} gives chapter {n} a unit count of {u!r}",
                  file=sys.stderr)
            return 2
        want[n] = u
    if not want:
        print(f"error: {index_path} lists no chapters", file=sys.stderr)
        return 2
    expected = len(want)

    chapters, broken = load(findings_dir, want)
    if not chapters and not broken:
        print(f"error: no findings-*.json in {findings_dir}", file=sys.stderr)
        return 2

    dest = book / "claim-checks"
    dest.mkdir(parents=True, exist_ok=True)
    today = datetime.date.today().isoformat()
    out = dest / f"{today}.md"
    n = 2
    while out.exists():
        # Never overwrite. A second round's value is that the first round's
        # reasoning survives to show whether a later fault was self-introduced.
        out = dest / f"{today}-round{n}.md"
        n += 1

    out.write_text(render(chapters, broken, book, command, expected) + "\n")
    totals = collections.Counter()
    for d in chapters:
        for v in ALL_VERDICTS:
            totals[v] += (d.get("counts") or {}).get(v, 0)
    print(f"wrote {out}")
    print(f"chapters {len(chapters)}"
          + (f" of {expected}" if expected else "")
          + f"   units {sum(d.get('units_checked', 0) for d in chapters)}")
    print("   ".join(f"{v} {totals[v]}" for v in ALL_VERDICTS))
    for name, why in broken:
        print(f"NOT USED  {name}: {why}")
    partial = sum(1 for d in chapters if d.get("partial_of"))
    if partial:
        print(f"PARTIAL   {partial} chapter(s) examined fewer units than the "
              f"worklist gave them; their findings are kept and the run is not "
              f"complete")
    return (1 if broken or partial or (expected and len(chapters) != expected)
            else 0)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
