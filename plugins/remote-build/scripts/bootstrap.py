#!/usr/bin/env python3
"""remote-build bootstrap: build every AWS prerequisite in one operator-run command.

The operator runs this with an admin AWS profile. It does what the operator guide's manual
steps 1-10 do, in order:

1. Preflight: admin identity, instance types per architecture, network, operator address.
2. One CloudFormation stack for the fixed pieces: security group, janitor Lambda with its
   schedule, log group and alarms, and (once images exist) a launch template per profile and
   the narrow operator role the daily profile assumes.
3. A worker image per launch profile: build machine, host key read through the authenticated
   console-output channel, provision.sh, image, cleanup.
4. The daily profile (assumes the operator role), known-hosts file and private config.
5. IAM dry-run checks and the janitor expiry test, so janitor_confirmed rests on a test that ran.

Subcommands: plan (read-only), apply, teardown, template (offline; prints the stack).
Standard library only. Re-running apply is safe: it reuses images and updates the stack.
"""
import argparse
import ipaddress
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys
import time
import urllib.request
import uuid

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import remote_build as rb  # noqa: E402

Refused = rb.Refused
require = rb.require

ASSETS = HERE / 'aws'
OWNER = r'[a-z][a-z0-9-]{0,31}'
PROFILE = r'[a-z][a-z0-9]{0,15}'
TYPE = r'[a-z0-9]+[a-z0-9-]*\.[a-z0-9]+'
TOOLCHAIN = r'[A-Za-z0-9][A-Za-z0-9._-]{0,63}'
ARCHES = {'amd64': 'x86_64', 'arm64': 'arm64'}
DEFAULT_NAMES = {'amd64': 'x86', 'arm64': 'arm'}
# Smallest types per architecture, used only to prove the policy denies an unapproved type.
UNAPPROVED_CANDIDATES = {'amd64': ['t3.nano', 't3.micro', 't2.nano'], 'arm64': ['t4g.nano', 't4g.micro']}
BASE_IMAGE = '/aws/service/canonical/ubuntu/server/24.04/stable/current/{arch}/hvm/ebs-gp3/ami-id'
TUNABLES = {'max_workers': 2, 'ttl_minutes': 120, 'max_snapshot_bytes': 33554432, 'max_jobs': 20}
ACTIVE = 'pending,running,stopping,stopped,shutting-down'
LOG_RETENTION_DAYS = 30
HOST_KEY_MINUTES = 15
WORKER_LOGIN_MINUTES = 5
JANITOR_TEST_MINUTES = 15
IAM_PROPAGATION_MINUTES = 3
MANAGED = '# managed by remote-build bootstrap for owner '


# ---------------------------------------------------------------- process boundary

def execute(argv, data=None, timeout=120):
    """The only place bootstrap starts a process; offline tests replace it."""
    try:
        p = subprocess.run(argv, input=data, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=timeout)
    except FileNotFoundError:
        raise Refused('Missing tool: ' + argv[0])
    except subprocess.TimeoutExpired:
        raise Refused('Timed out after %d seconds: %s' % (timeout, ' '.join(argv[:3])))
    return p.returncode, p.stdout, p.stderr


def pause(seconds):
    time.sleep(seconds)


def now():
    return time.time()


def say(message):
    print(time.strftime('%H:%M:%S ') + message, file=sys.stderr, flush=True)


def tail(err, limit=600):
    """The end of a tool's stderr. The operator runs bootstrap in their own terminal, and AWS
    error text is what they need to fix a failed step; it carries no credentials."""
    text = err.decode(errors='replace').strip() if isinstance(err, bytes) else str(err).strip()
    return text[-limit:] or 'no error text'


def operator_cidr():
    try:
        with urllib.request.urlopen('https://checkip.amazonaws.com', timeout=10) as reply:
            address = reply.read().decode().strip()
        return str(ipaddress.ip_network(address + '/32'))
    except Exception:  # network, certificate store or an unexpected answer
        raise Refused('Could not detect this machine\'s public address; pass --cidr <address>/32')


class Account:
    """One AWS CLI profile in one region."""

    def __init__(self, profile, region):
        self.profile, self.region = profile, region

    def raw(self, service, op, *args, timeout=120):
        return execute(['aws', '--profile', self.profile, '--region', self.region, '--output', 'json',
                        '--no-cli-pager', service, op] + list(args), timeout=timeout)

    def __call__(self, service, op, *args, timeout=120):
        code, out, err = self.raw(service, op, *args, timeout=timeout)
        require(code == 0, 'aws %s %s failed: %s' % (service, op, tail(err)))
        text = out.decode().strip()
        try:
            return json.loads(text) if text else {}
        except ValueError:
            return {'text': text}


# ---------------------------------------------------------------- inputs and local files

def parse_image(spec):
    """[name=]arch:type[,type...] -> launch profile request."""
    m = re.fullmatch(r'(?:(%s)=)?(amd64|arm64):(%s(?:,%s)*)' % (PROFILE, TYPE, TYPE), spec)
    require(m, 'Image spec must look like arm64:c7g.xlarge,c7g.2xlarge or x86=amd64:c7i.xlarge (got %r)' % spec)
    return {'name': m.group(1) or DEFAULT_NAMES[m.group(2)], 'arch': m.group(2), 'types': m.group(3).split(',')}


def load_json(path, default=None):
    return json.loads(path.read_text()) if path.exists() else default


def write_private(path, text):
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    tmp = path.with_name(path.name + '.tmp')
    with open(tmp, 'w') as stream:
        os.chmod(tmp, 0o600)
        stream.write(text)
    os.replace(tmp, path)


def save_state(paths, state):
    write_private(paths['state'], json.dumps(state, indent=2, sort_keys=True) + '\n')


def section_bounds(lines, header):
    start = next((i for i, l in enumerate(lines) if l.strip() == header), None)
    if start is None:
        return None
    end = next((i for i in range(start + 1, len(lines)) if lines[i].lstrip().startswith('[')), len(lines))
    return start, end


def read_section(text, header):
    lines = text.splitlines()
    bounds = section_bounds(lines, header)
    return None if bounds is None else lines[bounds[0]:bounds[1]]


def remove_section(text, header):
    """Drop one [section] from an AWS config file, leaving every other line as it was."""
    lines = text.splitlines()
    bounds = section_bounds(lines, header)
    if bounds is None:
        return text
    kept = lines[:bounds[0]] + lines[bounds[1]:]
    while kept and not kept[-1].strip():
        kept.pop()
    return '\n'.join(kept) + ('\n' if kept else '')


def set_section(text, header, body):
    rest = remove_section(text, header).rstrip('\n')
    return (rest + '\n\n' if rest else '') + '\n'.join([header] + body) + '\n'


def profile_header(name):
    return '[profile %s]' % name


def write_aws_config(path, text):
    """Write through a symlinked ~/.aws/config (dotfile setups) instead of replacing the link."""
    write_private(Path(os.path.realpath(path)), text)


# ---------------------------------------------------------------- the stack

def logical(name):
    return 'LaunchTemplate' + name


