# remote-build: catch a pinned Rust toolchain the worker image lacks before launch

Start date: 2026-11-01 UTC

Issue: https://github.com/cjus/cjus-skills/issues/118

## Changes

- Bootstrap tags each image it bakes `remote-build:toolchains` with what `builder` actually has
  (`rustup toolchain list`, host triples dropped, for example `1.97.0 stable`). No tag when rustup
  is missing or the list won't fit a tag value. The apply summary shows each image's toolchains,
  and `plan` and `apply` show `bake_toolchains`.
- `template()` reads the tag from the `describe-images` call it already makes. `setup`'s
  `repository` check compares it with the channel the Git root's `rust-toolchain` or
  `rust-toolchain.toml` pins (rustup's precedence, legacy plain-text form included):
  - a missing toolchain fails the check, with the rebuild command as `next`; the command keeps
    the image's other extra toolchains
  - a match reports the toolchain
  - an untagged image says the pin went unchecked
- `up` makes the same comparison before `RunInstances` and refuses with the same command, so a
  mismatch costs nothing.
- Not checked: a `path` toolchain, a file without a channel, components and targets.
- A tag on the image rather than a config field: the config format is versioned (a new field
  would need a contract version change), the tag describes the actual image, and hand-built
  images can carry it too (operator guide step 6 adds it).
- `--rust-toolchain`'s help, the re-run table and troubleshooting say a new list replaces the
  remembered one.
- Docs: operator guide (bake step, re-run table, summary fields, step 6, step 11), contract
  (repository selection), troubleshooting, README and the setup skill.
- Tests:
  - toolchain-file parsing
  - `up` refuses before any launch, and launches when the image has the toolchain or can't say
  - `setup` fails, passes or reports unchecked through the CLI
  - bootstrap tags images from builder's list, and a new list replaces the old one
  - an image without rustup is not tagged
  - Mutation checks: skipping the comparison, ignoring the tag, reversed file precedence, a fix
    that drops extra toolchains, an untagged bake, and merging lists instead of replacing each
    fail a test.
- Version 0.5.0.
