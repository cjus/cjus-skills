# AWS provider

The operator provisions the infrastructure. The plugin's session commands (`up`, `run`,
`status`, `down`) never create IAM credentials, keys, security groups, network rules, launch
templates, images or a janitor. The operator builds them either with `scripts/bootstrap.py
apply`, run with an admin profile, which deploys them as one CloudFormation stack plus one image
per launch profile, or by hand; the [operator guide](operator-guide.md) covers both. This page
states the requirements they must meet, whichever way they were built.
Use an existing AWS CLI profile with scoped permissions for STS identity, EC2 description,
RunInstances, launch-time tagging and TerminateInstances. Restrict template, region, instance
types and owner tags through IAM as appropriate; local config is not an IAM boundary.

Rustup images are supported when their required toolchains are preinstalled; the worker keeps
the original RUSTUP_HOME and disables auto-install. Its session Cargo home does not inherit
credentials. See [rustup environment variables](https://rust-lang.github.io/rustup/environment-variables.html).

Each launch profile names a pinned Linux AMI through a numeric launch-template version, with an
unprivileged SSH user, Python and the build toolchain. Use one profile per AMI architecture or
image; a repository selects a profile and one of its types in `.remote-build.json`. The client rejects template user data, instance profiles,
Spot options, instance requirements, hibernation and termination protection. It disables
instance metadata at launch, requests one On-Demand worker of the configured type, and sets
OS-initiated shutdown to terminate. No credentials are uploaded or forwarded.

Every effective EBS mapping must explicitly set DeleteOnTermination=true. Retained EBS cache
is deferred until ownership, expiry and attachment lifecycle can be enforced. Use fixed-size
storage suitable for the workload; a build can exhaust that disk and fail. The image and
network must already support any public dependency downloads required by the build.

Before setting `janitor_confirmed`, independently test an account-side janitor that terminates
instances with the exact owner tag after the `remote-build:expires` epoch timestamp, including
when the client is offline. Its permission boundary must prevent deleting unrelated resources.
It must inspect pending/running/stopped workers, retry failures, and alert on missed deadlines.
The CLI supplies `remote-build:owner`, `remote-build:project`, `remote-build:session` and
`remote-build:expires` tags. A janitor keyed on the owner tag covers every project's workers.
It does not install, inspect or guarantee the janitor. Budget alerts are useful but are not a
termination mechanism or spending cap.

Use existing SSH connectivity to the configured private/public IP. Populate the known-hosts
file through an authenticated image/host-certificate provisioning channel. This client disables
SSH config inheritance and agent/port forwarding, and requires strict verification against
that file. An IP change needs independently verified new host identity. Never disable host
checking to make the first connection work.

Provider references:

- [RunInstances](https://docs.aws.amazon.com/cli/latest/reference/ec2/run-instances.html): client token, launch template, instance count and metadata options.
- [Describe launch template versions](https://docs.aws.amazon.com/cli/latest/reference/ec2/describe-launch-template-versions.html): pinned template inspection.
- [TerminateInstances](https://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_TerminateInstances.html): idempotent termination semantics.
- [EC2 termination](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/terminating-instances.html): instance termination and volume deletion behavior.

Live validation remains a separate operator-authorized smoke test: confirm pinned image
boot, trusted SSH handshake, successful and failing build results after disconnect, and
janitor termination with billing/storage verification. Offline tests do not establish these.