def operator_policy(built):
    templates = [{'Fn::Sub': 'arn:${AWS::Partition}:ec2:${AWS::Region}:${AWS::AccountId}:launch-template/${%s}'
                  % logical(p['name'])} for p in built]
    types = sorted({t for p in built for t in p['types']})
    instance = {'Fn::Sub': 'arn:${AWS::Partition}:ec2:${AWS::Region}:${AWS::AccountId}:instance/*'}
    owner_tag = {'Ref': 'Owner'}
    return {'Version': '2012-10-17', 'Statement': [
        {'Sid': 'Read', 'Effect': 'Allow', 'Resource': '*',
         'Action': ['ec2:DescribeInstances', 'ec2:DescribeLaunchTemplateVersions', 'ec2:DescribeImages']},
        {'Sid': 'LaunchOnlyFromApprovedTemplates', 'Effect': 'Allow', 'Action': 'ec2:RunInstances', 'Resource': '*',
         'Condition': {'ArnEquals': {'ec2:LaunchTemplate': templates}}},
        # The template condition alone still lets a caller override the image, network or key
        # pair at launch; deny those unless they come from the template. (No IAM condition can
        # block --user-data; the client never sends it.)
        {'Sid': 'NoOverridingTemplateResources', 'Effect': 'Deny', 'Action': 'ec2:RunInstances',
         'Resource': ['arn:aws:ec2:*:*:image/*', 'arn:aws:ec2:*:*:security-group/*', 'arn:aws:ec2:*:*:subnet/*',
                      'arn:aws:ec2:*:*:network-interface/*'],
         'Condition': {'Bool': {'ec2:IsLaunchTemplateResource': 'false'}}},
        {'Sid': 'NoKeyPairs', 'Effect': 'Deny', 'Action': 'ec2:RunInstances', 'Resource': 'arn:aws:ec2:*:*:key-pair/*'},
        {'Sid': 'OnlyApprovedInstanceTypes', 'Effect': 'Deny', 'Action': 'ec2:RunInstances',
         'Resource': 'arn:aws:ec2:*:*:instance/*', 'Condition': {'StringNotEquals': {'ec2:InstanceType': types}}},
        {'Sid': 'RequireOwnerTagAtLaunch', 'Effect': 'Deny', 'Action': 'ec2:RunInstances',
         'Resource': 'arn:aws:ec2:*:*:instance/*',
         'Condition': {'StringNotEquals': {'aws:RequestTag/remote-build:owner': owner_tag}}},
        {'Sid': 'TagOnlyAtLaunch', 'Effect': 'Allow', 'Action': 'ec2:CreateTags', 'Resource': instance,
         'Condition': {'StringEquals': {'ec2:CreateAction': 'RunInstances'}}},
        {'Sid': 'TerminateOnlyOwnedWorkers', 'Effect': 'Allow', 'Action': 'ec2:TerminateInstances',
         'Resource': instance, 'Condition': {'StringEquals': {'aws:ResourceTag/remote-build:owner': owner_tag}}}]}


def render(owner, cidr, vpc, subnet, profiles, alert_email, public=True):
    """The CloudFormation template. Profiles without an image yet get no launch template, and
    the operator role appears once at least one template exists."""
    name = 'remote-build-' + owner
    janitor = name + '-janitor'
    code = (ASSETS / 'janitor.py').read_text()
    require(len(code) <= 4096, 'janitor.py exceeds the 4096-character inline Lambda limit')
    r = {
        'SecurityGroup': {'Type': 'AWS::EC2::SecurityGroup', 'Properties': {
            # No GroupName: a fixed name would stop CloudFormation replacing the group on a VPC change.
            'Tags': [{'Key': 'Name', 'Value': name + '-ssh'}],
            'GroupDescription': 'remote-build: SSH from the operator only',
            'VpcId': vpc, 'SecurityGroupIngress': [
                {'IpProtocol': 'tcp', 'FromPort': 22, 'ToPort': 22, 'CidrIp': cidr,
                 'Description': 'operator address'}]}},
        'JanitorRole': {'Type': 'AWS::IAM::Role', 'Properties': {
            'RoleName': janitor,
            'AssumeRolePolicyDocument': {'Version': '2012-10-17', 'Statement': [
                {'Effect': 'Allow', 'Principal': {'Service': 'lambda.amazonaws.com'}, 'Action': 'sts:AssumeRole'}]},
            'ManagedPolicyArns': [{'Fn::Sub': 'arn:${AWS::Partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole'}],
            'Policies': [{'PolicyName': 'terminate-expired-workers', 'PolicyDocument': {'Version': '2012-10-17', 'Statement': [
                {'Effect': 'Allow', 'Action': 'ec2:DescribeInstances', 'Resource': '*'},
                {'Effect': 'Allow', 'Action': 'ec2:TerminateInstances',
                 'Resource': {'Fn::Sub': 'arn:${AWS::Partition}:ec2:${AWS::Region}:${AWS::AccountId}:instance/*'},
                 'Condition': {'StringEquals': {'aws:ResourceTag/remote-build:owner': {'Ref': 'Owner'}}}}]}}]}},
        'JanitorLogs': {'Type': 'AWS::Logs::LogGroup', 'Properties': {
            'LogGroupName': '/aws/lambda/' + janitor, 'RetentionInDays': LOG_RETENTION_DAYS}},
        'Janitor': {'Type': 'AWS::Lambda::Function', 'DependsOn': 'JanitorLogs', 'Properties': {
            'FunctionName': janitor, 'Runtime': 'python3.12', 'Handler': 'index.handler', 'Timeout': 60,
            'Role': {'Fn::GetAtt': ['JanitorRole', 'Arn']}, 'Code': {'ZipFile': code},
            'Environment': {'Variables': {'OWNER': {'Ref': 'Owner'}}}}},
        'JanitorSchedule': {'Type': 'AWS::Events::Rule', 'Properties': {
            'Name': janitor, 'ScheduleExpression': 'rate(5 minutes)', 'State': 'ENABLED',
            'Targets': [{'Id': 'janitor', 'Arn': {'Fn::GetAtt': ['Janitor', 'Arn']}}]}},
        'JanitorPermission': {'Type': 'AWS::Lambda::Permission', 'Properties': {
            'FunctionName': {'Ref': 'Janitor'}, 'Action': 'lambda:InvokeFunction',
            'Principal': 'events.amazonaws.com', 'SourceArn': {'Fn::GetAtt': ['JanitorSchedule', 'Arn']}}},
        'Alerts': {'Type': 'AWS::SNS::Topic', 'Properties': {'TopicName': name + '-alerts'}},
        'JanitorErrors': {'Type': 'AWS::CloudWatch::Alarm', 'Properties': {
            'AlarmName': janitor + '-errors', 'AlarmDescription': 'The remote-build janitor failed a run',
            'Namespace': 'AWS/Lambda', 'MetricName': 'Errors', 'Statistic': 'Sum',
            'Dimensions': [{'Name': 'FunctionName', 'Value': {'Ref': 'Janitor'}}],
            'Period': 300, 'EvaluationPeriods': 1, 'Threshold': 1,
            'ComparisonOperator': 'GreaterThanOrEqualToThreshold', 'TreatMissingData': 'notBreaching',
            'AlarmActions': [{'Ref': 'Alerts'}]}},
        'JanitorSilent': {'Type': 'AWS::CloudWatch::Alarm', 'Properties': {
            'AlarmName': janitor + '-silent', 'AlarmDescription': 'The remote-build janitor stopped running',
            'Namespace': 'AWS/Lambda', 'MetricName': 'Invocations', 'Statistic': 'Sum',
            'Dimensions': [{'Name': 'FunctionName', 'Value': {'Ref': 'Janitor'}}],
            'Period': 900, 'EvaluationPeriods': 1, 'Threshold': 1,
            'ComparisonOperator': 'LessThanThreshold', 'TreatMissingData': 'breaching',
            'AlarmActions': [{'Ref': 'Alerts'}]}},
    }
    outputs = {'SecurityGroupId': {'Value': {'Ref': 'SecurityGroup'}},
               'AlertTopicArn': {'Value': {'Ref': 'Alerts'}}}
    if alert_email:
        r['AlertEmail'] = {'Type': 'AWS::SNS::Subscription', 'Properties': {
            'TopicArn': {'Ref': 'Alerts'}, 'Protocol': 'email', 'Endpoint': alert_email}}
    built = [p for p in profiles if p.get('ami')]
    for p in built:
        lid = logical(p['name'])
        r[lid] = {'Type': 'AWS::EC2::LaunchTemplate', 'Properties': {
            'LaunchTemplateName': name + '-' + p['name'],
            'VersionDescription': p['ami'],
            # Only what the client allows: no type, key pair, user data, instance profile, Spot,
            # instance requirements, hibernation or termination protection (setup refuses those).
            'LaunchTemplateData': {
                'ImageId': p['ami'],
                'NetworkInterfaces': [{'DeviceIndex': 0, 'SubnetId': subnet, 'Groups': [{'Ref': 'SecurityGroup'}],
                                       'AssociatePublicIpAddress': public, 'DeleteOnTermination': True}],
                'BlockDeviceMappings': [{'DeviceName': p['root_device'], 'Ebs': {'DeleteOnTermination': True}}]}}}
        outputs[lid + 'Id'] = {'Value': {'Ref': lid}}
        outputs[lid + 'Version'] = {'Value': {'Fn::GetAtt': [lid, 'LatestVersionNumber']}}
    if built:
        r['OperatorRole'] = {'Type': 'AWS::IAM::Role', 'Properties': {
            'RoleName': name + '-operator', 'MaxSessionDuration': 3600,
            'Description': 'remote-build daily profile: launch approved templates and types, terminate own workers',
            # Account root delegates to IAM: any principal in this account whose own policy allows
            # sts:AssumeRole on this role (the admin profile) can use it as a source profile.
            'AssumeRolePolicyDocument': {'Version': '2012-10-17', 'Statement': [
                {'Effect': 'Allow', 'Action': 'sts:AssumeRole',
                 'Principal': {'AWS': {'Fn::Sub': 'arn:${AWS::Partition}:iam::${AWS::AccountId}:root'}}}]},
            'Policies': [{'PolicyName': 'remote-build-operator', 'PolicyDocument': operator_policy(built)}]}}
        outputs['OperatorRoleArn'] = {'Value': {'Fn::GetAtt': ['OperatorRole', 'Arn']}}
    return {'AWSTemplateFormatVersion': '2010-09-09',
            'Description': 'remote-build prerequisites for owner ' + owner + ' (made by bootstrap.py)',
            'Parameters': {'Owner': {'Type': 'String', 'Default': owner, 'AllowedPattern': OWNER}},
            'Resources': r, 'Outputs': outputs}


