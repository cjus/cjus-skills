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
