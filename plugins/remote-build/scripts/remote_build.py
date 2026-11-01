#!/usr/bin/env python3
"""remote-build contract v2. Standard library; never invokes a local shell."""
import argparse
import base64
import fcntl
import hashlib
import io
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tarfile
import time
import uuid


class Refused(Exception):
    pass


def require(ok, message):
    if not ok:
        raise Refused(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':')).encode()


def call(argv, data=None, timeout=60):
    try:
        result = subprocess.run(argv, input=data, stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired):
        raise Refused('Tool unavailable or timed out: ' + Path(argv[0]).name)
    # Tool stderr can contain credentials, source, or private paths; do not echo it.
    require(result.returncode == 0, 'Tool failed: ' + Path(argv[0]).name)
    return result.stdout


def write(path, value):
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    tmp = path.with_suffix('.tmp')
    with open(tmp, 'wb') as stream:
        os.chmod(tmp, 0o600)
        stream.write(canonical(value))
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(tmp, path)


def load(path):
    return json.loads(path.read_text())


NAME = r'[a-zA-Z0-9][a-zA-Z0-9_.-]{0,63}'
PROJECT_FILE = '.remote-build.json'


def named(value):
    return isinstance(value, str) and re.fullmatch(NAME, value)


def configuration(path):
    """Private operator config (v2): shared settings plus named launch profiles."""
    c = load(path)
    require(isinstance(c, dict) and c.get('version') == 2,
            'Config version 2 is required; move the template and types into launch_profiles (reference/config.md)')
    required = {'version', 'provider', 'profile', 'region', 'owner', 'launch_profiles',
                'max_workers', 'ttl_minutes', 'janitor_confirmed', 'ssh_user', 'known_hosts',
                'identity_file', 'address_field', 'max_snapshot_bytes', 'max_jobs', 'cache_retention'}
    require(set(c) == required, 'Config fields must match reference/config.md exactly')
    require(c['provider'] == 'aws', 'Only the AWS provider is supported')
    for key in ('profile', 'region', 'owner', 'ssh_user'):
        require(named(c[key]), 'Invalid ' + key)
    profiles = c['launch_profiles']
    require(isinstance(profiles, dict) and profiles, 'Provide at least one launch profile')
    for name, lp in profiles.items():
        require(named(name), 'Invalid launch profile name')
        require(isinstance(lp, dict) and set(lp) == {'launch_template', 'launch_version', 'instance_types'},
                'Launch profile fields must match reference/config.md exactly')
        require(isinstance(lp['launch_template'], str) and re.fullmatch(r'lt-[a-f0-9]+', lp['launch_template']),
                'Invalid launch template in profile ' + name)
        require(isinstance(lp['launch_version'], str) and re.fullmatch(r'[1-9][0-9]*', lp['launch_version']),
                'Pin a numeric launch template version in profile ' + name)
        require(isinstance(lp['instance_types'], list) and lp['instance_types'] and
                all(named(t) for t in lp['instance_types']), 'Provide an instance-type list in profile ' + name)
    for key, upper in [('ttl_minutes', 480), ('max_snapshot_bytes', 33554432), ('max_jobs', 20),
                       ('max_workers', 10)]:
        require(type(c[key]) is int and 1 <= c[key] <= upper, 'Out-of-bounds ' + key)
    require(c['janitor_confirmed'] is True, 'Independent expiry janitor must be confirmed by operator')
    require(c['cache_retention'] == 'session', 'Only session-scoped cache retention is supported')
    require(c['address_field'] in ('PublicIpAddress', 'PrivateIpAddress'), 'Unsupported address field')
    for key in ('known_hosts', 'identity_file'):
        p = Path(c[key]).expanduser()
        require(p.is_absolute() and p.is_file() and not p.is_symlink(), 'Provide an existing absolute ' + key)
        c[key] = str(p)
    return c


def project_root(path):
    return Path(call(['git', '-C', str(path), 'rev-parse', '--show-toplevel']).decode().strip()).resolve()


