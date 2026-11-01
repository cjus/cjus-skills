"""Executable fixture for CLI integration. Never contacts a network service."""
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys

name = Path(sys.argv[0]).name
args = sys.argv[1:]
if args in (['--version'], ['-V']):
    print('offline fixture')
    sys.exit(0)
if name == 'ssh':
    # Simulate a connection refused before anything reaches the worker (exit 255, like ssh).
    fail_once = os.environ.get('FAKE_SSH_FAIL_ONCE')
    if fail_once and Path(fail_once).exists():
        Path(fail_once).unlink()
        sys.exit(255)
    env = dict(os.environ, HOME=os.environ['FAKE_WORKER_HOME'])
    # The production SSH command is parsed as argv, never run by a fixture shell.
    argv = shlex.split(args[-1])
    argv[0] = sys.executable
    sys.exit(subprocess.call(argv, env=env))
if name != 'aws':
    raise SystemExit('Unexpected fake tool')
state = Path(os.environ['FAKE_AWS_STATE'])
items = json.loads(state.read_text()) if state.exists() else []
service = args[args.index('--no-cli-pager') + 1]
op = args[args.index('--no-cli-pager') + 2]
if os.environ.get('FAKE_AWS_FAIL') == op:
    sys.exit(254)
if op == 'get-caller-identity':
    result = {'Account': 'fixture-account'}
elif op == 'describe-launch-template-versions':
    result = {'LaunchTemplateVersions': [{'LaunchTemplateData': {'ImageId': 'ami-fixture'}}]}
elif op == 'describe-images':
    result = {'Images': [{'BlockDeviceMappings': [{'DeviceName': '/dev/root', 'Ebs': {'DeleteOnTermination': True}}]}]}
    if 'FAKE_IMAGE_TOOLCHAINS' in os.environ:
        result['Images'][0]['Tags'] = [{'Key': 'remote-build:toolchains', 'Value': os.environ['FAKE_IMAGE_TOOLCHAINS']}]
elif op == 'describe-instances':
    def matches(item, spec):
        key, values = spec[len('Name='):].split(',Values=')
        values = values.split(',')
        tags = {t['Key']: t['Value'] for t in item['Tags']}
        if key == 'client-token': return item['ClientToken'] in values
        if key == 'instance-state-name': return item['State']['Name'] in values
        if key.startswith('tag:'): return tags.get(key[4:]) in values
        raise SystemExit('Unexpected fake filter: ' + key)
    filters = args[args.index('--filters') + 1:]
    result = {'Reservations': [{'Instances': [i for i in items if all(matches(i, f) for f in filters)]}]}
elif op == 'run-instances':
    token = args[args.index('--client-token') + 1]
    assert all(i['ClientToken'] != token for i in items), 'Duplicate launch'
    assert args[args.index('--count') + 1] == '1'
    assert args[args.index('--metadata-options') + 1] == 'HttpEndpoint=disabled'
    item = {'InstanceId': 'i-fixture%d' % len(items), 'ClientToken': token, 'State': {'Name': 'running'},
            'PrivateIpAddress': '192.0.2.1', 'InstanceType': args[args.index('--instance-type') + 1],
            'LaunchTemplate': json.loads(args[args.index('--launch-template') + 1]),
            'Tags': json.loads(args[args.index('--tag-specifications') + 1])[0]['Tags']}
    items.append(item)
    state.write_text(json.dumps(items))
    result = {'Instances': [item]}
elif op == 'terminate-instances':
    target = args[args.index('--instance-ids') + 1]
    [item] = [i for i in items if i['InstanceId'] == target]
    item['State']['Name'] = 'terminated'
    state.write_text(json.dumps(items))
    result = {}
else:
    raise SystemExit('Unexpected fake AWS operation: ' + op)
print(json.dumps(result))
