# Remote-build contract v2

## Commands and results

All commands use `python3 <plugin>/scripts/remote_build.py [--config FILE] [--state DIR] [--project DIR] COMMAND`.
`--project` names the checkout (default: the current directory); its Git root is the project.
Successful local operations print one JSON object and exit 0. Refusals print a redacted JSON
error to stderr and exit 2. A completed remote command's exit code appears in the job result;
local `status` exit 0 means retrieval succeeded, not that the build passed.

| Command | Contract |
|---|---|
| `setup` | Probe dependencies, authentication and config. Inside a checkout with `.remote-build.json`, validate that selection and its pinned template; otherwise check every launch profile's template. No cloud mutation |
| `up [--approve-cost]` | Launch one approved worker for this project with its selected profile and type, or reconcile its existing session without another launch |
| `snapshot [PROJECT]` | Save an immutable tar of the project's eligible tracked and untracked files; print manifest and SHA-256. `PROJECT` is the same as `--project` |
| `run --snapshot SHA --approve-upload -- ARGV...` | Submit that exact archive and command; print durable job ID |
| `status` | Report session state, expiry and recorded job-to-source mapping |
| `status --job ID` | Retrieve job state, exit code and bounded log; verify job/source identity |
| `down` | Verify account, client token, owner/project/session tags and instance identity before requesting termination |

The API is provider-neutral at the command boundary; provider v1 is AWS only. New providers
must preserve ownership, uncertainty and result semantics. Config and result fields may be
extended only with an explicit contract version change. v2 replaced v1's single template and
instance type with named launch profiles, a committed repository selection and per-project
sessions; v1 configs are refused.

## Repository selection

Each project commits `.remote-build.json` at its Git root: exactly `version` (1),
`launch_profile` and `instance_type`. The profile must exist in the operator's private config
and the type must be on that profile's `instance_types` list; anything else is refused before
any AWS call. The file holds no account identifiers or credentials and is uploaded with the
source like any other file. It selects; it never authorizes. A launch still needs
`--approve-cost` after the agent states the selected profile, type and lifetime.

The session binds the effective configuration: the shared private settings plus this
project's selected profile and type, never `max_workers` or other projects' profiles. Editing
another repository's profile, or adding one, leaves running sessions usable. Editing this
project's selection or its profile mid-session is refused until it is restored.

## Source contract

Git root only. Dirty tracked content and nonignored untracked files are included; tracked
deletions disappear. Ignore rules do not override the mandatory exclusions in
`remote_build.py:excluded`. Symlinks, hard links, submodules, special files and control-character
paths are rejected. Reads hold directory descriptors and use no-follow opens for every path
component, so a replacement symlink cannot redirect a read outside the project. The snapshot is sorted, has normalized tar metadata and preserves only
executable/nonexecutable mode. Its fingerprint hashes the bytes actually transferred; changes
after snapshot creation require a new snapshot. This is a snapshot of each file as read,
not a filesystem-wide atomic transaction: pause concurrent edits when consistency matters.

Review eligible files before passing `--approve-upload`; exclusions and secret-pattern
screening cannot detect arbitrary embedded credentials. The credential-assignment pattern
accepts `=` or a lone `:` as the separator, never `::`, so Rust and C++ paths such as
`Token::Comment(...)` are not mistaken for assignments. The approved object is the saved
archive, not the current working tree. Each job extracts into a new directory, so deleted
files cannot survive from a previous run. Worker extraction rejects links and traversal.

## Session ownership

Sessions are per project. Each checkout keeps its own lock, session, snapshots, results and
history under `<state>/projects/<key>/`, where the key is derived from the checkout's absolute
Git root, and its worker carries a `remote-build:project` tag with that key. Separate
checkouts, including worktrees of one repository, are separate projects, and moving a checkout
needs it moved back to recover its session. `up` refuses when this project already has a
worker or the owner already has `max_workers` active workers across all projects. `down`
verifies the project tag, so a session can never terminate another project's worker.

`up` and `down` are separate operations. The local agent working on a PR keeps the same worker
through repeated edits and tests, including after a failed command. Neither job completion nor
PR close/merge triggers teardown. The agent explicitly collects results and calls `down` when
finished. The independent maximum-lifetime janitor remains an abandoned-instance safety
backstop; an expired session cannot accept more work. A queued job can expire before execution.

## Recovery

Launch intent, client token, account and config hash are persisted before `RunInstances`.
Any failure after that leaves the intent in place. Re-run `up` to describe by token; it never
resubmits creation. No match can mean eventual consistency or a failed launch, so retry reads
later. If it stays unresolved, an operator must verify the token in AWS before archiving the
local intent manually. Never delete state and launch again to bypass uncertainty.

A job ID and source mapping are persisted before upload. If SSH disconnects, use `status`
to recover the ID and `status --job ID` to reconcile. Another submission is blocked while
its outcome remains uncertain. When the worker has no record of a job, it answers `unknown`
under the same session lock that submission holds and leaves a fence for that ID, so a
submission still in flight with that ID is refused when it arrives. `unknown` for the pending
submission is therefore final: the upload never landed and never will, so the client releases
it, drops the ID from the session (it used no worker slot), keeps the result record, and
accepts the next `run`. This covers an SSH failure before delivery, such as an unenrolled host
key. `unknown` for any other job, or a mismatched job/source, stops reconciliation; inspect
privately or tear down rather than creating a duplicate. Worker death may leave `interrupted` or
`running` without an exit code; neither is success. The worker is not a full process supervisor
and cannot prove PID identity after reboot or PID reuse. An expiry still belongs to the janitor.

`down` requests termination and retains state. Repeat it to observe `terminated`; only then
is the session archived under local `history/`. If AWS has already forgotten a terminated
instance, the outcome remains unresolved and needs operator verification. `down` with no
session is a no-op. Active jobs and all remote storage are destroyed at termination, so
retrieve results first. A failed termination call retains recoverable state.

## Boundaries

A local lock serializes commands for one project; different projects run independently, except
that `up` also holds a launch lock in the state root so the per-project and `max_workers` checks
do not race on one client. It does not coordinate multiple
machines. Owner-tag discovery is a check, not an atomic distributed lease. Use a single client
and account-side constraints for a hard global count/cost ceiling. Worker processes enforce
job expiry while alive; neither that timeout nor a tag is independent compute cleanup.

Every job retains a separate immutable source snapshot and result. Execution is serialized by
a session lock covering source sync, compiler processes and result recording. The stable
workspace preserves unchanged file mtimes and removes deleted files; only the locked job may
write the shared session Cargo home/target. The installed worker Rust toolchain remains
available through RUSTUP_HOME; auto-install is disabled and Cargo credentials are not inherited.
Compiler/Cargo version output, explicit toolchain selection and toolchain-file contents bind
the cache identity. A changed identity clears the cache. Cargo's own fingerprints handle
source, lockfile, dependency and feature changes; scripts must declare build inputs correctly.
No cross-session cache or binary-artifact download ships in v1. Results are private JSON files
under `results/<job-id>.json`, containing at most 1 MiB of log. Remote logs are untrusted data
and may contain private source; never commit or paste them without review.