def stack_status(admin, name):
    code, out, err = admin.raw('cloudformation', 'describe-stacks', '--stack-name', name)
    if code != 0:
        require(b'does not exist' in err, 'aws cloudformation describe-stacks failed: ' + tail(err))
        return None, {}
    stack = json.loads(out)['Stacks'][0]
    return stack['StackStatus'], {o['OutputKey']: o['OutputValue'] for o in stack.get('Outputs', [])}


def failure_reasons(admin, name):
    code, out, _ = admin.raw('cloudformation', 'describe-stack-events', '--stack-name', name)
    if code != 0:
        return ''
    events = [e for e in json.loads(out).get('StackEvents', []) if e.get('ResourceStatus', '').endswith('_FAILED')]
    return '; '.join('%s: %s' % (e['LogicalResourceId'], e.get('ResourceStatusReason', '')) for e in events[:5])


def delete_stack(admin, name):
    admin('cloudformation', 'delete-stack', '--stack-name', name)
    admin('cloudformation', 'wait', 'stack-delete-complete', '--stack-name', name, timeout=3600)


def deploy(admin, paths, name, template, owner):
    status, _ = stack_status(admin, name)
    if status == 'ROLLBACK_COMPLETE':
        say('Stack %s failed to create earlier; deleting it before trying again' % name)
        delete_stack(admin, name)
    else:
        # REVIEW_IN_PROGRESS is a stack whose first change set failed; deploy treats it as new.
        require(status in (None, 'REVIEW_IN_PROGRESS') or not status.endswith('_IN_PROGRESS'),
                'Stack %s is busy (%s); wait and re-run' % (name, status))
    path = paths['state'].with_name(owner + '.template.json')
    write_private(path, json.dumps(template, indent=2, sort_keys=True) + '\n')
    say('Deploying stack %s (a few minutes)' % name)
    code, _, err = admin.raw('cloudformation', 'deploy', '--template-file', str(path), '--stack-name', name,
                             '--capabilities', 'CAPABILITY_NAMED_IAM', '--no-fail-on-empty-changeset',
                             '--tags', 'remote-build:bootstrap=' + owner, timeout=3600)
    require(code == 0, 'Stack deploy failed: ' + (failure_reasons(admin, name) or tail(err)))
    return stack_status(admin, name)


def alert_state(admin, topic, email):
    """Whether janitor alarms reach anyone. AWS keeps an email subscription pending until its
    owner follows the link in the confirmation email, and sends nothing to it until then."""
    if not email:
        return 'none: pass --alert-email to be told when the janitor fails or stops'
    code, out, _ = admin.raw('sns', 'list-subscriptions-by-topic', '--topic-arn', topic)
    if code != 0:
        return 'unknown: could not read the subscription; check that %s confirmed the email AWS sent' % email
    mine = [s for s in json.loads(out).get('Subscriptions', [])
            if s.get('Protocol') == 'email' and s.get('Endpoint', '').lower() == email.lower()]
    # A pending subscription's ARN is the literal PendingConfirmation; a confirmed one is a real ARN.
    if any(s.get('SubscriptionArn', '').startswith('arn:') for s in mine):
        return 'confirmed: alarms reach ' + email
    return 'pending: confirm the subscription email AWS sent to ' + email


# ---------------------------------------------------------------- the worker image

def ssh_argv(paths, known_hosts, user, host, command):
    return ['ssh', '-F', '/dev/null', '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes',
            '-o', 'UserKnownHostsFile=' + str(known_hosts), '-o', 'GlobalKnownHostsFile=/dev/null',
            '-o', 'IdentitiesOnly=yes', '-o', 'ConnectTimeout=15', '-i', str(paths['identity']),
            user + '@' + host, command]


def host_key_from_console(text):
    block = re.search(r'-----BEGIN SSH HOST KEY KEYS-----(.*?)-----END SSH HOST KEY KEYS-----', text or '', re.S)
    if not block:
        return None
    for line in block.group(1).splitlines():
        m = re.match(r'\s*(ssh-ed25519 AAAA[A-Za-z0-9+/=]+)', line)
        if m:
            return m.group(1)
    return None


def console_host_key(admin, instance):
    """Read the host key through the AWS API, an authenticated channel, never a first connection."""
    deadline = now() + HOST_KEY_MINUTES * 60
    while True:
        code, out, _ = admin.raw('ec2', 'get-console-output', '--instance-id', instance, '--latest')
        if code != 0:  # --latest needs a Nitro instance; fall back to the boot-time capture
            code, out, _ = admin.raw('ec2', 'get-console-output', '--instance-id', instance)
        key = host_key_from_console(json.loads(out).get('Output')) if code == 0 and out.strip() else None
        if key:
            return key
        require(now() < deadline, 'No SSH host key in the console output after %d minutes' % HOST_KEY_MINUTES)
        pause(15)


def describe_instance(account, instance):
    reservations = account('ec2', 'describe-instances', '--instance-ids', instance)['Reservations']
    return reservations[0]['Instances'][0]


