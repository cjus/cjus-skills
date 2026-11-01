# Operator guide

This guide sets up everything remote-build needs before its first build. There are two ways
to do it:

- **[Quick start](#quick-start-bootstrap):** run `bootstrap.py apply` once with an AWS profile
  that can create EC2, IAM, Lambda and CloudFormation resources. It builds every piece below,
  tests them, and writes the private config. Most operators want this.
- **[Manual setup](#manual-setup):** the same pieces, one command at a time. Use it to see
  exactly what bootstrap does, to build in an account where you can't run CloudFormation, or
  as the starting point for your own variant.

Either way, `setup` checks the result. Run it after any step to see what is left; each failing
check links to the section that fixes it. The plugin's own commands (`up`, `run`, `status`,
`down`) never create infrastructure. Only you do, by running bootstrap or the manual steps.

> Neither bootstrap nor these commands have been run against live AWS by the plugin's tests.
> Bootstrap's tests drive it against a simulated cloud. Each step ends with a **Check**; stop
> at the first one that does not match and fix it before continuing.

## Overview

You will build, once:

| Piece | Why |
|---|---|
| An admin AWS CLI profile and a daily `remote-build` profile | Build the infrastructure with broad rights; run builds with narrow ones |
| An SSH key | The client logs in to workers as an unprivileged `builder` user |
| A security group | Lets SSH in from your address only |
| A build machine, then a worker image (AMI) | Workers boot with the toolchain, the `builder` user and a known host key |
| A known-hosts file | Strict host verification without trusting a first connection |
| A launch template per image | Pins the image, network and storage a worker launches with |
| An IAM policy | The daily profile can launch only approved templates and types, tagged as yours, and terminate only its own workers |
| An expiry janitor | Terminates expired workers even when your laptop is offline |
| The private config and a per-repository selection | Tell the plugin what to use |

Charges: build-machine hours while an image is made, the image's snapshot storage (ongoing,
per GB-month), public IPv4 addresses while machines run, and small Lambda, EventBridge,
CloudWatch and CloudFormation usage. Review current AWS prices; the plugin has no price
estimator or spending cap.

Two choices are deliberate and stay even with bootstrap:

- **The narrow daily profile.** Your admin credentials can do anything, which is exactly why
  remote-build's commands should not use them. The daily profile can only launch your approved
  templates and types, tagged as yours, and terminate its own workers. It limits what the
  plugin's commands can do, including when one misbehaves. It is not a sandbox against an agent
  that can read your other AWS profiles.
- **The baked host key.** Every worker presents the host key read from the image's build
  machine through the AWS API, so the client verifies workers strictly from the first
  connection, without waiting minutes per launch for console output.

## Quick start: bootstrap

You decide five things; bootstrap does the rest.

