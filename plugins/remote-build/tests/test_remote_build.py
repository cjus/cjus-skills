#!/usr/bin/env python3
"""Offline unit/provider tests. Never invokes AWS or a real SSH connection."""
import base64
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
import time
import unittest
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parents[1] / 'scripts'
spec = importlib.util.spec_from_file_location('remote_build', SCRIPTS / 'remote_build.py')
r = importlib.util.module_from_spec(spec)
spec.loader.exec_module(r)


class Lifecycle(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.state = self.root / 'state'; self.state.mkdir()
        self.c = dict(version=1, provider='aws', profile='test', region='test-region', owner='fixture',
                      launch_template='lt-abc', launch_version='1', instance_type='small',
                      allowed_instance_types=['small'], ttl_minutes=10, janitor_confirmed=True,
                      ssh_user='builder', known_hosts=str(self.root / 'hosts'),
                      identity_file=str(self.root / 'key'), address_field='PrivateIpAddress',
                      max_snapshot_bytes=1048576, max_jobs=2, cache_retention='session')
        (self.root / 'hosts').touch(); (self.root / 'key').touch()
        self.items = []; self.launches = 0; self.terminations = 0; self.fail_launch = False
        self.account = 'fixture-account'
        self.mock = patch.object(r, 'aws', side_effect=self.aws).start()
        self.addCleanup(patch.stopall)

    def aws(self, c, service, op, *args):
        if op == 'get-caller-identity': return {'Account': self.account}
        if op == 'describe-launch-template-versions':
            return {'LaunchTemplateVersions': [{'LaunchTemplateData': {'ImageId': 'ami-fixture'}}]}
        if op == 'describe-images':
            return {'Images': [{'BlockDeviceMappings': [{'DeviceName': '/dev/root', 'Ebs': {'DeleteOnTermination': True}}]}]}
        if op == 'describe-instances': return {'Reservations': [{'Instances': self.items}]}
        if op == 'run-instances':
            self.launches += 1
            token = args[args.index('--client-token') + 1]
            self.items = [{'InstanceId': 'i-fixture', 'ClientToken': token, 'State': {'Name': 'running'},
                           'PrivateIpAddress': '192.0.2.1', 'Tags': [
                               {'Key': 'remote-build:owner', 'Value': 'fixture'},
                               {'Key': 'remote-build:session', 'Value': token}]}]
            if self.fail_launch: raise r.Refused('timeout')
            return {'Instances': self.items}
        if op == 'terminate-instances':
            self.terminations += 1
            self.items[0]['State']['Name'] = 'terminated'
            return {}
        raise AssertionError(op)

    def test_launch_requires_authorization(self):
        with self.assertRaises(r.Refused): r.up(self.c, self.state, False)
        self.assertEqual(self.launches, 0)

    def test_uncertain_creation_reconciles_without_duplicate(self):
        self.fail_launch = True
        with self.assertRaises(r.Refused): r.up(self.c, self.state, True)
        self.assertTrue((self.state / 'session.json').exists())
        self.assertEqual(r.up(self.c, self.state, True)['state'], 'running')
        self.assertEqual(self.launches, 1)

    def test_absent_after_uncertain_creation_stays_blocked(self):
        self.fail_launch = True
        with self.assertRaises(r.Refused): r.up(self.c, self.state, True)
        self.items = []
        with self.assertRaises(r.Refused): r.up(self.c, self.state, True)
        self.assertEqual(self.launches, 1)

    def test_auth_failure_prevents_launch(self):
        with patch.object(r, 'identity', side_effect=r.Refused('auth')):
            with self.assertRaises(r.Refused): r.up(self.c, self.state, True)
        self.assertEqual(self.launches, 0)
        self.assertFalse((self.state / 'session.json').exists())

    def test_existing_worker_prevents_launch(self):
        self.items = [{}]
        with self.assertRaises(r.Refused): r.up(self.c, self.state, True)
        self.assertEqual(self.launches, 0)

    def test_teardown_ownership_and_idempotence(self):
        r.up(self.c, self.state, True)
        self.items[0]['Tags'][0]['Value'] = 'other'
        with self.assertRaises(r.Refused): r.down(self.c, self.state)
        self.assertEqual(self.terminations, 0)
        self.items[0]['Tags'][0]['Value'] = 'fixture'
        self.assertEqual(r.down(self.c, self.state)['state'], 'termination-requested')
        self.assertEqual(r.down(self.c, self.state)['state'], 'terminated')
        self.assertEqual(r.down(self.c, self.state)['state'], 'absent')
        self.assertEqual(self.terminations, 1)

    def test_account_and_config_change_refused(self):
        r.up(self.c, self.state, True)
        self.account = 'other'
        with self.assertRaises(r.Refused): r.down(self.c, self.state)
        self.account = 'fixture-account'
        self.c['region'] = 'elsewhere'
        with self.assertRaises(r.Refused): r.down(self.c, self.state)

    def test_limits_and_expiry_attestation(self):
        for key, bad in [('ttl_minutes', 481), ('max_jobs', 21), ('janitor_confirmed', False),
                         ('launch_version', '$Latest'), ('cache_retention', 'forever'), ('instance_type', 'large')]:
            c = dict(self.c); c[key] = bad
            path = self.root / 'config.json'; path.write_text(json.dumps(c))
            with self.subTest(key=key), self.assertRaises(r.Refused): r.configuration(path)

    def project(self):
        project = self.root / 'project'; project.mkdir()
        subprocess.run(['git', 'init', '-q', str(project)], check=True)
        (project / 'main.rs').write_text('fn main() {}')
        subprocess.run(['git', '-C', str(project), 'add', 'main.rs'], check=True)
        return project

    def test_snapshot_dirty_untracked_deletions_and_exclusions(self):
        project = self.project()
        (project / 'main.rs').write_text('fn main() { println!("changed"); }')
        (project / 'extra.rs').write_text('// untracked')
        for name in ['.env', '.env.production', 'private.pem', '.aws/credentials', '.codex/state', 'target/out']:
            f = project / name; f.parent.mkdir(parents=True, exist_ok=True); f.write_text('secret')
        result = r.snapshot(project, self.state, 1048576)
        self.assertEqual([e['path'] for e in result['files']], ['extra.rs', 'main.rs'])
        self.assertEqual(result['snapshot'], r.snapshot(project, self.state, 1048576)['snapshot'])
        (project / 'main.rs').unlink()
        self.assertNotEqual(result['snapshot'], r.snapshot(project, self.state, 1048576)['snapshot'])

    def test_snapshot_rejects_symlinks_hardlinks_secrets_and_size(self):
        project = self.project()
        link = project / 'leak'; link.symlink_to(self.root / 'key')
        with self.assertRaises(r.Refused): r.snapshot(project, self.state, 1048576)
        link.unlink(); os.link(project / 'main.rs', link)
        with self.assertRaises(r.Refused): r.snapshot(project, self.state, 1048576)
        link.unlink()
        (project / 'main.rs').write_text('-----BEGIN PRIVATE KEY-----')
        with self.assertRaises(r.Refused): r.snapshot(project, self.state, 1048576)
        (project / 'main.rs').write_text('safe')
        with self.assertRaises(r.Refused): r.snapshot(project, self.state, 1)

    def test_run_persists_job_before_disconnect_and_checks_source(self):
        project = self.project(); snap = r.snapshot(project, self.state, 1048576)['snapshot']
        r.up(self.c, self.state, True)
        with patch.object(r, 'remote', side_effect=r.Refused('disconnected')):
            with self.assertRaises(r.Refused): r.run(self.c, self.state, snap, ['false'], True)
        jobs = r.load(self.state / 'session.json')['jobs']; self.assertEqual(len(jobs), 1)
        job = next(iter(jobs))
        with patch.object(r, 'remote', return_value={'job': job, 'snapshot': 'wrong'}):
            with self.assertRaises(r.Refused): r.status(self.c, self.state, job)
        with patch.object(r, 'remote', return_value={'job': job, 'snapshot': snap, 'exit_code': 7, 'log': 'private'}):
            result = r.status(self.c, self.state, job)
            self.assertEqual(result['exit_code'], 7); self.assertNotIn('log', result)
            self.assertEqual(r.load(self.state / 'results' / (job + '.json'))['log'], 'private')

    def test_unresolved_submission_and_expired_session_block_runs(self):
        snap = r.snapshot(self.project(), self.state, 1048576)['snapshot']
        r.up(self.c, self.state, True)
        with patch.object(r, 'remote', side_effect=r.Refused('disconnect')) as remote:
            with self.assertRaises(r.Refused): r.run(self.c, self.state, snap, ['true'], True)
            with self.assertRaises(r.Refused): r.run(self.c, self.state, snap, ['true'], True)
            self.assertEqual(remote.call_count, 1)
        s = r.load(self.state / 'session.json'); s.pop('pending_job'); s['expires'] = 0
        r.write(self.state / 'session.json', s)
        with self.assertRaises(r.Refused): r.run(self.c, self.state, snap, ['true'], True)

    def test_retained_volume_refused_before_creation(self):
        original = self.aws
        def retained(c, service, op, *args):
            if op == 'describe-images':
                return {'Images': [{'BlockDeviceMappings': [{'DeviceName': '/dev/root', 'Ebs': {'DeleteOnTermination': False}}]}]}
            return original(c, service, op, *args)
        with patch.object(r, 'aws', side_effect=retained):
            with self.assertRaises(r.Refused): r.up(self.c, self.state, True)
        self.assertEqual(self.launches, 0)

    def test_missing_and_broken_dependency_stop_setup(self):
        with patch.object(r.shutil, 'which', return_value=None):
            with self.assertRaises(r.Refused): r.prerequisites()
        with patch.object(r.shutil, 'which', return_value='fixture'), patch.object(r, 'call', side_effect=r.Refused('broken')):
            with self.assertRaises(r.Refused): r.prerequisites()

    def test_ssh_never_weakens_host_verification(self):
        r.up(self.c, self.state, True); s = r.load(self.state / 'session.json')
        with patch.object(r, 'call', return_value=b'{}') as mock:
            r.remote(self.c, s, self.items[0], {'action': 'status', 'job': 'test'})
            argv = mock.call_args[0][0]
            self.assertIn('StrictHostKeyChecking=yes', argv)
            self.assertIn('ForwardAgent=no', argv)
            self.assertNotIn('StrictHostKeyChecking=no', argv)

    def test_subprocess_failure_is_redacted(self):
        with patch.object(r.subprocess, 'run', return_value=subprocess.CompletedProcess([], 1, b'', b'private secret')):
            with self.assertRaisesRegex(r.Refused, '^Tool failed: fake$'): r.call(['fake'])


class Worker(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.source = (SCRIPTS / 'worker.py').read_text()
        self.bootstrap = 'SOURCE=' + repr(self.source) + ';exec(compile(SOURCE,"worker","exec"))'
        self.session = 'a' * 36; self.job = 'b' * 36
        data = io.BytesIO()
        with tarfile.open(fileobj=data, mode='w') as tar:
            member = tarfile.TarInfo('example.txt'); content = b'fixture'; member.size = len(content)
            tar.addfile(member, io.BytesIO(content))
        self.archive = data.getvalue()

    def request(self, **values):
        payload = dict(session=self.session, job=self.job, **values)
        result = subprocess.run([sys.executable, '-c', self.bootstrap], input=json.dumps(payload).encode(),
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                env=dict(os.environ, HOME=str(self.home)), timeout=5)
        return result.returncode, json.loads(result.stdout)

    def test_durable_exit_and_log_after_client_disconnect(self):
        code, result = self.request(action='run', snapshot=r.digest(self.archive),
            archive=base64.b64encode(self.archive).decode(),
            argv=[sys.executable, '-c', 'import time;time.sleep(.2);print("result");raise SystemExit(7)'],
            expires=time.time()+10, max_jobs=2)
        self.assertEqual(code, 0)
        for _ in range(30):
            code, result = self.request(action='status')
            if result['state'] == 'finished': break
            time.sleep(.05)
        self.assertEqual(result['exit_code'], 7)
        self.assertEqual(result['log'], 'result\n')
        self.assertEqual(result['snapshot'], r.digest(self.archive))

    def test_worker_caps_log_and_stops_at_expiry(self):
        code, _ = self.request(action='run', snapshot=r.digest(self.archive),
            archive=base64.b64encode(self.archive).decode(),
            argv=[sys.executable, '-c', 'import sys,time;sys.stdout.write("x"*1100000);sys.stdout.flush();time.sleep(10)'],
            expires=time.time()+1, max_jobs=1)
        self.assertEqual(code, 0)
        for _ in range(50):
            _, result = self.request(action='status')
            if result['state'] == 'finished': break
            time.sleep(.05)
        self.assertTrue(result['timed_out'])
        self.assertTrue(result['log_truncated'])
        self.assertEqual(len(result['log']), 1048576)
        self.assertNotEqual(result['exit_code'], 0)

    def test_rejects_mismatch_and_archive_traversal(self):
        code, _ = self.request(action='run', snapshot='wrong', archive=base64.b64encode(self.archive).decode(),
                               argv=['true'], expires=time.time()+5, max_jobs=1)
        self.assertEqual(code, 2)
        data = io.BytesIO()
        with tarfile.open(fileobj=data, mode='w') as tar:
            item = tarfile.TarInfo('../escape'); item.size=1; tar.addfile(item, io.BytesIO(b'x'))
        data = data.getvalue()
        code, _ = self.request(action='run', snapshot=r.digest(data), archive=base64.b64encode(data).decode(),
                               argv=['true'], expires=time.time()+5, max_jobs=1)
        self.assertEqual(code, 2)
        self.assertFalse((self.home / '.cache/remote-build' / self.session / 'escape').exists())


class CLI(unittest.TestCase):
    setUp = Lifecycle.setUp
    aws = Lifecycle.aws
    project = Lifecycle.project
    def test_cli_fake_aws_ssh_round_trip(self):
        binaries = self.root / 'bin'; binaries.mkdir()
        fixture = Path(__file__).with_name('fake_tools.py').read_text()
        for name in ('aws', 'ssh'):
            tool = binaries / name
            tool.write_text('#!' + sys.executable + '\n' + fixture); tool.chmod(0o755)
        config = self.root / 'config.json'; config.write_text(json.dumps(self.c))
        home = self.root / 'worker'; home.mkdir()
        env = dict(os.environ, PATH=str(binaries) + os.pathsep + os.environ['PATH'],
                   FAKE_WORKER_HOME=str(home), FAKE_AWS_STATE=str(self.root / 'aws.json'))
        def invoke(*args):
            proc = subprocess.run([sys.executable, str(SCRIPTS / 'remote_build.py'),
                '--config', str(config), '--state', str(self.state), *args], env=env,
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=10)
            self.assertEqual(proc.returncode, 0, proc.stderr.decode())
            return json.loads(proc.stdout)
        self.assertEqual(invoke('setup')['version'], 1)
        self.assertEqual(invoke('up', '--approve-cost')['state'], 'running')
        snap = invoke('snapshot', str(self.project()))['snapshot']
        job = invoke('run', '--snapshot', snap, '--approve-upload', '--', sys.executable,
                     '-c', 'print("offline integration");raise SystemExit(3)')['job']
        for _ in range(30):
            result = invoke('status', '--job', job)
            if result['state'] == 'finished': break
            time.sleep(.05)
        self.assertEqual(result['exit_code'], 3)
        self.assertEqual(result['snapshot'], snap)
        self.assertIn('offline integration', r.load(self.state / 'results' / (job + '.json'))['log'])
        self.assertEqual(invoke('down')['state'], 'termination-requested')
        self.assertEqual(invoke('down')['state'], 'terminated')
        self.assertEqual(invoke('down')['state'], 'absent')


if __name__ == '__main__':
    unittest.main()