def project_key(root):
    """Stable per-checkout identity: state directory name and the remote-build:project tag."""
    return digest(str(root).encode())[:16]


def selection(c, root):
    """Merge the repository's committed choice into the operator config.

    The repository file only selects among operator-approved launch profiles and instance
    types; it never authorizes a launch (that still needs --approve-cost)."""
    path = root / PROJECT_FILE
    require(path.is_file() and not path.is_symlink(),
            'Add ' + PROJECT_FILE + ' at the Git root naming launch_profile and instance_type')
    p = load(path)
    require(isinstance(p, dict) and set(p) == {'version', 'launch_profile', 'instance_type'} and
            type(p['version']) is int and p['version'] == 1,
            PROJECT_FILE + ' must contain exactly version 1, launch_profile and instance_type')
    require(p['launch_profile'] in c['launch_profiles'], 'Repository launch_profile is not defined in the private config')
    lp = c['launch_profiles'][p['launch_profile']]
    require(p['instance_type'] in lp['instance_types'], 'Repository instance_type is not approved for its launch profile')
    e = {k: v for k, v in c.items() if k != 'launch_profiles'}
    e.update(launch_profile=p['launch_profile'], launch_template=lp['launch_template'],
             launch_version=lp['launch_version'], instance_type=p['instance_type'], project=project_key(root))
    return e


def binding(e):
    # A session binds only what identifies its own worker; editing another repository's
    # profile, or the cross-project max_workers cap, leaves running sessions usable.
    return digest(canonical({k: v for k, v in e.items() if k != 'max_workers'}))


def prerequisites():
    for binary, arg in [('aws', '--version'), ('ssh', '-V'), ('git', '--version')]:
        require(shutil.which(binary), 'Missing dependency: ' + binary)
        call([binary, arg])


def aws(c, service, operation, *args):
    data = call(['aws', '--profile', c['profile'], '--region', c['region'], '--output', 'json',
                 '--no-cli-pager', service, operation] + list(args))
    return json.loads(data)


def identity(c):
    return aws(c, 'sts', 'get-caller-identity')['Account']


def instances(c, *filters):
    data = aws(c, 'ec2', 'describe-instances', '--filters', *filters)
    return [i for r in data['Reservations'] for i in r['Instances']]


def template(c):
    versions = aws(c, 'ec2', 'describe-launch-template-versions', '--launch-template-id',
                   c['launch_template'], '--versions', c['launch_version'])['LaunchTemplateVersions']
    require(len(versions) == 1, 'Ambiguous launch template')
    t = versions[0]['LaunchTemplateData']
    require(not any(t.get(k) for k in ('IamInstanceProfile', 'UserData', 'InstanceMarketOptions',
                                      'InstanceRequirements', 'HibernationOptions')), 'Unsupported template capabilities')
    require(not t.get('DisableApiTermination'), 'Template enables termination protection')
    require(t.get('ImageId', '').startswith('ami-'), 'Pin an AMI in the template')
    images = aws(c, 'ec2', 'describe-images', '--image-ids', t['ImageId'])['Images']
    require(len(images) == 1, 'AMI unavailable')
    mappings = {b['DeviceName']: b for b in images[0].get('BlockDeviceMappings', [])}
    mappings.update({b['DeviceName']: b for b in t.get('BlockDeviceMappings', [])})
    require(mappings, 'Cannot verify storage retention')
    for b in mappings.values():
        require('Ebs' not in b or b['Ebs'].get('DeleteOnTermination') is True,
                'Every EBS volume must explicitly delete on termination')
    return {'image': t['ImageId'], 'storage': 'delete-on-termination'}


