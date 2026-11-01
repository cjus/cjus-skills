# Troubleshooting and recovery

Treat an unknown outcome as unknown. Do not clear state, switch owner names, weaken SSH
verification or launch replacements merely to make a command succeed.

For setup problems, run `setup`: every failing check names its next step and links the
[operator guide](operator-guide.md) section that fixes it.

## Bootstrap

`bootstrap.py` prints progress to stderr and, on failure, one JSON line naming what failed with
AWS's own error text. Re-running the same `apply` is always the first recovery step: it removes
build machines, key pairs and images an interrupted run left behind, then carries on.

| Symptom | Meaning and next action |
|---|---|
| A private config or AWS profile already exists | Apply refuses before changing anything. `--replace-config` backs the config up; `--replace-profile` or another `--daily-profile` resolves a profile name bootstrap did not write. |
| A type does not run an architecture, or no subnet offers every type | Choose types of the profile's architecture (`c7g` and `t4g` are arm64; `c7i` and `t3` are amd64), or pass `--subnet` in a zone that offers them. |
| Stack deploy failed | The error lists the failed resources and AWS's reasons (often a missing admin permission, or a name already taken by a resource from manual setup). Fix it and re-run; a stack that failed to create is deleted and retried. |
| No SSH host key in the console output | The build machine's console never printed its keys. Re-run; if it repeats, the base image or type may not support console output (use a Nitro type). |
| Cannot reach the build machine over SSH | Your public address changed, or `--address private` lacks a route. Re-run on the network you will use, or pass `--cidr`. |
| Provisioning failed | Read the log the error names (in `~/.local/state/remote-build/bootstrap/`). Fix the script, or re-run with `--keep-on-failure` and SSH in as `ubuntu` to investigate; the next apply removes the machine. |
| The daily profile cannot launch an approved worker | IAM can take minutes to apply; re-run. If it persists, check the admin profile may assume roles (`sts:AssumeRole`) and that `~/.aws/config` holds the profile bootstrap wrote. |
| Janitor test `failed` | Read `/aws/lambda/remote-build-<owner>-janitor` in CloudWatch, fix the cause, and re-run with `--retest-janitor`. `janitor_confirmed` stays false until it passes. |
| Workers are running | Apply won't change images, and teardown won't run, while your workers exist. Collect results and `/remote-build:down` them. |
| No default VPC | `plan` names the subnets that would work: an internet route (in public mode) in a zone offering every type. Pass one with `--subnet`. If it names none, create a default VPC (`aws ec2 create-default-vpc`) or such a subnet. |
| A subnet has no route to an internet gateway, or its zone lacks a type | Checked before any change, on every run, for `--subnet` and the remembered subnet. Pick another subnet, or use `--address private --cidr <your network>` if you reach the VPC privately. Network ACLs aren't checked. |
| `apply`'s output stopped in Claude Code after about two minutes | A `!` command moves to the background after about two minutes; `apply` keeps running and Claude is told when it ends. Not a failure. |
| A toolchain is missing from the image's list, or one you meant to keep is gone | A new `--rust-toolchain` list replaces the remembered one. Re-run with `--rebake` and every extra toolchain you need; `plan` shows them as `bake_toolchains`. |

## Sessions

