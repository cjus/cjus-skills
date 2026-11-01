"""Executed on a trusted disposable Linux worker. No credentials are transferred."""
import base64
import fcntl
import hashlib
import io
import json
import os
from pathlib import Path
import re
import selectors
import shutil
import signal
import subprocess
import sys
import tarfile
import time


def save(path, value):
    tmp = path.with_suffix('.tmp')
    tmp.write_text(json.dumps(value))
    os.replace(tmp, path)


def sync_source(source, destination):
    """Stable paths and mtimes allow Cargo reuse; remove stale files before every job."""
    if destination.is_symlink():
        destination.unlink()
    destination.mkdir(exist_ok=True)
    expected = {p.name for p in source.iterdir()}
    for old in destination.iterdir():
        if old.name not in expected:
            if old.is_dir() and not old.is_symlink():
                shutil.rmtree(old)
            else:
                old.unlink()
    for original in source.iterdir():
        target = destination / original.name
        if target.is_symlink():
            target.unlink()
        if original.is_dir():
            if target.exists() and not target.is_dir():
                target.unlink()
            sync_source(original, target)
        else:
            if target.is_dir():
                shutil.rmtree(target)
            if not target.exists() or target.read_bytes() != original.read_bytes():
                shutil.copyfile(original, target)
            target.chmod(original.stat().st_mode & 0o777)


def environment(root):
    home = root / 'home'
    home.mkdir(exist_ok=True)
    # Preserve only the worker's installed Rust toolchain location, never its Cargo home
    # (which may contain registry credentials). Missing toolchains must not auto-install.
    env = {'PATH': os.environ.get('PATH', '/usr/bin:/bin'), 'HOME': str(home),
           'CARGO_HOME': str(root / 'cargo'), 'CARGO_TARGET_DIR': str(root / 'target'),
           'RUSTUP_HOME': os.environ.get('RUSTUP_HOME', str(Path.home() / '.rustup')),
           'RUSTUP_AUTO_INSTALL': '0', 'LANG': 'C.UTF-8'}
    if os.environ.get('RUSTUP_TOOLCHAIN'):
        env['RUSTUP_TOOLCHAIN'] = os.environ['RUSTUP_TOOLCHAIN']
    return env


def cache_identity(source, env, argv):
    # Cargo itself handles source/dependency/feature fingerprints. Reset the entire target
    # when the selected toolchain changes, including an explicit cargo +toolchain argument.
    identity = {'format': 1, 'path': env['PATH'], 'rustup': env['RUSTUP_HOME'],
                'override': env.get('RUSTUP_TOOLCHAIN'), 'explicit': None, 'versions': []}
    if Path(argv[0]).name == 'cargo' and len(argv) > 1 and argv[1].startswith('+'):
        identity['explicit'] = argv[1]
    for binary, flag in [('rustc', '-vV'), ('cargo', '-V')]:
        if shutil.which(binary, path=env['PATH']):
            command = [binary] + ([identity['explicit']] if identity['explicit'] else []) + [flag]
            version = subprocess.run(command, cwd=str(source), env=env, stdout=subprocess.PIPE,
                                     stderr=subprocess.PIPE, timeout=15)
            identity['versions'].append([binary, version.returncode, version.stdout.decode(errors='replace')])
    for name in ('rust-toolchain', 'rust-toolchain.toml'):
        path = source / name
        identity[name] = hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None
    return hashlib.sha256(json.dumps(identity, sort_keys=True).encode()).hexdigest()


def execute(folder):
    job = Path(folder)
    root = job.parent
    meta = json.loads((job / 'meta.json').read_text())
    meta.update(state='queued', pid=os.getpid())
    save(job / 'meta.json', meta)
    # This lock spans source synchronization, all compiler processes and result recording.
    # No two jobs can mutate the stable workspace or Cargo caches concurrently.
    with open(root / 'build.lock', 'a') as lock:
        while True:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                if time.time() >= meta['expires']:
                    meta.update(state='expired', exit_code=None, timed_out=True)
                    save(job / 'result.json', meta)
                    return
                time.sleep(.1)
        if time.time() >= meta['expires']:
            meta.update(state='expired', exit_code=None, timed_out=True)
            save(job / 'result.json', meta)
            return
        try:
            source = root / 'source'
            sync_source(job / 'source', source)
            env = environment(root)
            key = cache_identity(source, env, meta['argv'])
            previous = root / 'cache.json'
            warm = previous.exists() and json.loads(previous.read_text()).get('key') == key
            if not warm:
                for name in ('target', 'cargo'):
                    cache = root / name
                    if cache.is_symlink(): cache.unlink()
                    elif cache.exists(): shutil.rmtree(cache)
            save(previous, {'key': key})
            meta.update(state='running', cache_key=key, cache_reused=warm)
            save(job / 'meta.json', meta)
            execute_command(job, source, env, meta, lock.fileno())
        except Exception:
            meta.update(state='failed', exit_code=None)
            save(job / 'result.json', meta)