def owned(c, s):
    require(identity(c) == s['account'], 'AWS account changed; restore the original profile')
    found = instances(c, 'Name=client-token,Values=' + s['token'])
    require(len(found) == 1, 'Creation unresolved or resource no longer visible; do not relaunch')
    i = found[0]
    tags = {t['Key']: t['Value'] for t in i.get('Tags', [])}
    require(tags.get('remote-build:owner') == c['owner'] and
            tags.get('remote-build:project') == c['project'] and
            tags.get('remote-build:session') == s['token'] and
            i.get('ClientToken') == s['token'], 'Ownership mismatch; refusing resource access')
    require(not s.get('instance') or s['instance'] == i['InstanceId'], 'Instance identity changed')
    return i


CHANGED = ('Configuration changed during a session: restore ' + PROJECT_FILE +
           ' and this launch profile to recover or tear down')


def up(c, state, approve):
    path = state / 'session.json'
    if path.exists():
        s = load(path)
        require(s['config'] == binding(c), CHANGED)
        i = owned(c, s)
        s['instance'] = i['InstanceId']
        write(path, s)
        return {'session': s['token'], 'state': i['State']['Name'], 'expires': s['expires'],
                'launch_profile': c['launch_profile'], 'instance_type': c['instance_type']}
    require(approve, 'Paid launch requires --approve-cost after explicit user authorization')
    account = identity(c)
    template(c)
    active = instances(c, 'Name=tag:remote-build:owner,Values=' + c['owner'],
                       'Name=instance-state-name,Values=pending,running,stopping,stopped,shutting-down')
    projects = [{t['Key']: t['Value'] for t in i.get('Tags', [])}.get('remote-build:project') for i in active]
    require(c['project'] not in projects, 'This repository already has a worker; recover it before launching')
    require(len(active) < c['max_workers'], 'Owner is at max_workers; release another worker first')
    token = str(uuid.uuid4())
    expires = int(time.time()) + c['ttl_minutes'] * 60
    s = {'token': token, 'account': account, 'expires': expires, 'config': binding(c), 'jobs': {}}
    # Persist before the request. Never resubmit a possibly successful creation, even after timeout.
    write(path, s)
    tags = [{'Key': 'remote-build:' + k, 'Value': v} for k, v in
            [('owner', c['owner']), ('project', c['project']), ('session', token), ('expires', str(expires))]]
    aws(c, 'ec2', 'run-instances', '--launch-template',
        json.dumps({'LaunchTemplateId': c['launch_template'], 'Version': c['launch_version']}),
        '--instance-type', c['instance_type'], '--count', '1', '--client-token', token,
        '--metadata-options', 'HttpEndpoint=disabled', '--instance-initiated-shutdown-behavior', 'terminate',
        '--tag-specifications', json.dumps([{'ResourceType': 'instance', 'Tags': tags}]))
    return up(c, state, False)


EXCLUDED = {'.git', '.env', '.aws', '.ssh', '.azure', '.config', '.kube', '.gnupg', '.npmrc',
            '.pypirc', '.netrc', '.docker', '.cargo', '.claude', '.codex', '.agents', '.mcp.json',
            'target', 'node_modules', '.venv', '__pycache__', 'AGENTS.md', 'CLAUDE.md'}
# A lone ':' is an assignment (YAML, JSON-ish, Python dicts); '::' is a Rust/C++ path such as
# Token::Comment(...), never a credential, and must not refuse the whole snapshot.
SECRET = re.compile(rb'-----BEGIN [A-Z ]*PRIVATE KEY-----|(?:AKIA|ASIA)[A-Z0-9]{16}|'
                    rb'gh[pousr]_[A-Za-z0-9]{20,}|'
                    rb'(?i:api[_-]?key|password|secret|token)\s*(?:=|:(?!:))\s*["\']?[^\s"\']{12,}')


def excluded(name):
    return any(p in EXCLUDED or p.startswith('.env') or p.lower().endswith(('.pem', '.key', '.p12', '.pfx'))
               or p.lower() in ('credentials', 'credentials.json', 'secrets.json') for p in Path(name).parts)


