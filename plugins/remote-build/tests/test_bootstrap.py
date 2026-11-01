#!/usr/bin/env python3
"""Offline bootstrap tests. A fake cloud stands in for the aws, ssh and ssh-keygen tools; nothing
contacts AWS, starts an instance or opens a network connection."""
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import re
import shlex
import sys
import tempfile
import types
import unittest
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parents[1] / 'scripts'
sys.path.insert(0, str(SCRIPTS))
spec = importlib.util.spec_from_file_location('bootstrap', SCRIPTS / 'bootstrap.py')
b = importlib.util.module_from_spec(spec)
spec.loader.exec_module(b)
rb = b.rb

HOST_KEY = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFixtureHostKey'
CONSOLE = 'boot\n-----BEGIN SSH HOST KEY KEYS-----\necdsa-sha2-nistp256 AAAAE2 root@ip\n' + \
          HOST_KEY + ' root@ip\n-----END SSH HOST KEY KEYS-----\n'
READ_ONLY = {'get-caller-identity', 'describe-instance-types', 'describe-vpcs', 'describe-subnets',
             'describe-instance-type-offerings', 'describe-stacks', 'describe-images', 'describe-instances',
             'get', 'describe-route-tables'}


def fail(text):
    return 254, b'', text.encode()


class FakeCloud:
    """Just enough EC2, CloudFormation, SSM, IAM evaluation, SSH and janitor behaviour."""

    def __init__(self, root):
        self.root = root
        self.clock = 1000000.0
        self.stacks, self.images, self.instances, self.key_pairs = {}, {}, {}, set()
        self.snapshots_deleted, self.ops, self.deploys, self.provisioned = [], [], [], set()
        self.lt_ids, self.lt_versions = {}, {}
        self.counter = 0
        self.fail_provision = False
        self.janitor_works = True
        self.termination_reason = 'Client.UserInitiatedShutdown'
        self.snapshot_busy = set()
        self.console_reads = 0
        self.subscriptions = {}  # topic: [subscription]; email ones stay pending until confirmed
        self.sns_readable = True
        self.toolchains = {}  # host: the extra toolchains its provisioning installed
        self.no_rustup = False
        self.default_vpc = True
        self.subnets = [{'SubnetId': 'subnet-b', 'VpcId': 'vpc-default', 'AvailabilityZone': 'us-test-1b'},
                        {'SubnetId': 'subnet-a', 'VpcId': 'vpc-default', 'AvailabilityZone': 'us-test-1a'}]
        self.route_tables = [{'RouteTableId': 'rtb-main', 'VpcId': 'vpc-default', 'Associations': [{'Main': True}],
                              'Routes': [{'DestinationCidrBlock': '0.0.0.0/0', 'GatewayId': 'igw-1', 'State': 'active'}]}]

    def next_id(self, prefix):
        self.counter += 1
        return '%s-%08x' % (prefix, self.counter)

    # -- dispatch
    def __call__(self, argv, data=None, timeout=120):
        tool = Path(argv[0]).name
        if argv[1:] in (['--version'], ['-V']):
            return 0, b'fixture\n', b''
        if tool == 'ssh-keygen':
            key = Path(argv[argv.index('-f') + 1])
            key.write_text('PRIVATE\n')
            key.with_name(key.name + '.pub').write_text('ssh-ed25519 AAAAfixturePublic remote-build\n')
            return 0, b'', b''
        if tool == 'ssh':
            return self.ssh(argv, data)
        assert tool == 'aws', argv
        if argv[1] == 'configure':
            return 0, b'us-test-1\n', b''
        profile = argv[argv.index('--profile') + 1]
        i = argv.index('--no-cli-pager')
        service, op, args = argv[i + 1], argv[i + 2], argv[i + 3:]
        if service == 'cloudformation' and op == 'wait':
            op = 'wait-' + args[0]
        elif service == 'ec2' and op == 'wait':
            op = 'wait-' + args[0]
        self.ops.append((profile, service, op))
        if profile != 'admin':
            assert self.daily_role(profile), 'daily profile used before bootstrap wrote it'
        handler = getattr(self, 'op_' + op.replace('-', '_'))
        result = handler(args, profile)
        if isinstance(result, tuple):
            return result
        return 0, json.dumps(result).encode(), b''

    def arg(self, args, name, default=None):
        return args[args.index(name) + 1] if name in args else default

    def filters(self, args):
        out = {}
        for f in args[args.index('--filters') + 1:] if '--filters' in args else []:
            if not f.startswith('Name='):
                break
            key, values = f[len('Name='):].split(',Values=')
            out[key] = values.split(',')
        return out

    def daily_role(self, profile):
        path = Path(os.environ['AWS_CONFIG_FILE'])
        section = b.read_section(path.read_text(), '[profile %s]' % profile) if path.exists() else None
        return section and next((l.split('=', 1)[1].strip() for l in section if l.startswith('role_arn')), None)

    # -- ssh
    def ssh(self, argv, data):
        user, host = argv[-2].split('@')
        command = argv[-1]
        assert '-F' in argv and 'StrictHostKeyChecking=yes' in argv
        hosts = Path(next(x for x in argv if x.startswith('UserKnownHostsFile='))[len('UserKnownHostsFile='):])
        assert '* %s' % HOST_KEY in hosts.read_text().splitlines(), 'connected without the console host key'
        done = host in self.provisioned
        if command == 'echo ok':
            return (0, b'ok\n', b'') if (user == 'ubuntu') != done else (255, b'', b'Permission denied')
        if command.endswith('</dev/null'):
            assert command.startswith('cat > /tmp/remote-build-provision.sh && ')
            assert user == 'ubuntu' and 'PUBKEY=' in command and data.startswith(b'#!/bin/bash')
            if self.fail_provision:
                return 1, b'apt output\n', b'E: provisioning broke\n'
            self.provisioned.add(host)
            extra = next(t for t in shlex.split(command) if t.startswith('RUST_TOOLCHAINS='))[len('RUST_TOOLCHAINS='):]
            self.toolchains[host] = extra.split()
            return 0, b'provisioned\n', b''
        if command == 'rustup toolchain list':
            if not done or user != 'builder' or self.no_rustup:
                return 127, b'', b'bash: rustup: command not found\n'
            lines = ['stable-x86_64-unknown-linux-gnu (default)'] + [
                t + '-x86_64-unknown-linux-gnu' for t in self.toolchains[host]]
            return 0, ('\n'.join(lines) + '\n').encode(), b''
        if command == 'python3 --version':  # a worker booted from the image
            return (0, b'Python 3.12.3\n', b'') if done and user == 'builder' else (255, b'', b'denied')
        if command.startswith('python3 -c'):
            return (0, b'Python 3.12.3\ncargo 1.91.0\n', b'') if done and user == 'builder' else (255, b'', b'denied')
        if command == 'sudo -n true':
            return 1, b'', b'sudo: a password is required'
        raise AssertionError(command)

    # -- sts, ssm
    def op_get_caller_identity(self, args, profile):
        return {'Account': '111122223333'}

    def op_get_parameter(self, args, profile):
        arch = 'arm64' if '/arm64/' in self.arg(args, '--name') else 'amd64'
        return {'Parameter': {'Value': 'ami-base' + arch}}

    # -- network and types
    def op_describe_instance_types(self, args, profile):
        found = args[args.index('--instance-types') + 1:]
        return {'InstanceTypes': [{'InstanceType': t, 'ProcessorInfo': {'SupportedArchitectures': [
            'arm64' if re.match(r'[a-z]+[0-9]+g', t) else 'x86_64']}} for t in found]}

    def op_describe_vpcs(self, args, profile):
        return {'Vpcs': [{'VpcId': 'vpc-default'}] if self.default_vpc else []}

    def op_describe_subnets(self, args, profile):
        subnets = self.subnets
        if '--subnet-ids' in args:
            subnets = [s for s in subnets if s['SubnetId'] == self.arg(args, '--subnet-ids')]
        elif '--filters' in args:
            subnets = [s for s in subnets if s['VpcId'] in self.filters(args).get('vpc-id', [s['VpcId']])]
        return {'Subnets': subnets}

    def op_describe_route_tables(self, args, profile):
        vpcs = self.filters(args).get('vpc-id') if '--filters' in args else None
        return {'RouteTables': [t for t in self.route_tables if vpcs is None or t['VpcId'] in vpcs]}

    def op_describe_instance_type_offerings(self, args, profile):
        wanted = self.filters(args)['instance-type']
        # Zone a lacks every type, so the default subnet must come from zone b.
        return {'InstanceTypeOfferings': [{'InstanceType': t, 'Location': 'us-test-1b'} for t in wanted]}

    # -- CloudFormation
    def op_describe_stacks(self, args, profile):
        name = self.arg(args, '--stack-name')
        if name not in self.stacks:
            return fail('An error occurred (ValidationError): Stack with id %s does not exist' % name)
        s = self.stacks[name]
        return {'Stacks': [{'StackStatus': s['status'],
                            'Outputs': [{'OutputKey': k, 'OutputValue': v} for k, v in s['outputs'].items()]}]}

    def op_describe_stack_events(self, args, profile):
        return {'StackEvents': []}

    def op_deploy(self, args, profile):
        assert 'CAPABILITY_NAMED_IAM' in args and '--no-fail-on-empty-changeset' in args
        name = self.arg(args, '--stack-name')
        template = json.loads(Path(self.arg(args, '--template-file')).read_text())
        self.deploys.append(template)
        outputs = {'SecurityGroupId': 'sg-remote', 'AlertTopicArn': 'arn:aws:sns:us-test-1:111122223333:alerts'}
        for lid, res in template['Resources'].items():
            if res['Type'] == 'AWS::EC2::LaunchTemplate':
                data = json.dumps(res['Properties']['LaunchTemplateData'], sort_keys=True)
                lt = self.lt_ids.setdefault(lid, self.next_id('lt'))
                versions = self.lt_versions.setdefault(lt, [])
                if not versions or versions[-1] != data:
                    versions.append(data)
                outputs[lid + 'Id'] = lt
                outputs[lid + 'Version'] = str(len(versions))
        for lid in list(self.lt_ids):
            if lid not in template['Resources']:
                self.lt_versions.pop(self.lt_ids.pop(lid))
        if 'OperatorRole' in template['Resources']:
            outputs['OperatorRoleArn'] = 'arn:aws:iam::111122223333:role/remote-build-operator'
        topic = outputs['AlertTopicArn']
        email = template['Resources'].get('AlertEmail', {}).get('Properties', {}).get('Endpoint')
        kept = [s for s in self.subscriptions.get(topic, []) if s['Endpoint'] == email]
        self.subscriptions[topic] = kept or ([{'Protocol': 'email', 'Endpoint': email,
                                               'SubscriptionArn': 'PendingConfirmation'}] if email else [])
        new = name not in self.stacks or self.stacks[name]['status'] == 'REVIEW_IN_PROGRESS'
        self.stacks[name] = {'status': 'CREATE_COMPLETE' if new else 'UPDATE_COMPLETE', 'outputs': outputs,
                             'template': template}
        return 0, b'Successfully created/updated stack\n', b''

    def confirm_alert_email(self):
        for subs in self.subscriptions.values():
            for s in subs:
                s['SubscriptionArn'] = 'arn:aws:sns:us-test-1:111122223333:alerts:0b1c'

    # -- SNS
    def op_list_subscriptions_by_topic(self, args, profile):
        if not self.sns_readable:
            return fail('An error occurred (AuthorizationError): not authorized to perform SNS:ListSubscriptionsByTopic')
        return {'Subscriptions': self.subscriptions.get(self.arg(args, '--topic-arn'), [])}

    def op_delete_stack(self, args, profile):
        self.stacks.pop(self.arg(args, '--stack-name'))
        self.lt_ids.clear()
        self.lt_versions.clear()
        return {}

    def op_wait_stack_delete_complete(self, args, profile):
        return 0, b'', b''

    # -- key pairs and images
    def op_import_key_pair(self, args, profile):
        self.key_pairs.add(self.arg(args, '--key-name'))
        return {}

    def op_delete_key_pair(self, args, profile):
        self.key_pairs.discard(self.arg(args, '--key-name'))
        return {}

    def op_describe_key_pairs(self, args, profile):
        prefix = self.filters(args)['key-name'][0].rstrip('*')
        return {'KeyPairs': [{'KeyName': k} for k in sorted(self.key_pairs) if k.startswith(prefix)]}

    def op_describe_images(self, args, profile):
        def shown(image):  # tags as AWS returns them
            return dict(image, Tags=[{'Key': k, 'Value': v} for k, v in image['Tags'].items()])
        if '--image-ids' in args:
            ami = self.arg(args, '--image-ids')
            if ami.startswith('ami-base'):
                return {'Images': [{'ImageId': ami, 'RootDeviceName': '/dev/sda1'}]}
            return {'Images': [shown(self.images[ami])]} if ami in self.images else fail('InvalidAMIID.NotFound')
        f = self.filters(args)
        found = list(self.images.values())
        if 'image-id' in f:
            found = [i for i in found if i['ImageId'] in f['image-id']]
        if 'tag:remote-build:bake' in f:
            found = [i for i in found if i['Tags'].get('remote-build:bake') in f['tag:remote-build:bake']]
        return {'Images': [shown(i) for i in found]}

    def op_create_image(self, args, profile):
        ami = self.next_id('ami')
        tags = {t['Key']: t['Value'] for t in json.loads(self.arg(args, '--tag-specifications'))[0]['Tags']}
        self.images[ami] = {'ImageId': ami, 'State': 'available', 'RootDeviceName': '/dev/sda1', 'Tags': tags,
                            'BlockDeviceMappings': [{'DeviceName': '/dev/sda1', 'Ebs': {
                                'SnapshotId': self.next_id('snap'), 'DeleteOnTermination': True}}]}
        return {'ImageId': ami}

    def op_deregister_image(self, args, profile):
        self.images.pop(self.arg(args, '--image-id'))
        return {}

    def op_delete_snapshot(self, args, profile):
        snapshot = self.arg(args, '--snapshot-id')
        if snapshot not in self.snapshot_busy and snapshot not in self.snapshots_deleted:
            self.snapshot_busy.add(snapshot)  # the first attempt races the deregistration
            return fail('An error occurred (InvalidSnapshot.InUse): snapshot is in use by ami')
        self.snapshots_deleted.append(snapshot)
        return {}

    def op_wait_image_available(self, args, profile):
        return 0, b'', b''

    # -- instances
    def op_run_instances(self, args, profile):
        tags = {t['Key']: t['Value'] for t in json.loads(self.arg(args, '--tag-specifications'))[0]['Tags']}
        itype = self.arg(args, '--instance-type')
        if '--launch-template' in args:
            assert profile == 'remote-build'
            lt = json.loads(self.arg(args, '--launch-template'))
            if not self.allowed(lt, itype, tags):
                return fail('An error occurred (UnauthorizedOperation) when calling the RunInstances operation')
            if '--dry-run' in args:
                return fail('An error occurred (DryRunOperation) when calling the RunInstances operation: '
                            'Request would have succeeded, but DryRun flag is set.')
        else:
            assert profile == 'admin' and self.arg(args, '--key-name') in self.key_pairs
        instance = self.next_id('i')
        self.instances[instance] = {'InstanceId': instance, 'State': {'Name': 'running'}, 'Tags': tags,
                                    'PublicIpAddress': '198.51.100.%d' % (self.counter % 250),
                                    'PrivateIpAddress': '10.0.0.%d' % (self.counter % 250), 'polls': 0}
        if '--launch-template' in args:  # booted from a baked image
            self.provisioned.update({self.instances[instance]['PublicIpAddress'],
                                     self.instances[instance]['PrivateIpAddress']})
        return {'Instances': [self.instances[instance]]}

    def allowed(self, lt, itype, tags):
        """Evaluate the deployed operator policy the way IAM would for these three conditions."""
        template = next(iter(self.stacks.values()))['template']
        owner = template['Parameters']['Owner']['Default']
        statements = {s['Sid']: s for s in template['Resources']['OperatorRole']['Properties']['Policies'][0]['PolicyDocument']['Statement']}
        approved_templates = [self.lt_ids[re.search(r'\$\{(\w+)\}$', t['Fn::Sub']).group(1)]
                              for t in statements['LaunchOnlyFromApprovedTemplates']['Condition']['ArnEquals']['ec2:LaunchTemplate']]
        approved_types = statements['OnlyApprovedInstanceTypes']['Condition']['StringNotEquals']['ec2:InstanceType']
        required = statements['RequireOwnerTagAtLaunch']['Condition']['StringNotEquals']['aws:RequestTag/remote-build:owner']
        required = owner if required == {'Ref': 'Owner'} else required
        return (lt['LaunchTemplateId'] in approved_templates and itype in approved_types
                and tags.get('remote-build:owner') == required)

    def op_describe_instances(self, args, profile):
        if '--instance-ids' in args:
            found = [self.instances[self.arg(args, '--instance-ids')]]
            for i in found:  # the janitor runs between polls
                i['polls'] += 1
                expired = int(i['Tags'].get('remote-build:expires', '9999999999')) <= self.clock
                if self.janitor_works and expired and i['polls'] >= 2 and 'remote-build:owner' in i['Tags'] \
                        and i['State']['Name'] == 'running':
                    i['State']['Name'] = 'terminated'
                    i['StateReason'] = {'Code': self.termination_reason}
        else:
            f = self.filters(args)
            found = [i for i in self.instances.values()
                     if all((i['State']['Name'] if k == 'instance-state-name' else i['Tags'].get(k[4:])) in v
                            for k, v in f.items())]
        return {'Reservations': [{'Instances': found}]}

    def op_wait_instance_running(self, args, profile):
        return 0, b'', b''

    def op_wait_instance_stopped(self, args, profile):
        return 0, b'', b''

    def op_wait_instance_terminated(self, args, profile):
        for instance in args[args.index('--instance-ids') + 1:]:
            self.instances[instance]['State']['Name'] = 'terminated'
        return 0, b'', b''

    def op_get_console_output(self, args, profile):
        self.console_reads += 1
        return {'Output': CONSOLE if self.console_reads > 1 else 'still booting'}

    def op_stop_instances(self, args, profile):
        self.instances[self.arg(args, '--instance-ids')]['State']['Name'] = 'stopped'
        return {}

    def op_terminate_instances(self, args, profile):
        for instance in args[args.index('--instance-ids') + 1:]:
            self.instances[instance]['State']['Name'] = 'terminated'
        return {}

    # -- remote_build.call (setup's checks)
    def call(self, argv, data=None, timeout=60):
        if argv[0] == 'aws' and '--no-cli-pager' in argv:
            i = argv.index('--no-cli-pager')
            op, args = argv[i + 2], argv[i + 3:]
            if op == 'describe-launch-template-versions':
                lt, version = self.arg(args, '--launch-template-id'), int(self.arg(args, '--versions'))
                return json.dumps({'LaunchTemplateVersions': [
                    {'LaunchTemplateData': json.loads(self.lt_versions[lt][version - 1])}]}).encode()
        code, out, err = self(argv, data, timeout)
        rb.require(code == 0, 'Tool failed: ' + argv[0])
        return out


