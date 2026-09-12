#!/usr/bin/env python3
"""Refresh desktop asset locks; publish only after all downloads/checks succeed."""
import argparse
import base64
import copy
from contextlib import contextmanager
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request

FAKE_HASH = 'sha256-' + base64.b64encode(bytes(32)).decode()


@contextmanager
def checkout_lock(root):
    relative = subprocess.check_output(
        ['git', '-C', str(root), 'rev-parse', '--git-path', 'source-update.lock'], text=True).strip()
    with (root / relative).open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError('Another source update is running in this checkout') from None
        yield


def run(args, **kwargs):
    return subprocess.run(args, check=True, text=True, **kwargs)


def api(source, endpoint):
    url = f"https://api.github.com/repos/{source['owner']}/{source['repo']}/{endpoint}"
    for attempt in range(3):
        try:
            request = urllib.request.Request(url, headers={'User-Agent': 'nix-config-source-updater'})
            with urllib.request.urlopen(request, timeout=30) as response:
                return json.load(response)
        except (urllib.error.URLError, TimeoutError):
            if attempt == 2:
                raise
            time.sleep(1 + attempt)


def sri(hex_digest):
    return 'sha256-' + base64.b64encode(bytes.fromhex(hex_digest)).decode()


def file_hash(source, digest=None):
    name = source['name']
    if Path(name).name != name:
        raise ValueError(f'Invalid asset filename: {name}')
    with tempfile.TemporaryDirectory(prefix='nix-source-download-') as temp:
        path = Path(temp) / name
        args = ['curl', '--fail', '--location', '--silent', '--show-error',
                '--retry', '3', '--connect-timeout', '20', '--max-time', '600']
        if 'assetId' in source:
            args += ['--header', 'Accept: application/octet-stream']
        run(args + ['--output', str(path), source['url']])
        with path.open('rb') as stream:
            hashed = hashlib.file_digest(stream, 'sha256').hexdigest()
        if digest and digest != 'sha256:' + hashed:
            raise ValueError(f"Upstream digest mismatch for {name}")
        # Populate the same flat fixed-output store path that fetchurl uses.
        run(['nix-store', '--add-fixed', 'sha256', str(path)], stdout=subprocess.DEVNULL)
        return sri(hashed)


def refresh(source):
    new = copy.deepcopy(source)
    policy = source['update']
    if policy['type'] == 'url':
        new['hash'] = file_hash(new)
        new['version'] = 'rolling-' + base64.b64decode(new['hash'][7:]).hex()[:12]
        return new
    if policy['type'] == 'branch':
        revision = api(source, 'commits/' + urllib.parse.quote(policy['branch'], safe=''))['sha']
        new['version'] = 'unstable-' + revision[:12]
    elif policy['type'] == 'release':
        endpoint = ('releases/tags/' + urllib.parse.quote(policy['tag'], safe='')
                    if 'tag' in policy else 'releases/latest')
        release = api(source, endpoint)
        tag = release['tag_name']
        new['version'] = tag.removeprefix('v')
        if source['kind'] == 'file':
            name = policy['asset'].format(tag=tag, version=new['version'])
            matches = [asset for asset in release['assets'] if asset['name'] == name]
            if len(matches) != 1:
                raise ValueError(f"Expected one {name} asset in {source['repo']} {tag}")
            asset = matches[0]
            new.update(name=name, assetId=asset['id'],
                       url=f"https://api.github.com/repos/{source['owner']}/{source['repo']}/releases/assets/{asset['id']}?download=1")
            digest = asset.get('digest')
            if (source.get('assetId') == asset['id'] and digest
                    and digest.startswith('sha256:') and source['hash'] == sri(digest[7:])):
                return new
            new['hash'] = file_hash(new, digest)
            return new
        revision = api(source, 'commits/' + urllib.parse.quote(tag, safe=''))['sha']
    else:
        raise ValueError(f"Unsupported update policy: {policy['type']}")
    if not re.fullmatch(r'[0-9a-f]{40}', revision):
        raise ValueError('GitHub returned an invalid commit ID')
    new['rev'] = revision
    if revision != source['rev']:
        url = f"https://github.com/{source['owner']}/{source['repo']}/archive/{revision}.tar.gz"
        result = run(['nix', 'store', 'prefetch-file', '--json', '--unpack', '--name', 'source', url],
                     capture_output=True)
        new['hash'] = json.loads(result.stdout)['hash']
    return new