def clean_bake_leftovers(admin, owner, state):
    """Remove what an interrupted bake left behind: build machines, key pairs, and images that
    no launch profile records (a half-made image, or one a crashed re-bake replaced)."""
    leftovers = admin('ec2', 'describe-instances', '--filters', 'Name=tag:remote-build:bake,Values=' + owner,
                      'Name=instance-state-name,Values=pending,running,stopping,stopped')['Reservations']
    ids = [i['InstanceId'] for r in leftovers for i in r['Instances']]
    if ids:
        say('Terminating leftover build machine(s): ' + ', '.join(ids))
        admin('ec2', 'terminate-instances', '--instance-ids', *ids)
        # Their network interfaces hold the security group until they are gone.
        admin('ec2', 'wait', 'instance-terminated', '--instance-ids', *ids, timeout=900)
    pairs = admin('ec2', 'describe-key-pairs', '--filters',
                  'Name=key-name,Values=remote-build-%s-bake-*' % owner).get('KeyPairs', [])
    for pair in pairs:
        admin('ec2', 'delete-key-pair', '--key-name', pair['KeyName'])
    recorded = {x['ami'] for x in state.get('profiles', {}).values()}
    images = admin('ec2', 'describe-images', '--owners', 'self', '--filters',
                   'Name=tag:remote-build:bake,Values=' + owner).get('Images', [])
    for image in images:
        if image['ImageId'] not in recorded:
            say('Removing image %s, which no launch profile uses' % image['ImageId'])
            retire_image(admin, image['ImageId'])
    state.pop('pending', None)


def installed_toolchains(paths, known, host):
    """The toolchains builder has, as rustup lists them without host triples, or None when rustup
    isn't there (a custom provisioning script) or the list won't fit in one tag value."""
    code, out, _ = execute(ssh_argv(paths, known, 'builder', host, 'rustup toolchain list'), timeout=60)
    if code != 0:
        return None
    names = sorted({rb.toolchain_name(line.split()[0]) for line in out.decode(errors='replace').splitlines()
                    if line.strip() and not line.startswith('no installed toolchains')})
    if not names or not all(rb.named(n) for n in names) or len(' '.join(names)) > 256:  # AWS tag value limit
        return None
    return names


def bake(admin, paths, owner, profile, sg, subnet, opts, state):
    """Build one worker image. Returns the image, its host key and root device."""
    name = profile['name']
    stamp = time.strftime('%Y%m%d-%H%M%S')
    key_name = 'remote-build-%s-bake-%s' % (owner, stamp)
    known = paths['state'].with_name('%s.%s.bake-known-hosts' % (owner, name))
    log = paths['state'].with_name('%s.%s.provision.log' % (owner, name))
    instance = None
    failed = True
    say('[%s] building the %s image on a %s; provisioning takes 15-25 minutes' % (name, profile['arch'], profile['types'][0]))
    try:
        admin('ec2', 'import-key-pair', '--key-name', key_name,
              '--public-key-material', 'fileb://' + str(paths['identity']) + '.pub')
        state['pending'] = {'key_pair': key_name}
        save_state(paths, state)
        base = admin('ssm', 'get-parameter', '--name', BASE_IMAGE.format(arch=profile['arch']))['Parameter']['Value']
        root = admin('ec2', 'describe-images', '--image-ids', base)['Images'][0]['RootDeviceName']
        launch = admin('ec2', 'run-instances', '--image-id', base, '--instance-type', profile['types'][0],
                       '--count', '1', '--key-name', key_name, '--subnet-id', subnet, '--security-group-ids', sg,
                       '--associate-public-ip-address' if opts['public'] else '--no-associate-public-ip-address',
                       '--block-device-mappings', json.dumps([{'DeviceName': root, 'Ebs': {
                           'VolumeSize': opts['disk_gb'], 'VolumeType': 'gp3', 'DeleteOnTermination': True}}]),
                       '--tag-specifications', json.dumps([{'ResourceType': 'instance', 'Tags': [
                           {'Key': 'Name', 'Value': 'remote-build-%s-bake-%s' % (owner, name)},
                           {'Key': 'remote-build:bake', 'Value': owner}]}]))
        instance = launch['Instances'][0]['InstanceId']
        state['pending']['instance'] = instance
        save_state(paths, state)
        admin('ec2', 'wait', 'instance-running', '--instance-ids', instance, timeout=900)
        host = describe_instance(admin, instance).get('PublicIpAddress' if opts['public'] else 'PrivateIpAddress')
        require(host, 'Build machine has no address')
        say('[%s] waiting for the host key in the console output' % name)
        key = console_host_key(admin, instance)
        write_private(known, '* %s\n' % key)
        for attempt in range(20):
            code, _, err = execute(ssh_argv(paths, known, 'ubuntu', host, 'echo ok'), timeout=60)
            if code == 0:
                break
            require(attempt < 19, 'Cannot reach the build machine over SSH: ' + tail(err))
            pause(15)
        say('[%s] provisioning (log: %s)' % (name, log))
        # Copy the script first and run it with stdin closed, so a package prompt can never read
        # the rest of the script as its answer.
        env = 'cat > /tmp/remote-build-provision.sh && PUBKEY=%s RUST_TOOLCHAINS=%s bash /tmp/remote-build-provision.sh </dev/null' % (
            shlex.quote(paths['identity'].with_name(paths['identity'].name + '.pub').read_text().strip()),
            shlex.quote(' '.join(opts['toolchains'])))
        code, out, err = execute(ssh_argv(paths, known, 'ubuntu', host, env),
                                 data=Path(opts['provision']).read_bytes(), timeout=5400)
        write_private(log, out.decode(errors='replace') + err.decode(errors='replace'))
        require(code == 0, 'Provisioning failed; see ' + str(log))
        code, out, err = execute(ssh_argv(paths, known, 'builder', host,
                                          "python3 -c 'import sys; sys.exit(sys.version_info < (3, 9))' && "
                                          "python3 --version && (cargo --version || true)"), timeout=120)
        require(code == 0, 'The image has no python3 3.9+ for the builder user: ' + tail(err))
        say('[%s] builder sees: %s' % (name, ' / '.join(l for l in out.decode().splitlines() if l)))
        code, _, _ = execute(ssh_argv(paths, known, 'builder', host, 'sudo -n true'), timeout=60)
        require(code != 0, 'builder has sudo on the image; fix the provisioning script')
        toolchains = installed_toolchains(paths, known, host)
        say('[%s] builder has toolchains: %s' % (name, ', '.join(toolchains) if toolchains else
                                                  'unknown (no rustup); the image is not tagged with them'))
        code, _, _ = execute(ssh_argv(paths, known, 'ubuntu', host, 'echo ok'), timeout=60)
        require(code != 0, 'ubuntu can still log in; the provisioning script must remove its key')
        say('[%s] making the image' % name)
        admin('ec2', 'stop-instances', '--instance-ids', instance)
        admin('ec2', 'wait', 'instance-stopped', '--instance-ids', instance, timeout=900)
        tags = [{'Key': 'remote-build:bake', 'Value': owner}, {'Key': 'remote-build:profile', 'Value': name}]
        # setup and up read this tag to refuse a repository whose pinned toolchain the image lacks.
        listed = [{'Key': rb.TOOLCHAIN_TAG, 'Value': ' '.join(toolchains)}] if toolchains else []
        ami = admin('ec2', 'create-image', '--instance-id', instance,
                    '--name', 'remote-build-%s-%s-%s' % (owner, name, stamp),
                    '--description', 'remote-build worker image (%s, %s)' % (owner, profile['arch']),
                    '--tag-specifications', json.dumps([{'ResourceType': 'image', 'Tags': tags + listed},
                                                        {'ResourceType': 'snapshot', 'Tags': tags}]))['ImageId']
        state['pending']['image'] = ami
        save_state(paths, state)
        for attempt in range(6):  # each CLI wait gives up after ten minutes
            code, _, err = admin.raw('ec2', 'wait', 'image-available', '--image-ids', ami, timeout=900)
            if code == 0:
                break
            require(attempt < 5, 'Image %s did not become available: %s' % (ami, tail(err)))
        image = admin('ec2', 'describe-images', '--image-ids', ami)['Images'][0]
        for mapping in image.get('BlockDeviceMappings', []):
            require('Ebs' not in mapping or mapping['Ebs'].get('DeleteOnTermination') is True,
                    'Image %s keeps a volume after termination' % ami)
        failed = False
        return {'ami': ami, 'host_key': key, 'root_device': image['RootDeviceName'], 'toolchains': toolchains}
    finally:
        if known.exists():
            known.unlink()
        if failed and opts['keep_on_failure'] and instance:
            say('[%s] keeping build machine %s for debugging (--keep-on-failure); the next apply removes it'
                % (name, instance))
        else:
            if failed:
                say('[%s] cleaning up after the failure' % name)
                half_made = state.get('pending', {}).get('image')
                if half_made:
                    try:
                        retire_image(admin, half_made)
                    except Refused:
                        pass  # the next apply removes images no profile records
            if instance:
                admin.raw('ec2', 'terminate-instances', '--instance-ids', instance)
            admin.raw('ec2', 'delete-key-pair', '--key-name', key_name)
            state.pop('pending', None)
            save_state(paths, state)


