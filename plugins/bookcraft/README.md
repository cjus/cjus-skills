# bookcraft

Four Claude Code skills that write a book, bind it, revise it, and check that it told the truth.

They share one folder format, so each one's output is the next one's input. You can use any of them alone, but the value is in the chain: a book that was written against real sources, carries a record of which claim came from where, and can be corrected later without breaking the citations pointing into it.

---

## Contents

- [Install](#install)
- [Quick start](#quick-start)
- [The book folder](#the-book-folder)
- [`/createbook`](#createbook)
- [`/makebook`](#makebook)
- [`/updatebook`](#updatebook)
- [`/check-claims`](#check-claims)
- [Provenance, and the four checkers](#provenance-and-the-four-checkers)
- [Troubleshooting](#troubleshooting)
- [What ships here](#what-ships-here)

---

## Install

```bash
claude plugin marketplace add cjus/cjus-skills
claude plugin install bookcraft@cjus-skills
```

Restart Claude Code. All four slash commands become available.

**Plugin skills are namespaced by their plugin**, so you invoke them as `/bookcraft:createbook`, `/bookcraft:makebook`, `/bookcraft:updatebook` and `/bookcraft:check-claims`. A bare `/createbook` does not resolve unless you happen to have a separate skill of that name. The prefix is what keeps two plugins from fighting over a common name; this page writes it out in every command you would type, and drops it when referring to a skill by name in prose.

### One-time setup for `/makebook`

Only `/makebook` needs third-party packages. The other three use the Python standard library and bash, and work the moment the plugin is installed.

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/install.sh
```

From an ordinary shell, where `$CLAUDE_PLUGIN_ROOT` is not set:

```bash
"$(claude plugin list --json | jq -r '.[] | select(.id | startswith("bookcraft@")) | .installPath')"/scripts/install.sh
```

| Requirement | Why | If missing |
|---|---|---|
| **Python 3.12+** | `build-book.py` uses PEP 701 nested same-quote f-strings, so an older interpreter fails while *parsing* the file | `install.sh` refuses and says so. macOS ships 3.9 at `/usr/bin/python3`; `brew install python@3.12` or newer |
| **`pdftotext`** (poppler) | The builder reads the rendered PDF back to resolve page numbers | Required. `brew install poppler` |
| **Chromium** | Renders the PDF | `install.sh` fetches it through Playwright |
| **`epubcheck`** | Verifying a built EPUB rather than trusting it | Optional. `brew install epubcheck` |
| **A Palatino-class serif** | The body font stack the page measurements assume | Not fatal. Chromium falls back and the book still binds, but the type metrics shift. See [Fonts](#fonts) |

The virtualenv lands at `~/.cache/bookcraft/venv`, honoring `XDG_CACHE_HOME`. It is deliberately **outside** the plugin: Claude Code installs each plugin version into its own directory, so a venv kept inside one would be discarded on every update and rebuilt at about 170 MB plus a Chromium download. One venv at a stable path serves every version and every project. `scripts/bookcraft-python` is the wrapper that finds it, which is why the commands below name that rather than an interpreter path.

Re-running `install.sh` is safe.

---

## Quick start

Write a book, check it, bind it:

```
/bookcraft:createbook "A practical guide to Docker for first-year CS students" --source Dockerfile --source docs/
```

That plans an outline, asks you to approve it, then narrates each chapter into its own file under `books/<book-slug>/`.

```bash
${CLAUDE_PLUGIN_ROOT}/skills/createbook/scripts/check-book.sh books/docker-guide
${CLAUDE_PLUGIN_ROOT}/skills/createbook/scripts/check-provenance.sh books/docker-guide
```

Then bind it:

```
/bookcraft:makebook "A Practical Guide to Docker" books/docker-guide
```

You get `a-practical-guide-to-docker.pdf` and `.epub` in the same folder.

Later, when something changes:

```
/bookcraft:updatebook books/docker-guide "chapter 5's Compose version has moved to v2.35"
```

And when you want to know whether the sources actually say what the book says they say:

```
/bookcraft:check-claims books/docker-guide --chapters 5
```

---

## The book folder

Everything here operates on one folder shape. `/createbook` writes it; the others read it.

```
books/<book-slug>/
  <slug>-01-<chapter-slug>.md     one file per chapter, filename sort = reading order
  <slug>-02-<chapter-slug>.md
  ...
  OUTLINE.md                      the plan each chapter was written against
  book.json                       title, byline, sources, tags on/off, front matter
  about-this-book.md              where the book's material came from
  glossary.md                     derived from the outline's term ledger
  diagrams/                       hand-authored SVG figures, written by /makebook
```

Two rules the format depends on, both measured against the builder rather than assumed:

- **Chapter numbers are zero-padded.** Chapters are collected with a plain lexicographic sort, so `bk-1-a.md`, `bk-10-c.md`, `bk-2-b.md` is the order an unpadded set actually produces.
- **The H1 is the file's first line.** The builder reads the chapter title from line 1 and only when it starts with `# `. A blank first line or YAML frontmatter drops the chapter to a prettified filename on the contents page.

### Everything a build needs is in the folder

**The builder reads nothing from the project you happen to be working in.** Every figure, image and cover reference resolves against the book folder you pass it, never against a repository root, a config file, or a path relative to your shell. A book folder is portable on its own: move it anywhere, point the builder at it, and you get the same PDF.

That is why figures belong in the folder rather than beside it. A chapter referencing `diagrams/01-something.svg` gets `<book-folder>/diagrams/01-something.svg`, and the EPUB packages that file into the archive. A reference climbing out with `../` still resolves and still packages correctly, so nothing breaks today; what you lose is the portability, because the folder now depends on a file that does not travel with it.

A reference that resolves to nothing is handled rather than shipped: the build warns with `N image(s) were not found and are not in the package`, naming each one, and the EPUB prints `[missing image: <path>]` where the figure would have been. That is deliberate, since leaving a dangling `src` in the archive would fail the whole book on `epubcheck`'s `RSC-007` instead of showing you one visible gap.

Nothing is fetched at build time either. Figures are hand-authored SVG rendered by the Chromium the builder already runs, so there is no diagram binary to install, no JS bundle, and no network access in a build. What a build touches is the book folder, the plugin, the venv, `pdftotext`, and the fonts on the machine.

### Paragraph tags

In a tagged book, which is the default, every paragraph opens with its address:

```
[3-1] Every image you have ever pulled arrived in pieces, and the pieces are
the reason a rebuild that changes one line finishes in two seconds.
```

`[3-1]` is chapter 3, paragraph 1. These reach the printed page, because they are text rather than markup, so the address a reader cites off paper is the address the markdown carries. That is the whole reason `/updatebook` edits in place: other files cite these, and regenerating the book would silently repoint every one of them.

Pass `--no-tags` to `/createbook` for a book meant only to be read.

---

## `/createbook`

Writes a whole book from a one-line description.

```
/bookcraft:createbook <what the book should be> [output-folder]
```

| Argument | Meaning |
|---|---|
| First (required) | What the book is: subject, and where useful the reader and the angle. Name no reader and the skill asks for one |
| Second (optional) | Output folder. Defaults to `books/<book-slug>/` |
| `--source <path>` (repeatable) | A resource the book is written against: a repo file, a folder, a PDF |
| `--minutes <N>` | How long the reader has. Sizes the book |
| `--no-tags` | Write without paragraph tags |

**The sources are the point.** A book here is a guide to a set of resources first and to its subject second: the resources are the authority, what the model knows fills what they leave out, and the reader can tell which is which. With no sources at all you get a legitimate but different book, one where every chapter header reads `Fills in: everything`, so the skill asks before going that way.

**URLs are never stored.** Web material is read at drafting time and then referenced by the terms a reader would search for. A link rots between the writing and the reading, so anything web-derived is marked `fill` by construction. What can be re-checked later is a repo file or a PDF, and the ledger records which sources are re-openable.

It plans the outline first and stops for your approval before narrating anything. That gate shows you the reader it settled on, and says where it came from — your argument, your answer to the question it asked, or its own inference — because an inferred persona reaches every chapter looking exactly like one you supplied.

### Two profiles

The gate also shows you the **profile**, which is the rule set the whole book is written under. It is one word in `book.json` at that point and a rewrite of every chapter afterwards.

| Profile | For | What it changes |
|---|---|---|
| `narration` | A book read once, straight through. An explainer, a primer, a long argument | Nothing. These are the rules every book was written under before profiles existed |
| `guide` (default for a new book) | A book opened at one chapter the week it is needed. A preparation guide, a runbook, a handbook | Chapters stand alone instead of chaining: each opens by orienting the reader and closes on its main point or next step; headings pass a contents-page test; `## In short` is the one summary; four labelled callouts, one idea each; numbered procedures; reference matter moves to appendices |

**The test is whether the reader opens the book at chapter one.** Someone preparing to teach week nine opens chapter nine, having read chapter eight a month ago. Everything the narration rules buy that reader costs them instead.

Set it with `"profile"` in `book.json`. **A new book gets `"guide"`**, because a book built from a set of sources is nearly always opened at the chapter somebody needs rather than read start to finish. Say so at the gate to get `"narration"` instead.

**An absent key still reads as `narration`, and that is not the same default.** It is what every book written before profiles existed is held to, so those keep passing untouched: re-checking one under the guide rules would fail it on a `## In short` section nobody had asked for. `/createbook` therefore writes the key explicitly rather than leaning on its absence, and `check-book.sh` prints the profile first on its summary line so a run against the wrong rule set is visible rather than silent.

---

## `/makebook`

Binds a folder of markdown into a PDF and a matching EPUB.

```
/bookcraft:makebook "Book Title" path/to/folder
```

Or directly:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/bookcraft-python \
  ${CLAUDE_PLUGIN_ROOT}/skills/makebook/scripts/build-book.py \
  "Book Title" path/to/folder
```

| Flag | Effect |
|---|---|
| `--out path/to/book.pdf` | Write elsewhere. The EPUB follows, taking the same path with an `.epub` suffix |
| `--type-size <N>` | Paragraph size, 11.8 to 17. Default 14 |

**Every run writes both formats.** There is no flag to pick one, because a book worth binding is worth having in both and a flag is one more thing to remember.

What it produces: a cover, a contents page, one chapter per file in filename order, hand-authored SVG figures where a concept needs one, a glossary where the folder carries one, and a back-of-book index whose page numbers are read back out of the rendered PDF rather than guessed. The build reports when page numbers have settled, meaning a re-read of the finished PDF reproduces every printed number.

### The reading edition

`--reading-edition`, or `"edition": "reading"` in `book.json`, binds the same folder with the workshop marks taken down: paragraph tags off the page, and the chapter header's `Draws on` and `Fills in` rows moved to endnotes. **The markdown is never touched**, so the tags other files cite keep resolving and both editions bind from one folder.

**A guide book binds the reading edition by default.** `/createbook` writes the key into every `guide` book's `book.json`, because a guide is handed to readers. The operator's tagged copy is `--no-reading-edition` with its own `--out`.

**Source keys print as their display names**, in the header of either edition and in the reading edition's endnotes, wherever `book.json` gives a source a `display` name. And the invisible markers the build uses to find page numbers are hidden in the finished PDF, so a screen reader or a copy no longer picks up strings like `ZQCH001QZ`.

### Type size

| `--type-size` | Characters/line | Use |
|---|---|---|
| `11.8` | 80.6 | The compact edition |
| **14** (default) | **67.6** | Closest to the classical optimum of 66 |
| `17` | 55.2 | Large print |

14pt is the default because it lands nearest the 45-to-75 range's ideal and is the last size whose justification stays where the book already justifies. 17pt costs +96% paper against the floor. `references/type-size.md` carries the full arithmetic, including what each end of the range spends and why the ceiling is where it is.

### Fonts

The body stack is `Palatino, "Palatino Linotype", "Iowan Old Style", Georgia, serif`, and **the characters-per-line figures above were measured with it resolving to real Palatino.** On a machine where none of the first three faces are installed, the book still binds and nothing warns you, but the measure changes under it.

Measured at 40pt on one string: the stack and Palatino both give 1054.06px, Georgia gives 1063.84px, and the generic serif fallback gives 979.06px. So Georgia sets about 1% wider and a bare serif fallback about 7% narrower, which moves the line length and the page count away from the table.

This is worth knowing in two situations. If your page counts disagree with the table, check which face you actually got. And if a book is bound on more than one machine, bind it on the same one each time, or the pagination will not match between runs.

Headings, captions, the running footer and the contents page use `system-ui`, and code uses `"SF Mono", Menlo, Consolas, "Liberation Mono", monospace`. Both have wide fallbacks and neither carries a measurement that depends on the exact face.

### Figures

Figures are hand-authored SVG, rendered by the Chromium the builder already runs, so a book with diagrams needs no diagram toolchain. The sizing rule is the one that bites: an SVG scales to its container, so the font size written in the SVG is not the size that reaches the page.

```
rendered_pt = svg_font_px × (measure_pt ÷ viewBox_width)
```

**8pt is the floor for a figure label**, and the builder fails you on it rather than leaving it to inspection. Design at a viewBox width of 640 to 900; slide-sized art at 1280 and up with 14px labels renders around 4.5pt in a book column, which is unreadable. `references/diagram-style.md` has the multiplier table, the palette, and the accessibility scaffolding every figure carries.

Raster figures (`.png`, `.jpg`, `.gif`, `.webp`) bind and package, but the builder cannot read the type inside one, so it lists them as *not checked* against the legibility floor rather than passing them silently. A passing DPI number is not a legibility pass.

---

## `/updatebook`

Revises a book in place.

```
/bookcraft:updatebook <book-folder> <what to change>
```

| Argument | Meaning |
|---|---|
| First (required) | The folder holding the book |
| Second (required) | What to change, in your words: `"add a chapter on partitioning"`, `"chapter 5's SQLite version has moved"` |

**A chapter the instruction does not reach comes back byte-identical.** Not similar, and provably so: the skill diffs against the starting state to show it. That is the guarantee the whole skill exists for, because paragraph tags are addresses other files cite and a rerun would renumber them silently.

Two things travel with an edit, or the record stops being one:

- **`OUTLINE.md`** is what the book was written against, so a change to a chapter's scope, terms or anchors moves the outline in the same run.
- **`glossary.md`** is derived from the outline's term ledger, so a term that arrives or retires reaches it in the same run.

**A new paragraph takes a lettered tag, so nothing renumbers.** A paragraph added after `[5-12]` is `[5-12a]`, and `[5-13]` stays where it is. A paragraph grows only while it stays at 90 words, and new text never goes into a callout, table or list just because those take no tag.

**Some changes are not edits.** When a fact a chapter's plans are built on changes, or a chapter needs several new paragraphs at once, the skill rewrites that one chapter, keeping its number and repointing citations into it. When the chapters' boundaries or order change, or the rules the book was written under do, it says the book is due for a recreate with `/createbook`. Either way it moves any fact a revision put only into the prose into `OUTLINE.md` first, so the rewrite does not drop it.

It runs both checkers before the edit as well as after, because a failure that was already there is not yours and finding that out afterwards costs an hour. It stops on uncommitted changes in the book folder, since those poison the proof that untouched chapters are untouched.

A rebind is not automatic: an in-place edit leaves the bound PDF and EPUB stale, and the skill reports that with the command to fix it rather than running it for you.

---

## `/check-claims`

Checks paraphrased claims against the sources their marks name, one agent per chapter, each reading the real source.

```
/bookcraft:check-claims <book-folder> [--chapters N,M]
```

This catches the failure no script can reach: **a mark that names a real file, points at a real page, quotes nothing, and sits beside a sentence that page never supports.** The three mechanical checks below it verify that the source is declared and on disk, that the locator resolves, and that long quotations appear where they claim to. None of them touches a paraphrase. Only a model reading both settles it.

Three things it is not:

- **Not a gate.** It reports; nothing fails on a finding. The quotation check one rung below was built as a hard failure, fired ten times against the reference book, and was wrong ten times. It reports now for that reason, and a paraphrase judgement is softer still.
- **Not a prose review.** Prose quality is explicitly out of scope in `reference/judgement.md`.
- **Not cheap.** One agent per chapter reading real sources is minutes of wall time and real tokens. Nothing runs it for you.

Pass `--chapters` to scope it. An `/updatebook` run already knows which chapters its edit reached.

---

## Provenance, and the four checkers

Every unit in a book carries a mark saying where its claims came from:

```markdown
<!-- src: docs/build.md § Caching -->
<!-- src: Dockerfile; fill (the framing) -->
<!-- src: docker build output, measured 2026-09-10 -->
```

`fill` means the model supplied it and nothing can re-check it later. The format asks a book to declare that honestly rather than hiding it.

Four checks run over a book, in ascending order of what they are worth. The first three are scripts; the fourth is `/check-claims`.

| Checker | Direction | Answers |
|---|---|---|
| `check-book.sh` | Inside the book | Filenames, ordering, the H1, the H2 per part, the paragraph tags, the markdown a chapter may not carry |
| `check-provenance.sh` | Marks pointing **out** | Is the named source declared and present? Does the locator resolve? Does every quotation of 25+ characters appear in a source the mark names? |
| `check-references.sh` | Citations pointing **in** | Do `ch. N` and `[N-M]` citations from other files resolve to chapters and paragraphs that exist? Does a quotation attributed to a chapter appear in *that* chapter? |
| `/check-claims` | Both, with a reader | Does the source actually support the paraphrase beside the mark? |

```bash
check-book.sh [--require-tags | --no-tags] <book-folder>
check-provenance.sh [--locators-only|--quotes-only] [--emit-worklist DIR] [--chapters N,M] <book-folder>
check-references.sh [--since <ref> | --no-baseline] <book-folder> <referring-file>...
render-report.py <findings-dir> <book-folder> [--worklist <dir>] [--command "<the command>"]
```

All of them live under `${CLAUDE_PLUGIN_ROOT}/skills/createbook/scripts/`, except `render-report.py`, which is `/check-claims`'s and sits under that skill.

**Read the census lines, not only the exit code.** `check-provenance.sh` reports how many components were `fill`, how many locators went unparsed, and how many quotations could not be verified. Those numbers move without moving the exit code, and a rise in them is worth a sentence even though neither fails a run.

**A `REVIEW` item is not a failure and not an all-clear.** The tools report `OK*` when nothing failed but review items are still unread, which is deliberate: it is not a pass until someone has been through them.

### Fixtures

`skills/createbook/fixtures/` holds small books that exercise the checkers. One command runs every folder and asserts what each is supposed to report:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/test-fixtures.sh            # every folder, every assertion
${CLAUDE_PLUGIN_ROOT}/scripts/test-fixtures.sh --strict   # a skipped check is a failure
```

That is what CI runs on every push and pull request. Give it a plugin path to grade an installed copy rather than the source tree, which is how a packaging defect is caught — a lost executable bit, or a file that did not ship at all.

The folders are also the fastest way to see what a single failure looks like:

```bash
cd ${CLAUDE_PLUGIN_ROOT}/skills/createbook
./scripts/check-book.sh fixtures/fence                    # exits 0
./scripts/check-book.sh fixtures/guide                    # exits 0, the guide profile
./scripts/check-book.sh fixtures/guide-under-narration    # exits 1, five failures by design
./scripts/check-book.sh fixtures/provenance               # exits 0
./scripts/check-provenance.sh fixtures/provenance         # exits 1, six failures by design
./scripts/check-provenance.sh fixtures/provenance --chapters 1   # exits 0, chapter 1 is clean
./scripts/check-book.sh fixtures/guide-reports            # exits 0, with seven REPORT lines
./fixtures/jq-unrunnable/run.sh                           # exits 0, the jq guard still fires
./fixtures/ledger/run.sh                                  # exits 0, --ledger-only still fires
./fixtures/paragraph-stop/run.sh                          # exits 0, the stop fails a guide and reports under narration
./fixtures/lettered-tags/run.sh                           # exits 0, every checker accepts [1-2a]
```

Chapter 1 of the provenance fixture holds only passing marks, so a run reporting anything against it is a regression. Chapter 2 holds one of each failing shape, named in the line above it.

**`guide` and `guide-under-narration` are the same chapters under different profiles.** The first declares `"profile": "guide"` and passes; the second declares nothing, so the narration rules apply and every guide-only construct in it fails. Running both is what shows the profile is doing the work rather than the checker having gone quiet.

**An expected exit code is not an assertion on its own.** `fixtures/provenance/` exited 1 under `check-book.sh` for a year, for a structural reason unrelated to provenance, and an exit-code-only suite would have passed it the whole time while reporting nothing about what the folder exists to check. So `test-fixtures.sh` pairs every expectation with a string the output has to carry, and a folder covered by neither a manifest row nor a `run.sh` fails the run rather than going quiet.

**`guide-reports` passes and draws every report.** A `REPORT` line fails nothing: it is a long sentence, a callout holding two ideas, a summary copying its chapter, a phrase recurring across chapters, or a path-like source key in a header. The manifest row names each one, so a report that stops firing fails the suite.

**Five fixtures are scripts rather than folders to check.** A book folder cannot express a `PATH` to manipulate or a mutated copy to compare against, so those carry a `run.sh` beside them and the suite runs it. `jq-unrunnable/run.sh` runs `check-book.sh` three times against its own fully-declared book: with a working `jq`, expecting the three modes to read `required`; with a `jq` that exits 126, expecting the run to stop; and with no `jq` on `PATH` at all, expecting the documented fallback, which grades in the weakest mode and says so. No one of the three passes for the right reason alone — without the second the guard could be deleted and nothing would say so, without the first a checker that rejected every book would pass, and without the third a CI runner with no `jq` would grade every folder in the weakest mode while still reporting success. `ledger/run.sh` covers `check-provenance.sh --ledger-only`, and `check-claims/fixtures/appendix/run.sh` covers the appendix rules. `paragraph-stop/run.sh` runs one chapter under both profiles, because the 90-word stop fails a guide book and only reports under narration. `lettered-tags/run.sh` runs a revised chapter through all three checkers and mutates it three ways, one broken lettering sequence each.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `SyntaxError: f-string: unmatched '['` | Python older than 3.12 | Run `install.sh`, which checks the version and says what to do |
| `bookcraft: no interpreter at ...` | Setup has not run, or the cache was cleared | `${CLAUDE_PLUGIN_ROOT}/scripts/install.sh` |
| `missing dependency: <name>` | The venv exists but is incomplete | Re-run `install.sh`; it upgrades in place |
| Page numbers wrong in the index | `pdftotext` is not on PATH | `brew install poppler` |
| makebook stopped working after a plugin update | Should not happen, since the venv is outside the plugin. If it does, the cache path was cleared | Re-run `install.sh` |
| Figures warn about type below 8pt | The SVG was designed at slide width | Redesign against a viewBox of 640 to 900. Widening the figure buys only 17% |
| A chapter titles itself from its filename | The H1 is not line 1 | Move it to the first line; no blank line, no frontmatter above it |
| Page counts disagree with the type-size table, or differ between machines | The body font stack fell back to something other than Palatino | Install a Palatino-class serif, or bind the book on one machine consistently. See [Fonts](#fonts) |
| `warning: N image(s) were not found and are not in the package` | A figure reference resolves to nothing | Fix the path. The EPUB prints `[missing image: <path>]` in the text rather than shipping a dangling `src`, which would fail the whole book on `epubcheck`'s `RSC-007` |
| Chapters bind out of order | Unpadded chapter numbers | Zero-pad them, to three digits past 99 chapters |

---

## What ships here

```
.claude-plugin/plugin.json          name, version, metadata
scripts/install.sh                  one-time venv setup, with the Python 3.12 gate
scripts/bookcraft-python            runs a bookcraft script under that venv
scripts/test-fixtures.sh            runs every fixture folder and asserts what it reports
skills/
  createbook/
    SKILL.md                        the procedure
    NOTES.md                        what is measured and what is asserted
    reference/chapter-prose.md      the prose rules every chapter follows: shape, voice, budgets
    reference/guide.md              the guide profile's own rules, with examples
    reference/narration.md          the narration profile's handoff rules
    scripts/check-book.sh           structure
    scripts/check-provenance.sh     marks pointing out
    scripts/check-references.sh     citations pointing in
    fixtures/                       books that exercise the checkers, plus the run.sh
                                    fixtures for what a book folder cannot express
  makebook/
    SKILL.md                        the procedure
    requirements.txt                playwright, markdown-it-py, mdit-py-plugins, EbookLib
    scripts/build-book.py           the builder
    references/type-size.md         the arithmetic behind 14pt and the range
    references/diagram-style.md     figure sizing, palette, scaffolding
    references/figure-template.svg  a starting point
  updatebook/
    SKILL.md, NOTES.md
  check-claims/
    SKILL.md
    reference/judgement.md          what a verdict means and what is in scope
    scripts/render-report.py        turns per-chapter findings into one report
    fixtures/                       the appendix-versus-chapter collision, and its runner
```

`NOTES.md` files are not loaded at runtime. They record which numbers in a spec were measured and which were asserted, so anyone tightening a rule knows which kind they are touching. Read the relevant one before changing a ceiling.

---

## License

MIT. See the [repository root](https://github.com/cjus/cjus-skills).