| Choice | Flag | Example |
|---|---|---|
| Admin AWS profile (creates the pieces) | `--admin-profile` | `default` |
| Region (default: the admin profile's) | `--region` | `us-east-1` |
| Owner: a stable name for your workers | `--owner` | `yourname-builds` |
| One launch profile per architecture: approved instance types (the first also builds the image) | `--image`, repeatable | `arm64:c7g.xlarge,c7g.2xlarge`, `x86=amd64:c7i.xlarge` |
| Where janitor alarms go (optional, recommended) | `--alert-email` | `you@example.com` |

`--image` takes `[name=]arch:type[,type...]`. Without a name, `arm64` profiles are called `arm`
and `amd64` ones `x86`; repositories choose a profile by that name.

Find the installed plugin (`setup` prints it as `guide.installed`; the plugin is two folders
up), look first, then apply. In Claude Code, prefix each command with `!` so its output lands
in the conversation and Claude can help read it.

```sh
PLUGIN=~/.claude/plugins/cache/cjus-skills/remote-build/<version>
python3 "$PLUGIN/scripts/bootstrap.py" plan --admin-profile default --owner yourname-builds \
  --image arm64:c7g.xlarge,c7g.2xlarge
python3 "$PLUGIN/scripts/bootstrap.py" apply --admin-profile default --owner yourname-builds \
  --image arm64:c7g.xlarge,c7g.2xlarge --alert-email you@example.com
```

`plan` only reads: it checks the admin profile, that each type runs its architecture, picks a
default-VPC subnet whose zone offers every type, and says what apply would build. `apply` takes
20-40 minutes, mostly compiling the toolchain into the image, and prints progress as it goes:

1. Creates `~/.ssh/remote-build-identity` if it does not exist.
2. Deploys the CloudFormation stack `remote-build-<owner>`: the security group (SSH from this
   machine's public address only), the janitor Lambda with its five-minute schedule, a 30-day
   log group, and alarms for a janitor that fails or stops running.
3. Builds one image per launch profile: a build machine from Ubuntu 24.04, its host key read
   through `get-console-output`, [`scripts/aws/provision.sh`](../scripts/aws/provision.sh) run over
   SSH, checks that `builder` has Python and no sudo and that `ubuntu` can no longer log in,
   then the image, tagged `remote-build:toolchains` with the toolchains `builder` has (`setup` and
   `up` read the tag; see [step 11](#step-11-repository-selection)). The build machine and its
   temporary key pair are deleted, also on failure.
4. Updates the stack with a launch template per profile and the operator role, whose policy is
   the one in [step 8](#step-8-iam-permissions).
5. Writes the daily profile to `~/.aws/config`: it assumes the operator role, using your admin
   profile as its source, so there is no access key to create or rotate.
6. Writes `~/.ssh/remote-build-known-hosts` and the private config (step 10's fields).
7. Proves the policy with dry runs (an approved launch is allowed; an unapproved type and
   another owner's tag are denied; nothing starts).
8. Runs the janitor test from [step 9](#step-9-expiry-janitor), which also proves a real worker
   works: it launches a worker with the daily profile exactly as the client does (metadata
   service off), logs in as `builder` against the new known-hosts file, and waits for the
   janitor to terminate it once its five-minute expiry passes. Only a termination the janitor
   made counts. Only then is `janitor_confirmed` set to `true`. This costs up to twenty minutes
   of your first listed type.

If you gave `--alert-email`, confirm the subscription email AWS sends, or the alarms reach no one.
The summary's `alerts` reads `pending` until you do; a later apply shows `confirmed`.

apply ends with a JSON summary of what it did and the state it left. (`plan` says what apply would
do instead: `image` is `bake` or `reuse`, `remove_profiles` lists what would go, and a new stack
`will be created`.)

| Field | Says |
|---|---|
| `stack` | The stack's CloudFormation status after the last deploy, for example `CREATE_COMPLETE` or `UPDATE_COMPLETE` |
| `launch_profiles.<name>.image` | `built <ami>` when this run made the image, `reused <ami>` when it kept one |
| `launch_profiles.<name>.launch_version` | The launch template version the private config now pins |
| `launch_profiles.<name>.toolchains` | What `builder` has on that image, as its `remote-build:toolchains` tag records, or `unknown` for an image made before images were tagged |
| `bake_toolchains` | What a bake installs: `stable` plus the remembered `--rust-toolchain` list |
| `removed_profiles`, `retired_images` | Profiles dropped and images deleted by this run (replaced or dropped) |
| `alerts` | `confirmed`, `pending` (confirm the email), `none` (no `--alert-email`) or `unknown` (the subscription could not be read) |
| `janitor_test` | `passed`, `already passed`, `skipped`, `failed` or `login failed` |
| `setup` | Each `setup` check's status |

**Check:** `janitor_test` is `passed` and `setup` shows every check `ok` except `repository`.
Then commit each repository's selection
([step 11](#step-11-repository-selection)) and run the first smoke test ([step 12](#step-12-first-smoke-test)).

### Running apply again

Apply is safe to repeat. It remembers your choices (in `~/.local/state/remote-build/bootstrap/`),
reuses images that are still available, removes anything an interrupted run left behind, and
only changes what you asked for. Re-runs need only `--admin-profile` and `--owner`.

| You want to | Run apply with | Image rebuilt? |
|---|---|---|
| Follow a new public address (SSH stops working) | nothing extra | No |
| Approve other types for a profile | `--image` lists with the new types | No |
| Add an architecture | the existing `--image` values plus the new one | Only the new one |
| Drop a profile | `--image` without it (its image is deleted) | No |
| Update the toolchain or OS packages | `--rebake` | Yes |
| Preinstall a pinned Rust toolchain | `--rebake --rust-toolchain 1.85.0` (name every extra toolchain to keep: the list replaces the last one) | Yes |
| Use your own provisioning script | `--rebake --provision-script ./my-provision.sh` | Yes |
| Retry a janitor test that failed | `--retest-janitor` | No |
| Debug a failed image build | `--keep-on-failure`, then SSH in as `ubuntu`; the next apply removes it | Yes |

A rebuilt image becomes a new version of the same launch template, so repositories keep working;
the replaced image and its snapshot are deleted. Apply refuses to change images while any of
your workers runs: collect results and `/remote-build:down` first. Your edits to `max_workers`,
`ttl_minutes`, `max_jobs` and `max_snapshot_bytes` in the private config are kept.

Apply refuses, before changing anything, when a private config for another owner exists
(`--replace-config` backs it up and replaces it) or when the daily profile name is already used
by a profile bootstrap did not write (`--replace-profile`, or pick `--daily-profile`).

### Removing everything

```sh
python3 "$PLUGIN/scripts/bootstrap.py" teardown --admin-profile default --owner yourname-builds \
  --confirm yourname-builds
```

It refuses while any of your workers runs. Then it deletes the stack (security group, role,
templates, janitor, alarms), every image and snapshot it made, the daily profile section in
`~/.aws/config`, the private config, the known-hosts file and its own state. It keeps your SSH
key and per-project build state; delete those yourself if you no longer need them.

To read the exact stack without touching AWS, print it: `bootstrap.py template --owner
yourname-builds --image arm64:c7g.xlarge` (placeholder IDs).

## Make it yours

remote-build is a starting point, not a fixed product. Its defaults suit one operator building
Rust on public-address Ubuntu workers. Your projects, network and rules for Claude probably
differ, and you should change the plugin to fit them. There are two levels.

**1. Change your setup (no code).** Most needs are a flag or a config field:

| Need | Where |
|---|---|
| Other toolchains or tools on the image | `--provision-script` with your copy of `scripts/aws/provision.sh`, or `--rust-toolchain`; then `--rebake` |
| Bigger disks | `--disk-gb` (workers can't grow their disk); then `--rebake` |
| Private networking (VPN, peered VPC) | `--subnet`, `--address private`, `--cidr <your network>` |
| Other instance types or architectures | `--image` |
| Limits: lifetime, concurrency, jobs, snapshot size | `ttl_minutes`, `max_workers`, `max_jobs`, `max_snapshot_bytes` in the [private config](config.md) |
| Which types a repository may use | the repository's `.remote-build.json`, within the profile's types |

**2. Make a custom version.** When you want the plugin itself to behave differently, change your
own copy. Some examples: let Claude run `bootstrap.py apply` itself, use another base image or
OS, run the janitor more often, keep caches between sessions, screen secrets differently, ask
for approval another way, or add a provider.

- **Don't edit the installed copy.** Everything under `~/.claude/plugins/cache/` is replaced
  when the plugin updates.
- **Fork the marketplace** (`cjus/cjus-skills`) or copy `plugins/remote-build` into your own
  marketplace repository. Give the plugin a new `name` in `.claude-plugin/plugin.json` and in the
  marketplace entry so it can be installed next to the original, and set `homepage` to your
  repository so `setup`'s guide links point at your copy.
- **Install yours:** `claude plugin marketplace add <you>/<repo>`, then
  `claude plugin install <name>@<marketplace>`. A fork changes only when you merge upstream
  changes, so it also pins the version you tested.
- **Run the offline tests** after each change: `python3 tests/test_remote_build.py` and
  `python3 tests/test_bootstrap.py`.

Where each behaviour lives:

| To change | Edit |
|---|---|
| What the worker image contains | `scripts/aws/provision.sh` |
| Which workers the janitor terminates | `scripts/aws/janitor.py` |
| The AWS resources bootstrap creates | `render()` in `scripts/bootstrap.py` |
| What the daily profile may do | `operator_policy()` in `scripts/bootstrap.py` |
| What Claude may and may not do at each step | `skills/<step>/SKILL.md` |
| Client rules: template checks, limits, snapshot exclusions and secret screen | `scripts/remote_build.py` |

The client relies on a few things being true, and refuses or misbehaves when they are not. Keep
them, or change the client's checks and tests with them on purpose: every volume deletes on
termination; templates carry no user data, instance profile, Spot options, instance
requirements, hibernation or termination protection; images boot without cloud-init (the client
disables the metadata service at launch), give `builder` Python 3.9+ and no sudo, and present a host key you
read through an authenticated channel; and something independent terminates expired workers
tagged with your owner.

## Manual setup

The steps below build the same pieces by hand. Set these shell variables first and keep the
terminal open; later steps use them. Replace the angle-bracket values.

```sh
ADMIN=<admin-profile>        # an existing AWS CLI profile that can create EC2, IAM and Lambda resources
REGION=<region>              # for example us-east-1
OWNER=<owner>                # a stable name for your workers, for example yourname-builds
PLUGIN=<installed-plugin>    # the folder holding scripts/ and reference/; setup prints guide.installed
ACCOUNT_ID=$(aws sts get-caller-identity --profile "$ADMIN" --query Account --output text)
```

Expect an hour or two.

## Step 0: Local tools

The client needs Python 3.9+, Git, OpenSSH and AWS CLI v2 on the machine you work from.
Install any that are missing with your usual package manager.

**Check:** each of these prints a version, and `aws --version` starts with `aws-cli/2`.

```sh
python3 --version; git --version; ssh -V; aws --version
```

## Step 1: AWS CLI profile

You need two profiles:

- **Admin** (`$ADMIN`): used only in this guide, to create the pieces below.
- **Daily** (`remote-build`): what the plugin uses. It gets only the policy from step 8, so
  create it then. If your organisation uses IAM Identity Center, it will be a permission set
  with that policy (`aws configure sso --profile remote-build`); otherwise an IAM user with that
  policy and an access key (`aws configure --profile remote-build`).

**Check:** the admin profile authenticates in your region.

```sh
aws sts get-caller-identity --profile "$ADMIN" --region "$REGION"
```

If it fails, log in with your usual flow (for example `aws sso login --profile "$ADMIN"`).

## Step 2: SSH identity

Create a key used for nothing else. The client runs SSH non-interactively, so either leave the
key without a passphrase (as here) or give it one and keep it loaded in `ssh-agent`.

```sh
ssh-keygen -t ed25519 -N '' -C remote-build -f ~/.ssh/remote-build-identity
chmod 600 ~/.ssh/remote-build-identity
```

Register the public half with EC2 for the build machine only; step 6 removes it again.

```sh
aws ec2 import-key-pair --key-name remote-build-image-build \
  --public-key-material fileb://$HOME/.ssh/remote-build-identity.pub \
  --profile "$ADMIN" --region "$REGION"
```

**Check:** `ls -l ~/.ssh/remote-build-identity` shows `-rw-------`.

## Step 3: Network

This uses the default VPC and public addresses, allowing SSH only from your current address.
(If you reach a VPC privately, for example over a VPN, use that subnet instead, skip the
public address, and set `address_field` to `PrivateIpAddress` in step 10.)

```sh
VPC=$(aws ec2 describe-vpcs --filters Name=is-default,Values=true \
  --query 'Vpcs[0].VpcId' --output text --profile "$ADMIN" --region "$REGION")
SUBNET=$(aws ec2 describe-subnets --filters Name=vpc-id,Values="$VPC" Name=default-for-az,Values=true \
  --query 'Subnets[0].SubnetId' --output text --profile "$ADMIN" --region "$REGION")
MYIP=$(curl -s https://checkip.amazonaws.com)
SG=$(aws ec2 create-security-group --group-name remote-build-ssh \
  --description 'remote-build: SSH from the operator only' --vpc-id "$VPC" \
  --query GroupId --output text --profile "$ADMIN" --region "$REGION")
aws ec2 authorize-security-group-ingress --group-id "$SG" --protocol tcp --port 22 \
  --cidr "$MYIP/32" --profile "$ADMIN" --region "$REGION"
echo "VPC=$VPC SUBNET=$SUBNET SG=$SG"
```

Outbound traffic stays open, which builds need for public crate downloads. When your address
changes, authorize the new `/32` and revoke the old one.

**Check:** the group allows only port 22 from your address.

```sh
aws ec2 describe-security-groups --group-ids "$SG" --query 'SecurityGroups[0].IpPermissions' \
  --profile "$ADMIN" --region "$REGION"
```

## Step 4: Start an image build machine

Pick the architecture of the image (one launch profile per architecture; repeat steps 4–7 for
a second one). The build machine's disk size becomes every worker's disk size, because workers
cannot grow their root filesystem: choose enough for a full build, `target` directory included.

```sh
ARCH=amd64                        # or arm64
BUILD_TYPE=<small-instance-type>  # any small type of that architecture, for example c7i.large or c7g.large
DISK_GB=40
BASE_AMI=$(aws ssm get-parameter \
  --name /aws/service/canonical/ubuntu/server/24.04/stable/current/$ARCH/hvm/ebs-gp3/ami-id \
  --query Parameter.Value --output text --profile "$ADMIN" --region "$REGION")
BUILD=$(aws ec2 run-instances --image-id "$BASE_AMI" --instance-type "$BUILD_TYPE" \
  --key-name remote-build-image-build --subnet-id "$SUBNET" --security-group-ids "$SG" \
  --associate-public-ip-address \
  --block-device-mappings "DeviceName=/dev/sda1,Ebs={VolumeSize=$DISK_GB,VolumeType=gp3,DeleteOnTermination=true}" \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=remote-build-image-build}]' \
  --query 'Instances[0].InstanceId' --output text --profile "$ADMIN" --region "$REGION")
aws ec2 wait instance-running --instance-ids "$BUILD" --profile "$ADMIN" --region "$REGION"
BUILD_IP=$(aws ec2 describe-instances --instance-ids "$BUILD" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text --profile "$ADMIN" --region "$REGION")
echo "BUILD=$BUILD BUILD_IP=$BUILD_IP"
```

The build machine is billed until step 6 terminates it. It carries no `remote-build:owner` tag,
so the janitor will not touch it.

**Check:** `echo $BUILD_IP` prints an IPv4 address.

## Step 5: Host keys

Read the machine's SSH host key through the AWS API, which is an authenticated channel,
instead of trusting whatever answers the first connection. Ubuntu prints its host keys to the
console at first boot; they can take a few minutes to appear, so repeat until the block shows.

```sh
aws ec2 get-console-output --instance-id "$BUILD" --latest --output text \
  --profile "$ADMIN" --region "$REGION" > /tmp/remote-build-console.txt
HOSTKEY=$(sed -n '/BEGIN SSH HOST KEY KEYS/,/END SSH HOST KEY KEYS/p' /tmp/remote-build-console.txt \
  | awk '$1 == "ssh-ed25519" {print $1" "$2}')
echo "$HOSTKEY"
```

`$HOSTKEY` must be one line starting `ssh-ed25519 AAAA`. Write it to a known-hosts file used
only by remote-build:

```sh
printf '* %s\n' "$HOSTKEY" > ~/.ssh/remote-build-known-hosts
chmod 600 ~/.ssh/remote-build-known-hosts
```

Step 6 keeps this host key in the image, so every worker presents it, and the `*` pattern covers
whatever address a worker gets. The trade-off: anyone who can read the image's snapshot can
extract the host key, so keep the image private (the default). SSH host certificates
(`@cert-authority *` entries) avoid sharing a key but need a signing setup of their own.

**Check:** this logs in without any host-key prompt and prints `ok`.

```sh
ssh -F /dev/null -o StrictHostKeyChecking=yes -o UserKnownHostsFile=$HOME/.ssh/remote-build-known-hosts \
  -o IdentitiesOnly=yes -i ~/.ssh/remote-build-identity ubuntu@"$BUILD_IP" echo ok
```

## Step 6: Build the worker image

The plugin ships the provisioning script as
[`scripts/aws/provision.sh`](../scripts/aws/provision.sh); bootstrap runs the same file. It creates
the unprivileged `builder` user, installs Rust with rustfmt, clippy, cargo-deny and mdbook on the
non-interactive SSH `PATH`, and prepares the image for how the client launches workers. Copy and
change it for another toolchain (see [Make it yours](#make-it-yours)); keep its last two sections.
Set `RUST_TOOLCHAINS` to preinstall the toolchains your projects pin in `rust-toolchain.toml`:
workers never download toolchains. Then tag the image with what `builder` has (below), so `setup`
and `up` can refuse a repository whose pinned toolchain the image lacks.

Run it on the build machine, then check the result as `builder`:

```sh
rbssh() { ssh -F /dev/null -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$HOME/.ssh/remote-build-known-hosts" \
  -o IdentitiesOnly=yes -i "$HOME/.ssh/remote-build-identity" "$@"; }
rbssh ubuntu@"$BUILD_IP" "cat > /tmp/remote-build-provision.sh && PUBKEY='$(cat ~/.ssh/remote-build-identity.pub)' \
  RUST_TOOLCHAINS='' bash /tmp/remote-build-provision.sh </dev/null" < "$PLUGIN/scripts/aws/provision.sh"
rbssh builder@"$BUILD_IP" 'cargo --version && rustc --version && cargo deny --version && mdbook --version && python3 --version'
rbssh builder@"$BUILD_IP" 'sudo -n true' && echo 'builder has sudo: fix this' || echo 'builder has no sudo: good'
```

Compiling cargo-deny and mdbook takes several minutes on a small machine.

**Check:** the five versions print, and the last line says `builder has no sudo: good`.

Then record `builder`'s toolchains (host triples dropped, for example `1.85.0 stable`), stop the
machine, turn it into an image tagged with them, and clean up:

```sh
TOOLCHAINS=$(rbssh builder@"$BUILD_IP" 'rustup toolchain list' | awk '{print $1}' \
  | sed -E 's/-(x86_64|aarch64)-unknown-linux-gnu$//' | sort | tr '\n' ' ' | sed 's/ $//')
aws ec2 stop-instances --instance-ids "$BUILD" --profile "$ADMIN" --region "$REGION"
aws ec2 wait instance-stopped --instance-ids "$BUILD" --profile "$ADMIN" --region "$REGION"
AMI=$(aws ec2 create-image --instance-id "$BUILD" --name "remote-build-$ARCH-$(date +%Y%m%d)" \
  --query ImageId --output text --profile "$ADMIN" --region "$REGION")
aws ec2 wait image-available --image-ids "$AMI" --profile "$ADMIN" --region "$REGION"   # repeat if it times out
aws ec2 create-tags --resources "$AMI" --profile "$ADMIN" --region "$REGION" \
  --tags "[{\"Key\": \"remote-build:toolchains\", \"Value\": \"$TOOLCHAINS\"}]"
aws ec2 terminate-instances --instance-ids "$BUILD" --profile "$ADMIN" --region "$REGION"
aws ec2 delete-key-pair --key-name remote-build-image-build --profile "$ADMIN" --region "$REGION"
echo "AMI=$AMI"
```

**Check:** every volume in the image deletes on termination.

```sh
aws ec2 describe-images --image-ids "$AMI" --query 'Images[0].BlockDeviceMappings' \
  --profile "$ADMIN" --region "$REGION"
```

## Step 7: Launch template

The template pins the image, subnet, security group and storage policy. Leave out the instance
type (the plugin passes the repository's choice), any key pair (the key is in the image), user
data, instance profiles, Spot options, instance requirements, hibernation and termination
protection: `setup` refuses templates with any of those.

```sh
LT=$(aws ec2 create-launch-template --launch-template-name "remote-build-$ARCH" \
  --version-description "$AMI" --launch-template-data "{
    \"ImageId\": \"$AMI\",
    \"NetworkInterfaces\": [{\"DeviceIndex\": 0, \"SubnetId\": \"$SUBNET\", \"Groups\": [\"$SG\"],
                             \"AssociatePublicIpAddress\": true, \"DeleteOnTermination\": true}],
    \"BlockDeviceMappings\": [{\"DeviceName\": \"/dev/sda1\", \"Ebs\": {\"DeleteOnTermination\": true}}]
  }" --query 'LaunchTemplate.LaunchTemplateId' --output text --profile "$ADMIN" --region "$REGION")
echo "LT=$LT (version 1)"
```

Its first version is `1`; that is the profile's `launch_version`. To roll out a new image
later, create a new version with `create-launch-template-version --source-version 1
--launch-template-data '{"ImageId": "<new-ami>"}'` and update `launch_version` between sessions.

**Check:** version 1 shows the image, the network interface and the deletion setting, and
nothing from the excluded list.

```sh
aws ec2 describe-launch-template-versions --launch-template-id "$LT" --versions 1 \
  --query 'LaunchTemplateVersions[0].LaunchTemplateData' --profile "$ADMIN" --region "$REGION"
```

## Step 8: IAM permissions

Save this as `remote-build-operator.json`, replacing the placeholders: `<REGION>`,
`<ACCOUNT_ID>`, `<OWNER>`, each launch template ID from step 7, and every instance type you will
approve in any profile.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Read",
      "Effect": "Allow",
      "Action": ["ec2:DescribeInstances", "ec2:DescribeLaunchTemplateVersions", "ec2:DescribeImages"],
      "Resource": "*"
    },
    {
      "Sid": "LaunchOnlyFromApprovedTemplates",
      "Effect": "Allow",
      "Action": "ec2:RunInstances",
      "Resource": "*",
      "Condition": {
        "ArnEquals": {
          "ec2:LaunchTemplate": [
            "arn:aws:ec2:<REGION>:<ACCOUNT_ID>:launch-template/<x86-launch-template-id>",
            "arn:aws:ec2:<REGION>:<ACCOUNT_ID>:launch-template/<arm64-launch-template-id>"
          ]
        }
      }
    },
    {
      "Sid": "NoOverridingTemplateResources",
      "Effect": "Deny",
      "Action": "ec2:RunInstances",
      "Resource": ["arn:aws:ec2:*:*:image/*", "arn:aws:ec2:*:*:security-group/*",
                   "arn:aws:ec2:*:*:subnet/*", "arn:aws:ec2:*:*:network-interface/*"],
      "Condition": {"Bool": {"ec2:IsLaunchTemplateResource": "false"}}
    },
    {
      "Sid": "NoKeyPairs",
      "Effect": "Deny",
      "Action": "ec2:RunInstances",
      "Resource": "arn:aws:ec2:*:*:key-pair/*"
    },
    {
      "Sid": "OnlyApprovedInstanceTypes",
      "Effect": "Deny",
      "Action": "ec2:RunInstances",
      "Resource": "arn:aws:ec2:*:*:instance/*",
      "Condition": {"StringNotEquals": {"ec2:InstanceType": ["<approved-type>", "<another-approved-type>"]}}
    },
    {
      "Sid": "RequireOwnerTagAtLaunch",
      "Effect": "Deny",
      "Action": "ec2:RunInstances",
      "Resource": "arn:aws:ec2:*:*:instance/*",
      "Condition": {"StringNotEquals": {"aws:RequestTag/remote-build:owner": "<OWNER>"}}
    },
    {
      "Sid": "TagOnlyAtLaunch",
      "Effect": "Allow",
      "Action": "ec2:CreateTags",
      "Resource": "arn:aws:ec2:<REGION>:<ACCOUNT_ID>:instance/*",
      "Condition": {"StringEquals": {"ec2:CreateAction": "RunInstances"}}
    },
    {
      "Sid": "TerminateOnlyOwnedWorkers",
      "Effect": "Allow",
      "Action": "ec2:TerminateInstances",
      "Resource": "arn:aws:ec2:<REGION>:<ACCOUNT_ID>:instance/*",
      "Condition": {"StringEquals": {"aws:ResourceTag/remote-build:owner": "<OWNER>"}}
    }
  ]
}
```

The template condition alone would still let a caller override the template's image, network or
key pair at launch; the two deny statements close that. No IAM condition can block `--user-data`,
which the client never sends.

Create it, then give it to the daily `remote-build` profile (step 1): attach it to the IAM user,
or add it to the Identity Center permission set.

```sh
aws iam create-policy --policy-name remote-build-operator \
  --policy-document file://remote-build-operator.json --profile "$ADMIN"
```

**Check:** a dry run as the daily profile is allowed, and launching nothing. Allow a minute for
IAM changes to apply.

```sh
aws ec2 run-instances --dry-run --launch-template LaunchTemplateId="$LT",Version=1 \
  --instance-type <approved-type> --count 1 --metadata-options HttpEndpoint=disabled \
  --instance-initiated-shutdown-behavior terminate \
  --tag-specifications "ResourceType=instance,Tags=[{Key=remote-build:owner,Value=$OWNER},{Key=remote-build:project,Value=dry-run},{Key=remote-build:session,Value=dry-run},{Key=remote-build:expires,Value=0}]" \
  --profile remote-build --region "$REGION"
```

The expected answer is an error: `DryRunOperation ... Request would have succeeded, but DryRun
flag is set.` Repeat it with an instance type you did not approve, and with a different owner
tag value: both must answer `UnauthorizedOperation`. To see why a request was refused, decode
the message with `aws sts decode-authorization-message --encoded-message <message> --profile "$ADMIN"`.

## Step 9: Expiry janitor

The janitor terminates workers whose `remote-build:expires` time has passed, every five
minutes, whether or not your laptop is on. This example is a small Lambda function. It treats a
worker with a missing or unreadable expiry tag as expired.

The handler is [`scripts/aws/janitor.py`](../scripts/aws/janitor.py), the same code bootstrap
deploys. Copy it next to the files below:

```sh
cp "$PLUGIN/scripts/aws/janitor.py" janitor.py
```

Save as `janitor-trust.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [{"Effect": "Allow", "Principal": {"Service": "lambda.amazonaws.com"}, "Action": "sts:AssumeRole"}]
}
```

Save as `janitor-policy.json`, replacing `<REGION>`, `<ACCOUNT_ID>` and `<OWNER>`. It can
terminate only instances tagged with your owner:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {"Effect": "Allow", "Action": "ec2:DescribeInstances", "Resource": "*"},
    {
      "Effect": "Allow",
      "Action": "ec2:TerminateInstances",
      "Resource": "arn:aws:ec2:<REGION>:<ACCOUNT_ID>:instance/*",
      "Condition": {"StringEquals": {"aws:ResourceTag/remote-build:owner": "<OWNER>"}}
    }
  ]
}
```

Create the role, the function and the five-minute schedule:

```sh
aws iam create-role --role-name remote-build-janitor \
  --assume-role-policy-document file://janitor-trust.json --profile "$ADMIN"
aws iam attach-role-policy --role-name remote-build-janitor \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole --profile "$ADMIN"
aws iam put-role-policy --role-name remote-build-janitor --policy-name terminate-expired-workers \
  --policy-document file://janitor-policy.json --profile "$ADMIN"
zip janitor.zip janitor.py
sleep 15   # let the new role propagate before Lambda uses it
aws lambda create-function --function-name remote-build-janitor --runtime python3.12 \
  --handler janitor.handler --zip-file fileb://janitor.zip --timeout 60 \
  --role "arn:aws:iam::$ACCOUNT_ID:role/remote-build-janitor" \
  --environment "Variables={OWNER=$OWNER}" --profile "$ADMIN" --region "$REGION"
aws events put-rule --name remote-build-janitor --schedule-expression 'rate(5 minutes)' \
  --profile "$ADMIN" --region "$REGION"
aws lambda add-permission --function-name remote-build-janitor --statement-id remote-build-schedule \
  --action lambda:InvokeFunction --principal events.amazonaws.com \
  --source-arn "arn:aws:events:$REGION:$ACCOUNT_ID:rule/remote-build-janitor" --profile "$ADMIN" --region "$REGION"
aws events put-targets --rule remote-build-janitor \
  --targets "Id=janitor,Arn=arn:aws:lambda:$REGION:$ACCOUNT_ID:function:remote-build-janitor" \
  --profile "$ADMIN" --region "$REGION"
```

Add alerts for a janitor that fails or stops running. Confirm the subscription email AWS sends.

```sh
TOPIC=$(aws sns create-topic --name remote-build-alerts --query TopicArn --output text \
  --profile "$ADMIN" --region "$REGION")
aws sns subscribe --topic-arn "$TOPIC" --protocol email --notification-endpoint <your-email> \
  --profile "$ADMIN" --region "$REGION"
aws cloudwatch put-metric-alarm --alarm-name remote-build-janitor-errors --namespace AWS/Lambda \
  --metric-name Errors --dimensions Name=FunctionName,Value=remote-build-janitor --statistic Sum \
  --period 300 --evaluation-periods 1 --threshold 1 --comparison-operator GreaterThanOrEqualToThreshold \
  --treat-missing-data notBreaching --alarm-actions "$TOPIC" --profile "$ADMIN" --region "$REGION"
aws cloudwatch put-metric-alarm --alarm-name remote-build-janitor-silent --namespace AWS/Lambda \
  --metric-name Invocations --dimensions Name=FunctionName,Value=remote-build-janitor --statistic Sum \
  --period 900 --evaluation-periods 1 --threshold 1 --comparison-operator LessThanThreshold \
  --treat-missing-data breaching --alarm-actions "$TOPIC" --profile "$ADMIN" --region "$REGION"
```

**Check:** launch an already-expired worker with the daily profile, using your cheapest approved
type, and watch the janitor terminate it within about ten minutes. This also proves the daily
profile can launch for real. It costs a few minutes of that instance.

```sh
TEST=$(aws ec2 run-instances --launch-template LaunchTemplateId="$LT",Version=1 \
  --instance-type <cheapest-approved-type> --count 1 --metadata-options HttpEndpoint=disabled \
  --instance-initiated-shutdown-behavior terminate \
  --tag-specifications "ResourceType=instance,Tags=[{Key=remote-build:owner,Value=$OWNER},{Key=remote-build:project,Value=janitor-test},{Key=remote-build:session,Value=janitor-test},{Key=remote-build:expires,Value=0}]" \
  --query 'Instances[0].InstanceId' --output text --profile remote-build --region "$REGION")
aws ec2 describe-instances --instance-ids "$TEST" --query 'Reservations[0].Instances[0].State.Name' \
  --output text --profile remote-build --region "$REGION"   # repeat: running, then shutting-down, then terminated
```

If it is still running after fifteen minutes, read the function's logs in CloudWatch
(`/aws/lambda/remote-build-janitor`), fix the cause, and terminate the test instance yourself.
Only once it terminates on its own, set `janitor_confirmed` to `true` in step 10. That setting is
your statement that this works; the plugin cannot verify it.

## Step 10: Private config

Write the config from the values above. Run this in the same terminal, after replacing the
instance-type placeholders with the types you approved in step 8. Add a second launch profile
if you built a second image.

```sh
PROFILE_NAME=x86   # the launch profile name repositories will use for this image, for example x86 or arm
mkdir -p ~/.config/remote-build && chmod 700 ~/.config/remote-build
cat > ~/.config/remote-build/config.json <<EOF
{
  "version": 2,
  "provider": "aws",
  "profile": "remote-build",
  "region": "$REGION",
  "owner": "$OWNER",
  "launch_profiles": {
    "$PROFILE_NAME": {
      "launch_template": "$LT",
      "launch_version": "1",
      "instance_types": ["<approved-type>", "<another-approved-type>"]
    }
  },
  "max_workers": 2,
  "ttl_minutes": 120,
  "janitor_confirmed": true,
  "ssh_user": "builder",
  "known_hosts": "$HOME/.ssh/remote-build-known-hosts",
  "identity_file": "$HOME/.ssh/remote-build-identity",
  "address_field": "PublicIpAddress",
  "max_snapshot_bytes": 33554432,
  "max_jobs": 20,
  "cache_retention": "session"
}
EOF
chmod 600 ~/.config/remote-build/config.json
```

Every field is described in [configuration](config.md). Claude can also write this file for you
from the values you give it; it stays outside every repository.

**Check:** run `/remote-build:setup` (or `python3 <plugin>/scripts/remote_build.py setup`) from a
repository. Every check except `repository` is `ok`.

## Step 11: Repository selection

In each repository that will use remote-build, commit a selection naming one launch profile and
one of its approved types:

```sh
printf '%s\n' '{ "version": 1, "launch_profile": "x86", "instance_type": "<approved-type>" }' > .remote-build.json
git add .remote-build.json
```

If the repository pins a toolchain (`rust-toolchain` or `rust-toolchain.toml` at its Git root),
`setup` compares it with the image's `remote-build:toolchains` tag, and `up` refuses to launch
when the image lacks it: workers never download a toolchain, so every `cargo` call would fail.
The `repository` check then names the rebuild, for example
`bootstrap.py apply --admin-profile <admin-profile> --owner <owner> --rebake --rust-toolchain 1.97.0`,
keeping the image's other extra toolchains. A `stable` pin matches any image. An image without the
tag (made before bootstrap tagged images, or by hand without the tag) is not checked; `setup`
says so, and a `--rebake` or the tag from step 6 enables the check. Only the Git root's file is
read, and only its channel: components and targets beyond the image's are not checked.

**Check:** `setup` from that repository reports `"ready": true`.

## Step 12: First smoke test

This launches a real worker, so give the cost approval it asks for. In Claude Code:

1. `/remote-build:up`: approve the launch; repeat `/remote-build:status` until the state is
   `running`.
2. `/remote-build:run` with `cargo --version`: approve the snapshot upload, then
   `/remote-build:status` with the job ID until `exit_code` is `0`. This proves SSH, the host
   key, the `builder` login and the toolchain.
3. Optionally run the repository's real build or test command the same way.
4. `/remote-build:down`: repeat until it reports `terminated`.

**Check:** the worker and its volume are gone.

```sh
aws ec2 describe-instances --filters Name=tag:remote-build:owner,Values="$OWNER" \
  --query 'Reservations[].Instances[].[InstanceId,State.Name]' --output text --profile remote-build --region "$REGION"
aws ec2 describe-volumes --filters Name=status,Values=available \
  --query 'Volumes[].[VolumeId,Size,CreateTime]' --output text --profile "$ADMIN" --region "$REGION"
```

Every instance listed is `terminated`, and no unattached volume appears that you did not expect
(workers' volumes are not tagged, so this lists every unattached volume in the region).

If a step fails, see [troubleshooting](troubleshooting.md).

## Removing everything

To take remote-build out of the account, collect results and `down` every worker first, then:

```sh
aws events remove-targets --rule remote-build-janitor --ids janitor --profile "$ADMIN" --region "$REGION"
aws events delete-rule --name remote-build-janitor --profile "$ADMIN" --region "$REGION"
aws lambda delete-function --function-name remote-build-janitor --profile "$ADMIN" --region "$REGION"
aws cloudwatch delete-alarms --alarm-names remote-build-janitor-errors remote-build-janitor-silent \
  --profile "$ADMIN" --region "$REGION"
aws sns delete-topic --topic-arn "$TOPIC" --profile "$ADMIN" --region "$REGION"
aws iam delete-role-policy --role-name remote-build-janitor --policy-name terminate-expired-workers --profile "$ADMIN"
aws iam detach-role-policy --role-name remote-build-janitor \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole --profile "$ADMIN"
aws iam delete-role --role-name remote-build-janitor --profile "$ADMIN"
aws ec2 delete-launch-template --launch-template-id "$LT" --profile "$ADMIN" --region "$REGION"
SNAP=$(aws ec2 describe-images --image-ids "$AMI" --query 'Images[0].BlockDeviceMappings[0].Ebs.SnapshotId' \
  --output text --profile "$ADMIN" --region "$REGION")
aws ec2 deregister-image --image-id "$AMI" --profile "$ADMIN" --region "$REGION"
aws ec2 delete-snapshot --snapshot-id "$SNAP" --profile "$ADMIN" --region "$REGION"
aws ec2 delete-security-group --group-id "$SG" --profile "$ADMIN" --region "$REGION"
```

Detach and delete the `remote-build-operator` policy and the daily profile's user or permission
set, then remove `~/.config/remote-build`, `~/.local/state/remote-build` and the
`~/.ssh/remote-build-*` files.