def execute_command(job, source, env, meta, lease_fd):
    proc = None
    try:
        proc = subprocess.Popen(meta['argv'], cwd=str(source), env=env,
                                stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, start_new_session=True, pass_fds=(lease_fd,))
        sel = selectors.DefaultSelector()
        sel.register(proc.stdout, selectors.EVENT_READ)
        written = 0
        timed_out = False
        with open(job / 'output.log', 'wb') as out:
            while sel.get_map():
                if time.time() >= meta['expires']:
                    timed_out = True
                    os.killpg(proc.pid, signal.SIGKILL)
                    break
                for key, _ in sel.select(timeout=0.2):
                    chunk = os.read(key.fileobj.fileno(), 65536)
                    if not chunk:
                        sel.unregister(key.fileobj)
                    else:
                        out.write(chunk[:max(0, 1048576 - written)])
                        written += len(chunk)
            rc = proc.wait(timeout=max(1, meta['expires'] - time.time()))
        # Stop descendants before releasing the shared cache lease.
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        meta.update(state='finished', exit_code=rc, timed_out=timed_out, log_truncated=written > 1048576)
    except Exception:
        if proc is not None:
            try:
                os.killpg(proc.pid, signal.SIGKILL)
                proc.wait()
            except ProcessLookupError:
                pass
        meta.update(state='failed', exit_code=None)
    save(job / 'result.json', meta)


def handle(payload):
    for key in ('session', 'job'):
        if not re.fullmatch(r'[a-f0-9-]{36}', payload[key]):
            raise ValueError('Invalid identifier')
    root = Path.home() / '.cache/remote-build' / payload['session']
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    job = root / payload['job']
    if payload['action'] == 'status':
        if not (job / 'meta.json').exists():
            return {'job': payload['job'], 'state': 'unknown', 'snapshot': None}
        meta = json.loads((job / 'result.json' if (job / 'result.json').exists() else job / 'meta.json').read_text())
        if meta['state'] in ('running', 'queued'):
            try:
                os.kill(meta['pid'], 0)
            except ProcessLookupError:
                meta['state'] = 'interrupted'
        log = job / 'output.log'
        meta['log'] = log.read_bytes()[:1048576].decode('utf-8', errors='replace') if log.exists() else ''
        return meta
    if payload['action'] != 'run' or time.time() >= payload['expires']:
        raise ValueError('Unsupported or expired request')
    with open(root / 'lock', 'a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if job.exists():
            raise ValueError('Job already submitted; reconnect instead')
        if len(list(root.glob('*/meta.json'))) >= payload['max_jobs']:
            raise ValueError('Job limit reached')
        archive = base64.b64decode(payload['archive'], validate=True)
        if len(archive) > 33554432 or hashlib.sha256(archive).hexdigest() != payload['snapshot']:
            raise ValueError('Source mismatch')
        job.mkdir(mode=0o700)
        source = job / 'source'
        source.mkdir()
        total = 0
        with tarfile.open(fileobj=io.BytesIO(archive), mode='r:') as tar:
            for member in tar.getmembers():
                name = Path(member.name)
                if not member.isfile() or name.is_absolute() or '..' in name.parts:
                    raise ValueError('Unsafe archive')
                total += member.size
                if total > 33554432:
                    raise ValueError('Source exceeds limit')
                dest = source / name
                dest.parent.mkdir(parents=True, exist_ok=True)
                with open(dest, 'xb') as out:
                    out.write(tar.extractfile(member).read())
                dest.chmod(0o755 if member.mode & 0o111 else 0o644)
        meta = {k: payload[k] for k in ('job', 'snapshot', 'argv', 'expires')}
        meta['state'] = 'submitted'
        save(job / 'meta.json', meta)
        # SOURCE is supplied by the SSH bootstrap, or by tests. No SSH channel remains open.
        with open(os.devnull, 'wb') as null:
            child = subprocess.Popen([sys.executable, '-c', SOURCE, '--execute', str(job)],
                                     stdin=subprocess.DEVNULL, stdout=null, stderr=null,
                                     start_new_session=True, close_fds=True)
        return {'job': meta['job'], 'snapshot': meta['snapshot'], 'state': 'submitted'}


if __name__ == '__main__':
    os.umask(0o077)
    if len(sys.argv) > 1 and sys.argv[1] == '--execute':
        execute(sys.argv[2])
    else:
        try:
            print(json.dumps(handle(json.load(sys.stdin))))
        except Exception:
            print(json.dumps({'error': 'Worker rejected request; inspect private worker state'}))
            sys.exit(2)