def encode(sources):
    return (json.dumps(sources, indent=2, sort_keys=True) + '\n').encode()


def copy_checkout(root, stage):
    # Include local new source files, but never copy Git internals or ignored state.
    files = subprocess.check_output(['git', '-C', str(root), 'ls-files', '--cached',
                                     '--others', '--exclude-standard', '-z']).split(b'\0')
    for name in set(files) - {b''}:
        relative = Path(os.fsdecode(name))
        source = root / relative
        if source.is_file() or source.is_symlink():
            destination = stage / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination, follow_symlinks=False)


def update_vendor_hash(stage, sources):
    sources['dms']['vendorHash'] = FAKE_HASH
    (stage / 'sources.json').write_bytes(encode(sources))
    target = f'path:{stage}#dms.goModules'
    result = subprocess.run(['nix', 'build', '--impure', '--no-link', target],
                            capture_output=True, text=True)
    # Accept only the deliberate fixed-output mismatch, never an unrelated failure.
    match = re.search(r'hash mismatch in fixed-output derivation[^\n]*-go-modules[^\n]*:\s*'
                      r'specified:\s*' + re.escape(FAKE_HASH) + r'\s*got:\s*(sha256-[A-Za-z0-9+/=]+)',
                      result.stderr)
    if result.returncode == 0 or not match:
        raise RuntimeError('Could not compute DMS vendorHash:\n' + result.stderr)
    sources['dms']['vendorHash'] = match[1]
    (stage / 'sources.json').write_bytes(encode(sources))
    run(['nix', 'build', '--impure', '--no-link', target])


def publish(root, originals, updates):
    for name, original in originals.items():
        if (root / name).read_bytes() != original:
            raise RuntimeError(f'{name} changed during update; refusing to overwrite it')
    changed = []
    try:
        for name, data in updates.items():
            if data == originals[name]:
                continue
            temporary = root / (name + '.updating')
            # Exclusive creation also prevents two updaters from sharing a temp file.
            with temporary.open('xb') as stream:
                stream.write(data)
            try:
                os.replace(temporary, root / name)
            finally:
                temporary.unlink(missing_ok=True)
            changed.append(name)
    except BaseException:
        for name in changed:
            (root / name).write_bytes(originals[name])
        raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--flake', action='store_true', help='also update flake.lock before validating')
    parser.add_argument('--only', action='append', help='update only this source (repeatable)')
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    originals = {name: (root / name).read_bytes() for name in ['sources.json', 'flake.lock']}
    sources = json.loads(originals['sources.json'])
    selected = args.only or list(sources)
    unknown = set(selected) - sources.keys()
    if unknown:
        parser.error('Unknown sources: ' + ', '.join(sorted(unknown)))
    with tempfile.TemporaryDirectory(prefix='nix-source-update-') as temp:
        stage = Path(temp)
        copy_checkout(root, stage)
        for name in selected:
            print(f'Updating {name}...', flush=True)
            sources[name] = refresh(sources[name])
            print(f"  {sources[name]['version']} {sources[name]['hash']}", flush=True)
        (stage / 'sources.json').write_bytes(encode(sources))
        if args.flake:
            run(['nix', 'flake', 'update'], cwd=stage)
        old = json.loads(originals['sources.json'])['dms']
        if args.flake or sources['dms']['hash'] != old['hash']:
            print('Computing and verifying DMS Go dependency hash...', flush=True)
            update_vendor_hash(stage, sources)
        # Evaluate the full desktop configuration before touching the real locks.
        run(['nix', 'eval', '--impure', '--raw',
             f'path:{stage}#homeConfigurations.current.activationPackage.drvPath'], stdout=subprocess.DEVNULL)
        updates = {'sources.json': encode(sources)}
        if args.flake:
            updates['flake.lock'] = (stage / 'flake.lock').read_bytes()
        publish(root, originals, updates)
    print('Locks updated. Review sources.json' + (' and flake.lock' if args.flake else '') +
          '; Code Studio compatibility pins are unchanged.')


if __name__ == '__main__':
    try:
        with checkout_lock(Path(__file__).resolve().parent.parent):
            main()
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        detail = getattr(error, 'stderr', None) or ''
        raise SystemExit(f'update-sources: {error}\n{detail}'.rstrip())