def images_by_id(admin, ids):
    """Our images among ids; a filter, unlike --image-ids, does not fail on a missing one."""
    return admin('ec2', 'describe-images', '--owners', 'self', '--filters',
                 'Name=image-id,Values=' + ','.join(ids)).get('Images', [])


def retire_image(admin, ami):
    images = images_by_id(admin, [ami])
    snapshots = [m['Ebs']['SnapshotId'] for i in images for m in i.get('BlockDeviceMappings', []) if 'Ebs' in m]
    admin('ec2', 'deregister-image', '--image-id', ami)
    for snapshot in snapshots:
        for attempt in range(12):  # deregistration takes a moment to release the snapshot
            code, _, err = admin.raw('ec2', 'delete-snapshot', '--snapshot-id', snapshot)
            if code == 0 or b'InvalidSnapshot.NotFound' in err:
                break
            require(b'InvalidSnapshot.InUse' in err and attempt < 11,
                    'aws ec2 delete-snapshot failed: ' + tail(err))
            pause(10)


# ---------------------------------------------------------------- checks with the daily profile

def worker_tags(owner, project, session, expires):
    return json.dumps([{'ResourceType': 'instance', 'Tags': [
        {'Key': 'remote-build:owner', 'Value': owner}, {'Key': 'remote-build:project', 'Value': project},
        {'Key': 'remote-build:session', 'Value': session}, {'Key': 'remote-build:expires', 'Value': str(expires)}]}])


def launch_args(template, version, instance_type, owner, project, session, expires):
    return ['--launch-template', json.dumps({'LaunchTemplateId': template, 'Version': version}),
            '--instance-type', instance_type, '--count', '1', '--metadata-options', 'HttpEndpoint=disabled',
            '--instance-initiated-shutdown-behavior', 'terminate',
            '--tag-specifications', worker_tags(owner, project, session, expires)]


def dry_run(daily, *args):
    _, _, err = daily.raw('ec2', 'run-instances', '--dry-run', *args)
    text = err.decode(errors='replace')
    if 'DryRunOperation' in text:
        return 'allowed'
    if 'UnauthorizedOperation' in text:
        return 'denied'
    return 'error: ' + tail(text, 300)


def check_policy(daily, owner, profile, out):
    """Prove the daily profile can launch an approved worker and nothing else (no instance starts)."""
    args = lambda itype, tag_owner: launch_args(out['launch_template'], out['launch_version'], itype,
                                                tag_owner, 'dry-run', 'dry-run', 0)
    deadline = now() + IAM_PROPAGATION_MINUTES * 60
    while True:  # a new role takes a minute or two to become assumable
        allowed = dry_run(daily, *args(profile['types'][0], owner))
        if allowed == 'allowed' or now() > deadline:
            break
        pause(15)
    require(allowed == 'allowed', 'The daily profile cannot launch an approved worker: ' + allowed)
    unapproved = next((t for t in UNAPPROVED_CANDIDATES[profile['arch']] if t not in profile['types']), None)
    results = {'approved type': allowed}
    if unapproved:
        results['unapproved type ' + unapproved] = dry_run(daily, *args(unapproved, owner))
    results['other owner'] = dry_run(daily, *args(profile['types'][0], owner + '-other'))
    wrong = [k for k, v in results.items() if k != 'approved type' and v == 'allowed']
    require(not wrong, 'The operator policy allows what it must deny: ' + ', '.join(wrong))
    return results


def janitor_test(daily, paths, owner, profile, out, public):
    """Boot a real worker the way the client does, log in as builder, then watch the janitor end it.

    Returns 'passed', 'failed' (the janitor did not terminate it) or 'login failed'. Only a
    termination that a client initiated (the janitor's TerminateInstances) after the worker ran
    counts; a launch that dies on its own is not evidence."""
    session = 'bootstrap-' + str(uuid.uuid4())
    expires = int(now()) + WORKER_LOGIN_MINUTES * 60
    say('Janitor test: launching a %s worker that expires in %d minutes; logging in as builder, then '
        'waiting for the janitor' % (profile['types'][0], WORKER_LOGIN_MINUTES))
    launch = daily('ec2', 'run-instances', '--client-token', session,
                   *launch_args(out['launch_template'], out['launch_version'], profile['types'][0],
                                owner, 'bootstrap-janitor-test', session, expires))
    instance = launch['Instances'][0]['InstanceId']
    ended = False
    try:
        logged_in = False
        while now() < expires and not logged_in:
            i = describe_instance(daily, instance)
            if i['State']['Name'] in ('shutting-down', 'terminated'):
                ended = True
                return 'login failed'
            host = i.get('PublicIpAddress' if public else 'PrivateIpAddress')
            if i['State']['Name'] == 'running' and host:
                code, _, _ = execute(ssh_argv(paths, paths['known_hosts'], 'builder', host,
                                              'python3 --version'), timeout=60)
                logged_in = code == 0
            if not logged_in:
                pause(15)
        if not logged_in:
            return 'login failed'
        say('Janitor test: builder logged in to the worker; waiting for the janitor')
        deadline = expires + JANITOR_TEST_MINUTES * 60
        while now() < deadline:
            pause(30)
            i = describe_instance(daily, instance)
            if i['State']['Name'] in ('shutting-down', 'terminated'):
                ended = True
                return 'passed' if i.get('StateReason', {}).get('Code') == 'Client.UserInitiatedShutdown' else 'failed'
        return 'failed'
    finally:
        if not ended:
            say('Janitor test: terminating test worker %s myself' % instance)
            daily.raw('ec2', 'terminate-instances', '--instance-ids', instance)


# ---------------------------------------------------------------- plan and apply

def default_paths(a):
    return {'config': a.config, 'state_root': a.state, 'state': a.state / 'bootstrap' / (a.owner + '.json'),
            'known_hosts': a.known_hosts.expanduser(), 'identity': a.identity.expanduser(),
            'aws_config': Path(os.environ.get('AWS_CONFIG_FILE', str(Path.home() / '.aws' / 'config')))}


def region_for(a, state):
    if a.region or state.get('region'):
        return a.region or state['region']
    code, out, _ = execute(['aws', 'configure', 'get', 'region', '--profile', a.admin_profile])
    require(code == 0 and out.strip(), 'Pass --region (the admin profile has no default region)')
    return out.decode().strip()


