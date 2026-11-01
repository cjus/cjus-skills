#!/usr/bin/env python3
"""Offline unit/provider tests. Never invokes AWS or a real SSH connection."""
import base64
import importlib.util
import io
import json
import os
import re
import shutil
import shlex
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
        self.g = dict(version=2, provider='aws', profile='test', region='test-region', owner='fixture',
                      launch_profiles={
                          'x86': dict(launch_template='lt-abc', launch_version='1', instance_types=['small', 'medium']),
                          'arm': dict(launch_template='lt-def', launch_version='2', instance_types=['graviton'])},
                      max_workers=2, ttl_minutes=10, janitor_confirmed=True,
                      ssh_user='builder', known_hosts=str(self.root / 'hosts'),
                      identity_file=str(self.root / 'key'), address_field='PrivateIpAddress',
                      max_snapshot_bytes=1048576, max_jobs=2, cache_retention='session')
        (self.root / 'hosts').write_text('* ssh-ed25519 AAAAfixture\n'); (self.root / 'key').touch()
        (self.root / 'key').chmod(0o600)
        self.repo = self.repository('repo', 'x86', 'small')
        self.c = r.selection(self.g, self.repo)
        self.items = []; self.launches = 0; self.terminations = 0; self.fail_launch = False
        self.account = 'fixture-account'
        self.image_toolchains = None  # the image's remote-build:toolchains tag, when it has one
        self.mock = patch.object(r, 'aws', side_effect=self.aws).start()
        self.addCleanup(patch.stopall)

    def aws(self, c, service, op, *args):
        if op == 'get-caller-identity': return {'Account': self.account}
        if op == 'describe-launch-template-versions':
            return {'LaunchTemplateVersions': [{'LaunchTemplateData': {'ImageId': 'ami-fixture'}}]}
        if op == 'describe-images':
            image = {'BlockDeviceMappings': [{'DeviceName': '/dev/root', 'Ebs': {'DeleteOnTermination': True}}]}
            if self.image_toolchains is not None:
                image['Tags'] = [{'Key': 'remote-build:bake', 'Value': 'fixture'},
                                 {'Key': r.TOOLCHAIN_TAG, 'Value': self.image_toolchains}]
            return {'Images': [image]}
        if op == 'describe-instances': return {'Reservations': [{'Instances': self.items}]}
        if op == 'run-instances':
            self.launches += 1
            token = args[args.index('--client-token') + 1]
            self.items = [{'InstanceId': 'i-fixture', 'ClientToken': token, 'State': {'Name': 'running'},
                           'PrivateIpAddress': '192.0.2.1',
                           'Tags': json.loads(args[args.index('--tag-specifications') + 1])[0]['Tags']}]
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

    def repository(self, name, profile, instance_type):
        repo = self.root / name; repo.mkdir()
        subprocess.run(['git', 'init', '-q', str(repo)], check=True)
        (repo / r.PROJECT_FILE).write_text(json.dumps(
            {'version': 1, 'launch_profile': profile, 'instance_type': instance_type}))
        return repo.resolve()

    def test_existing_worker_for_this_repository_prevents_launch(self):
        self.items = [{'Tags': [{'Key': 'remote-build:project', 'Value': self.c['project']}]}]
        with self.assertRaisesRegex(r.Refused, 'This repository already has a worker'):
            r.up(self.c, self.state, True)
        self.assertEqual(self.launches, 0)

    def test_other_repository_worker_counts_toward_max_workers(self):
        self.items = [{'Tags': [{'Key': 'remote-build:project', 'Value': 'other'}]}]
        c = dict(self.c, max_workers=1)
        with self.assertRaisesRegex(r.Refused, 'max_workers'): r.up(c, self.state, True)
        self.assertEqual(self.launches, 0)
        self.assertEqual(r.up(self.c, self.state, True)['state'], 'running')
        self.assertEqual(self.launches, 1)

    def test_launch_uses_the_repository_selection(self):
        repo = self.repository('arm-repo', 'arm', 'graviton')
        c = r.selection(self.g, repo)
        self.assertEqual(r.up(c, self.state, True)['instance_type'], 'graviton')
        args = [a for call in self.mock.call_args_list if call[0][2] == 'run-instances' for a in call[0][3:]]
        self.assertEqual(args[args.index('--instance-type') + 1], 'graviton')
        self.assertEqual(json.loads(args[args.index('--launch-template') + 1]),
                         {'LaunchTemplateId': 'lt-def', 'Version': '2'})
        tags = {t['Key']: t['Value'] for t in self.items[0]['Tags']}
        self.assertEqual(tags['remote-build:project'], r.project_key(repo))
        self.assertNotEqual(tags['remote-build:project'], self.c['project'])

    def test_repository_selection_is_validated_against_private_config(self):
        for name, selected in [('undefined', {'version': 1, 'launch_profile': 'gpu', 'instance_type': 'small'}),
                               ('unlisted', {'version': 1, 'launch_profile': 'x86', 'instance_type': 'graviton'}),
                               ('extra', {'version': 1, 'launch_profile': 'x86', 'instance_type': 'small', 'ttl_minutes': 480}),
                               ('version', {'version': 2, 'launch_profile': 'x86', 'instance_type': 'small'}),
                               ('boolean', {'version': True, 'launch_profile': 'x86', 'instance_type': 'small'})]:
            (self.repo / r.PROJECT_FILE).write_text(json.dumps(selected))
            with self.subTest(name), self.assertRaises(r.Refused): r.selection(self.g, self.repo)
        (self.repo / r.PROJECT_FILE).unlink()
        with self.assertRaisesRegex(r.Refused, r.PROJECT_FILE): r.selection(self.g, self.repo)

    def test_session_binds_only_its_own_selection(self):
        r.up(self.c, self.state, True)
        g = json.loads(json.dumps(self.g))
        g['launch_profiles']['gpu'] = dict(launch_template='lt-0', launch_version='9', instance_types=['big'])
        g['launch_profiles']['arm']['launch_version'] = '3'
        g['max_workers'] = 5
        self.assertEqual(r.status(r.selection(g, self.repo), self.state)['state'], 'running')
        (self.repo / r.PROJECT_FILE).write_text(json.dumps(
            {'version': 1, 'launch_profile': 'x86', 'instance_type': 'medium'}))
        with self.assertRaisesRegex(r.Refused, 'Configuration changed'):
            r.status(r.selection(g, self.repo), self.state)
        g['launch_profiles']['x86']['launch_version'] = '2'
        (self.repo / r.PROJECT_FILE).write_text(json.dumps(
            {'version': 1, 'launch_profile': 'x86', 'instance_type': 'small'}))
        with self.assertRaisesRegex(r.Refused, 'Configuration changed'):
            r.down(r.selection(g, self.repo), self.state)
        self.assertEqual(self.terminations, 0)

    def test_teardown_refuses_another_repositorys_worker(self):
        r.up(self.c, self.state, True)
        other = r.selection(self.g, self.repository('other', 'x86', 'small'))
        s = r.load(self.state / 'session.json'); s['config'] = r.binding(other)
        r.write(self.state / 'session.json', s)
        with self.assertRaisesRegex(r.Refused, 'Ownership mismatch'): r.down(other, self.state)
        self.assertEqual(self.terminations, 0)

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
        path = self.root / 'config.json'; path.write_text(json.dumps(self.g))
        self.assertEqual(r.configuration(path)['launch_profiles'], self.g['launch_profiles'])
        for key, bad in [('ttl_minutes', 481), ('max_jobs', 21), ('max_workers', 0), ('max_workers', 11),
                         ('janitor_confirmed', False), ('cache_retention', 'forever'), ('version', 1),
                         ('launch_profiles', {})]:
            c = dict(self.g); c[key] = bad
            path.write_text(json.dumps(c))
            with self.subTest(key=key, bad=bad), self.assertRaises(r.Refused): r.configuration(path)
        for key, bad in [('launch_version', '$Latest'), ('launch_template', 'template'),
                         ('instance_types', []), ('instance_types', ['bad type'])]:
            c = json.loads(json.dumps(self.g)); c['launch_profiles']['x86'][key] = bad
            path.write_text(json.dumps(c))
            with self.subTest(profile_key=key, bad=bad), self.assertRaises(r.Refused): r.configuration(path)
        v1 = {k: v for k, v in self.g.items() if k not in ('launch_profiles', 'max_workers')}
        v1.update(version=1, launch_template='lt-abc', launch_version='1', instance_type='small',
                  allowed_instance_types=['small'])
        path.write_text(json.dumps(v1))
        with self.assertRaisesRegex(r.Refused, 'version 2'): r.configuration(path)

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
        for assignment in ['password = "hunter2hunter2hunter2"', 'api_key: sk_fixture_abcdefghijkl',
                           'TOKEN=abcdefghijklmnopqrstuvwx']:
            (project / 'main.rs').write_text(assignment)
            with self.subTest(assignment=assignment), self.assertRaises(r.Refused):
                r.snapshot(project, self.state, 1048576)

    def test_snapshot_accepts_rust_paths_named_like_credentials(self):
        project = self.project()
        (project / 'main.rs').write_text(
            'fn lex(tokens: &mut Vec<Token>, comment: String) {\n'
            '    tokens.push(Token::Comment(collapse(comment)));\n'
            '    let key = Secret::from_environment_variable();\n'
            '    let check = Password ::from_user_supplied_text(input);\n}\n')
        result = r.snapshot(project, self.state, 1048576)
        self.assertEqual([e['path'] for e in result['files']], ['main.rs'])

    def test_snapshot_rejects_file_swap_at_open(self):
        project = self.project()
        outside = self.root / 'outside'; outside.write_text('external data')
        original = os.open
        swapped = []
        def swap(path, flags, *args, **kwargs):
            if path == 'main.rs' and not swapped:
                swapped.append(True)
                (project / 'main.rs').unlink()
                (project / 'main.rs').symlink_to(outside)
            return original(path, flags, *args, **kwargs)
        with patch.object(r.os, 'open', side_effect=swap):
            with self.assertRaises(r.Refused): r.snapshot(project, self.state, 1048576)
        self.assertTrue(swapped)
        self.assertFalse((self.state / 'snapshots').exists())

    def test_snapshot_rejects_directory_swap_at_open(self):
        project = self.project(); (project / 'src').mkdir()
        (project / 'src/lib.rs').write_text('safe')
        outside = self.root / 'outside'; outside.mkdir(); (outside / 'lib.rs').write_text('external')
        original = os.open
        swapped = []
        def swap(path, flags, *args, **kwargs):
            if path == 'src' and not swapped:
                swapped.append(True)
                (project / 'src').rename(project / 'old-src')
                (project / 'src').symlink_to(outside, target_is_directory=True)
            return original(path, flags, *args, **kwargs)
        with patch.object(r.os, 'open', side_effect=swap):
            with self.assertRaises(r.Refused): r.snapshot(project, self.state, 1048576)
        self.assertTrue(swapped)

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

    def test_undelivered_submission_is_released_by_fenced_unknown(self):
        snap = r.snapshot(self.project(), self.state, 1048576)['snapshot']
        r.up(self.c, self.state, True)
        with patch.object(r, 'remote', side_effect=r.Refused('Tool failed: ssh')):
            with self.assertRaises(r.Refused): r.run(self.c, self.state, snap, ['true'], True)
        job = r.load(self.state / 'session.json')['pending_job']
        with self.assertRaises(r.Refused): r.run(self.c, self.state, snap, ['true'], True)
        unknown = {'job': job, 'state': 'unknown', 'snapshot': None}
        with patch.object(r, 'remote', return_value=dict(unknown)):
            released = r.status(self.c, self.state, job)
        self.assertEqual({k: v for k, v in released.items() if k != 'result_file'}, unknown)
        self.assertTrue(released['result_file'].endswith(job + '.json'))
        s = r.load(self.state / 'session.json')
        self.assertNotIn('pending_job', s); self.assertEqual(s['jobs'], {})
        self.assertEqual(r.load(self.state / 'results' / (job + '.json')), unknown)
        with patch.object(r, 'remote', side_effect=lambda c, s, i, p: {'job': p['job'], 'snapshot': p['snapshot'],
                                                                       'state': 'submitted'}):
            retry = r.run(self.c, self.state, snap, ['true'], True)
        self.assertNotEqual(retry['job'], job)
        self.assertEqual(r.load(self.state / 'session.json')['jobs'], {retry['job']: snap})

    def test_unknown_for_a_delivered_job_still_stops(self):
        snap = r.snapshot(self.project(), self.state, 1048576)['snapshot']
        r.up(self.c, self.state, True)
        with patch.object(r, 'remote', side_effect=lambda c, s, i, p: {'job': p['job'], 'snapshot': p['snapshot'],
                                                                       'state': 'submitted'}):
            job = r.run(self.c, self.state, snap, ['true'], True)['job']
        with patch.object(r, 'remote', return_value={'job': job, 'state': 'unknown', 'snapshot': None}):
            with self.assertRaises(r.Refused): r.status(self.c, self.state, job)
        self.assertEqual(r.load(self.state / 'session.json')['jobs'], {job: snap})

    def test_retained_volume_refused_before_creation(self):
        original = self.aws
        def retained(c, service, op, *args):
            if op == 'describe-images':
                return {'Images': [{'BlockDeviceMappings': [{'DeviceName': '/dev/root', 'Ebs': {'DeleteOnTermination': False}}]}]}
            return original(c, service, op, *args)
        with patch.object(r, 'aws', side_effect=retained):
            with self.assertRaises(r.Refused): r.up(self.c, self.state, True)
        self.assertEqual(self.launches, 0)

    def test_pinned_toolchain_reads_the_files_rustup_reads(self):
        repo = self.repo
        def pin(legacy=None, toml=None):
            for name, text in (('rust-toolchain', legacy), ('rust-toolchain.toml', toml)):
                if (repo / name).exists():
                    (repo / name).unlink()
                if text is not None:
                    (repo / name).write_text(text)
            return r.pinned_toolchain(repo)
        self.assertIsNone(pin())
        self.assertEqual(pin(toml='[toolchain]\nchannel = "1.97.0"\ncomponents = ["rustfmt", "clippy"]\n'),
                         ('rust-toolchain.toml', '1.97.0'))
        self.assertEqual(pin(toml="# pinned\n[toolchain]\n  channel='nightly-2026-10-01'  # dated\n"),
                         ('rust-toolchain.toml', 'nightly-2026-10-01'))
        self.assertEqual(pin(toml='[toolchain]\nchannel = "stable-x86_64-unknown-linux-gnu"\n'),
                         ('rust-toolchain.toml', 'stable'))
        self.assertIsNone(pin(toml='[toolchain]\npath = "/opt/my-rust"\n'))
        self.assertIsNone(pin(toml='[toolchain]\ncomponents = ["clippy"]\n'))
        self.assertIsNone(pin(toml='[other]\nchannel = "1.97.0"\n'))
        self.assertEqual(pin(legacy='1.85.0\n'), ('rust-toolchain', '1.85.0'))
        self.assertEqual(pin(legacy='[toolchain]\nchannel = "beta"\n'), ('rust-toolchain', 'beta'))
        # rustup uses the legacy file when both exist.
        self.assertEqual(pin(legacy='1.85.0\n', toml='[toolchain]\nchannel = "1.97.0"\n'),
                         ('rust-toolchain', '1.85.0'))
        self.assertEqual(r.toolchain_name('1.97.0-aarch64-unknown-linux-gnu'), '1.97.0')
        self.assertEqual(r.toolchain_name('nightly-2026-10-01'), 'nightly-2026-10-01')

    def test_up_refuses_a_pinned_toolchain_the_image_lacks_before_launching(self):
        (self.repo / 'rust-toolchain.toml').write_text('[toolchain]\nchannel = "1.97.0"\n')
        self.image_toolchains = 'stable 1.96.0'
        with self.assertRaises(r.Refused) as refused:
            r.up(self.c, self.state, True, self.repo)
        message = str(refused.exception)
        self.assertIn('the x86 image lacks toolchain 1.97.0, which rust-toolchain.toml pins', message)
        self.assertIn('bootstrap.py apply --admin-profile <admin-profile> --owner fixture --rebake '
                      '--rust-toolchain 1.96.0 --rust-toolchain 1.97.0', message)
        self.assertEqual(self.launches, 0)
        self.assertFalse((self.state / 'session.json').exists())

    def test_up_launches_when_the_image_has_the_toolchain_or_cannot_say(self):
        (self.repo / 'rust-toolchain.toml').write_text('[toolchain]\nchannel = "1.97.0"\n')
        for name, tag in [('has it', 'stable 1.97.0'), ('untagged image', None)]:
            with self.subTest(name):
                self.image_toolchains = tag
                state = self.root / ('state-' + name.replace(' ', '-')); state.mkdir()
                self.items = []
                self.assertEqual(r.up(self.c, state, True, self.repo)['state'], 'running')
        (self.repo / 'rust-toolchain.toml').write_text('[toolchain]\nchannel = "stable"\n')
        self.image_toolchains = 'stable'
        self.items = []
        state = self.root / 'state-stable'; state.mkdir()
        self.assertEqual(r.up(self.c, state, True, self.repo)['state'], 'running')
        self.assertEqual(self.launches, 3)

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
        self.extra_env = {}
        self.unset_env = []
        data = io.BytesIO()
        with tarfile.open(fileobj=data, mode='w') as tar:
            member = tarfile.TarInfo('example.txt'); content = b'fixture'; member.size = len(content)
            tar.addfile(member, io.BytesIO(content))
        self.archive = data.getvalue()

    def request(self, **values):
        payload = dict(session=self.session, job=self.job, **values)
        result = subprocess.run([sys.executable, '-c', self.bootstrap], input=json.dumps(payload).encode(),
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                env={k: v for k, v in dict(dict(os.environ, HOME=str(self.home)), **self.extra_env).items()
                                     if k not in self.unset_env}, timeout=5)
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
        self.extra_env = {'PATH': ''}  # isolate timeout from optional toolchain probes
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

    def archive_files(self, files):
        archive = io.BytesIO()
        with tarfile.open(fileobj=archive, mode='w') as tar:
            for name, text in files.items():
                data = text.encode(); member = tarfile.TarInfo(name); member.size = len(data)
                tar.addfile(member, io.BytesIO(data))
        return archive.getvalue()

    def submit_wait(self, archive, argv):
        self.job = str(r.uuid.uuid4())
        code, _ = self.request(action='run', snapshot=r.digest(archive),
                              archive=base64.b64encode(archive).decode(), argv=argv,
                              expires=time.time()+30, max_jobs=10)
        self.assertEqual(code, 0)
        for _ in range(200):
            _, result = self.request(action='status')
            if result['state'] in ('finished', 'failed', 'expired'): return result
            time.sleep(.05)
        self.fail('worker did not finish')

    def test_real_rustup_warm_build_and_source_change(self):
        rustup = shutil.which('rustup')
        if not rustup:
            if os.environ.get('CI'): self.fail('CI requires a preinstalled rustup toolchain')
            self.skipTest('no preinstalled rustup available; no installation attempted')
        probe = subprocess.run([rustup, 'which', 'rustc'], stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE, timeout=10)
        if probe.returncode:
            if os.environ.get('CI'): self.fail('CI requires an installed default Rust toolchain')
            self.skipTest('no installed Rust toolchain; no installation attempted')
        toolchain = Path(probe.stdout.decode().strip()).parent.parent
        rusthome = self.home / '.rustup'; (rusthome / 'toolchains').mkdir(parents=True)
        (rusthome / 'toolchains/fixture').symlink_to(toolchain, target_is_directory=True)
        (rusthome / 'settings.toml').write_text('version = "12"\ndefault_toolchain = "fixture"\n')
        binaries = self.home / 'bin'; binaries.mkdir()
        (binaries / 'rustup').symlink_to(rustup)
        for name in ('rustc', 'cargo'):
            proxy = binaries / name
            proxy.write_text('#!/bin/sh\nexec ' + shlex.quote(rustup) +
                             ' run fixture ' + name + ' \"$@\"\n')
            proxy.chmod(0o755)
        self.extra_env = {'PATH': str(binaries)+os.pathsep+os.environ['PATH'],
                          'RUSTUP_HOME': str(rusthome), 'RUSTUP_TOOLCHAIN': 'fixture',
                          'RUSTUP_AUTO_INSTALL': '0'}
        files = {'Cargo.toml': '[package]\nname="warm_fixture"\nversion="0.1.0"\nedition="2021"\n',
                 'Cargo.lock': 'version = 3\n[[package]]\nname="warm_fixture"\nversion="0.1.0"\n',
                 'src/main.rs': 'fn main() { println!("first"); }'}
        self.unset_env = ['RUSTUP_HOME']  # first build exercises the worker's default home
        first = self.submit_wait(self.archive_files(files), ['cargo', 'build', '--offline', '--locked', '-v'])
        self.assertEqual(first['exit_code'], 0, first.get('log'))
        self.unset_env = []  # subsequent build uses explicit RUSTUP_HOME
        second = self.submit_wait(self.archive_files(files), ['cargo', 'build', '--offline', '--locked', '-v'])
        self.assertEqual(second['exit_code'], 0, second.get('log'))
        self.assertTrue(second['cache_reused'])
        self.assertIn('Fresh warm_fixture', second['log'])
        files['src/main.rs'] = 'fn main() { println!("changed"); }'
        third = self.submit_wait(self.archive_files(files), ['cargo', 'run', '--offline', '--locked'])
        self.assertEqual(third['exit_code'], 0, third.get('log'))
        self.assertIn('changed', third['log'])
        self.assertTrue(third['cache_reused'])
        files['rust-toolchain.toml'] = '[toolchain]\nchannel="fixture"\n'
        fourth = self.submit_wait(self.archive_files(files), ['cargo', 'build', '--offline', '--locked', '-v'])
        self.assertEqual(fourth['exit_code'], 0, fourth.get('log'))
        self.assertFalse(fourth['cache_reused'])
        self.assertNotEqual(third['cache_key'], fourth['cache_key'])

    def test_shared_cache_jobs_are_serialized_and_stale_source_removed(self):
        script = ('import os,time;from pathlib import Path;'
                  'p=Path(os.environ["CARGO_TARGET_DIR"]);p.mkdir(exist_ok=True);'
                  'lock=p/"exclusive";f=lock.open("x");time.sleep(.4);f.close();lock.unlink();'
                  'print(Path("example.txt").read_text())')
        first = self.job
        code, _ = self.request(action='run', snapshot=r.digest(self.archive),
            archive=base64.b64encode(self.archive).decode(), argv=[sys.executable, '-c', script],
            expires=time.time()+15, max_jobs=5)
        self.assertEqual(code, 0)
        second = self.submit_wait(self.archive, [sys.executable, '-c', script])
        self.assertEqual(second['exit_code'], 0)
        self.job = first
        _, result = self.request(action='status'); self.assertEqual(result['exit_code'], 0)
        changed = self.archive_files({'other.txt': 'new'})
        third = self.submit_wait(changed, [sys.executable, '-c',
            'from pathlib import Path;assert not Path("example.txt").exists();print(Path("other.txt").read_text())'])
        self.assertEqual(third['exit_code'], 0)
        self.assertEqual(third['log'], 'new\n')

    def test_unknown_fences_a_late_submission(self):
        code, result = self.request(action='status')
        self.assertEqual((code, result), (0, {'job': self.job, 'state': 'unknown', 'snapshot': None}))
        code, _ = self.request(action='run', snapshot=r.digest(self.archive),
                               archive=base64.b64encode(self.archive).decode(), argv=['true'],
                               expires=time.time()+5, max_jobs=1)
        self.assertEqual(code, 2)
        code, result = self.request(action='status')
        self.assertEqual(result['state'], 'unknown')
        # A fence is not a job: it uses no slot, so a new ID still fits under max_jobs=1.
        self.job = 'c' * 36
        code, result = self.request(action='run', snapshot=r.digest(self.archive),
                                    archive=base64.b64encode(self.archive).decode(), argv=['true'],
                                    expires=time.time()+5, max_jobs=1)
        self.assertEqual((code, result['state']), (0, 'submitted'))
        # Let the detached job finish before the temporary home is removed.
        for _ in range(100):
            _, result = self.request(action='status')
            if result['state'] == 'finished': break
            time.sleep(.05)
        self.assertEqual(result['exit_code'], 0)

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
    repository = Lifecycle.repository

    def tools(self, **extra):
        binaries = self.root / 'bin'; binaries.mkdir(exist_ok=True)
        fixture = Path(__file__).with_name('fake_tools.py').read_text()
        for name in ('aws', 'ssh'):
            tool = binaries / name
            tool.write_text('#!' + sys.executable + '\n' + fixture); tool.chmod(0o755)
        config = self.root / 'config.json'; config.write_text(json.dumps(self.g)); config.chmod(0o600)
        self.config = config
        home = self.root / 'worker'; home.mkdir(exist_ok=True)
        env = dict(os.environ, PATH=str(binaries) + os.pathsep + os.environ['PATH'],
                   FAKE_WORKER_HOME=str(home), FAKE_AWS_STATE=str(self.root / 'aws.json'), **extra)
        def invoke(project, *args, code=0):
            proc = subprocess.run([sys.executable, str(SCRIPTS / 'remote_build.py'), '--config', str(config),
                '--state', str(self.state), '--project', str(project), *args], env=env,
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=10)
            self.assertEqual(proc.returncode, code, proc.stderr.decode())
            return json.loads(proc.stdout or proc.stderr)
        return invoke

    def wait(self, invoke, project, job):
        for _ in range(60):
            result = invoke(project, 'status', '--job', job)
            if result['state'] in ('finished', 'failed', 'expired'): return result
            time.sleep(.05)
        self.fail('job did not finish')

    def test_cli_two_repositories_run_concurrent_workers(self):
        invoke = self.tools()
        arm = self.repository('arm-repo', 'arm', 'graviton')
        (arm / 'main.rs').write_text('fn main() {}')
        (self.repo / 'main.rs').write_text('fn main() {}')
        self.assertEqual(invoke(self.repo, 'setup')['repository'], {'launch_profile': 'x86', 'instance_type': 'small'})
        outside = {e['check']: e['status'] for e in invoke(self.root, 'setup', code=2)['checks']}
        self.assertEqual((outside['launch-profile:arm'], outside['launch-profile:x86'], outside['repository']),
                         ('ok', 'ok', 'blocked'))
        self.assertEqual(invoke(self.repo, 'up', '--approve-cost')['instance_type'], 'small')
        self.assertEqual(invoke(arm, 'up', '--approve-cost')['instance_type'], 'graviton')
        third = self.repository('third', 'x86', 'medium')
        self.assertIn('max_workers', invoke(third, 'up', '--approve-cost', code=2)['error'])
        launched = {i['InstanceType']: i['LaunchTemplate'] for i in json.loads((self.root / 'aws.json').read_text())}
        self.assertEqual(launched, {'small': {'LaunchTemplateId': 'lt-abc', 'Version': '1'},
                                    'graviton': {'LaunchTemplateId': 'lt-def', 'Version': '2'}})
        jobs = {}
        for project, word in [(self.repo, 'x86 build'), (arm, 'arm build')]:
            snap = invoke(project, 'snapshot')['snapshot']
            jobs[project] = invoke(project, 'run', '--snapshot', snap, '--approve-upload', '--',
                                   sys.executable, '-c', 'print(%r)' % word)['job']
        for project, word in [(self.repo, 'x86 build'), (arm, 'arm build')]:
            self.assertEqual(self.wait(invoke, project, jobs[project])['exit_code'], 0)
            results = self.state / 'projects' / r.project_key(project) / 'results'
            self.assertIn(word, r.load(results / (jobs[project] + '.json'))['log'])
            self.assertEqual(list(invoke(project, 'status')['jobs']), [jobs[project]])
        self.assertEqual(invoke(self.repo, 'down')['state'], 'termination-requested')
        self.assertEqual(invoke(self.repo, 'down')['state'], 'terminated')
        self.assertEqual(invoke(arm, 'status')['state'], 'running')
        self.assertEqual(invoke(arm, 'down')['state'], 'termination-requested')
        self.assertEqual(invoke(arm, 'down')['state'], 'terminated')
        self.assertEqual(invoke(third, 'down')['state'], 'absent')
    def test_cli_fake_aws_ssh_round_trip(self):
        invoke = self.tools()
        project = self.repo
        (project / 'main.rs').write_text('fn main() {}')
        self.assertEqual(invoke(project, 'setup')['version'], 2)
        self.assertEqual(invoke(project, 'up', '--approve-cost')['state'], 'running')
        snap = invoke(project, 'snapshot', str(project))['snapshot']
        job = invoke(project, 'run', '--snapshot', snap, '--approve-upload', '--', sys.executable,
                     '-c', 'print("offline integration");raise SystemExit(3)')['job']
        result = self.wait(invoke, project, job)
        self.assertEqual(result['exit_code'], 3)
        self.assertEqual(result['snapshot'], snap)
        results = self.state / 'projects' / r.project_key(project) / 'results'
        self.assertIn('offline integration', r.load(results / (job + '.json'))['log'])
        self.assertEqual(invoke(project, 'status')['state'], 'running')
        retry = invoke(project, 'run', '--snapshot', snap, '--approve-upload', '--', sys.executable,
                       '-c', 'print("next build")')['job']
        self.assertEqual(self.wait(invoke, project, retry)['exit_code'], 0)
        self.assertEqual(invoke(project, 'status')['state'], 'running')
        self.assertEqual(len(json.loads((self.root / 'aws.json').read_text())), 1)

        self.assertEqual(invoke(project, 'down')['state'], 'termination-requested')
        self.assertEqual(invoke(project, 'down')['state'], 'terminated')
        self.assertEqual(invoke(project, 'down')['state'], 'absent')

    def test_cli_waits_for_a_job_and_a_teardown(self):
        invoke = self.tools()
        project = self.repo
        invoke(project, 'up', '--approve-cost')
        snap = invoke(project, 'snapshot')['snapshot']
        job = invoke(project, 'run', '--snapshot', snap, '--approve-upload', '--', sys.executable,
                     '-c', 'import time; time.sleep(1.5); print("waited for")')['job']
        result = invoke(project, 'status', '--job', job, '--wait')
        self.assertEqual((result['state'], result['exit_code']), ('finished', 0))
        self.assertNotIn('log', result)  # the log stays in the private result file it names
        saved = self.state / 'projects' / r.project_key(project) / 'results' / (job + '.json')
        self.assertEqual(result['result_file'], r.shown(saved))
        self.assertIn('waited for', r.load(saved)['log'])
        self.assertIn('Pass --job with --wait', invoke(project, 'status', '--wait', code=2)['error'])
        self.assertEqual(invoke(project, 'down', '--wait')['state'], 'terminated')
        self.assertEqual(invoke(project, 'down', '--wait')['state'], 'absent')

    def test_poll_backs_off_and_stops_at_the_deadline(self):
        states, slept, clock = iter(['submitted', 'queued', 'running', 'finished']), [], [1000.0]
        def sleep(seconds):
            slept.append(seconds)
            clock[0] += seconds
        done = lambda result: result['state'] not in r.RUNNING
        step = lambda: {'state': next(states)}
        self.assertEqual(r.poll(step, done, 2000, sleep, lambda: clock[0]), {'state': 'finished'})
        self.assertEqual(slept, [1, 2, 4])
        slept.clear()
        result = r.poll(lambda: {'state': 'running'}, done, clock[0] + 100, sleep, lambda: clock[0])
        self.assertEqual(result['state'], 'running')
        self.assertIn('stopped at the deadline', result['wait'])
        self.assertEqual(slept, [1, 2, 4, 8, 16, 20, 20, 20])
        self.assertLessEqual(sum(slept), 100)

    def test_waiting_releases_the_project_lock_between_polls(self):
        import fcntl
        free = []
        states = iter(['running', 'finished'])
        # Between polls another command takes the lock without waiting, as a CLI command would.
        r.poll(lambda: r.locked(self.state, lambda: {'state': next(states)}, wait=True),
               lambda x: x['state'] not in r.RUNNING, 10 ** 10,
               lambda seconds: free.append(r.locked(self.state, lambda: 'free')), lambda: 0)
        self.assertEqual(free, ['free'])
        # While a command holds it, another refuses at once instead of waiting. The attempt runs in
        # a thread, so a lock that waits fails this test rather than hanging it.
        import threading
        outcome = []
        def attempt():
            try:
                outcome.append(r.locked(self.state, lambda: 'ran'))
            except r.Refused as e:
                outcome.append(str(e))
        with open(self.state / 'lock', 'a') as held:
            fcntl.flock(held, fcntl.LOCK_EX)
            thread = threading.Thread(target=attempt, daemon=True)
            thread.start()
            thread.join(5)
            self.assertTrue(outcome and 'holds this project' in outcome[0], outcome or 'blocked instead of refusing')

    def test_cli_recovers_from_ssh_failure_before_delivery(self):
        fail = self.root / 'ssh-fails-once'
        invoke = self.tools(FAKE_SSH_FAIL_ONCE=str(fail))
        project = self.repo
        (project / 'main.rs').write_text('fn main() {}')
        invoke(project, 'up', '--approve-cost')
        snap = invoke(project, 'snapshot')['snapshot']
        fail.touch()
        command = ['--snapshot', snap, '--approve-upload', '--', sys.executable, '-c', 'print("delivered")']
        self.assertEqual(invoke(project, 'run', *command, code=2), {'error': 'Tool failed: ssh'})
        self.assertIn('unresolved', invoke(project, 'run', *command, code=2)['error'])
        lost = next(iter(invoke(project, 'status')['jobs']))
        self.assertEqual(invoke(project, 'status', '--job', lost)['state'], 'unknown')
        self.assertEqual(invoke(project, 'status')['jobs'], {})
        job = invoke(project, 'run', *command)['job']
        self.assertEqual(self.wait(invoke, project, job)['exit_code'], 0)
        self.assertEqual(len(json.loads((self.root / 'aws.json').read_text())), 1)

    def setup_checks(self, invoke, project, code):
        result = invoke(project, 'setup', code=code)
        return result, {e['check']: e for e in result['checks']}

    def test_setup_without_config_explains_and_links_the_guide(self):
        invoke = self.tools()
        self.config.unlink()
        result, checks = self.setup_checks(invoke, self.repo, 2)
        self.assertFalse(result['ready'])
        self.assertEqual(checks['tools']['status'], 'ok')
        self.assertEqual(checks['config']['status'], 'fail')
        self.assertIn('No private config at', checks['config']['detail'])
        self.assertTrue(checks['config']['guide'].endswith('/plugins/remote-build/reference/operator-guide.md#quick-start-bootstrap'))
        self.assertTrue(checks['config']['guide'].startswith('https://github.com/cjus/cjus-skills/blob/main/'))
        for name in ('aws-auth', 'launch-profiles', 'ssh-identity', 'known-hosts', 'janitor', 'repository'):
            self.assertEqual(checks[name]['status'], 'blocked', name)
        self.assertTrue(result['next'].startswith('config: Run scripts/bootstrap.py apply'))
        self.assertTrue(Path(result['guide']['installed']).is_file())
        self.assertIn('run setup', invoke(self.repo, 'status', code=2)['error'])

    def test_setup_ready_when_every_prerequisite_passes(self):
        invoke = self.tools()
        result, checks = self.setup_checks(invoke, self.repo, 0)
        self.assertTrue(result['ready'])
        self.assertEqual({e['status'] for e in result['checks']}, {'ok'})
        self.assertNotIn('next', result)
        self.assertEqual(result['repository'], {'launch_profile': 'x86', 'instance_type': 'small'})
        self.assertEqual(sorted(k for k in checks if k.startswith('launch-profile:')),
                         ['launch-profile:arm', 'launch-profile:x86'])
        text = json.dumps(result)
        self.assertNotIn('fixture-account', text)
        self.assertNotIn(str(self.root / 'key'), text)

    def test_setup_reports_each_gap_separately(self):
        invoke = self.tools()
        (self.root / 'key').chmod(0o644)
        (self.root / 'hosts').write_text('# no entries yet\n')
        g = dict(self.g, janitor_confirmed=False)
        self.config.write_text(json.dumps(g))
        (self.repo / r.PROJECT_FILE).unlink()
        result, checks = self.setup_checks(invoke, self.repo, 2)
        failing = sorted(k for k, e in checks.items() if e['status'] == 'fail')
        self.assertEqual(failing, ['janitor', 'known-hosts', 'repository', 'ssh-identity'])
        self.assertIn('arm: graviton; x86: small, medium', checks['repository']['next'])
        self.assertTrue(checks['janitor']['guide'].endswith('#step-9-expiry-janitor'))
        self.assertTrue(result['next'].startswith('ssh-identity: '))
        self.config.chmod(0o644)
        _, checks = self.setup_checks(invoke, self.repo, 2)
        self.assertEqual(checks['config-permissions']['status'], 'fail')

    def test_setup_and_up_refuse_a_pinned_toolchain_the_image_lacks(self):
        invoke = self.tools(FAKE_IMAGE_TOOLCHAINS='stable')
        (self.repo / 'rust-toolchain.toml').write_text('[toolchain]\nchannel = "1.97.0"\n')
        result, checks = self.setup_checks(invoke, self.repo, 2)
        self.assertEqual(checks['repository']['status'], 'fail')
        self.assertIn('x86 / small; the x86 image lacks toolchain 1.97.0, which rust-toolchain.toml pins',
                      checks['repository']['detail'])
        self.assertEqual(checks['repository']['next'], 'Rebuild the image: bootstrap.py apply --admin-profile '
                         '<admin-profile> --owner fixture --rebake --rust-toolchain 1.97.0')
        self.assertTrue(checks['repository']['guide'].endswith('#quick-start-bootstrap'))
        self.assertTrue(result['next'].startswith('repository: Rebuild the image'))
        self.assertIn('Not launching', invoke(self.repo, 'up', '--approve-cost', code=2)['error'])
        aws_state = self.root / 'aws.json'
        self.assertFalse(aws_state.exists() and json.loads(aws_state.read_text()))

    def test_setup_says_whether_the_pinned_toolchain_was_checked(self):
        (self.repo / 'rust-toolchain.toml').write_text('[toolchain]\nchannel = "1.97.0"\n')
        for tag, expected in [('stable 1.97.0', 'x86 / small; the image has toolchain 1.97.0 (rust-toolchain.toml)'),
                              (None, 'x86 / small; toolchain 1.97.0 (rust-toolchain.toml) not checked: '
                                     'the image has no remote-build:toolchains tag')]:
            with self.subTest(tag):
                invoke = self.tools(**({'FAKE_IMAGE_TOOLCHAINS': tag} if tag else {}))
                result, checks = self.setup_checks(invoke, self.repo, 0)
                self.assertTrue(result['ready'])
                self.assertEqual(checks['repository']['detail'], expected)

    def test_setup_blocks_templates_when_authentication_fails(self):
        invoke = self.tools(FAKE_AWS_FAIL='get-caller-identity')
        _, checks = self.setup_checks(invoke, self.repo, 2)
        self.assertEqual(checks['aws-auth']['status'], 'fail')
        self.assertIn('aws sso login --profile test', checks['aws-auth']['next'])
        self.assertEqual(checks['launch-profile:x86']['status'], 'blocked')
        self.assertEqual(checks['repository']['status'], 'ok')

    def test_setup_links_survive_the_install_cache_layout(self):
        installed = self.root / 'cache' / 'marketplace' / 'remote-build' / '9.9.9'
        shutil.copytree(SCRIPTS.parent, installed, ignore=shutil.ignore_patterns('tests', '__pycache__'))
        proc = subprocess.run([sys.executable, str(installed / 'scripts' / 'remote_build.py'),
                               '--config', str(self.root / 'missing.json'), '--state', str(self.state),
                               '--project', str(self.repo), 'setup'],
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30)
        result = json.loads(proc.stdout)
        expected = 'https://github.com/cjus/cjus-skills/blob/main/plugins/remote-build/reference/operator-guide.md'
        self.assertEqual(result['guide']['web'], expected)
        self.assertEqual(result['guide']['installed'], str((installed / 'reference' / 'operator-guide.md').resolve()))
        self.assertTrue(all(e['guide'].startswith(expected + '#') for e in result['checks'] if 'guide' in e))

    def test_setup_guide_anchors_exist(self):
        guide = (SCRIPTS.parent / 'reference' / 'operator-guide.md').read_text()
        # GitHub's heading anchors: lowercase, punctuation dropped, spaces to hyphens.
        anchors = {re.sub(r'[^a-z0-9 -]', '', line.lstrip('#').strip().lower()).replace(' ', '-')
                   for line in guide.splitlines() if line.startswith('## ')}
        used = set(re.findall(r"'(overview|quick-start-bootstrap|step-[0-9]+-[a-z-]+)'", (SCRIPTS / 'remote_build.py').read_text()))
        self.assertTrue(used)
        self.assertEqual(used - anchors, set())

if __name__ == '__main__':
    unittest.main()
