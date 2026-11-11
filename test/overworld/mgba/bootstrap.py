#!/usr/bin/env python3
"""Build pinned Lua-enabled mGBA under an explicitly selected cache directory."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import tempfile
import time

MGBA_REVISION = '669817d03e4858e65d0b992bcd96d3009236cc1e'
LUA_VERSION = '5.4.8'
LUA_SHA256 = '4f18ddae154e793e46eeab727c59ef1c0c0c2b744e7b94219710d76f530629ae'
HERE = Path(__file__).resolve().parent


def run(argv, **kwargs):
    environment = {k: v for k, v in os.environ.items() if k in {'PATH', 'HOME', 'TMPDIR', 'TMP', 'TEMP', 'LANG', 'SDKROOT'} or k.startswith(('LC_', 'PKG_CONFIG_'))}
    subprocess.run(argv, stdout=sys.stderr, stderr=sys.stderr, check=True, env=environment, **kwargs)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def identity():
    cc = os.environ.get('CC', 'cc')
    if len(cc.split()) != 1:
        raise ValueError('bootstrap CC must name one compiler executable')
    cc = shutil.which(cc) or cc
    return {
        'recipe_sha256': sha(__file__), 'cc': cc,
        'dependency_search': {k: v for k, v in os.environ.items() if k.startswith('PKG_CONFIG_')},
        'mgba': MGBA_REVISION, 'lua': LUA_VERSION, 'lua_sha256': LUA_SHA256,
        'patch_sha256': sha(HERE / '0001-headless-video-buffer-save-and-rtc.patch'),
        'platform': platform.system(), 'architecture': platform.machine(),
        'runtime': platform.mac_ver()[0] if platform.system() == 'Darwin' else ' '.join(platform.libc_ver()),
        'png_zlib_versions': subprocess.check_output(['pkg-config', '--modversion', 'libpng', 'zlib'], text=True).strip(),
        'compiler': subprocess.check_output([cc, '--version'], text=True).splitlines()[0],
        'cmake': subprocess.check_output(['cmake', '--version'], text=True).splitlines()[0],
    }


def valid(entry, expected):
    try:
        record = json.loads((entry / 'complete.json').read_text())
        return record['identity'] == expected and sha(entry / 'mgba/build/mgba-headless') == record['binary_sha256']
    except (OSError, ValueError, KeyError):
        return False


def lua_archive(prefix):
    downloads = prefix / 'downloads'
    downloads.mkdir(exist_ok=True)
    cached = downloads / f'lua-{LUA_VERSION}-{LUA_SHA256}.tar.gz'
    if cached.exists():
        if sha(cached) != LUA_SHA256:
            raise ValueError(f'changed source archive cache: {cached}')
        return cached
    urls = (f'https://www.lua.org/ftp/lua-{LUA_VERSION}.tar.gz',
            f'https://distfiles.macports.org/lua/lua-{LUA_VERSION}.tar.gz')
    descriptor, name = tempfile.mkstemp(prefix='lua-', suffix='.tar.gz', dir=downloads)
    os.close(descriptor)
    temporary = Path(name)
    try:
        for url in urls:
            try:
                run(['curl', '--fail', '--location', '--retry', '1', '--retry-all-errors',
                     '--retry-delay', '1', '--retry-max-time', '90', '--connect-timeout', '10',
                     '--max-time', '60', '--output', str(temporary), url])
                if sha(temporary) != LUA_SHA256:
                    raise ValueError('Lua archive SHA256 differs from the pinned official checksum')
                temporary.replace(cached)
                return cached
            except subprocess.CalledProcessError:
                print(f'Lua source unavailable from {url}; trying the verified mirror', file=sys.stderr)
        raise ValueError('could not download the pinned Lua source from either source')
    finally:
        if temporary.exists():
            temporary.unlink()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--prefix', required=True, type=Path)
    parser.add_argument('--jobs', type=int, default=os.cpu_count() or 2)
    args = parser.parse_args()
    if args.jobs < 1:
        parser.error('--jobs must be positive')
    start = time.monotonic()
    expected = identity()
    key = hashlib.sha256(json.dumps(expected, sort_keys=True).encode()).hexdigest()[:24]
    prefix = args.prefix.resolve()
    prefix.mkdir(parents=True, exist_ok=True)
    final = prefix / key
    if valid(final, expected):
        print(f'bootstrap cache hit: {key}', file=sys.stderr)
        print(final / 'mgba/build/mgba-headless')
        return 0
    if final.exists():
        raise ValueError(f'incomplete or changed tool cache: {final}; remove that entry explicitly and retry')
    temporary = Path(tempfile.mkdtemp(prefix=key + '-', dir=prefix))
    try:
        archive = lua_archive(prefix)
        run(['tar', '-xzf', str(archive), '-C', str(temporary)])
        lua = temporary / ('lua-' + LUA_VERSION)
        make = shutil.which('gmake') or shutil.which('make')
        if not make:
            raise ValueError('GNU make is required')
        run([make, '-C', str(lua / 'src'), f'-j{args.jobs}', 'liblua.a', 'CC=' + expected['cc'], 'MYCFLAGS=-fPIC -DLUA_USE_POSIX' + (' -mmacosx-version-min=11.0' if platform.system() == 'Darwin' else '')])
        mgba = temporary / 'mgba'
        run(['git', 'init', '-q', str(mgba)])
        run(['git', '-C', str(mgba), 'remote', 'add', 'origin', 'https://github.com/mgba-emu/mgba.git'])
        run(['git', '-C', str(mgba), 'fetch', '--depth', '1', 'origin', MGBA_REVISION])
        run(['git', '-C', str(mgba), 'checkout', '--detach', 'FETCH_HEAD'])
        if subprocess.check_output(['git', '-C', str(mgba), 'rev-parse', 'HEAD'], text=True).strip() != MGBA_REVISION:
            raise ValueError('mGBA checkout does not match the pinned revision')
        run(['git', '-C', str(mgba), 'apply', str(HERE / '0001-headless-video-buffer-save-and-rtc.patch')])
        run(['cmake', '-S', str(mgba), '-B', str(mgba / 'build'),
             '-DCMAKE_POLICY_VERSION_MINIMUM=3.5', '-DCMAKE_BUILD_TYPE=Release', '-DCMAKE_C_COMPILER=' + expected['cc'],
             '-DBUILD_HEADLESS=ON', '-DENABLE_SCRIPTING=ON', '-DUSE_LUA=ON',
             '-DBUILD_QT=OFF', '-DBUILD_SDL=OFF', '-DUSE_FFMPEG=OFF', '-DUSE_DISCORD_RPC=OFF',
             '-DBUILD_SHARED=OFF', '-DBUILD_STATIC=ON', '-DBUILD_LTO=OFF', '-DUSE_LIBZIP=OFF', '-DUSE_LZMA=OFF',
             '-DUSE_FREETYPE=OFF', '-DUSE_JSON_C=OFF', '-DUSE_SQLITE3=OFF', '-DUSE_ELF=OFF', '-DUSE_EDITLINE=OFF', '-DUSE_MINIZIP=OFF',
             '-DLUA_INCLUDE_DIR=' + str(lua / 'src'), '-DLUA_LIBRARY=' + str(lua / 'src/liblua.a')])
        cache = (mgba / 'build/CMakeCache.txt').read_text()
        if str(lua / 'src/liblua.a') not in cache or str(lua / 'src') not in cache:
            raise ValueError('CMake did not select the pinned Lua build')
        run(['cmake', '--build', str(mgba / 'build'), f'-j{args.jobs}', '--target', 'mgba-headless'])
        binary = mgba / 'build/mgba-headless'
        version = subprocess.check_output([str(binary), '--version', 'unused.gba'], text=True).strip()
        (temporary / 'complete.json').write_text(json.dumps({'identity': expected, 'binary_sha256': sha(binary), 'version': version, 'setup_seconds': round(time.monotonic() - start, 3)}, indent=2) + '\n')
        try:
            temporary.rename(final)
        except OSError:
            if not valid(final, expected):
                raise
        print(f'bootstrap ready: {key}; elapsed={time.monotonic() - start:.3f}s; {version}', file=sys.stderr)
        print(final / 'mgba/build/mgba-headless')
        return 0
    finally:
        if temporary.exists():
            shutil.rmtree(temporary)


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, OSError, subprocess.SubprocessError) as exc:
        print(f'bootstrap failed: {exc}', file=sys.stderr)
        sys.exit(2)
