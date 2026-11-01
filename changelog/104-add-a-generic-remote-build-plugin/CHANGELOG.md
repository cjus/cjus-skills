# Add a generic remote-build plugin

Start date: 2026-11-01 UTC

Issue: https://github.com/cjus/cjus-skills/issues/104

## Changes

- Add remote-build 0.1.0 manifest, marketplace/catalog registration and five namespaced skills.
- Add a standard-library Python client and Linux worker for approved AWS launch, immutable
  source snapshots, detached jobs, result retrieval and ownership-checked teardown.
- Persist uncertain launch/job intent before external calls; require reconciliation before retry.
- Require strict SSH verification, private state, mandatory source exclusions, pinned templates,
  explicit storage deletion and an operator-confirmed independent expiry janitor.
- Document contract v1, configuration, AWS prerequisites, security, Rust workflow and Codex adapter.
- Add offline lifecycle/worker tests and a macOS/Linux Python 3.9/3.14 CI matrix.
- Pin the Linux Python 3.9 leg to Ubuntu 22.04 after the latest image lacked that interpreter;
  use the asserted macOS system Python 3.9 floor, matching existing CI conventions.
