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
- Document contract v1, configuration, AWS prerequisites, security, Rust workflow and Claude Code workflow.
- Add offline lifecycle/worker tests and a macOS/Linux Python 3.9/3.14 CI matrix.
- Pin the Linux Python 3.9 leg to Ubuntu 22.04 after the latest image lacked that interpreter;
  use the asserted macOS system Python 3.9 floor, matching existing CI conventions.

2026-11-01 UTC — pre-merge review repairs

- Close halted on the internal review's source-read race and rustup compatibility finding.
- Read source through held directory descriptors with no-follow opens and descriptor checks.
- Preserve preinstalled rustup context without inheriting Cargo credentials or installing tools.
- Serialize jobs over a stable workspace and toolchain-bound warm session Cargo caches;
  retain immutable per-job source/results and remove stale source before execution.
- Add race, real offline Rust cache reuse/invalidation, concurrent-job isolation and
  failed-then-successful same-instance regressions. Builds never terminate the worker.

2026-11-01 UTC — close review

- Independent delta review approved the source-boundary and Rust-session repairs.
- Make the real Rust fixture portable to hosted rustup launchers; cover default and explicit
  RUSTUP_HOME without installing or downloading a toolchain.
- Refresh plan status and close summary; retain both review outcomes as evidence.

2026-11-01 UTC — documentation scope clarification

- Restrict the new plugin's documentation and metadata to Claude Code, remove the alternate
  harness adapter section, and use CLAUDE_PLUGIN_ROOT consistently in examples.
- Preserve the shared CLI, source-privacy exclusions and unrelated existing plugin content.