def prepare(a):
    """Everything apply needs, from read-only calls. Plan prints this; apply acts on it."""
    require(re.fullmatch(OWNER, a.owner), 'Owner must be lowercase letters, digits and hyphens, at most 32')
    require(a.daily_profile != 'default' and rb.named(a.daily_profile), 'Choose a named daily profile, not default')
    for t in a.rust_toolchain:
        require(re.fullmatch(TOOLCHAIN, t), 'Invalid toolchain name: ' + t)
    if a.alert_email:
        require(re.fullmatch(r'[^@\s]+@[^@\s]+\.[^@\s]+', a.alert_email), 'Invalid alert email')
    paths = default_paths(a)
    state = load_json(paths['state'], {}) or {}
    region = region_for(a, state)
    # Re-runs keep earlier choices unless a flag changes them.
    a.disk_gb = a.disk_gb or state.get('disk_gb') or 40
    a.address = a.address or state.get('address') or 'public'
    require(1 <= a.disk_gb <= 1024, 'Disk size must be 1-1024 GB')
    admin = Account(a.admin_profile, region)
    account = admin('sts', 'get-caller-identity')['Account']
    require(state.get('account', account) == account and state.get('region', region) == region,
            'Bootstrap state for owner %s belongs to another account or region; use another owner' % a.owner)
    requested = [parse_image(s) for s in a.image] or [
        {'name': n, 'arch': p['arch'], 'types': p['types']} for n, p in sorted(state.get('profiles', {}).items())]
    require(requested, 'Name at least one image, for example --image arm64:c7g.xlarge,c7g.2xlarge')
    names = [p['name'] for p in requested]
    require(len(set(names)) == len(names), 'Each launch profile name must be unique')
    previous = load_json(paths['config']) if paths['config'].exists() else None
    if previous is not None:
        require(isinstance(previous, dict), 'The existing private config is not a JSON object')
        same = previous.get('owner') == a.owner and previous.get('profile') == a.daily_profile
        require(same or a.replace_config, 'A private config for owner %r already exists at %s; pass --replace-config '
                'to back it up and replace it' % (previous.get('owner'), rb.shown(paths['config'])))
    if paths['aws_config'].exists():
        section = read_section(paths['aws_config'].read_text(), profile_header(a.daily_profile))
        managed = section is not None and any(l.strip() == MANAGED + a.owner for l in section)
        require(section is None or managed or a.replace_profile,
                'AWS profile %s already exists and bootstrap did not write it; pass --replace-profile or choose '
                '--daily-profile' % a.daily_profile)
    public = a.address == 'public'
    require(public or a.cidr or state.get('cidr_source') == 'explicit',
            'Private addressing needs --cidr: the network your client reaches workers from')
    for p in requested:
        found = admin('ec2', 'describe-instance-types', '--instance-types', *p['types'])['InstanceTypes']
        for t in found:
            require(ARCHES[p['arch']] in t['ProcessorInfo']['SupportedArchitectures'],
                    '%s does not run %s images (profile %s)' % (t['InstanceType'], p['arch'], p['name']))
    if a.subnet or state.get('subnet'):
        subnet_id = a.subnet or state['subnet']
        s = admin('ec2', 'describe-subnets', '--subnet-ids', subnet_id)['Subnets'][0]
        vpc, subnet = s['VpcId'], s['SubnetId']
    else:
        vpcs = admin('ec2', 'describe-vpcs', '--filters', 'Name=is-default,Values=true')['Vpcs']
        require(vpcs, 'No default VPC in %s; pass --subnet' % region)
        vpc = vpcs[0]['VpcId']
        subnets = admin('ec2', 'describe-subnets', '--filters', 'Name=vpc-id,Values=' + vpc,
                        'Name=default-for-az,Values=true')['Subnets']
        types = sorted({t for p in requested for t in p['types']})
        offers = admin('ec2', 'describe-instance-type-offerings', '--location-type', 'availability-zone',
                       '--filters', 'Name=instance-type,Values=' + ','.join(types))['InstanceTypeOfferings']
        zones = {}
        for o in offers:
            zones.setdefault(o['Location'], set()).add(o['InstanceType'])
        usable = sorted((s for s in subnets if zones.get(s['AvailabilityZone'], set()) >= set(types)),
                        key=lambda s: s['AvailabilityZone'])
        require(usable, 'No default subnet whose zone offers every type (%s); pass --subnet' % ', '.join(types))
        subnet = usable[0]['SubnetId']
    if a.cidr:
        cidr, source = str(ipaddress.ip_network(a.cidr, strict=False)), 'explicit'
    elif state.get('cidr_source') == 'explicit':
        cidr, source = state['cidr'], 'explicit'
    else:
        cidr, source = operator_cidr(), 'detected'
    stack = 'remote-build-' + a.owner
    status, outputs = stack_status(admin, stack)
    known = state.get('profiles', {})
    bake, keep, unavailable = [], [], []
    for p in requested:
        old = known.get(p['name'])
        if a.rebake or not old or old.get('arch') != p['arch'] or old.get('disk_gb') != a.disk_gb:
            bake.append(p['name'])
        else:
            keep.append(p['name'])
    if keep:
        existing = images_by_id(admin, [known[n]['ami'] for n in keep])
        available = {i['ImageId'] for i in existing if i.get('State') == 'available'}
        for n in list(keep):
            if known[n]['ami'] not in available:
                keep.remove(n)
                bake.append(n)
                unavailable.append(n)
    removed = sorted(set(known) - set(names))
    active = admin('ec2', 'describe-instances', '--filters', 'Name=tag:remote-build:owner,Values=' + a.owner,
                   'Name=instance-state-name,Values=' + ACTIVE)['Reservations']
    active = [i['InstanceId'] for r in active for i in r['Instances']]
    tested = bool(state.get('janitor_tested')) and status is not None and not a.retest_janitor
    return {'paths': paths, 'admin': admin, 'state': state, 'account': account, 'region': region,
            'profiles': requested, 'previous': previous, 'public': public, 'vpc': vpc, 'subnet': subnet,
            'cidr': cidr, 'cidr_source': source, 'stack': stack, 'stack_status': status, 'outputs': outputs,
            'bake': sorted(bake), 'keep': sorted(keep), 'unavailable': unavailable, 'remove': removed, 'active_workers': active,
            # A new --rust-toolchain list replaces the remembered one, so a toolchain can be dropped.
            'toolchains': a.rust_toolchain or state.get('toolchains', []),
            'janitor_test': 'already passed' if tested else ('skipped' if a.skip_janitor_test else 'will run')}


def network_of(p):
    return {'vpc': p['vpc'], 'subnet': p['subnet'], 'ssh_from': p['cidr'], 'address': 'public' if p['public'] else 'private'}


def summary_of(p):
    """What apply would do, from the read-only plan."""
    return {'region': p['region'], 'stack': p['stack'] + ' (' + (p['stack_status'] or 'will be created') + ')',
            'network': network_of(p),
            'launch_profiles': {x['name']: {'arch': x['arch'], 'instance_types': x['types'],
                                            'image': 'bake' if x['name'] in p['bake'] else 'reuse'}
                                for x in p['profiles']},
            'bake_toolchains': ['stable'] + p['toolchains'],
            'remove_profiles': p['remove'], 'active_workers': p['active_workers'], 'janitor_test': p['janitor_test']}


def applied(p, status, state, built, retired):
    """What apply did and the state it left, unlike summary_of, which is the plan made before."""
    return {'region': p['region'], 'stack': '%s (%s)' % (p['stack'], status), 'network': network_of(p),
            'launch_profiles': {x['name']: {'arch': x['arch'], 'instance_types': x['types'],
                                            'image': ('built ' if x['name'] in p['bake'] else 'reused ') +
                                            state['profiles'][x['name']]['ami'],
                                            'launch_version': built[x['name']]['launch_version'],
                                            'toolchains': state['profiles'][x['name']].get('toolchains') or
                                            'unknown: the image has no %s tag; --rebake records them' % rb.TOOLCHAIN_TAG}
                                for x in p['profiles']},
            'bake_toolchains': ['stable'] + p['toolchains'],
            'removed_profiles': p['remove'], 'retired_images': retired, 'active_workers': p['active_workers']}


