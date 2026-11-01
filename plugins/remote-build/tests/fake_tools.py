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
if op == 'get-caller-identity':
    result = {'Account': 'fixture-account'}
elif op == 'describe-launch-template-versions':
    result = {'LaunchTemplateVersions': [{'LaunchTemplateData': {'ImageId': 'ami-fixture'}}]}
elif op == 'describe-images':
    result = {'Images': [{'BlockDeviceMappings': [{'DeviceName': '/dev/root', 'Ebs': {'DeleteOnTermination': True}}]}]}
elif op == 'describe-instances':
    result = {'Reservations': [{'Instances': items}]}
elif op == 'run-instances':
    token = args[args.index('--client-token') + 1]
    assert not items, 'Duplicate launch'
    assert args[args.index('--count') + 1] == '1'
    assert args[args.index('--metadata-options') + 1] == 'HttpEndpoint=disabled'
    items = [{'InstanceId': 'i-fixture', 'ClientToken': token, 'State': {'Name': 'running'},
              'PrivateIpAddress': '192.0.2.1',
              'Tags': json.loads(args[args.index('--tag-specifications') + 1])[0]['Tags']}]
    state.write_text(json.dumps(items))
    result = {'Instances': items}
elif op == 'terminate-instances':
    assert args[args.index('--instance-ids') + 1] == items[0]['InstanceId']
    items[0]['State']['Name'] = 'terminated'
    state.write_text(json.dumps(items))
    result = {}
else:
    raise SystemExit('Unexpected fake AWS operation: ' + op)
print(json.dumps(result))
