# remote-build

Build and test an exact source snapshot on an ephemeral Linux worker while an agent edits
locally. Five Claude Code skills guide a shared Python CLI; Codex and other agents can use
the same CLI directly. AWS EC2 On-Demand is the first provider.

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

Read [configuration](reference/config.md) and [AWS prerequisites](reference/aws.md) before
setup. An operator supplies a pinned launch template, network access, SSH identity, verified
host keys, and independent expiry cleanup. Setup probes existing auth; it does not grant
launch authorization. Credentials remain on the local client.

## Workflow

Resolve the installed plugin root once. In Claude Code it is `CLAUDE_PLUGIN_ROOT`; outside
Claude Code, point `REMOTE_BUILD_ROOT` at the trusted checkout or installed plugin directory.
The CLI never depends on the consumer project's working directory.

```sh
python3 "$REMOTE_BUILD_ROOT/scripts/remote_build.py" setup
# Only after the user approves this paid worker and its lifetime:
python3 "$REMOTE_BUILD_ROOT/scripts/remote_build.py" up --approve-cost
python3 "$REMOTE_BUILD_ROOT/scripts/remote_build.py" snapshot .
# Review the manifest and eligible source, then use its exact fingerprint:
python3 "$REMOTE_BUILD_ROOT/scripts/remote_build.py" run --snapshot <sha256> --approve-upload -- cargo test --locked
python3 "$REMOTE_BUILD_ROOT/scripts/remote_build.py" status
python3 "$REMOTE_BUILD_ROOT/scripts/remote_build.py" status --job <job-id>
python3 "$REMOTE_BUILD_ROOT/scripts/remote_build.py" down
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

For Rust, use a baked Linux image with `cargo` and `rustc` on PATH, and a pinned
`rust-toolchain.toml` plus `Cargo.lock`. The image must expose actual toolchain executables
independently of a user home; rustup shims that depend on a preexisting home will not work
with the isolated job home. Start with `cargo test --locked` or
`cargo build --locked`. A fresh job has its own Cargo home and target directory. Private
registries/dependencies requiring credentials are unsupported. Public dependency downloads
require preconfigured outbound access. This runs whole remote Cargo jobs, not sccache's
distributed compiler protocol. macOS frameworks, signing, packaging, final native builds,
and UI validation still run locally.

## Cost and retention

EC2, EBS, networking and public IPs can incur charges. There is no dollar-price estimator or
billing cap. The CLI enforces one outstanding session per state directory, checks for existing
workers under the configured owner, and caps requested TTL at eight hours and jobs at twenty.
Cross-machine races and other AWS tools require account-side IAM/quota controls.
An expiry tag is only a timestamp: the operator's independent janitor must terminate expired
workers, even when the laptop is offline. CLI setup validates the operator's declaration,
not the janitor's installation or effectiveness.

V1 uses **session-only retention**: all EBS volumes must delete on termination; no retained
EBS cache is supported yet. Each job has isolated source and build directories, retained
until teardown. Disk consumption is bounded by the operator's pre-sized volumes, not a
per-job filesystem quota. Logs are capped at 1 MiB and source archives at 32 MiB. Local
snapshots and results persist until the operator removes private state after review.

## Codex adapter

Read [contract v1](reference/contract-v1.md), then use the shared script through an explicit
plugin root. A local Codex skill may wrap the same setup/up/run/status/down commands and
approval boundaries. Resolve resources relative to that skill's known plugin location;
do not assume Codex provides `CLAUDE_PLUGIN_ROOT` or that a Claude marketplace installation
automatically registers Codex skills. No host instructions or settings are installed by this
plugin. The five skill files provide the workflow text for such an adapter.

## Verification and limits

```sh
python3 plugins/remote-build/tests/test_remote_build.py -v
```

Tests use a fake AWS boundary and run the worker locally in temporary directories; no AWS
credentials, paid instances, or real SSH connections are used. CI runs Python 3.9 and a
current version on macOS and Linux. See [security](reference/security.md) and
[contract v1](reference/contract-v1.md) for recovery and trust boundaries. A first live smoke
test requires separate user authorization and operator-provisioned infrastructure.
