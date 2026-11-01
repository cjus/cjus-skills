# Remote-build plugin

Issue: https://github.com/cjus/cjus-skills/issues/104

Local agents can now prepare an immutable source snapshot, submit a durable Linux build/test
job to an explicitly approved AWS worker, reconnect for its result, and tear down only a
verified owned instance. The five skills share one Python CLI and contract v1; Codex uses
that CLI through an explicit plugin path.

## Validation

- 24 offline tests pass on Python 3.9.6 and 3.14.2, including executable fake AWS/SSH CLI
  integration, launch uncertainty, auth failures, ownership, exclusions, source mismatch,
  disconnect recovery, command failure, job expiry and bounded logs.
- Strict marketplace and plugin validation pass. The plugin validator reports an advisory
  missing-icon warning; no icon is required by the existing repository plugin convention.
- Repository citation check and staged whitespace check pass.
- Skill-creator quick validation could not run because its optional PyYAML dependency is
  unavailable. No dependency was installed. Plugin manifest validation is independently green.
- New code, examples, tests and PR text were reviewed for credentials, real infrastructure
  identifiers, personal paths, consumer repository names and private logs; none were included.

## Limits and review focus

Live AWS/SSH infrastructure has not been exercised. The operator must independently provision
and verify the pinned image/template, host identity, IAM/network controls and expiry janitor.
The CLI checks a janitor declaration, not deployment. Count checks are local plus owner-tag
reads, not a distributed lease or billing cap. V1 retains cache only for the session and
requires EBS deletion on termination. Jobs serialize cache writes and retain isolated immutable snapshots/results. Binary
artifact downloads and retained EBS cache are deferred.

Review launch/termination ownership, uncertain-outcome recovery, source filtering and worker
process handling first. The repository pre-merge close workflow is being completed on this branch. No GitHub
approving review, merge or release tag is part of this work.

## Key changes and interface examples

`plugins/remote-build/scripts/remote_build.py` implements the versioned client. Before a
potentially ambiguous AWS request it persists a session token, config hash and account binding:

```python
write(path, s)
# The subsequent RunInstances request uses the persisted token as its client token.
```

The public interface submits a reviewed archive rather than resynchronizing a changing tree:

```sh
python3 "$REMOTE_BUILD_ROOT/scripts/remote_build.py" snapshot .
python3 "$REMOTE_BUILD_ROOT/scripts/remote_build.py" run --snapshot <sha256> --approve-upload -- cargo test --locked
python3 "$REMOTE_BUILD_ROOT/scripts/remote_build.py" status --job <job-id>
```

`plugins/remote-build/scripts/worker.py` launches a detached supervisor, preserves each job's source/result identity while serializing a warm session workspace and Cargo cache and records bounded output plus command status. The five `skills/`
entrypoints use this interface; `reference/` defines config, source/recovery semantics and the
operator's infrastructure responsibilities. The manifests and root catalog register the plugin.

## Plan alignment and impact

All implementation phases are complete. The initial retained-volume recommendation was
narrowed to session-only retention so v1 can enforce deletion without claiming an unimplemented
cache lifecycle. CI's Python 3.9 Linux leg uses Ubuntu 22.04 because the current latest image
has no Python 3.9 package; the macOS floor follows the repository's system-interpreter pattern.

The implementation checkpoint changes 21 files, adding 1,418 lines and removing 5; subsequent
close artifacts are housekeeping. There are no Python package dependencies or changes to
existing plugin runtime behavior. The only external runtime dependencies are operator-provided
Git, OpenSSH, AWS CLI v2 and the worker toolchain. This is a new 0.1.0 interface.

For an offline manual check, run the test command in the plugin README, then strict plugin
and marketplace validation. A live manual test is explicitly outside this task's authorization.
Continuity entries and assertions audit are disabled by repository configuration.

## Deferred work triage candidates

Retained caches, binary artifact download, additional providers and MCP remain out of v1.
A separately authorized live smoke test and independent janitor provisioning belong to operator
setup; this branch does not deploy them or claim they are validated.

## Internal review repairs

The first internal review halted close on a reproduced source symlink-swap race. Source reads
now hold directory descriptors, use no-follow opens for every component, and validate the same
file descriptor before/after reading. Two race regression tests cover leaf and ancestor swaps.

Standard preinstalled rustup toolchains now remain available through the worker's RUSTUP_HOME
without inheriting Cargo credentials. Automatic installation is disabled. A real dependency-free
Rust fixture builds offline, proves a second build is Fresh, recompiles changed source, and
checks toolchain-identity cache invalidation. Session serialization prevents concurrent cache
writes and stale files are removed. A failed build followed by a successful job leaves the
same instance running until an explicit down command. PR close/merge does not trigger teardown.
