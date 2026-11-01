# Troubleshooting and recovery

Treat an unknown outcome as unknown. Do not clear state, switch owner names, weaken SSH
verification or launch replacements merely to make a command succeed.

| Symptom | Meaning and next action |
|---|---|
| Missing/broken executable | Install or repair the operator-managed dependency, then rerun setup. The plugin installs nothing. |
| Invalid/unavailable local data | Check the private JSON against the exact config fields and replace example placeholders. Ensure private SSH files exist and global options precede the subcommand. Error output deliberately omits private values. |
| AWS tool/authentication failure | Repair the existing profile/session using the operator's normal login flow. Do not create keys or change IAM/network policy as an implicit workaround. |
| Unsupported template or retained EBS | Have the infrastructure owner provide a compatible pinned template. User data, instance profiles, Spot/requirements/hibernation and termination protection are unsupported; EBS deletion must be explicit. |
| Owner already has a worker | Recover the original state/client session. The owner discovery check is not permission to adopt or terminate an unidentified worker. |
| Launch timed out / creation unresolved | Intent was saved before the call. Re-run `up` without the approval flag to describe by the same token. Eventual consistency may need another read later. It never creates a second instance. |
| Creation remains unresolved | Independently inspect the saved token in the original AWS account/region. Only after the operator proves the outcome may they archive stale intent manually. Never blindly delete session.json and relaunch. |
| Worker pending or missing IP | Wait and read status; check the operator's existing instance/network provisioning. The plugin neither creates routing nor assigns missing networking after launch. |
| SSH verification fails | Verify the instance's host identity through an authenticated channel and update the existing known-hosts file. Never disable checking or trust a key scan alone. |
| Snapshot rejects a symlink, hard link or special file | These are unsupported. Use ordinary files inside the selected Git root; do not dereference an outside secret into source. Held directory descriptors prevent symlink-swap reads. |
| Snapshot too large | Review exclusions/ignore rules and reduce eligible source. The limit includes tar overhead. Do not upload local target directories or raise limits beyond the supported ceiling. |
| Potential secret in source | Inspect the source privately. Remove/exclude the sensitive content and create a new reviewed snapshot; do not evade the screening by renaming a secret. |
| Source changes after snapshot | The old archive remains immutable. Snapshot again to test new edits; a result applies only to the recorded fingerprint. |
| SSH disconnects during submission | Use session status to recover the recorded job ID, then status for that job. Another submission is blocked while its outcome is unresolved. |
| Unknown or mismatched job/source | Stop and inspect private worker/state evidence. Do not silently retry. If recovery is impossible, explicitly collect available evidence and tear down the session. |
| Job is queued | Another job holds the session workspace/cache lock. Jobs serialize, and a queued job can expire before it starts. |
| Command exits nonzero | Retrieval can still succeed. Inspect exit_code and the private log, edit locally, and submit a new reviewed snapshot on the same worker. |
| Rust toolchain unavailable | Preinstall the requested toolchain on the worker image and expose cargo/rustc through the actual noninteractive SSH PATH. The plugin preserves worker RUSTUP_HOME but disables auto-install; local toolchains are not uploaded. |
| Cache not reused | A first build or changed toolchain identity is cold. Source/dependency/feature changes also trigger Cargo's own rebuilding. cache_reused reports the session cache identity, not that every crate was Fresh. |
| Disk exhausted / log truncated | Storage is bounded by the operator's pre-sized volumes; logs cap at 1 MiB. The plugin has no disk-expansion or log-streaming command. Inspect the failure and explicitly release/reprovision within fresh authorization if necessary. |
| Worker interrupted or no exit code | Worker death/reboot may prevent a reliable final result. PID checks cannot prove identity after reboot/reuse. Do not report success without an exit code. |
| Session expired / job limit reached | No new work is accepted. Retrieve results and explicitly terminate; a new session needs authorization. The external janitor is the independent cost backstop. |
| Configuration/account changed | Restore the original private configuration and authenticated profile before recovery/teardown. The session binds their identity to avoid touching another resource. |
| Termination requested but not observed | Repeat down/status; retain intent. If the provider later no longer returns the instance, operator verification is required before archiving state. |

## Trust and cost boundaries

Use this with trusted project build code on a trusted disposable image. It is not an isolation
boundary for hostile scripts. The worker has no forwarded credentials/agent or instance
metadata access, but build commands still have its network and disk access. Review source,
keep images credential-free, and treat remote logs as untrusted data. Full details are in
[security](security.md) and [contract v1](contract-v1.md).

The CLI checks configured type/TTL/job/upload limits and the operator's janitor declaration.
It does not verify janitor deployment, estimate exact prices, enforce a dollar cap, or provide
an atomic multi-machine lease. Use a single client/state directory and account-side controls.
EC2, EBS, networking and public IPs may incur charges until the relevant resources are released.

## What has actually been tested

The offline suite exercises fake AWS and SSH executables, local detached worker processes,
authentication/launch uncertainty, ownership checks, source exclusions and symlink races,
job/source matching, reconnect, exit status, timeouts and bounded logs. A dependency-free real
Rust fixture uses an already installed toolchain with offline Cargo commands; it proves warm
reuse, changed-source rebuilding and toolchain identity invalidation. Concurrency and a failed
job followed by success on the same running instance are covered. CI runs those tests on
macOS/Linux and Python 3.9/3.14.

No real AWS launch, real SSH handshake, live IAM/network behavior, janitor termination, billing
verification or EBS deletion has been tested by this implementation task. Before live use,
an operator must separately authorize and perform a bounded smoke test of those surfaces.
The configuration declaration and mocked tests are not evidence that live infrastructure works.