def source_file(root_fd, name, limit):
    """Read relative to held directory descriptors; never follow replacement symlinks."""
    directory = os.dup(root_fd)
    try:
        parts = Path(name).parts
        for component in parts[:-1]:
            child = os.open(component, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=directory)
            os.close(directory)
            directory = child
        fd = os.open(parts[-1], os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=directory)
        with os.fdopen(fd, 'rb') as stream:
            before = os.fstat(stream.fileno())
            require(stat.S_ISREG(before.st_mode) and before.st_nlink == 1,
                    'Submodules, special files and hard links are unsupported')
            require(before.st_size <= limit, 'Snapshot exceeds configured byte limit')
            data = stream.read(limit + 1)
            after = os.fstat(stream.fileno())
            fields = ('st_size', 'st_mtime_ns', 'st_ctime_ns', 'st_nlink', 'st_mode')
            require(all(getattr(before, k) == getattr(after, k) for k in fields) and len(data) == before.st_size,
                    'Source changed while snapshotting; retry')
            return data, before.st_mode
    except FileNotFoundError:
        return None  # intended deletion, or concurrent deletion; no bytes were uploaded
    except OSError:
        raise Refused('Unsafe or unreadable source path; symlinks are unsupported')
    finally:
        os.close(directory)


def source_root(project):
    directory = os.open('/', os.O_RDONLY | os.O_DIRECTORY)
    try:
        for component in project.parts[1:]:
            child = os.open(component, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=directory)
            os.close(directory)
            directory = child
        return directory
    except BaseException:
        os.close(directory)
        raise


def snapshot(project, state, limit):
    project = project.resolve()
    require(state.resolve() != project and project not in state.resolve().parents,
            'State must live outside the source project')
    require(call(['git', '-C', str(project), 'rev-parse', '--show-toplevel']).decode().strip() == str(project),
            'Project must be a Git root')
    names = call(['git', '-C', str(project), 'ls-files', '-z', '--cached', '--others', '--exclude-standard']).split(b'\0')
    archive = io.BytesIO()
    root_fd = source_root(project)
    try:
        return make_snapshot(names, root_fd, state, limit, archive)
    finally:
        os.close(root_fd)


def make_snapshot(names, root_fd, state, limit, archive):
    entries, total = [], 0
    with tarfile.open(fileobj=archive, mode='w') as tar:
        for raw in sorted(set(names) - {b''}):
            name = raw.decode('utf-8')
            require(not Path(name).is_absolute() and '..' not in Path(name).parts and
                    all(ord(x) >= 32 for x in name), 'Unsupported source filename')
            if excluded(name):
                continue
            content = source_file(root_fd, name, limit - total)
            if content is None:
                continue
            data, file_mode = content
            total += len(data)
            require(not SECRET.search(data), 'Potential secret in source; review locally and exclude it')
            mode = 0o755 if file_mode & 0o111 else 0o644
            entries.append({'path': name, 'sha256': digest(data), 'mode': mode})
            ti = tarfile.TarInfo(name)
            ti.size, ti.mode = len(data), mode
            tar.addfile(ti, io.BytesIO(data))
    require(entries, 'No eligible source files')
    data = archive.getvalue()
    require(len(data) <= limit, 'Archive exceeds configured byte limit')
    fingerprint = digest(data)
    folder = state / 'snapshots'
    folder.mkdir(mode=0o700, exist_ok=True)
    dest = folder / (fingerprint + '.tar')
    dest.write_bytes(data)
    os.chmod(dest, 0o600)
    write(folder / (fingerprint + '.json'), entries)
    return {'snapshot': fingerprint, 'bytes': len(data), 'files': entries,
            'notice': 'Review this exact manifest and source before authorizing upload'}


