# cjus-skills

A [Claude Code](https://claude.com/claude-code) plugin marketplace holding skills by Carlos Justiniano.

Each plugin is a self-contained set of skills you install into Claude Code and invoke with a slash command. Four ship today, and the marketplace exists so the collection can grow.

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

A skill refers to its own files through `${CLAUDE_PLUGIN_ROOT}`, which Claude Code sets to the installed plugin's directory, so nothing in a skill assumes a path relative to the project you are working in.

## Requirements

Installing a plugin copies files; it resolves no dependencies. A Claude Code manifest has no
dependency-resolution step, so every binary below is one you provide yourself. Each plugin
fails loudly and specifically when something it needs is missing, rather than degrading in
silence.

**Everything needs**: Claude Code, and a POSIX shell. The plugins ship a mix of `#!/bin/sh`
and `#!/usr/bin/env bash` scripts and are run through their shebangs.

| Plugin | Needs | Optional |
|---|---|---|
| **bookcraft** | For `/makebook` only: `python3` **3.12 or newer**, the packages in `skills/makebook/requirements.txt`, Chromium via Playwright, and `pdftotext` (poppler). The other three skills need nothing beyond the standard library. | `jq`, `epubcheck` |
| **council** | Nothing. With no roster file it seats four Claude members, which needs no key, no Node and no `jq`. | `jq` **or** Node for a roster file — either, not both; `curl` to probe Ollama; Node plus `COUNCIL_OPENROUTER_API_KEY` for OpenRouter members; the `codex` CLI, logged in, for a Codex member |
| **explain** | Nothing. | Network when a `/explain:qve` page is opened, since Mermaid loads from a CDN at view time — unreachable means the diagram source stays visible, degraded rather than broken. Graphviz (`dot`) for a guaranteed-offline page |
| **pr** | `git`, the `gh` CLI authenticated against your repo, and Node for the lifecycle script | `jq`, used where present and routed around where not |

Run `${CLAUDE_PLUGIN_ROOT}/scripts/install.sh` once for `/makebook`. It builds its virtualenv
outside the plugin directory, at `${XDG_CACHE_HOME:-$HOME/.cache}/bookcraft/venv`, because a
plugin installs to a version-scoped path and a venv kept under it would be discarded on every
release.

**A broken `jq` is worse than no `jq`.** Where `jq` is optional, the plugins mean absent, not
present-but-unrunnable. bookcraft's `check-book.sh` probes it with `printf '{}' | jq -e .` and
exits 2 rather than run, because every `book.json` declaration would otherwise read as absent
and the book would be checked in the weakest mode while reporting success. The case that
motivated the probe: a stale x86-only `jq` at `/usr/local/bin/jq` shadowing a working universal
one on an arm64 Mac. Move the stale binary aside; do not weaken the probe.

## Platform support

**macOS** is the only platform these are developed and tested on, and everything here is
known to work.

**Linux and other Unixes** should work, with two edits, though no run has been recorded.
The scripts avoid GNU-only and BSD-only flags throughout, and `bookcraft/scripts/install.sh`
already resolves Playwright's cache to `~/.cache/ms-playwright` off macOS. What is macOS-shaped
is the documentation rather than the code: `/explain:qve` ends by running `open "$HTML"` to put
the page on screen, which is `xdg-open` elsewhere, and the setup hints say `brew install`
where a package manager is named. Neither is load-bearing.

**Windows is not supported**, and not by omission — the plugins are shell scripts calling
POSIX tools, and nothing here is written against `cmd` or PowerShell. **WSL2** is the likely
route, and would face the same two edits as Linux, but it is untested here. Git Bash is likely too thin: `pr` needs `git` and `gh`,
`council` and `pr` need Node, and bookcraft drives a headless Chromium through Playwright.

## Plugins

| Plugin | What it does |
|---|---|
| [**bookcraft**](plugins/bookcraft/README.md) | Writes a book, binds it into a PDF and a matching EPUB, revises it in place, and checks that its claims are ones its cited sources actually support. |
| [**council**](plugins/council/README.md) | Puts one question to several independent members and reconciles their answers without manufacturing consensus. |
| [**explain**](plugins/explain/README.md) | Explains a topic for a mid-level engineer — as prose in at most 250 words, or as a diagrammed page when the answer's shape is the point. |
| [**pr**](plugins/pr/README.md) | A GitHub-issue-backed PR lifecycle. The issue number is the ticket number, two labels carry state, and the merge closes the ticket. |

Each plugin's own README is its full documentation — every skill it ships, plus whatever setup, configuration and running costs that plugin has.

## Releasing

Each plugin releases on its own, and the procedure is the same for all four. `plugins/<plugin>/.claude-plugin/plugin.json` carries that plugin's version and is the source of truth for it. To cut a release, raise `version` there, commit, then:

```bash
claude plugin tag plugins/<plugin>
```

That creates a `<plugin>--v<version>` git tag, first checking that `plugin.json` and the plugin's entry in `.claude-plugin/marketplace.json` agree. Push the tag, and installs of that plugin pick it up. Tagging one plugin leaves the other three untouched, so their versions move independently.

Validate before releasing. The marketplace manifest and the plugin's own manifest should both pass strictly:

```bash
claude plugin validate --strict .
claude plugin validate --strict plugins/<plugin>
```

Substitute `bookcraft`, `council`, `explain` or `pr` for `<plugin>` throughout. The bare `.` in the first validate command is the repo root and stays as written — it checks `.claude-plugin/marketplace.json`, which covers all four.

## License

MIT. See [LICENSE](LICENSE).
