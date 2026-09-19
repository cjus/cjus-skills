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

### council

Puts one question to several independent members and reconciles their answers without manufacturing consensus. A single model asked three times gives you three draws from one error distribution; this is for the calls where that difference matters.

Nothing to configure to start: with no roster the council is four Claude members on distinct models, needing no key, no Node and no `jq`. Everything beyond that is opt-in.

| Skill | What it does |
|---|---|
| `/council:ask` | Fans one question out to every seated member, then reconciles — verbatim, sorted into agreement/complementary/conflict, or Delphi-pooled so a correct minority survives the second round. Refuses to compute a consensus score, and reports how correlated the roster actually is every time. |
| `/council:setup` | Writes the roster, which is a consent record rather than a capability list. Asks provider by provider what you agree to spend, stating each choice's cost where it offers it, and never seats a paid provider just because it is installed. |
| `/council:status` | A read-only 20-second answer to "what would this seat right now, and why is it still HOMOGENEOUS": key resolution and its source, roster state, per-member seating, and anything consented but unavailable with the reason. |

Seating is a join, not a lookup — a member needs both the roster's consent and availability on this machine. A roster can enable OpenRouter with four vetted models while no key resolves anywhere, and the council then runs, agrees with itself, and reports a class that reads like a roster problem rather than a key problem. `/council:status` is what shows you which it was.

### explain

Explains a topic for a mid-level engineer, in prose or as a page you can look at. Same audience and same honesty bar; the medium is the only difference.

| Skill | What it does |
|---|---|
| `/explain:qe` | Explains a concept in at most 250 words: the core idea, then the mechanism, then why it exists. Simplifies freely, but says so where precision was traded away rather than leaving a clean lie. |
| `/explain:qve` | Builds one self-contained HTML page with diagrams and opens it, for when the answer's *shape* is the point. Refuses rather than decorates: if a topic has nothing worth drawing, it says so and points back at `/explain:qe`. |

### pr

A GitHub-issue-backed PR lifecycle. The issue number is the ticket number, two labels carry state, and the merge closes the ticket. Works in any repo with a GitHub remote.

Run `/pr:init` once per repo. It detects what it can, asks about the rest, writes `.claude/pr-config.json`, and creates the `status:*` and `priority:*` labels the queue runs on.

```
/pr:init → /pr:ticket → /pr:start → [ work ] → /pr:pre-test → /pr:close → (merge) → /pr:cleanup
```

| Skill | What it does |
|---|---|
| `/pr:init` | One-time setup: config file plus the label scheme. |
| `/pr:ticket` | Files an issue as `status:todo` + `priority:high` and reports the branch name it yields. |
| `/pr:start` | Creates the branch (in a worktree when configured), installs dependencies, writes the plan folder, moves the issue to `status:in-progress`. |
| `/pr:pre-test` | Opens a draft PR so CI starts, runs the configured checks and a code review, and says whether the branch is ready to test by hand. |
| `/pr:close` | Required before a merge. Conflict, drift and check gates, a review gate, a **verified** closing reference, handoff artifacts, deferred-work triage, then commit and push. |
| `/pr:cleanup` | After the merge: confirms the issue closed, removes the worktree, deletes the branch, pulls the merge. |
| `/pr:abort` | Ends a branch that will never merge. Closes the issue as *not planned* and deletes everything. Permanent. |

Alongside the spine: `/pr:cp`, `/pr:status`, `/pr:resume`, `/pr:sync`, `/pr:plan-check`, `/pr:precompact`, `/pr:condense`, `/pr:summary`, `/pr:commitmsg` and `/pr:sanity`. Working on the queue rather than a branch: `/pr:next`, `/pr:reviews` and `/pr:triage`.

#### Configuration

Everything repo-shaped lives in `.claude/pr-config.json`, and every key is optional. Defaults give you `feature/123-slug` branches with the bare issue number as the ticket ID, worktrees on, and no check commands. Set `ticketPrefix` for `ABC-123`-style IDs, turn worktrees off, point `checks.*` at your lint and test commands, or disable the continuity and assertions conventions entirely. The full table is in `plugins/pr/reference/config.md`.

#### Hooks

Three, declared in the plugin's own `hooks/hooks.json`, so they install with the plugin and need no `.claude/settings.json` edit. **They are inert in any repo that has no `.claude/pr-config.json`**, which makes `/pr:init` writing that file the act that turns them on: a plugin enabled at user scope otherwise reaches every repo on the machine, and a hook is ambient where a skill is invoked. See `plugins/pr/hooks/README.md`.

- **Session start** loads the current branch's plan folder into a new or compacted session.
- **Default-branch guard** (`PreToolUse`) requires operator approval for a commit or push on the default branch. Ships with a probe suite; run it after any edit to that hook, because nearly every defence in it exists because the obvious spelling was measured to fail open.
- **Close gate** (`Stop`) refuses to end a turn while a close is in flight and its artifacts are uncommitted.

Turn the guard or the close gate off per repo with `mainGuard.enabled` and `closeGate.enabled`. To turn all three off, disable the plugin.

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
  council/
    .claude-plugin/plugin.json    the plugin manifest, and the version of record
    reference/roster.example.json a commented roster to copy
    reference/*.md                roster format, provider calls, trust boundary
    scripts/council-lib.sh        shared sh helpers: key chain, paths, defaults
    scripts/council-state.sh      the seating join, --text or --json
    scripts/detect.sh             capability probe, injected at skill load
    scripts/*.mjs                 the Node side: key chain, OpenRouter, roster parser
    scripts/test-*.sh             four probe suites
    skills/<name>/SKILL.md        one directory per skill
  explain/
    .claude-plugin/plugin.json    the plugin manifest, and the version of record
    skills/<name>/SKILL.md        one directory per skill
    skills/qve/references/        the page template qve fills in
  pr/
    .claude-plugin/plugin.json    the plugin manifest, and the version of record
    reference/*.md                the rules the skills cite, owned by the plugin
    scripts/pr-lifecycle-state.mjs  computes where a branch sits in the lifecycle
    hooks/hooks.json              declares the three hooks, so they ship with the plugin
    hooks/*.sh                    the three hooks plus a probe suite
    agents/code-reviewer.md       the review agent the close gate spawns
    skills/<name>/SKILL.md        one directory per skill
```

A skill refers to its own files through `${CLAUDE_PLUGIN_ROOT}`, which Claude Code sets to the installed plugin's directory. Nothing in a skill assumes a path relative to the project you are working in.

Reference documents are how a plugin's skills stay repo-agnostic. `pr` carries the ticketing, evidence, scope and lifecycle rules its skills cite, so nothing depends on the host repo having a `CLAUDE.md`; `council` carries the roster format, the provider invocations and the trust boundary, so its three skills document each of those once between them.

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
