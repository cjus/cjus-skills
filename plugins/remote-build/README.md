# remote-build

Build and test an exact source snapshot on an ephemeral Linux worker while an agent edits
locally. Five Claude Code skills guide a shared Python CLI. AWS EC2 On-Demand is the first
provider.

## Usage guides

- [Operator guide](reference/operator-guide.md): **start here.** One bootstrap command that builds and tests every AWS and SSH prerequisite, the same steps by hand, and how to adapt the plugin; `setup` links to its sections.
- [Complete PR session walkthrough](reference/walkthrough.md): prerequisites, first safe preflight, approved launch, repeated builds, reconnect/results and explicit teardown.
- [Configuration and complete example](reference/config.md): every field and private storage locations.
- [AWS prerequisites](reference/aws.md): what the infrastructure must provide, however it was built.
- [Troubleshooting and validation boundaries](reference/troubleshooting.md): exact failure/recovery behavior, costs and mocked versus live coverage.
- [Contract v2](reference/contract-v2.md) and [security](reference/security.md): source identity, session ownership and trust boundaries.

## Install and requirements

```sh
claude plugin marketplace add cjus/cjus-skills
claude plugin install remote-build@cjus-skills
```

Restart Claude Code. Commands are `/remote-build:setup`, `/remote-build:up`,
`/remote-build:run`, `/remote-build:status`, and `/remote-build:down`.
Installation copies files; it installs no dependencies or infrastructure.

The local client needs Python 3.9+, Git, OpenSSH, and AWS CLI v2 authenticated with an
existing profile. It uses Python's standard library only. macOS and Linux clients are
intended; offline tests cover them in CI. Windows needs a POSIX environment and is not
validated. Actual EC2/SSH integration has not yet been validated on live infrastructure.
The Linux image needs Python 3.9+, the build toolchain on PATH, and trusted SSH access.
Build tools must already be installed; this plugin does not install them.

Run `/remote-build:setup` first: it checks every prerequisite, says what is missing and links
each gap to the [operator guide](reference/operator-guide.md) section that fixes it. Setup probes
existing auth; it does not grant launch authorization. Credentials remain on the local client.

## Set up AWS in one command

An operator whose AWS profile can create EC2, IAM, Lambda and CloudFormation resources runs
bootstrap once (in Claude Code, prefix it with `!`):

```sh
python3 "<plugin>/scripts/bootstrap.py" plan  --admin-profile <admin> --owner <you>-builds --image arm64:c7g.xlarge,c7g.2xlarge
python3 "<plugin>/scripts/bootstrap.py" apply --admin-profile <admin> --owner <you>-builds --image arm64:c7g.xlarge,c7g.2xlarge --alert-email <you@example.com>
```