def plan(a):
    p = prepare(a)
    result = summary_of(p)
    result['changes'] = 'none' if not p['bake'] and not p['remove'] and p['stack_status'] else 'apply would make them'
    result['estimate'] = ('%d image bake(s) at 15-25 minutes each' % len(p['bake']) if p['bake'] else 'no image bake') + \
        ('; janitor test up to %d minutes' % (WORKER_LOGIN_MINUTES + JANITOR_TEST_MINUTES)
         if p['janitor_test'] == 'will run' else '')
    result['blocked'] = ('Active workers %s: down them before images change' % ', '.join(p['active_workers'])
                         if p['active_workers'] and (p['bake'] or p['remove']) else None)
    return result


def ensure_identity(paths):
    key = paths['identity']
    if key.exists():
        require(key.with_name(key.name + '.pub').exists(), 'Missing public half: %s.pub' % key)
        os.chmod(key, 0o600)
        return False
    key.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    code, _, err = execute(['ssh-keygen', '-q', '-t', 'ed25519', '-N', '', '-C', 'remote-build', '-f', str(key)])
    require(code == 0, 'ssh-keygen failed: ' + tail(err))
    os.chmod(key, 0o600)
    return True


def write_config(p, a, built, janitor_confirmed):
    previous = p['previous'] if p['previous'] and p['previous'].get('owner') == a.owner else {}
    config = {'version': 2, 'provider': 'aws', 'profile': a.daily_profile, 'region': p['region'], 'owner': a.owner,
              'launch_profiles': built, 'janitor_confirmed': janitor_confirmed, 'ssh_user': 'builder',
              'known_hosts': str(p['paths']['known_hosts']), 'identity_file': str(p['paths']['identity']),
              'address_field': 'PublicIpAddress' if p['public'] else 'PrivateIpAddress', 'cache_retention': 'session'}
    for key, default in TUNABLES.items():
        config[key] = previous.get(key, default)
    path = p['paths']['config']
    if p['previous'] is not None and not previous:
        backup = path.with_name(path.name + '.bak-' + time.strftime('%Y%m%d-%H%M%S'))
        os.replace(path, backup)
        say('Backed up the previous config to ' + rb.shown(backup))
    write_private(path, json.dumps(config, indent=2, sort_keys=True) + '\n')
    rb.parse_config(path)
    return config


def apply(a):
    p = prepare(a)
    admin, paths, state, owner = p['admin'], p['paths'], p['state'], a.owner
    require(not (p['active_workers'] and (p['bake'] or p['remove'])),
            'Workers %s are running; collect results and /remote-build:down them before images change'
            % ', '.join(p['active_workers']))
    provision = Path(a.provision_script or state.get('provision_script') or ASSETS / 'provision.sh').expanduser()
    require(provision.is_file(), 'Provisioning script not found: %s' % provision)
    state.update(account=p['account'], region=p['region'], stack=p['stack'], subnet=p['subnet'],
                 cidr=p['cidr'], cidr_source=p['cidr_source'], address=a.address, disk_gb=a.disk_gb,
                 toolchains=p['toolchains'],
                 provision_script=str(provision) if (a.provision_script or state.get('provision_script')) else None,
                 alert_email=a.alert_email or state.get('alert_email'))
    state.setdefault('profiles', {})
    save_state(paths, state)
    if ensure_identity(paths):
        say('Created SSH key ' + rb.shown(paths['identity']))
    clean_bake_leftovers(admin, owner, state)
    save_state(paths, state)

    # A profile keeps its current image (and so its launch template ID) until a new one is
    # ready; only a profile whose image is gone waits for its bake to get a template.
    missing = set(p['unavailable'])

    def stack_template():
        profiles = [dict(x, **{k: state['profiles'][x['name']][k] for k in ('ami', 'root_device')})
                    if x['name'] in state['profiles'] and x['name'] not in missing else x for x in p['profiles']]
        return render(owner, p['cidr'], p['vpc'], p['subnet'], profiles, state['alert_email'], p['public'])

    status, outputs = deploy(admin, paths, p['stack'], stack_template(), owner)
    retired = [state['profiles'].pop(name)['ami'] for name in p['remove']]
    opts = {'public': p['public'], 'disk_gb': a.disk_gb, 'toolchains': state['toolchains'],
            'provision': provision, 'keep_on_failure': a.keep_on_failure}
    for x in p['profiles']:
        if x['name'] not in p['bake']:
            continue
        image = bake(admin, paths, owner, x, outputs['SecurityGroupId'], p['subnet'], opts, state)
        old = state['profiles'].get(x['name'], {}).get('ami')
        if old and old != image['ami']:
            retired.append(old)
        state['profiles'][x['name']] = dict(image, arch=x['arch'], types=x['types'], disk_gb=a.disk_gb)
        missing.discard(x['name'])
        save_state(paths, state)
    for x in p['profiles']:
        state['profiles'][x['name']]['types'] = x['types']
    save_state(paths, state)
    if p['bake']:
        status, outputs = deploy(admin, paths, p['stack'], stack_template(), owner)
    for ami in retired:
        say('Removing the replaced image ' + ami)
        retire_image(admin, ami)

    aws_config = paths['aws_config']
    text = aws_config.read_text() if aws_config.exists() else ''
    write_aws_config(aws_config, set_section(text, profile_header(a.daily_profile), [
        MANAGED + owner, 'role_arn = ' + outputs['OperatorRoleArn'], 'source_profile = ' + a.admin_profile,
        'role_session_name = remote-build', 'region = ' + p['region']]))
    write_private(paths['known_hosts'], ''.join('* %s\n' % state['profiles'][x['name']]['host_key']
                                               for x in p['profiles']))
    built = {x['name']: {'launch_template': outputs[logical(x['name']) + 'Id'],
                         'launch_version': str(outputs[logical(x['name']) + 'Version']),
                         'instance_types': x['types']} for x in p['profiles']}
    confirmed = p['janitor_test'] == 'already passed'
    write_config(p, a, built, confirmed)

    daily = Account(a.daily_profile, p['region'])
    first = p['profiles'][0]
    say('Checking the daily profile policy with dry runs (no instance starts)')
    checks = {x['name']: check_policy(daily, owner, x, built[x['name']]) for x in p['profiles']}
    janitor = p['janitor_test']
    if janitor == 'will run':
        janitor = janitor_test(daily, paths, owner, first, built[first['name']], p['public'])
        passed = janitor == 'passed'
        state['janitor_tested'] = passed
        save_state(paths, state)
        if passed:
            write_config(dict(p, previous=load_json(paths['config'])), a, built, True)
    report = rb.setup_report(paths['config'], paths['state_root'], None)
    result = applied(p, status, state, built, retired)
    result.update(janitor_test=janitor, policy_checks=checks, config=rb.shown(paths['config']),
                  daily_profile=a.daily_profile,
                  alerts=alert_state(admin, outputs['AlertTopicArn'], state['alert_email']),
                  setup={e['check']: e['status'] for e in report['checks']},
                  next='In each repository, commit .remote-build.json naming a launch profile and one of its types, '
                       'for example {"version": 1, "launch_profile": "%s", "instance_type": "%s"}'
                       % (first['name'], first['types'][0]))
    if janitor == 'login failed':
        result['next'] = ('The test worker never accepted a builder login with the image host key within %d minutes. '
                          'Check the network path (address, --cidr) and that the image boots without cloud-init '
                          '(rebake with --keep-on-failure to inspect). janitor_confirmed stays false.' % WORKER_LOGIN_MINUTES)
    if janitor == 'failed':
        result['next'] = ('The janitor did not terminate the expired test worker within %d minutes; read its logs '
                          '(/aws/lambda/remote-build-%s-janitor), fix the cause and re-run apply with --retest-janitor. '
                          'janitor_confirmed stays false until then.' % (JANITOR_TEST_MINUTES, owner))
    return result


