# remote-build: per-repository launch profiles

Start date: 2026-11-01 UTC

Issue: https://github.com/cjus/cjus-skills/issues/108

## Changes

- Private config v2: `launch_profiles` (template, pinned version, approved types per profile)
  replace the single template and type fields; `max_workers` caps the owner's concurrent workers.
  v1 configs are refused with a migration pointer.
- Repositories commit `.remote-build.json` (`version`, `launch_profile`, `instance_type`). An
  undefined profile or unlisted type is refused before any AWS call. It selects, never authorizes.
- Global `--project DIR` (default: current directory); `snapshot [PROJECT]` keeps the positional.
- State, lock, snapshots and results live under `<state>/projects/<key>/`, keyed by the checkout's
  absolute Git root. Workers carry a `remote-build:project` tag; `up` refuses a second worker for
  the project or exceeding `max_workers`; `down` verifies the project tag. The owner tag is
  unchanged, so an existing janitor keeps working.
- A session binds the shared settings plus its own profile and type, so other repositories'
  profiles and `max_workers` can change while it runs. `up` holds a launch lock in the state root.
- `setup` validates the repository's selection and its template, or every profile outside one.
- Fake AWS fixture holds several instances and honours filters. Tests: selection validation,
  per-project and max_workers checks, launch arguments, binding scope, cross-project teardown
  refusal, v2 config validation, and a CLI round trip with two repositories on different
  profiles running concurrently.
- Contract renamed to contract-v2.md; config, AWS, walkthrough, troubleshooting, security,
  README and all five skills updated. Version 0.2.0.
