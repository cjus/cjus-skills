# cjus-skills

A [Claude Code](https://claude.com/claude-code) plugin marketplace holding skills by Carlos Justiniano.

Each plugin is a self-contained set of skills you install into Claude Code and invoke with a slash command. The marketplace exists so the collection can grow: `bookcraft` is the first plugin in it, not the whole of it.

## Install

Add the marketplace once:

```bash
claude plugin marketplace add cjus/cjus-skills
```

Then install a plugin from it:

```bash
claude plugin install bookcraft@cjus-skills
```

Restart Claude Code, and the plugin's skills become available as slash commands. **Plugin skills are namespaced by their plugin**, so they are invoked as `/<plugin>:<skill>`, for example `/bookcraft:makebook`. A bare `/makebook` does not resolve; the prefix is what keeps two plugins from fighting over a common name.

## Plugins

### bookcraft

Writes a book, binds it, revises it, and checks that it told the truth. Four skills that share one folder format, so the output of each is the input of the next.

| Skill | What it does |
|---|---|
| `/bookcraft:createbook` | Turns a one-line description into a planned chapter outline, then narrates every chapter into its own markdown file, named so a plain filename sort is the reading order. |
| `/bookcraft:makebook` | Binds a folder of markdown into an ebook-style PDF and a matching EPUB, with a cover, a contents page, hand-authored SVG figures, and a back-of-book index whose page numbers are read back out of the rendered PDF. |
| `/bookcraft:updatebook` | Revises a book in place. Edits only the chapters an instruction reaches and leaves every other chapter byte-identical, so the paragraph tags other files cite keep pointing where they did. |
| `/bookcraft:check-claims` | Reads each chapter's sources for real, one agent per chapter, and checks that the paraphrased claims are ones those sources actually support. It catches what no script can: a provenance mark that resolves perfectly and sits beside a sentence its source does not support. |

#### One-time setup for `/makebook`

`/makebook` renders its PDF through headless Chromium and needs Python packages the others do not. Run the installer once. Inside a Claude Code session the plugin's directory is in `$CLAUDE_PLUGIN_ROOT`:

```bash
${CLAUDE_PLUGIN_ROOT}/scripts/install.sh
```

From an ordinary shell, ask `claude` where the plugin landed and run it from there:

```bash
"$(claude plugin list --json | jq -r '.[] | select(.id | startswith("bookcraft@")) | .installPath')"/scripts/install.sh
```

It builds a virtualenv, installs `playwright`, `markdown-it-py`, `mdit-py-plugins` and `EbookLib`, and fetches Chromium. Re-running it is safe.

**Python 3.12 or newer is required.** `build-book.py` uses nested same-quote f-strings ([PEP 701](https://peps.python.org/pep-0701/)), so an older interpreter fails while parsing the file rather than with a useful message. The installer checks the version and refuses rather than building a venv that cannot work. macOS ships 3.9 at `/usr/bin/python3`; `brew install python@3.12` or newer covers it.

Two host tools are used and are not Python packages. `pdftotext` (`brew install poppler`) is required, because the builder reads the rendered PDF back to resolve page numbers. `epubcheck` (`brew install epubcheck`) is optional, and only needed to verify a built EPUB rather than trust it.

**The venv lives at `~/.cache/bookcraft/venv`, outside the plugin,** honoring `XDG_CACHE_HOME` where it is set. Claude Code installs each plugin version into its own directory, so a venv kept inside one would be discarded on every update and rebuilt from nothing, at about 170 MB plus a Chromium download. One venv at a stable path serves every version and every project. `scripts/bookcraft-python` is the wrapper that finds it, which is why the documented commands name that rather than an interpreter path.

The other three skills need no setup. Their scripts use only the Python standard library and bash.

## Layout

```
.claude-plugin/marketplace.json   the marketplace manifest
plugins/
  bookcraft/
    .claude-plugin/plugin.json    the plugin manifest, and the version of record
    scripts/install.sh            one-time venv setup
    scripts/bookcraft-python      runs a bookcraft script under that venv
    skills/<name>/SKILL.md        one directory per skill
```

A skill refers to its own files through `${CLAUDE_PLUGIN_ROOT}`, which Claude Code sets to the installed plugin's directory. Nothing in a skill assumes a path relative to the project you are working in.

## Releasing

`plugins/bookcraft/.claude-plugin/plugin.json` carries the version, and it is the source of truth. To cut a release, raise `version` there, commit, then:

```bash
claude plugin tag plugins/bookcraft
```

That creates a `bookcraft--v<version>` git tag, first checking that `plugin.json` and the marketplace entry agree. Push the tag, and installs of the plugin pick it up.

Validate before releasing. Both manifests should pass strictly:

```bash
claude plugin validate --strict .
claude plugin validate --strict plugins/bookcraft
```

## License

MIT. See [LICENSE](LICENSE).