`apply` deploys one CloudFormation stack (security group, launch templates, a narrow operator
role the daily profile assumes, the expiry janitor and its alarms), bakes a worker image per
architecture with a verified host key, writes the daily profile, known-hosts file and private
config, proves the policy with dry runs, and tests the janitor before declaring it. It takes
20-40 minutes, is safe to re-run, and `teardown` removes everything it made. Claude runs only
the read-only `plan`; the operator runs `apply` and `teardown`. The
[quick start](reference/operator-guide.md#quick-start-bootstrap) has the details; the manual
steps remain for anyone who wants to build each piece by hand.

## Make it yours

This plugin is a starting point. Its defaults suit one operator building Rust on public-address
Ubuntu workers, and you will probably want to change some of it. Most needs are a bootstrap flag
or a config field: your own provisioning script for other toolchains, bigger disks, private
networking, other instance types, different limits. When you want the plugin itself to behave
differently (say, let Claude run bootstrap, use another OS, keep caches, or change what each
skill allows), make a custom version: fork this marketplace or copy the plugin into your own,
give it a new name, and install that. Don't edit the installed copy, because updates replace it.
The operator guide's [Make it yours](reference/operator-guide.md#make-it-yours) says where each
behaviour lives and which guarantees the client relies on.

## Per-repository selection

Each repository commits `.remote-build.json` at its Git root, choosing one of the operator's
launch profiles and one of that profile's instance types:

```json
{ "version": 1, "launch_profile": "x86", "instance_type": "<approved-x86-type>" }
```

Each checkout has its own session, state and worker, tagged with a per-project key, so
repositories with different instance types or architectures can run workers concurrently up
to the owner's `max_workers`. The file selects; it never authorizes a launch. See
[configuration](reference/config.md#repository-selection).

## Workflow

Run commands from the repository (or pass `--project DIR`). Claude Code supplies `CLAUDE_PLUGIN_ROOT` for the installed plugin. All five skills resolve
the shared CLI through that path, independently of the consumer project's working directory.

```sh
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/remote_build.py" setup
# Only after the user approves this paid worker and its lifetime:
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/remote_build.py" up --approve-cost
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/remote_build.py" snapshot
# Review the manifest and eligible source, then use its exact fingerprint:
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/remote_build.py" run --snapshot <sha256> --approve-upload -- cargo test --locked
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/remote_build.py" status
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/remote_build.py" status --job <job-id>
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/remote_build.py" down
```

`up` returns while the worker may still be pending. Use `status`; provision trusted host keys
through an existing authenticated channel before submitting a job. Do not accept an
unverified `ssh-keyscan` result. Each `run` submits a new job and returns quickly. The worker
keeps running through a local disconnect. Poll the same job ID to retrieve its bounded log
and exit status into private local state. A failed command is reported as `exit_code`, not
as a successful test. Collect results before `down`, then repeat `down` until it observes
termination. Do not call `run` again to reconnect.

Commands are argv arrays: shell operators such as `&&` are literal arguments. Run separate
jobs, or deliberately invoke a trusted script already in the snapshot. Logs and result
metadata are retrieved; arbitrary binary artifact download is outside v1.

For Rust, use a baked Linux image with `cargo`, `rustc` and optionally rustup on PATH.
Preinstall the toolchains named by `rust-toolchain.toml` or a worker-side `RUSTUP_TOOLCHAIN`;
automatic rustup installation is disabled. The worker preserves its installed `RUSTUP_HOME`
while using a fresh session Cargo home that contains no operator registry credentials.
Start with `cargo test --locked` or `cargo build --locked`. Private registries/dependencies
requiring credentials are unsupported; public dependency downloads need preconfigured outbound
access. This runs whole remote Cargo jobs, not sccache's distributed compiler protocol.
macOS frameworks, signing, packaging, final native builds and UI validation still run locally.

**The local PR agent owns the session across builds.** Call `up` once, then repeat snapshot,
run and status while editing. Neither a successful nor a failed job terminates the instance.
Only an explicit `down` action releases it; closing or merging a PR does not call `down`.
The agent should collect results and explicitly release its worker when finished. Independent
maximum-lifetime cleanup is a safety backstop for abandoned sessions, not per-build teardown.

Within a project's session, jobs retain separate immutable source archives/results, but execute
one at a time under a session lock against a stable working directory. Unchanged source files keep their mtimes;
changed and deleted files are synchronized before execution. Cargo home and target directories
are reused only while that lock is held. A toolchain identity change resets both caches.
Result metadata reports `cache_key` and `cache_reused`; Cargo still decides which crates need
rebuilding. Build scripts must declare their inputs correctly; use an explicit `cargo clean`
job when an opaque external input changes. Caches never cross session termination.

## Cost and retention

EC2, EBS, networking and public IPs can incur charges. There is no dollar-price estimator or
billing cap. The CLI enforces one outstanding session per project, refuses a second worker for
the same project, caps the owner's concurrent workers at `max_workers` (at most ten), and caps
requested TTL at eight hours and jobs at twenty.
Cross-machine races and other AWS tools require account-side IAM/quota controls.
An expiry tag is only a timestamp: the operator's independent janitor must terminate expired
workers, even when the laptop is offline. CLI setup validates the operator's declaration,
not the janitor's installation or effectiveness.

V1 uses **session-only retention**: all EBS volumes must delete on termination; no retained
EBS cache is supported yet. Each job retains its immutable source/result directory, and the serialized build workspace
and Cargo caches remain until teardown. Disk consumption is bounded by the operator's pre-sized volumes, not a
per-job filesystem quota. Logs are capped at 1 MiB and source archives at 32 MiB. Local
snapshots and results persist until the operator removes private state after review.

## Verification and limits

```sh
python3 plugins/remote-build/tests/test_remote_build.py -v
python3 plugins/remote-build/tests/test_bootstrap.py -v
```

Bootstrap's tests drive apply, re-runs, rebakes, failure cleanup and teardown against a simulated
cloud that evaluates the deployed operator policy and runs the janitor between polls.
The client's tests use fake AWS/SSH tools and run the worker locally in temporary directories. A dependency-free
Rust fixture uses an already installed toolchain to verify warm builds without downloads; CI
requires that toolchain and local runs explicitly skip the Rust test if none exists. No AWS
credentials, paid instances, or real SSH connections are used. CI runs Python 3.9 and a
current version on macOS and Linux. See [security](reference/security.md) and
[contract v2](reference/contract-v2.md) for recovery and trust boundaries. A first live smoke
test requires separate user authorization and operator-provisioned infrastructure.