| Symptom | Meaning and next action |
|---|---|
| Missing/broken executable | Install or repair the operator-managed dependency, then rerun setup. The plugin installs nothing. |
| Invalid/unavailable local data | Check the private JSON against the exact config fields and replace example placeholders. Ensure private SSH files exist and global options precede the subcommand. Error output deliberately omits private values. |
| AWS tool/authentication failure | Repair the existing profile/session using the operator's normal login flow. Do not create keys or change IAM/network policy as an implicit workaround. |
| Unsupported template or retained EBS | Have the infrastructure owner provide a compatible pinned template. User data, instance profiles, Spot/requirements/hibernation and termination protection are unsupported; EBS deletion must be explicit. |
| Missing or invalid `.remote-build.json` | Run from the repository (or pass `--project`) and commit the selection at its Git root: exactly `version` 1, a `launch_profile` the private config defines and an `instance_type` on that profile's list. Do not add types to a profile to satisfy a repository without operator approval. |
| This repository already has a worker | Recover this checkout's original state/client session. The discovery check is not permission to adopt or terminate an unidentified worker. |
| Owner is at max_workers | Other repositories hold the allowed workers. Collect their results and `down` one, or have the operator raise `max_workers` within budget. Do not use a different owner to get around the cap. |
| Launch timed out / creation unresolved | Intent was saved before the call. Re-run `up` without the approval flag to describe by the same token. Eventual consistency may need another read later. It never creates a second instance. |
| Creation remains unresolved | Independently inspect the saved token in the original AWS account/region. Only after the operator proves the outcome may they archive stale intent manually. Never blindly delete session.json and relaunch. |
| Worker pending or missing IP | Wait and read status; check the operator's existing instance/network provisioning. The plugin neither creates routing nor assigns missing networking after launch. |
| SSH verification fails | Verify the instance's host identity through an authenticated channel and update the existing known-hosts file. Never disable checking or trust a key scan alone. |
| Snapshot rejects a symlink, hard link or special file | These are unsupported. Use ordinary files inside the selected Git root; do not dereference an outside secret into source. Held directory descriptors prevent symlink-swap reads. |
| Snapshot too large | Review exclusions/ignore rules and reduce eligible source. The limit includes tar overhead. Do not upload local target directories or raise limits beyond the supported ceiling. |
| Potential secret in source | Inspect the source privately. Remove/exclude the sensitive content and create a new reviewed snapshot; do not evade the screening by renaming a secret. A `::` path such as `Token::Comment(...)` does not match; a type annotation such as `token: Option<Token>` still can, so restructure that line rather than weakening the screen. |
| Source changes after snapshot | The old archive remains immutable. Snapshot again to test new edits; a result applies only to the recorded fingerprint. |
| SSH disconnects during submission | Use session status to recover the recorded job ID, then status for that job. Another submission is blocked while its outcome is unresolved. If SSH failed before delivery (for example an unenrolled host key), fix the connection first; `status --job` then reports `unknown`, which fences that ID on the worker and releases the submission, and the next `run` is accepted on the same worker. |
| Unknown (not the pending submission) or mismatched job/source | Stop and inspect private worker/state evidence. Do not silently retry. If recovery is impossible, explicitly collect available evidence and tear down the session. |
| Job is queued | Another job holds the session workspace/cache lock. Jobs serialize, and a queued job can expire before it starts. |
| Command exits nonzero | Retrieval can still succeed. Inspect exit_code and the private log, edit locally, and submit a new reviewed snapshot on the same worker. |
| A test or build script passes locally and fails on the worker over git | Snapshots never include `.git`, so the worker builds a source tree. Make scripts that ask git handle a missing repository (as builds from a release tarball must), and tests that assume a checkout check for one. |
| Rust toolchain unavailable | Preinstall the requested toolchain on the worker image and expose cargo/rustc through the actual noninteractive SSH PATH. The plugin preserves worker RUSTUP_HOME but disables auto-install; local toolchains are not uploaded. |
| `repository` fails: the image lacks a pinned toolchain, or `up` says `Not launching` | The repository's `rust-toolchain(.toml)` pins a channel the image's `remote-build:toolchains` tag doesn't list. The operator runs the rebuild command `setup` prints (`bootstrap.py apply ... --rebake --rust-toolchain <channel>`); it keeps the image's other extra toolchains. Nothing launched. |
| `repository` says a pinned toolchain was `not checked` | The image has no `remote-build:toolchains` tag (made before bootstrap tagged images, or by hand). A `--rebake` tags it; for a hand-built image, add the tag as in the operator guide's step 6. |
| Cache not reused | A first build or changed toolchain identity is cold. Source/dependency/feature changes also trigger Cargo's own rebuilding. cache_reused reports the session cache identity, not that every crate was Fresh. |
| Disk exhausted / log truncated | Storage is bounded by the operator's pre-sized volumes; logs cap at 1 MiB. The plugin has no disk-expansion or log-streaming command. Inspect the failure and explicitly release/reprovision within fresh authorization if necessary. |
| Worker interrupted or no exit code | Worker death/reboot may prevent a reliable final result. PID checks cannot prove identity after reboot/reuse. Do not report success without an exit code. |
| Session expired / job limit reached | No new work is accepted. Retrieve results and explicitly terminate; a new session needs authorization. The external janitor is the independent cost backstop. |
| Configuration/account changed | Restore the original private configuration, this repository's `.remote-build.json` and its launch profile, and the authenticated profile, before recovery/teardown. The session binds them to avoid touching another resource. Other repositories' profiles can change freely. |
| Termination requested but not observed | Repeat down/status; retain intent. If the provider later no longer returns the instance, operator verification is required before archiving state. |

## Trust and cost boundaries

Use this with trusted project build code on a trusted disposable image. It is not an isolation
boundary for hostile scripts. The worker has no forwarded credentials/agent or instance
metadata access, but build commands still have its network and disk access. Review source,
keep images credential-free, and treat remote logs as untrusted data. Full details are in
[security](security.md) and [contract v2](contract-v2.md).

The CLI checks configured type/TTL/job/upload limits and the operator's janitor declaration.
It does not verify janitor deployment, estimate exact prices, enforce a dollar cap, or provide
an atomic multi-machine lease. Use a single client/state root and account-side controls.
EC2, EBS, networking and public IPs may incur charges until the relevant resources are released.

## What has actually been tested

The offline suite exercises fake AWS and SSH executables, local detached worker processes,
authentication/launch uncertainty, ownership checks, source exclusions and symlink races,
job/source matching, reconnect, exit status, timeouts and bounded logs. A dependency-free real
Rust fixture uses an already installed toolchain with offline Cargo commands; it proves warm
reuse, changed-source rebuilding and toolchain identity invalidation. Concurrency and a failed
job followed by success on the same running instance are covered. Bootstrap's suite runs apply
from an empty simulated account to a config `setup` reports ready, plus re-runs, rebakes, type
changes, failed and kept builds, the janitor failing, refusals before any change, and teardown;
the simulated cloud evaluates the deployed operator policy for dry runs and runs the janitor
between polls. CI runs both suites on macOS/Linux and Python 3.9/3.14.

No real AWS launch, real SSH handshake, live IAM/network behavior, CloudFormation deployment,
janitor termination, billing verification or EBS deletion has been tested by this implementation
task. Bootstrap's own janitor test and dry runs are the first live evidence an operator gets. Before live use,
an operator must separately authorize and perform a bounded smoke test of those surfaces.
The configuration declaration and mocked tests are not evidence that live infrastructure works.