class Bootstrap(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.cloud = FakeCloud(self.root)
        self.aws_config = self.root / 'aws-config'
        self.aws_config.write_text('[default]\nregion = us-test-1\n\n[profile admin]\nregion = us-test-1\n')
        patch.dict(os.environ, {'AWS_CONFIG_FILE': str(self.aws_config)}).start()
        patch.object(b, 'execute', side_effect=self.cloud).start()
        patch.object(b, 'pause', side_effect=self.advance).start()
        patch.object(b, 'now', side_effect=lambda: self.cloud.clock).start()
        patch.object(b, 'operator_cidr', return_value='203.0.113.7/32').start()
        patch.object(rb, 'call', side_effect=self.cloud.call).start()
        self.addCleanup(patch.stopall)
        self.config = self.root / 'config' / 'config.json'

    def advance(self, seconds):
        self.cloud.clock += seconds

    def main(self, *args, owner='fixture-builds', code=0):
        common = ['--config', str(self.config), '--state', str(self.root / 'state')]
        extra = [] if args[0] == 'template' else [
            '--admin-profile', 'admin', '--known-hosts', str(self.root / 'ssh' / 'known'),
            '--identity', str(self.root / 'ssh' / 'id')]
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            result = b.main(common + [args[0], '--owner', owner] + extra + list(args[1:]))
        self.assertEqual(result, code, err.getvalue())
        return json.loads(out.getvalue() if code == 0 else err.getvalue().strip().splitlines()[-1])

    def apply(self, *args, **kw):
        return self.main('apply', '--image', 'arm64:c7g.xlarge,c7g.2xlarge', '--image', 'x86=amd64:c7i.xlarge',
                         *args, **kw)

    def builds(self):
        return [o for o in self.cloud.ops if o[0] == 'admin' and o[2] == 'run-instances']

    # ------------------------------------------------------------ the template and its parts

    def test_template_command_is_offline_and_well_formed(self):
        t = self.main('template', '--image', 'arm64:c7g.large', '--alert-email', 'ops@example.com')
        self.assertEqual(self.cloud.ops, [])
        self.assertIn('OperatorRole', t['Resources'])
        self.assertIn('AlertEmail', t['Resources'])
        data = t['Resources']['LaunchTemplatearm']['Properties']['LaunchTemplateData']
        # Nothing the client refuses, and every volume deletes on termination.
        self.assertFalse({'IamInstanceProfile', 'UserData', 'InstanceMarketOptions', 'InstanceRequirements',
                          'HibernationOptions', 'DisableApiTermination', 'InstanceType', 'KeyName'} & set(data))
        self.assertTrue(all(m['Ebs']['DeleteOnTermination'] for m in data['BlockDeviceMappings']))
        self.assertIn(Path(SCRIPTS / 'aws' / 'janitor.py').read_text(),
                      t['Resources']['Janitor']['Properties']['Code']['ZipFile'])

    def test_role_waits_for_an_image_and_policy_pins_templates_types_and_owner(self):
        bare = b.render('o', '203.0.113.7/32', 'vpc-1', 'subnet-1', [b.parse_image('arm64:c7g.large')], None)
        self.assertNotIn('OperatorRole', bare['Resources'])
        self.assertFalse(any(r['Type'] == 'AWS::EC2::LaunchTemplate' for r in bare['Resources'].values()))
        built = [dict(b.parse_image('arm64:c7g.large,c7g.xlarge'), ami='ami-1', root_device='/dev/sda1'),
                 dict(b.parse_image('amd64:c7i.large'), ami='ami-2', root_device='/dev/sda1')]
        policy = b.operator_policy(built)
        s = {x['Sid']: x for x in policy['Statement']}
        self.assertEqual(len(s['LaunchOnlyFromApprovedTemplates']['Condition']['ArnEquals']['ec2:LaunchTemplate']), 2)
        self.assertEqual(s['OnlyApprovedInstanceTypes']['Condition']['StringNotEquals']['ec2:InstanceType'],
                         ['c7g.large', 'c7g.xlarge', 'c7i.large'])
        self.assertEqual(s['TerminateOnlyOwnedWorkers']['Condition']['StringEquals'],
                         {'aws:ResourceTag/remote-build:owner': {'Ref': 'Owner'}})
        self.assertEqual(s['OnlyApprovedInstanceTypes']['Effect'], 'Deny')
        self.assertEqual(s['NoOverridingTemplateResources']['Condition'], {'Bool': {'ec2:IsLaunchTemplateResource': 'false'}})
        self.assertEqual(s['NoKeyPairs']['Effect'], 'Deny')
        group = b.render('o', '203.0.113.7/32', 'vpc-1', 'subnet-1', built, None)['Resources']['SecurityGroup']
        self.assertNotIn('GroupName', group['Properties'])  # a fixed name would block replacement

    def test_janitor_terminates_only_expired_or_unreadable(self):
        calls = []

        class Client:
            def get_paginator(self, name):
                return types.SimpleNamespace(paginate=lambda Filters: calls.append(Filters) or [{'Reservations': [
                    {'Instances': [{'InstanceId': 'i-old', 'Tags': [{'Key': 'remote-build:expires', 'Value': '1'}]},
                                   {'InstanceId': 'i-new', 'Tags': [{'Key': 'remote-build:expires', 'Value': '9999999999'}]},
                                   {'InstanceId': 'i-bad', 'Tags': [{'Key': 'remote-build:expires', 'Value': 'soon'}]},
                                   {'InstanceId': 'i-none'}]}]}])

            def terminate_instances(self, InstanceIds):
                calls.append(InstanceIds)

        fake = types.ModuleType('boto3')
        fake.client = lambda name: Client()
        with patch.dict(sys.modules, {'boto3': fake}), patch.dict(os.environ, {'OWNER': 'fixture'}):
            spec = importlib.util.spec_from_file_location('janitor', SCRIPTS / 'aws' / 'janitor.py')
            janitor = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(janitor)
            with contextlib.redirect_stdout(io.StringIO()):
                result = janitor.handler({}, None)
        self.assertEqual(result['terminated'], ['i-old', 'i-bad', 'i-none'])
        self.assertEqual(calls[0][0], {'Name': 'tag:remote-build:owner', 'Values': ['fixture']})
        self.assertEqual(calls[1], ['i-old', 'i-bad', 'i-none'])

    def test_image_specs(self):
        self.assertEqual(b.parse_image('arm64:c7g.large'), {'name': 'arm', 'arch': 'arm64', 'types': ['c7g.large']})
        self.assertEqual(b.parse_image('big=amd64:c7i.2xlarge,m7i.xlarge')['name'], 'big')
        for bad in ('c7g.large', 'arm64:', 'riscv:c7g.large', 'Big=arm64:c7g.large', 'a=arm64:c7g.large;rm'):
            with self.subTest(bad), self.assertRaises(b.Refused):
                b.parse_image(bad)

    def test_aws_config_sections_leave_other_lines_alone(self):
        text = '# mine\n[default]\nregion = x\n\n[profile remote-build]\nold = 1\n\n[profile other]\nk = v\n'
        out = b.set_section(text, '[profile remote-build]', ['role_arn = r'])
        self.assertIn('# mine\n[default]\nregion = x\n', out)
        self.assertIn('[profile other]\nk = v', out)
        self.assertNotIn('old = 1', out)
        self.assertTrue(out.endswith('[profile remote-build]\nrole_arn = r\n'))
        self.assertEqual(b.remove_section(out, '[profile remote-build]'),
                         '# mine\n[default]\nregion = x\n\n[profile other]\nk = v\n')

    # ------------------------------------------------------------ apply

    def test_apply_from_an_empty_account_reaches_a_ready_config(self):
        result = self.apply('--alert-email', 'ops@example.com')
        # Two deploys: the fixed pieces first, then templates and the role once images exist.
        self.assertEqual(len(self.cloud.deploys), 2)
        self.assertNotIn('OperatorRole', self.cloud.deploys[0]['Resources'])
        self.assertIn('OperatorRole', self.cloud.deploys[1]['Resources'])
        self.assertEqual(len(self.builds()), 2)
        self.assertEqual({i['State']['Name'] for i in self.cloud.instances.values()}, {'terminated'})
        self.assertEqual(self.cloud.key_pairs, set())
        self.assertEqual(len(self.cloud.images), 2)
        c = rb.parse_config(self.config)
        self.assertEqual(self.config.stat().st_mode & 0o777, 0o600)
        self.assertTrue(c['janitor_confirmed'])
        self.assertEqual(c['profile'], 'remote-build')
        self.assertEqual(sorted(c['launch_profiles']), ['arm', 'x86'])
        self.assertEqual(c['launch_profiles']['arm']['instance_types'], ['c7g.xlarge', 'c7g.2xlarge'])
        self.assertEqual(c['launch_profiles']['arm']['launch_version'], '1')
        self.assertEqual((c['max_workers'], c['ttl_minutes']), (2, 120))
        self.assertEqual(Path(c['known_hosts']).read_text(), '* %s\n* %s\n' % (HOST_KEY, HOST_KEY))
        self.assertEqual((self.root / 'ssh' / 'id').stat().st_mode & 0o777, 0o600)
        section = b.read_section(self.aws_config.read_text(), '[profile remote-build]')
        self.assertIn('source_profile = admin', section)
        self.assertIn('[profile admin]', self.aws_config.read_text())
        self.assertEqual(result['janitor_test'], 'passed')
        self.assertEqual(result['network']['subnet'], 'subnet-b')
        for name in ('arm', 'x86'):
            checks = result['policy_checks'][name]
            self.assertEqual(checks['approved type'], 'allowed')
            self.assertEqual(checks['other owner'], 'denied')
            self.assertTrue(any(k.startswith('unapproved type') and v == 'denied' for k, v in checks.items()))
        expected = {k: 'ok' for k in result['setup']}
        expected['repository'] = 'blocked'
        self.assertEqual(result['setup'], expected)
        self.assertIn('"launch_profile": "arm"', result['next'])

    def state_amis(self):
        state = json.loads((self.root / 'state' / 'bootstrap' / 'fixture-builds.json').read_text())
        return {name: p['ami'] for name, p in state['profiles'].items()}

    def test_the_summary_reports_what_apply_did_not_the_plan(self):
        result = self.apply('--alert-email', 'ops@example.com')
        amis = self.state_amis()
        self.assertEqual(result['stack'], 'remote-build-fixture-builds (UPDATE_COMPLETE)')
        self.assertEqual({n: p['image'] for n, p in result['launch_profiles'].items()},
                         {n: 'built ' + amis[n] for n in ('arm', 'x86')})
        self.assertEqual(result['launch_profiles']['arm']['launch_version'], '1')
        self.assertEqual((result['removed_profiles'], result['retired_images']), ([], []))
        self.assertNotIn('remove_profiles', result)
        self.assertEqual(result['alerts'], 'pending: confirm the subscription email AWS sent to ops@example.com')

        self.cloud.confirm_alert_email()
        result = self.apply()
        self.assertEqual({n: p['image'] for n, p in result['launch_profiles'].items()},
                         {n: 'reused ' + amis[n] for n in ('arm', 'x86')})
        self.assertEqual(result['alerts'], 'confirmed: alarms reach ops@example.com')

        result = self.apply('--rebake')
        rebuilt = self.state_amis()
        self.assertEqual({n: p['image'] for n, p in result['launch_profiles'].items()},
                         {n: 'built ' + rebuilt[n] for n in ('arm', 'x86')})
        self.assertEqual(sorted(result['retired_images']), sorted(amis.values()))
        self.assertEqual(result['launch_profiles']['x86']['launch_version'], '2')

        result = self.main('apply', '--image', 'arm64:c7g.xlarge,c7g.2xlarge')
        self.assertEqual(result['removed_profiles'], ['x86'])
        self.assertEqual(result['retired_images'], [rebuilt['x86']])
        self.assertEqual(list(result['launch_profiles']), ['arm'])

    def test_a_subscription_that_cannot_be_read_is_reported_as_unknown(self):
        self.cloud.sns_readable = False
        result = self.apply('--alert-email', 'ops@example.com')
        self.assertTrue(result['alerts'].startswith(
            'unknown: could not read the subscription; check that ops@example.com confirmed'), result['alerts'])
        self.assertEqual(result['janitor_test'], 'passed')

    def test_without_an_alert_email_the_summary_says_so_and_reads_no_subscription(self):
        self.assertTrue(self.apply()['alerts'].startswith('none: pass --alert-email'))
        self.assertNotIn('list-subscriptions-by-topic', {op for _, _, op in self.cloud.ops})

    def test_images_are_tagged_with_the_toolchains_builder_has(self):
        result = self.apply('--rust-toolchain', '1.97.0')
        amis = self.state_amis()
        for name in ('arm', 'x86'):
            self.assertEqual(self.cloud.images[amis[name]]['Tags']['remote-build:toolchains'], '1.97.0 stable')
            self.assertEqual(result['launch_profiles'][name]['toolchains'], ['1.97.0', 'stable'])
        self.assertEqual(result['bake_toolchains'], ['stable', '1.97.0'])
        # The client reads the tag back the way setup and up do.
        config = rb.parse_config(self.config)
        self.assertEqual(rb.template(dict(config, **config['launch_profiles']['arm']))['toolchains'], ['1.97.0', 'stable'])
        # A plain re-run remembers the list; a new one replaces it, so 1.97.0 can be dropped.
        self.assertEqual(self.main('plan')['bake_toolchains'], ['stable', '1.97.0'])
        self.assertEqual(self.main('plan', '--rust-toolchain', '1.98.0')['bake_toolchains'], ['stable', '1.98.0'])
        result = self.apply('--rebake', '--rust-toolchain', '1.98.0')
        self.assertEqual(result['launch_profiles']['arm']['toolchains'], ['1.98.0', 'stable'])
        self.assertEqual(self.cloud.images[self.state_amis()['arm']]['Tags']['remote-build:toolchains'], '1.98.0 stable')

    def test_an_image_without_rustup_is_not_tagged(self):
        self.cloud.no_rustup = True
        result = self.apply()
        self.assertTrue(all('remote-build:toolchains' not in i['Tags'] for i in self.cloud.images.values()))
        self.assertTrue(result['launch_profiles']['arm']['toolchains'].startswith('unknown: the image has no'))
        self.assertEqual(result['janitor_test'], 'passed')

    def test_rerun_reuses_images_and_follows_a_new_address(self):
        self.apply()
        first = rb.parse_config(self.config)
        builds = len(self.builds())
        b.operator_cidr.return_value = '198.51.100.9/32'
        result = self.apply()
        self.assertEqual(len(self.builds()), builds)
        self.assertEqual(result['janitor_test'], 'already passed')
        ingress = self.cloud.deploys[-1]['Resources']['SecurityGroup']['Properties']['SecurityGroupIngress']
        self.assertEqual(ingress[0]['CidrIp'], '198.51.100.9/32')
        self.assertEqual(rb.parse_config(self.config), first)

    def test_rebake_keeps_the_template_id_and_retires_the_old_image(self):
        self.apply()
        before = rb.parse_config(self.config)['launch_profiles']
        old = set(self.cloud.images)
        self.apply('--rebake')
        after = rb.parse_config(self.config)['launch_profiles']
        for name in ('arm', 'x86'):
            self.assertEqual(after[name]['launch_template'], before[name]['launch_template'])
            self.assertEqual(after[name]['launch_version'], '2')
        self.assertEqual(set(self.cloud.images) & old, set())
        self.assertEqual(len(self.cloud.images), 2)
        self.assertEqual(len(self.cloud.snapshots_deleted), 2)

    def test_rerun_keeps_private_addressing_disk_and_a_symlinked_aws_config(self):
        real = self.root / 'dotfiles-aws-config'
        real.write_text(self.aws_config.read_text())
        self.aws_config.unlink()
        self.aws_config.symlink_to(real)
        self.apply('--address', 'private', '--cidr', '10.8.0.0/16', '--disk-gb', '80')
        builds = len(self.builds())
        self.apply()
        self.assertEqual(len(self.builds()), builds)
        c = rb.parse_config(self.config)
        self.assertEqual(c['address_field'], 'PrivateIpAddress')
        data = self.cloud.deploys[-1]['Resources']['LaunchTemplatearm']['Properties']['LaunchTemplateData']
        self.assertFalse(data['NetworkInterfaces'][0]['AssociatePublicIpAddress'])
        ingress = self.cloud.deploys[-1]['Resources']['SecurityGroup']['Properties']['SecurityGroupIngress']
        self.assertEqual(ingress[0]['CidrIp'], '10.8.0.0/16')
        self.assertTrue(self.aws_config.is_symlink())
        self.assertIn('[profile remote-build]', real.read_text())

    def test_changing_types_needs_no_bake_and_dropping_a_profile_retires_it(self):
        self.apply()
        builds = len(self.builds())
        self.main('apply', '--image', 'arm64:c7g.large')
        c = rb.parse_config(self.config)
        self.assertEqual(list(c['launch_profiles']), ['arm'])
        self.assertEqual(c['launch_profiles']['arm']['instance_types'], ['c7g.large'])
        self.assertEqual(len(self.builds()), builds)
        self.assertEqual(len(self.cloud.images), 1)
        self.assertEqual(Path(c['known_hosts']).read_text(), '* %s\n' % HOST_KEY)

    def test_failed_provisioning_cleans_up_and_a_rerun_recovers(self):
        self.cloud.fail_provision = True
        error = self.apply(code=2)['error']
        self.assertIn('Provisioning failed', error)
        log = Path(re.search(r'see (\S+)', error).group(1))
        self.assertIn('provisioning broke', log.read_text())
        self.assertEqual({i['State']['Name'] for i in self.cloud.instances.values()}, {'terminated'})
        self.assertEqual(self.cloud.key_pairs, set())
        self.assertEqual(self.cloud.images, {})
        self.assertFalse(self.config.exists())
        self.cloud.fail_provision = False
        self.assertEqual(self.apply()['janitor_test'], 'passed')

    def test_keep_on_failure_leaves_the_build_machine_for_the_next_apply(self):
        self.cloud.fail_provision = True
        self.apply('--keep-on-failure', code=2)
        running = [i for i in self.cloud.instances.values() if i['State']['Name'] == 'running']
        self.assertEqual(len(running), 1)
        self.assertEqual(len(self.cloud.key_pairs), 1)
        self.cloud.fail_provision = False
        self.apply()
        self.assertEqual(running[0]['State']['Name'], 'terminated')
        self.assertEqual(self.cloud.key_pairs, set())

    def test_janitor_failure_leaves_the_declaration_false(self):
        self.cloud.janitor_works = False
        result = self.apply()
        self.assertEqual(result['janitor_test'], 'failed')
        self.assertFalse(rb.parse_config(self.config)['janitor_confirmed'])
        self.assertIn('/aws/lambda/remote-build-fixture-builds-janitor', result['next'])
        tests = [i for i in self.cloud.instances.values() if i['Tags'].get('remote-build:owner')]
        self.assertEqual([i['State']['Name'] for i in tests], ['terminated'])
        self.assertEqual(result['setup']['janitor'], 'fail')

    def test_termination_the_janitor_did_not_cause_is_not_a_pass(self):
        self.cloud.termination_reason = 'Server.InternalError'
        result = self.apply()
        self.assertEqual(result['janitor_test'], 'failed')
        self.assertFalse(rb.parse_config(self.config)['janitor_confirmed'])

    def test_a_worker_builder_cannot_log_in_to_fails_the_test(self):
        real = self.cloud.op_run_instances

        def unreachable(args, profile):
            result = real(args, profile)
            if '--launch-template' in args and '--dry-run' not in args:
                self.cloud.provisioned.clear()
            return result
        self.cloud.op_run_instances = unreachable
        result = self.apply()
        self.assertEqual(result['janitor_test'], 'login failed')
        self.assertIn('builder login', result['next'])
        self.assertFalse(rb.parse_config(self.config)['janitor_confirmed'])
        workers = [i for i in self.cloud.instances.values() if i['Tags'].get('remote-build:owner')]
        self.assertEqual([i['State']['Name'] for i in workers], ['terminated'])

    def test_a_stack_whose_first_change_set_failed_is_deployed_over(self):
        self.cloud.stacks['remote-build-fixture-builds'] = {'status': 'REVIEW_IN_PROGRESS', 'outputs': {}, 'template': {}}
        self.assertEqual(self.apply()['janitor_test'], 'passed')

    def test_refuses_another_owners_config_or_an_unmanaged_profile_before_any_change(self):
        self.config.parent.mkdir()
        self.config.write_text(json.dumps({'owner': 'someone-else', 'profile': 'remote-build'}))
        self.assertIn('--replace-config', self.apply(code=2)['error'])
        self.config.unlink()
        self.aws_config.write_text(self.aws_config.read_text() + '\n[profile remote-build]\naws_access_key_id = x\n')
        self.assertIn('--replace-profile', self.apply(code=2)['error'])
        self.assertEqual(self.cloud.deploys, [])
        self.assertFalse((self.root / 'ssh' / 'id').exists())

    def test_replace_config_backs_up_the_old_one(self):
        self.config.parent.mkdir()
        self.config.write_text(json.dumps({'owner': 'someone-else', 'profile': 'remote-build'}))
        self.apply('--replace-config')
        backups = list(self.config.parent.glob('config.json.bak-*'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(json.loads(backups[0].read_text())['owner'], 'someone-else')

    def test_running_workers_block_a_rebake(self):
        self.apply()
        self.cloud.instances['i-worker'] = {'InstanceId': 'i-worker', 'State': {'Name': 'running'},
                                            'Tags': {'remote-build:owner': 'fixture-builds'}, 'polls': 0}
        self.assertIn('/remote-build:down', self.apply('--rebake', code=2)['error'])
        self.apply()  # nothing changes, so a refresh is fine

    def test_plan_only_reads(self):
        result = self.main('plan', '--image', 'arm64:c7g.xlarge')
        self.assertTrue({op for _, _, op in self.cloud.ops} <= READ_ONLY, self.cloud.ops)
        self.assertEqual(result['launch_profiles']['arm']['image'], 'bake')
        self.assertEqual(result['janitor_test'], 'will run')
        self.assertFalse((self.root / 'ssh' / 'id').exists())
        self.assertFalse((self.root / 'state').exists())

    def legacy_network(self):
        """No default VPC: one older VPC whose public route table serves two subnets, one in a zone
        without the types, and whose main table (the private subnet's) has no internet route."""
        self.cloud.default_vpc = False
        self.cloud.subnets = [
            {'SubnetId': 'subnet-pub-b', 'VpcId': 'vpc-legacy', 'AvailabilityZone': 'us-test-1b'},
            {'SubnetId': 'subnet-pub-a', 'VpcId': 'vpc-legacy', 'AvailabilityZone': 'us-test-1a'},
            {'SubnetId': 'subnet-priv-b', 'VpcId': 'vpc-legacy', 'AvailabilityZone': 'us-test-1b'}]
        self.cloud.route_tables = [
            {'RouteTableId': 'rtb-main', 'VpcId': 'vpc-legacy', 'Associations': [{'Main': True}],
             'Routes': [{'DestinationCidrBlock': '10.0.0.0/16', 'GatewayId': 'local', 'State': 'active'}]},
            {'RouteTableId': 'rtb-public', 'VpcId': 'vpc-legacy',
             'Associations': [{'SubnetId': 'subnet-pub-b'}, {'SubnetId': 'subnet-pub-a'}],
             'Routes': [{'DestinationCidrBlock': '0.0.0.0/0', 'GatewayId': 'igw-legacy', 'State': 'active'}]}]

    def test_without_a_default_vpc_plan_names_the_subnets_that_would_work(self):
        self.legacy_network()
        error = self.main('plan', '--image', 'arm64:c7g.xlarge', code=2)['error']
        self.assertIn('No default VPC in us-test-1. Subnets that would work: subnet-pub-b (vpc-legacy, us-test-1b); '
                      'pass one with --subnet', error)
        self.assertNotIn('subnet-pub-a', error)  # its zone lacks the type
        self.assertNotIn('subnet-priv-b', error)  # no internet route
        self.assertTrue({op for _, _, op in self.cloud.ops} <= READ_ONLY, self.cloud.ops)
        self.assertEqual(self.main('plan', '--image', 'arm64:c7g.xlarge', '--subnet', 'subnet-pub-b')['network']['subnet'],
                         'subnet-pub-b')
        # With private addressing, an internet route isn't needed.
        error = self.main('plan', '--image', 'arm64:c7g.xlarge', '--address', 'private', '--cidr', '10.8.0.0/16',
                          code=2)['error']
        self.assertIn('subnet-priv-b (vpc-legacy, us-test-1b), subnet-pub-b (vpc-legacy, us-test-1b)', error)
        self.cloud.route_tables = self.cloud.route_tables[:1]
        self.assertIn('No subnet has a route to an internet gateway in a zone that offers every type (c7g.xlarge)',
                      self.main('plan', '--image', 'arm64:c7g.xlarge', code=2)['error'])

    def test_a_subnet_that_cannot_work_is_refused_before_any_change(self):
        self.legacy_network()
        error = self.apply('--subnet', 'subnet-priv-b', code=2)['error']
        self.assertIn('Subnet subnet-priv-b has no route to an internet gateway', error)
        self.assertIn('Subnet subnet-pub-a is in us-test-1a, which does not offer every type',
                      self.apply('--subnet', 'subnet-pub-a', code=2)['error'])
        self.assertEqual((self.cloud.deploys, self.builds()), ([], []))
        self.assertFalse((self.root / 'ssh' / 'id').exists())
        # Private addressing accepts the subnet without an internet route.
        self.assertEqual(self.apply('--subnet', 'subnet-priv-b', '--address', 'private', '--cidr', '10.0.0.0/16')
                         ['network']['subnet'], 'subnet-priv-b')

    def test_a_remembered_public_subnet_that_lost_its_route_is_refused(self):
        self.legacy_network()
        self.apply('--subnet', 'subnet-pub-b')
        self.cloud.route_tables[1]['Routes'] = []
        deploys = len(self.cloud.deploys)
        self.assertIn('Subnet subnet-pub-b has no route to an internet gateway', self.apply(code=2)['error'])
        self.assertEqual(len(self.cloud.deploys), deploys)

    def test_type_that_cannot_run_the_architecture_is_refused(self):
        self.assertIn('does not run arm64', self.main('plan', '--image', 'arm64:c7i.large', code=2)['error'])

    # ------------------------------------------------------------ teardown

    def test_teardown_removes_everything_it_made_and_nothing_else(self):
        self.apply()
        neighbour = self.root / 'state' / 'bootstrap' / 'fixture-builds-two.json'
        neighbour.write_text('{}')
        self.assertIn('--confirm fixture-builds', self.main('teardown', code=2)['error'])
        result = self.main('teardown', '--confirm', 'fixture-builds')
        self.assertEqual(self.cloud.stacks, {})
        self.assertEqual(self.cloud.images, {})
        self.assertEqual(len(self.cloud.snapshots_deleted), 2)
        self.assertFalse(self.config.exists())
        self.assertFalse((self.root / 'ssh' / 'known').exists())
        self.assertTrue((self.root / 'ssh' / 'id').exists())
        text = self.aws_config.read_text()
        self.assertNotIn('remote-build', text)
        self.assertIn('[profile admin]', text)
        self.assertEqual(sorted(p.name for p in (self.root / 'state' / 'bootstrap').iterdir()), [neighbour.name])
        self.assertIn('stack remote-build-fixture-builds', result['removed'])

    def test_teardown_refuses_while_workers_run(self):
        self.apply()
        self.cloud.instances['i-worker'] = {'InstanceId': 'i-worker', 'State': {'Name': 'running'},
                                            'Tags': {'remote-build:owner': 'fixture-builds'}, 'polls': 0}
        self.assertIn('i-worker', self.main('teardown', '--confirm', 'fixture-builds', code=2)['error'])
        self.assertTrue(self.cloud.stacks)
        self.cloud.instances['i-worker']['State']['Name'] = 'shutting-down'
        self.main('teardown', '--confirm', 'fixture-builds')
        waits = [o for o in self.cloud.ops if o[2] == 'wait-instance-terminated']
        self.assertEqual(len(waits), 1)
        self.assertLess(self.cloud.ops.index(waits[0]),
                        self.cloud.ops.index(next(o for o in self.cloud.ops if o[2] == 'delete-stack')))


if __name__ == '__main__':
    unittest.main()
