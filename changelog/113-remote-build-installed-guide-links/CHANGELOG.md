# remote-build: guide links from an installed copy

Start date: 2026-11-01 UTC

Issue: https://github.com/cjus/cjus-skills/issues/113

## Changes

- `guide_links()` takes the plugin name from `.claude-plugin/plugin.json` instead of the directory,
  which is the version (`cache/<marketplace>/<name>/<version>/`) in an installed copy.
- Regression test runs setup from a copy laid out like the install cache. Version 0.3.1.
