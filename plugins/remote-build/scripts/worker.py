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
import signal
import subprocess
import sys
import tarfile
import time


def save(path, value):
    tmp = path.with_suffix('.tmp')
    tmp.write_text(json.dumps(value))
    os.replace(tmp, path)


def execute(folder):
    job = Path(folder)
    meta = json.loads((job / 'meta.json').read_text())
    env = {'PATH': os.environ.get('PATH', '/usr/bin:/bin'), 'HOME': str(job / 'home'),
           'CARGO_HOME': str(job / 'home/.cargo'), 'CARGO_TARGET_DIR': str(job / 'target'),
           'LANG': 'C.UTF-8'}
    (job / 'home').mkdir(exist_ok=True)
    proc = None
    try:
        proc = subprocess.Popen(meta['argv'], cwd=str(job / 'source'), env=env,
                                stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, start_new_session=True)
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
        if meta['state'] == 'running':
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
        meta.update(state='running', pid=child.pid)
        save(job / 'meta.json', meta)
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
