# Remote-build contract v1

## Commands and results

All commands use `python3 <plugin>/scripts/remote_build.py [--config FILE] [--state DIR] COMMAND`.
Successful local operations print one JSON object and exit 0. Refusals print a redacted JSON
error to stderr and exit 2. A completed remote command's exit code appears in the job result;
local `status` exit 0 means retrieval succeeded, not that the build passed.

| Command | Contract |
|---|---|
| `setup` | Probe dependencies, existing authentication, config and pinned template; no cloud mutation |
| `up [--approve-cost]` | Launch one approved worker, or reconcile an existing session without another launch |
| `snapshot PROJECT` | Save an immutable tar of eligible tracked and untracked files; print manifest and SHA-256 |
| `run --snapshot SHA --approve-upload -- ARGV...` | Submit that exact archive and command; print durable job ID |
| `status` | Report session state, expiry and recorded job-to-source mapping |
| `status --job ID` | Retrieve job state, exit code and bounded log; verify job/source identity |
| `down` | Verify account, client token, session/owner tags and instance identity before requesting termination |

The API is provider-neutral at the command boundary; provider v1 is AWS only. New providers
must preserve ownership, uncertainty and result semantics. Config and result fields may be
extended only with an explicit contract version change.

## Source contract

Git root only. Dirty tracked content and nonignored untracked files are included; tracked
deletions disappear. Ignore rules do not override the mandatory exclusions in
`remote_build.py:excluded`. Symlinks, hard links, submodules, special files and control-character
paths are rejected. The snapshot is sorted, has normalized tar metadata and preserves only
executable/nonexecutable mode. Its fingerprint hashes the bytes actually transferred; changes
after snapshot creation require a new snapshot. This is a snapshot of each file as read,
not a filesystem-wide atomic transaction: pause concurrent edits when consistency matters.

Review eligible files before passing `--approve-upload`; exclusions and secret-pattern
screening cannot detect arbitrary embedded credentials. The approved object is the saved
archive, not the current working tree. Each job extracts into a new directory, so deleted
files cannot survive from a previous run. Worker extraction rejects links and traversal.

## Recovery

Launch intent, client token, account and config hash are persisted before `RunInstances`.
Any failure after that leaves the intent in place. Re-run `up` to describe by token; it never
resubmits creation. No match can mean eventual consistency or a failed launch, so retry reads
later. If it stays unresolved, an operator must verify the token in AWS before archiving the
local intent manually. Never delete state and launch again to bypass uncertainty.

A job ID and source mapping are persisted before upload. If SSH disconnects, use `status`
to recover the ID and `status --job ID` to reconcile. Another submission is blocked while
its outcome remains uncertain. Unknown/mismatched jobs stop reconciliation; inspect privately
or tear down rather than creating a duplicate. Worker death may leave `interrupted` or
`running` without an exit code; neither is success. The worker is not a full process supervisor
and cannot prove PID identity after reboot or PID reuse. An expiry still belongs to the janitor.

`down` requests termination and retains state. Repeat it to observe `terminated`; only then
is the session archived under local `history/`. If AWS has already forgotten a terminated
instance, the outcome remains unresolved and needs operator verification. `down` with no
session is a no-op. Active jobs and all remote storage are destroyed at termination, so
retrieve results first. A failed termination call retains recoverable state.

## Boundaries

A local lock serializes commands sharing a state directory. It does not coordinate multiple
machines. Owner-tag discovery is a check, not an atomic distributed lease. Use a single client
and account-side constraints for a hard global count/cost ceiling. Worker processes enforce
job expiry while alive; neither that timeout nor a tag is independent compute cleanup.

Every job has a separate Cargo home/target directory; no concurrently writable shared cache.
No cross-session cache or binary-artifact download ships in v1. Results are private JSON files
under `results/<job-id>.json`, containing at most 1 MiB of log. Remote logs are untrusted data
and may contain private source; never commit or paste them without review.
