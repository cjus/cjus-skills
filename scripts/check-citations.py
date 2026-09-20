#!/usr/bin/env python3
"""Check that every cross-reference in the repo's markdown still resolves.

Skill files are prompts an agent reads at runtime, so a reference that points at
the wrong place is a runtime fault with no stack trace: the agent reads whatever
is there now and proceeds on what it inferred. Nothing else in the repo checks
them, because a reference is a string in a markdown file rather than a symbol
any compiler resolves.

Three forms are checked, and a fourth is rejected outright:

  `build-book.py:load_chapters`          a Python def or class
  `createbook/SKILL.md § 5. Draft ...`   a markdown heading
  `chapter-prose.md § The reader`        a bold rule lead, which is how
                                         chapter-prose.md names its rules
  `build-book.py:398`                    a line number: refused when the file is
                                         in this repo, because every insertion
                                         above it silently invalidates it

A citation whose file is not tracked in this repo is left alone. Those point into
a book folder `/createbook` writes (`OUTLINE.md`, `about-this-book.md`), or into
a gitignored local file, or stand as an illustration of what an in-book citation
looks like. Only tracked files ship, so only tracked files can be checked on
anyone else's machine.

Fenced code blocks are stripped before scanning. What looks like a citation
inside one is example data, not a reference: `book.json`'s `sources` map really
does use `"CLAUDE.md § Teaching Calendar"` as a key.

`changelog/` is skipped entirely. Those are branch working notes, frozen at the
date in their filename, and a line number in one was accurate when it was
written. Rewriting a record of what was true then to match what is true now
would destroy the only thing such a record is for.
"""

import re
import subprocess
import sys
from pathlib import Path

SYMBOL = re.compile(r"`([A-Za-z0-9_.-]+\.py):([A-Za-z_][A-Za-z0-9_]*)`")
SECTION = re.compile(r"`([A-Za-z0-9_./-]+\.md)\s+§\s+([^`]+)`")
LINE = re.compile(r"`([A-Za-z0-9_./-]+\.(?:md|py|sh)):(\d+(?:-\d+)?)`")


def strip_fences(text: str) -> str:
    """Blank out fenced blocks, keeping line numbers intact for reporting."""
    out, fence = [], None
    for line in text.split("\n"):
        marker = line.strip()[:3]
        if fence is None:
            if marker in ("```", "~~~"):
                fence, line = marker, ""
        else:
            if marker == fence:
                fence = None
            line = ""
        out.append(line)
    return "\n".join(out)


def resolve(name: str, citing: Path, root: Path, tracked: set[Path]) -> Path | None:
    """Find a cited file: nearest first, then outward to the repo root."""
    for base in list(citing.parents) + [root]:
        if base != root and root not in base.parents:
            continue
        candidate = (base / name).resolve()
        if candidate in tracked:
            return candidate
    matches = [p for p in tracked if p.name == Path(name).name]
    return matches[0] if len(matches) == 1 else None


def has_anchor(body: str, anchor: str) -> bool:
    anchor = " ".join(anchor.split())           # citations wrap across lines
    if re.fullmatch(r"\d+", anchor):            # "§ 5" for "### 5. Draft ..."
        return re.search(rf"^#{{1,6}} {anchor}\.\s", body, re.M) is not None
    name = re.escape(anchor)
    return bool(
        re.search(rf"^#{{1,6}} {name}\b", body, re.M)        # a heading
        or re.search(rf"^\*\*{name}[.,:]?\*\*", body, re.M)  # a bold rule lead
        or re.search(rf"^\*\*{name}\b", body, re.M)
    )


def has_symbol(body: str, symbol: str) -> bool:
    return re.search(rf"^\s*(def|class)\s+{re.escape(symbol)}\b", body, re.M) is not None


def main() -> int:
    root = Path(
        subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
    )

    def ls(*args: str) -> list[str]:
        out = subprocess.run(
            ["git", "ls-files", "-z", *args],
            capture_output=True, text=True, check=True, cwd=root,
        ).stdout
        return [p for p in out.split("\0") if p]

    # Everything tracked is a citable target; only live docs are scanned.
    tracked = {(root / p).resolve() for p in ls()}
    docs = ls("*.md", ":(exclude)changelog/**")

    failures, checked, external = [], 0, 0

    for rel in docs:
        doc = root / rel
        text = strip_fences(doc.read_text(encoding="utf-8"))

        def where(match) -> str:
            return f"{rel}:{text[: match.start()].count(chr(10)) + 1}"

        for m in SYMBOL.finditer(text):
            target = resolve(m.group(1), doc, root, tracked)
            if target is None:
                external += 1
                continue
            checked += 1
            if not has_symbol(target.read_text(encoding="utf-8"), m.group(2)):
                failures.append(
                    f"{where(m)}: {m.group(0)} — no `def {m.group(2)}` in {target.relative_to(root)}"
                )

        for m in SECTION.finditer(text):
            target = resolve(m.group(1), doc, root, tracked)
            if target is None:
                external += 1
                continue
            checked += 1
            if not has_anchor(target.read_text(encoding="utf-8"), m.group(2)):
                anchor = " ".join(m.group(2).split())
                failures.append(
                    f"{where(m)}: `{m.group(1)} § {anchor}` — no such heading or "
                    f"bold rule in {target.relative_to(root)}"
                )

        for m in LINE.finditer(text):
            target = resolve(m.group(1), doc, root, tracked)
            if target is None:
                external += 1
                continue
            checked += 1
            failures.append(
                f"{where(m)}: {m.group(0)} — line numbers rot. Cite the heading "
                f"(`§ Name`) or the symbol (`file.py:func`) instead."
            )

    if failures:
        print(f"{len(failures)} unresolved citation(s):\n", file=sys.stderr)
        for line in failures:
            print(f"  {line}", file=sys.stderr)
        print(
            f"\n{checked} checked, {external} skipped as untracked.",
            file=sys.stderr,
        )
        return 1

    print(f"citations ok: {checked} resolve, {external} skipped as untracked")
    return 0


if __name__ == "__main__":
    sys.exit(main())
