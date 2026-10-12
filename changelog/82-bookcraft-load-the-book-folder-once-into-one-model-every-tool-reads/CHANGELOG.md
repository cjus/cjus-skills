# bookcraft: load the book folder once, into one model every tool reads

Start date: 2026-10-12 10:47:01 MDT

Every bookcraft tool reads the book folder on its own, with its own copy of the rules that say
what a file is, and the copies have drifted. The appendix filename rule exists four times and
the copies disagree. This branch adds one stdlib-only `book_model.py` that reads the folder
once, moves the binder and every checker onto it, and adds a fixture proving they classify each
file the same way.

## Changes

### 2026-10-12 10:57:05 MDT: the rules inventory

Line numbers are on `498a68a`. "binder" is `makebook/scripts/build-book.py`, and the three
checkers are in `createbook/scripts/`.

**`render-report.py` has no rule of its own.** It never reads the book folder. It takes each
file's `(kind, number)` from `index.json` and the findings files, both written by
`check-provenance.sh --emit-worklist` (:1416-1430), so the model reaches it only through that
emitter. #21's collision was fixed in the emitter by #17, merged 2026-09-21, the day before #21
was filed. `check-claims/fixtures/appendix/run.sh` reproduces #21 and passes 17 of 17 on main.

| Rule | binder | `check-book.sh` | `check-provenance.sh` | `check-references.sh` |
|---|---|---|---|---|
| Discovery, order | `sorted(glob("*.md"))` :901 | `find -maxdepth 1 \| sort`, `LC_ALL=C` :282, :25 | `sorted(glob("*.md"))` :1755 | `sorted(glob("*.md"))` :526 |
| Skip list | `description_file`, `exclude`, `glossary_file`, `front_matter_file` :3994-4010 | `OUTLINE.md`, `exclude`, `glossary_file`, `front_matter_file` :87, :164-180 (jq only) | `OUTLINE.md`, `glossary.md`, `about-this-book.md` hard-coded, `exclude` :1753 | `exclude`, `glossary_file` :516; any file without `-NN-` is ignored :529 |
| Chapter number | position in sort order, never the filename :950 | `-NN-` (two or more digits), the first digit run, must equal position :364, :377 | first digit run anywhere, `\d+` :1238 | first `-(\d{2,})-` anywhere :87 |
| Appendix | `APPENDIX_FILE_RE`, any profile :773 | guide profile only :334 | prefix only :1217 | prefix only :86 |
| Title | line 1 after marks are stripped, else `prettify(stem)` :908-915 | raw line 1 must start `# ` :384 | not read | not read |
| `sections` group | sequential number, appendices included in some places | not checked | not read | not read |
| Paragraph tag | `^\[A?\d+-\d+[a-z]?\] ` :755 | same, with `[0-9]` :147 | same :295 | same :69 |
| Mark | whole line only, stripped :744 | whole line only; any other comment fails :1227 | anywhere on a line, `MARK.search` :706 | n/a |
| Fence | markdown-it: backtick and `~~~` fences | backtick fences only :764 | backtick fences only :698 | backtick fences only :325 |

**Disagreements beyond the appendix pattern.** Each row in the first table below came from
running the tools' own code on the name: the real `load_chapters`, `chapter_id` and `unit_of`,
and `check-book.sh`'s grep and sed patterns.

1. **Chapter number has four rules.** The binder's number is a position. Every checker reads one
   from the filename, and no two of them read it the same way:

   | Filename | binder | provenance | references | check-book |
   |---|---|---|---|---|
   | `bk2-07-slug-digit.md` | chapter (position) | chapter 2 | chapter 7 | rejected |
   | `notes-v2.md` | chapter (position) | chapter 2 | ignored | rejected |
   | `bk-1-one-digit.md` | chapter (position) | chapter 1 | ignored | rejected |
   | `01-intro.md` | chapter 1 | chapter 1 | ignored | rejected |

   In a book with a gap (`-01-`, `-03-`), the binder prints "Chapter 2" over the file every
   checker calls chapter 3. `check-book.sh` fails the gap, but the binder runs without it.
2. **Three skip lists.**
   - Only the binder skips `description_file`.
   - The binder skips `OUTLINE.md` only because `createbook/SKILL.md:419` writes it into
     `exclude`.
   - `check-provenance.sh` hard-codes the default glossary and front-matter names, so a renamed
     one is a chapter to it: scanned for marks, and counted in `n_chapters`.
   - No fixture sets `description_file`, `glossary_file` or `front_matter_file`.
3. **Appendices under the narration profile.**
   - `check-book.sh` recognises an appendix only under the guide profile. The other three
     recognise one under any profile.
   - Its comment says a narration appendix "falls through to the chapter rule and fails there by
     name". That holds only for a one-digit number. Under narration, `bk-appendix-10-x.md` passes
     the chapter rule as chapter 10, and `bk-appendix-01-x.md` passes as chapter 1.
4. **`sections` disagrees within the binder itself.**
   - The chapter eyebrows leave appendices out of a part (:2278, :3815).
   - The contents (:1651), the PDF outline (:3246) and the EPUB nav (:3748) group appendices by
     their sequential number. So a range that spans an appendix's number nests it under a part
     its own page does not name.
5. **Numbers that count appendices as chapters.**
   - `check-provenance.sh` bounds a mark's `ch. N` by `n_chapters`, which counts every file it
     did not skip, appendices included (:1772, :1884).
   - The glossary's `(ch. N)` is bounded the same way by the binder (:4057) and by
     `check-book.sh` (:1325). Both accept a `(ch. N)` past the last chapter, and the binder then
     resolves it to an appendix.
6. **Paragraph rules, which matter only where `check-book.sh` has not run.**
   - Line 1 that is a mark above the H1: the binder finds the title, `check-book.sh` fails it.
     Its comment cites `build-book.py:406`; the rule is now at :910.
   - A mark that does not fill its line: provenance reads it, the binder leaves it in the page.
   - A `~~~` fence: the binder renders it as code, the checkers read its contents as prose.
   - Python's `\d` matches non-ASCII digits, where `check-book.sh`'s `[0-9]` does not.

**For the agreement fixture.** On a case-insensitive disk (macOS's default),
`bk-appendix-1-answer-key.md` and `bk-appendix-1-Answer-Key.md` are one file, so the probe lost
one of them. The ticket's four names cannot share a folder, so the fixture needs one folder
per name, or it must classify names without creating the files.