# ---------------------------------------------------------------- teardown

def teardown(a):
    require(a.confirm == a.owner, 'Teardown deletes every remote-build resource for this owner; pass --confirm %s' % a.owner)
    paths = default_paths(a)
    state = load_json(paths['state'], {}) or {}
    admin = Account(a.admin_profile, region_for(a, state))
    account = admin('sts', 'get-caller-identity')['Account']
    require(state.get('account', account) == account, 'Bootstrap state for this owner belongs to another account')
    active = admin('ec2', 'describe-instances', '--filters', 'Name=tag:remote-build:owner,Values=' + a.owner,
                   'Name=instance-state-name,Values=' + ACTIVE)['Reservations']
    instances = [i for r in active for i in r['Instances']]
    active = [i['InstanceId'] for i in instances if i['State']['Name'] != 'shutting-down']
    require(not active, 'Workers %s are still running; collect results and /remote-build:down them first'
            % ', '.join(active))
    ending = [i['InstanceId'] for i in instances if i['State']['Name'] == 'shutting-down']
    if ending:  # they still hold the security group
        admin('ec2', 'wait', 'instance-terminated', '--instance-ids', *ending, timeout=900)
    removed = []
    clean_bake_leftovers(admin, a.owner, state)
    stack = 'remote-build-' + a.owner
    if stack_status(admin, stack)[0] is not None:
        say('Deleting stack %s (a few minutes)' % stack)
        delete_stack(admin, stack)
        removed.append('stack ' + stack)
    images = admin('ec2', 'describe-images', '--owners', 'self', '--filters',
                   'Name=tag:remote-build:bake,Values=' + a.owner).get('Images', [])
    for image in images:
        retire_image(admin, image['ImageId'])
        removed.append('image ' + image['ImageId'])
    if paths['aws_config'].exists():
        text = paths['aws_config'].read_text()
        section = read_section(text, profile_header(a.daily_profile))
        if section and any(l.strip() == MANAGED + a.owner for l in section):
            write_aws_config(paths['aws_config'], remove_section(text, profile_header(a.daily_profile)))
            removed.append('AWS profile ' + a.daily_profile)
    config = load_json(paths['config']) if paths['config'].exists() else None
    if isinstance(config, dict) and config.get('owner') == a.owner:
        paths['config'].unlink()
        removed.append(rb.shown(paths['config']))
    if paths['known_hosts'].exists() and state:
        paths['known_hosts'].unlink()
        removed.append(rb.shown(paths['known_hosts']))
    # Owner names never contain a dot, so this matches this owner's files and no one else's.
    for leftover in paths['state'].parent.glob(a.owner + '.*'):
        leftover.unlink()
    return {'removed': removed, 'kept': [rb.shown(paths['identity']) + ' (delete it yourself if unused)',
                                         'per-project state under ' + rb.shown(paths['state_root'] / 'projects')]}


# ---------------------------------------------------------------- command line

def template_command(a):
    profiles = [dict(parse_image(s), ami='ami-0123456789abcdef0', root_device='/dev/sda1') for s in a.image] or \
        [dict(parse_image('arm64:c7g.xlarge'), ami='ami-0123456789abcdef0', root_device='/dev/sda1')]
    return render(a.owner, a.cidr or '203.0.113.10/32', 'vpc-0123456789abcdef0', a.subnet or 'subnet-0123456789abcdef0',
                  profiles, a.alert_email, a.address != 'private')


def parser():
    home = Path.home()
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--config', type=Path, default=Path(os.environ.get('XDG_CONFIG_HOME', str(home / '.config'))) / 'remote-build/config.json')
    p.add_argument('--state', type=Path, default=Path(os.environ.get('XDG_STATE_HOME', str(home / '.local/state'))) / 'remote-build')
    sub = p.add_subparsers(dest='action', required=True)
    for name, text in [('plan', 'Show what apply would do; read-only'), ('apply', 'Create or update everything'),
                       ('teardown', 'Delete everything bootstrap made for this owner'),
                       ('template', 'Print the CloudFormation template; offline')]:
        s = sub.add_parser(name, help=text)
        s.add_argument('--owner', required=True, help='Stable name for your workers, for example yourname-builds')
        s.add_argument('--image', action='append', default=[], metavar='[NAME=]ARCH:TYPES',
                       help='A launch profile: arm64:c7g.xlarge,c7g.2xlarge or x86=amd64:c7i.xlarge (repeatable; '
                            'the first type also builds the image). Re-runs default to the last set')
        s.add_argument('--cidr', help='Network allowed to SSH to workers (default: this machine\'s public address)')
        s.add_argument('--subnet', help='Subnet for workers (default: a default-VPC subnet offering every type)')
        s.add_argument('--address', choices=['public', 'private'],
                       help='How the client reaches workers (default public); private needs a route such as a VPN, and --cidr')
        s.add_argument('--alert-email', help='Where to send janitor failure alarms')
        if name == 'template':
            continue
        s.add_argument('--admin-profile', required=True, help='AWS CLI profile that can create EC2, IAM, Lambda and CloudFormation resources')
        s.add_argument('--region', help='Default: the admin profile\'s region')
        s.add_argument('--daily-profile', default='remote-build', help='AWS profile the plugin uses (default remote-build)')
        s.add_argument('--known-hosts', type=Path, default=home / '.ssh' / 'remote-build-known-hosts')
        s.add_argument('--identity', type=Path, default=home / '.ssh' / 'remote-build-identity')
        s.add_argument('--disk-gb', type=int, help='Worker disk size; workers cannot grow it (default 40)')
        s.add_argument('--rust-toolchain', action='append', default=[],
                       help='Extra toolchain to preinstall besides stable (repeatable). The list replaces the one '
                            'remembered from earlier runs, so name every toolchain to keep')
        s.add_argument('--provision-script', help='Your own provisioning script instead of scripts/aws/provision.sh')
        s.add_argument('--rebake', action='store_true', help='Build fresh images even when the current ones are usable')
        s.add_argument('--skip-janitor-test', action='store_true', help='Leave janitor_confirmed false; test it yourself')
        s.add_argument('--retest-janitor', action='store_true', help='Run the janitor test again')
        s.add_argument('--replace-config', action='store_true', help='Back up and replace another owner\'s private config')
        s.add_argument('--replace-profile', action='store_true', help='Overwrite an AWS profile bootstrap did not write')
        s.add_argument('--keep-on-failure', action='store_true', help='Keep a failed build machine for debugging')
        if name == 'teardown':
            s.add_argument('--confirm', help='Repeat the owner name to confirm deletion')
    return p


def main(argv=None):
    a = parser().parse_args(argv)
    os.umask(0o077)
    try:
        if a.action == 'template':
            require(re.fullmatch(OWNER, a.owner), 'Owner must be lowercase letters, digits and hyphens, at most 32')
            result = template_command(a)
        else:
            result = {'plan': plan, 'apply': apply, 'teardown': teardown}[a.action](a)
    except Refused as e:
        print(json.dumps({'error': str(e)}), file=sys.stderr)
        return 2
    except KeyboardInterrupt:
        print(json.dumps({'error': 'Interrupted; re-run the same command to continue or clean up'}), file=sys.stderr)
        return 130
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == '__main__':
    sys.exit(main())
