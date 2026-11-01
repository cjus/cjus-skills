# Operator guide

This guide walks an operator through everything remote-build needs before its first build.
The plugin itself never creates, changes or deletes cloud resources: you run these commands,
and `setup` checks the result. Run `setup` after any step to see what is left; each of its
failing checks links to the step below that fixes it.

> These commands were written for this guide and have not been run against live AWS by the
> plugin's tests. Each step ends with a **Check**. Stop at the first check that does not match
> and fix it before continuing.

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

Expect an hour or two. Charges while you work: the build machine's hours, the image's
snapshot storage (ongoing, per GB-month), public IPv4 addresses while machines run, and small
Lambda, EventBridge and CloudWatch usage. Review current AWS prices; the plugin has no price
estimator or spending cap.

Set these shell variables first and keep the terminal open; later steps use them. Replace the
angle-bracket values.

```sh
ADMIN=<admin-profile>        # an existing AWS CLI profile that can create EC2, IAM and Lambda resources
REGION=<region>              # for example us-east-1
OWNER=<owner>                # a stable name for your workers, for example yourname-builds
ACCOUNT_ID=$(aws sts get-caller-identity --profile "$ADMIN" --query Account --output text)
```

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

Save this script as `provision.sh`. It creates the unprivileged `builder` user, installs Rust
with rustfmt, clippy, cargo-deny and mdbook on the non-interactive SSH `PATH`, and prepares the
image for how the client launches workers.

```sh
#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
sudo apt-get -y upgrade
sudo apt-get -y install build-essential pkg-config curl python3 git

# Unprivileged build user, reachable only with the remote-build key; no sudo.
sudo useradd --create-home --shell /bin/bash builder
sudo install -d -m 700 -o builder -g builder /home/builder/.ssh
printf '%s\n' "$PUBKEY" | sudo tee /home/builder/.ssh/authorized_keys >/dev/null
sudo chown builder:builder /home/builder/.ssh/authorized_keys
sudo chmod 600 /home/builder/.ssh/authorized_keys

# Rust for builder. Add `rustup toolchain install <version>` lines for any toolchain your
# projects pin in rust-toolchain.toml: workers never download toolchains.
sudo -iu builder bash -c 'curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable -c rustfmt -c clippy'
sudo -iu builder bash -c '~/.cargo/bin/cargo install --locked cargo-deny mdbook'
# Non-interactive SSH sessions do not read the rustup PATH line in ~/.bashrc; link the tools instead.
for tool in cargo rustc rustdoc rustup rustfmt cargo-fmt cargo-clippy clippy-driver cargo-deny mdbook; do
  sudo ln -sf /home/builder/.cargo/bin/$tool /usr/local/bin/$tool
done

# The client disables the instance metadata service at launch, and cloud-init needs it to set
# up networking and would regenerate host keys. Turn cloud-init off, keep this host key, and
# use DHCP on any ethernet interface rather than this machine's MAC address.
sudo tee /etc/netplan/60-remote-build.yaml >/dev/null <<'NETPLAN'
network:
  version: 2
  ethernets:
    primary:
      match:
        name: "en*"
      dhcp4: true
NETPLAN
sudo chmod 600 /etc/netplan/60-remote-build.yaml
sudo rm -f /etc/netplan/50-cloud-init.yaml
sudo touch /etc/cloud/cloud-init.disabled

# Only builder may log in to workers.
sudo rm -f /home/ubuntu/.ssh/authorized_keys
```

Run it on the build machine, then check the result as `builder`:

```sh
rbssh() { ssh -F /dev/null -o StrictHostKeyChecking=yes -o UserKnownHostsFile="$HOME/.ssh/remote-build-known-hosts" \
  -o IdentitiesOnly=yes -i "$HOME/.ssh/remote-build-identity" "$@"; }
rbssh ubuntu@"$BUILD_IP" "PUBKEY='$(cat ~/.ssh/remote-build-identity.pub)' bash -s" < provision.sh
rbssh builder@"$BUILD_IP" 'cargo --version && rustc --version && cargo deny --version && mdbook --version && python3 --version'
rbssh builder@"$BUILD_IP" 'sudo -n true' && echo 'builder has sudo: fix this' || echo 'builder has no sudo: good'
```

Compiling cargo-deny and mdbook takes several minutes on a small machine.

**Check:** the five versions print, and the last line says `builder has no sudo: good`.

Then stop the machine, turn it into an image, and clean up:

```sh
aws ec2 stop-instances --instance-ids "$BUILD" --profile "$ADMIN" --region "$REGION"
aws ec2 wait instance-stopped --instance-ids "$BUILD" --profile "$ADMIN" --region "$REGION"
AMI=$(aws ec2 create-image --instance-id "$BUILD" --name "remote-build-$ARCH-$(date +%Y%m%d)" \
  --query ImageId --output text --profile "$ADMIN" --region "$REGION")
aws ec2 wait image-available --image-ids "$AMI" --profile "$ADMIN" --region "$REGION"   # repeat if it times out
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

Save as `janitor.py`:

```python
import os
import time

import boto3

OWNER = os.environ['OWNER']
ec2 = boto3.client('ec2')


def handler(event, context):
    now = int(time.time())
    expired = []
    pages = ec2.get_paginator('describe_instances').paginate(Filters=[
        {'Name': 'tag:remote-build:owner', 'Values': [OWNER]},
        {'Name': 'instance-state-name', 'Values': ['pending', 'running', 'stopping', 'stopped']}])
    for page in pages:
        for reservation in page['Reservations']:
            for instance in reservation['Instances']:
                tags = {t['Key']: t['Value'] for t in instance.get('Tags', [])}
                try:
                    deadline = int(tags['remote-build:expires'])
                except (KeyError, ValueError):
                    deadline = 0
                if deadline <= now:
                    expired.append(instance['InstanceId'])
    if expired:
        # An exception here fails the run, which the error alarm below reports.
        ec2.terminate_instances(InstanceIds=expired)
    print({'terminated': expired})
    return {'terminated': expired}
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