def remote(c, s, i, payload):
    require(i['State']['Name'] == 'running', 'Worker is not running')
    host = i.get(c['address_field'], '')
    import ipaddress
    try:
        ipaddress.ip_address(host)
    except ValueError:
        raise Refused('Worker has no valid configured IP address')
    agent = Path(__file__).with_name('worker.py').read_bytes()
    program = 'import base64;SOURCE=base64.b64decode(' + repr(base64.b64encode(agent).decode()) + ").decode();exec(compile(SOURCE,'worker','exec'))"
    import shlex
    argv = ['ssh', '-F', '/dev/null', '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes',
            '-o', 'UserKnownHostsFile=' + c['known_hosts'], '-o', 'GlobalKnownHostsFile=/dev/null',
            '-o', 'IdentitiesOnly=yes', '-o', 'ForwardAgent=no', '-o', 'ClearAllForwardings=yes',
            '-o', 'ConnectTimeout=15', '-i', c['identity_file'], c['ssh_user'] + '@' + host,
            'python3 -c ' + shlex.quote(program)]
    payload.update(session=s['token'])
    return json.loads(call(argv, canonical(payload), timeout=120))


def session(c, state):
    require((state / 'session.json').exists(), 'No session; use up')
    s = load(state / 'session.json')
    require(s['config'] == binding(c), CHANGED)
    return s, owned(c, s)


def run(c, state, fingerprint, argv, approve):
    require(approve, 'Upload requires --approve-upload after review of the snapshot')
    require(re.fullmatch('[a-f0-9]{64}', fingerprint), 'Invalid snapshot fingerprint')
    require(argv and all(isinstance(x, str) and '\0' not in x for x in argv), 'Provide command argv after --')
    s, i = session(c, state)
    require(not s.get('pending_job'), 'Submission outcome unresolved; use status --job before another run')
    require(time.time() < s['expires'], 'Session expired; collect results and tear down')
    require(len(s['jobs']) < c['max_jobs'], 'Session job limit reached; collect results and tear down')
    data = (state / 'snapshots' / (fingerprint + '.tar')).read_bytes()
    require(digest(data) == fingerprint and len(data) <= c['max_snapshot_bytes'], 'Snapshot changed or oversized')
    job = str(uuid.uuid4())
    s['jobs'][job] = fingerprint
    s['pending_job'] = job
    write(state / 'session.json', s)
    result = remote(c, s, i, {'action': 'run', 'job': job, 'snapshot': fingerprint,
                            'archive': base64.b64encode(data).decode(), 'argv': argv,
                            'expires': s['expires'], 'max_jobs': c['max_jobs']})
    require(result.get('job') == job and result.get('snapshot') == fingerprint, 'Job/source mismatch')
    s.pop('pending_job', None)
    write(state / 'session.json', s)
    return result


def status(c, state, job=None):
    s, i = session(c, state)
    if not job:
        return {'session': s['token'], 'state': i['State']['Name'], 'expires': s['expires'], 'jobs': s['jobs']}
    require(job in s['jobs'], 'Unknown job')
    result = remote(c, s, i, {'action': 'status', 'job': job})
    require(result.get('job') == job, 'Job/source mismatch')
    if s.get('pending_job') == job and result.get('state') == 'unknown' and result.get('snapshot') is None:
        # The worker answered under its submission lock and fenced this ID, so the upload never
        # landed and never will. Release the submission (it used no worker slot); keep the record.
        write(state / 'results' / (job + '.json'), result)
        del s['jobs'][job]
        s.pop('pending_job')
        write(state / 'session.json', s)
        return result
    require(result.get('snapshot') == s['jobs'][job], 'Job/source mismatch')
    # Results remain private local files; never print remote log text as agent instructions.
    write(state / 'results' / (job + '.json'), result)
    if s.get('pending_job') == job:
        s.pop('pending_job')
        write(state / 'session.json', s)
    return {k: v for k, v in result.items() if k != 'log'}


def down(c, state):
    if not (state / 'session.json').exists():
        return {'state': 'absent'}
    s, i = session(c, state)
    name = i['State']['Name']
    if name not in ('terminated', 'shutting-down'):
        aws(c, 'ec2', 'terminate-instances', '--instance-ids', i['InstanceId'])
        name = 'termination-requested'
    # Keep state until termination is observed, allowing safe retry after disconnect.
    if name == 'terminated':
        write(state / 'history' / (s['token'] + '.json'), s)
        (state / 'session.json').unlink()
    return {'state': name, 'session': s['token']}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--config', type=Path, default=Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home() / '.config'))) / 'remote-build/config.json')
    p.add_argument('--state', type=Path, default=Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state'))) / 'remote-build')
    p.add_argument('--project', type=Path, default=Path('.'),
                   help='Checkout whose ' + PROJECT_FILE + ' selects the worker (default: current directory)')
    sub = p.add_subparsers(dest='action', required=True)
    sub.add_parser('setup')
    u = sub.add_parser('up'); u.add_argument('--approve-cost', action='store_true')
    sn = sub.add_parser('snapshot'); sn.add_argument('checkout', type=Path, nargs='?', help='Same as --project')
    r = sub.add_parser('run'); r.add_argument('--snapshot', required=True); r.add_argument('--approve-upload', action='store_true'); r.add_argument('command', nargs=argparse.REMAINDER)
    st = sub.add_parser('status'); st.add_argument('--job')
    sub.add_parser('down')
    a = p.parse_args()
    os.umask(0o077)
    try:
        c = configuration(a.config)
        plugin = Path(__file__).resolve().parent.parent
        for path in (a.state.resolve(), a.config.resolve()):
            require(path != plugin and plugin not in path.parents, 'Config and state must live outside the plugin')
        try:
            root = project_root(getattr(a, 'checkout', None) or a.project)
        except Refused:
            require(a.action == 'setup', 'Run inside a Git checkout or pass --project')
            root = None
        require(root is None or root not in a.config.resolve().parents, 'Config must live outside the source project')
        if a.action == 'setup':
            prerequisites()
            identity(c)
            chosen = selection(c, root) if root and (root / PROJECT_FILE).exists() else None
            names = [chosen['launch_profile']] if chosen else sorted(c['launch_profiles'])
            result = {'version': 2, 'provider': 'aws',
                      'launch_profiles': {n: template(dict(c, **c['launch_profiles'][n])) for n in names},
                      'repository': chosen and {k: chosen[k] for k in ('launch_profile', 'instance_type')},
                      'limits': {k: c[k] for k in ('ttl_minutes', 'max_jobs', 'max_workers', 'max_snapshot_bytes', 'cache_retention')},
                      'expiry': 'operator-attested independent janitor; not verified by CLI'}
            print(json.dumps(result, sort_keys=True))
            return 0
        e = selection(c, root)
        # One session, lock and snapshot store per checkout, so repositories never block each other.
        state = a.state / 'projects' / e['project']
        state.mkdir(mode=0o700, parents=True, exist_ok=True)
        with open(state / 'lock', 'a') as lock:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                raise Refused('Another local remote-build command holds this project\'s state lock')
            prerequisites()
            if a.action == 'up':
                # Projects lock separately, so serialize launches across them on this client:
                # the per-project and max_workers discovery checks must not race each other.
                with open(a.state / 'launch.lock', 'a') as launch:
                    fcntl.flock(launch, fcntl.LOCK_EX)
                    result = up(e, state, a.approve_cost)
            elif a.action == 'snapshot': result = snapshot(root, state, e['max_snapshot_bytes'])
            elif a.action == 'run': result = run(e, state, a.snapshot, a.command[1:] if a.command[:1] == ['--'] else a.command, a.approve_upload)
            elif a.action == 'status': result = status(e, state, a.job)
            else: result = down(e, state)
            print(json.dumps(result, sort_keys=True))
    except (Refused, OSError, ValueError, KeyError, TypeError) as e:
        message = str(e) if isinstance(e, Refused) else 'Invalid or unavailable local/provider data; inspect privately'
        print(json.dumps({'error': message}), file=sys.stderr)
        return 2
    return 0


if __name__ == '__main__':
    sys.exit(main())
