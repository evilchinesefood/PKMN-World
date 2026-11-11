#!/usr/bin/env python3
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
FLAGS = ('POKEVIAL_FEATURE', 'QOL_FIELD_MOVES_ITEM_GATE', 'PW_GRAPHICAL_START_MENU')
HEADERS = ('pokevial.h', 'qol_field_moves.h', 'start_menu.h')


def main():
    with tempfile.TemporaryDirectory(prefix='pw-mode-test-') as temporary:
        tmp = Path(temporary)
        source, tools, trace = tmp / 'source', tmp / 'tools', tmp / 'trace.jsonl'
        source.mkdir(); tools.mkdir()
        trace.write_text('')
        prefix = '#!/usr/bin/env python3\nimport json, os, sys\nfrom pathlib import Path\n'
        prefix += f'TRACE = Path({str(trace)!r})\n'
        prefix += "def note(name, **data):\n    with TRACE.open('a') as f: f.write(json.dumps(dict(name=name, **data)) + '\\n')\n"

        def script(path, body):
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(prefix + body)
            path.chmod(0o755)

        (source / 'test').mkdir()
        shutil.copy2(ROOT / 'test/verify.py', source / 'test/verify.py')
        for flag, header in zip(FLAGS, HEADERS):
            path = source / 'include/config' / header
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(f'#define {flag} TRUE\n')
        script(tools / 'gmake', '''
assert not any(k in os.environ for k in ('TEST', 'RELEASE', 'GAME_VERSION', 'MAKEFLAGS', 'CFLAGS', 'PW_SAVE'))
args = sys.argv[1:]
assert 'GAME_VERSION=EMERALD' in args and 'RELEASE=0' in args and 'LTO=0' in args
assert any(a.startswith('PW_VERSION=') and len(a) > 11 for a in args)
flags = [p.stem for p in Path('include/config').glob('*.h') if 'FALSE' in p.read_text()]
note('build', cwd=Path.cwd().name, args=args, disabled=flags)
for name in ('pokemonworld.gba', 'pokemonworld.elf'):
    Path(name).write_bytes(b'build double')
''')
        emulator = tools / 'mgba-double'
        script(emulator, "assert '--version' in sys.argv\nprint('instrumented emulator')\n")
        script(source / 'test/overworld/mgba/bootstrap.py', f"note('bootstrap')\nprint({str(emulator)!r})\n")
        shell = source / 'test/overworld/mgba/bootstrap.sh'
        shell.write_text('#!/usr/bin/env bash\nexec python3 "$(dirname "$0")/bootstrap.py" "$@"\n')
        script(source / 'test/overworld/NativeRunner.py', '''
assert sys.argv[1] == 'bundle'
note('bind')
out = Path(sys.argv[sys.argv.index('--out') + 1]); out.mkdir()
for name in ('pokemonworld.gba', 'pokemonworld.elf', 'symbols.lua'):
    (out / name).write_text('bound double')
(out / 'bundle.json').write_text('{}')
''')
        (source / 'test/overworld/cases.tsv').write_text('name\tsuite\tfixture\tsmoke\tscope\nSmokeBoot\tlua/SmokeBoot.lua\tfresh\t1\trequired\nVerifyOwnerSave\tlua/VerifyOwnerSave.lua\tpersonal\t0\tmanual\n')
        script(source / 'test/overworld/sweep.py', '''
mode = sys.argv[sys.argv.index('--profile') + 1]
note('lua', profile=mode)
''')
        shell = source / 'test/overworld/run-all.sh'
        shell.write_text('#!/usr/bin/env bash\nexec python3 "$(dirname "$0")/sweep.py" "$@"\n')
        script(source / 'test/overworld/johto-playthrough/run.py', '''
region = sys.argv[sys.argv.index('--campaign') + 1]
beat = sys.argv[sys.argv.index('--to') + 1]
assert '--no-retry' in sys.argv and sys.argv[sys.argv.index('--lose') + 1] == beat + ':trainer'
note('loss', region=region, beat=beat)
''')
        for filename, label in (('test/validate-host.py', 'host'), ('test/overworld/SavePatch.py', 'abi'), ('test/overworld/TestPaletteDependencies.py', 'palette'), ('test/overworld/TestNativeRunner.py', 'boundary')):
            script(source / filename, f'note({label!r})\n')
        for args in (['init', '-q'], ['add', '.'], ['-c', 'user.name=Verification', '-c', 'user.email=verification@example.invalid', 'commit', '-qm', 'test fixture']):
            subprocess.run(['git', '-C', str(source), *args], check=True)
        expected = {
            'build': ['build'],
            'smoke': ['build', 'bootstrap', 'bind', 'lua'],
            'full': ['build', 'bootstrap', 'bind', 'lua', 'boundary', 'loss', 'loss', 'loss', 'host', 'abi', 'palette', 'build', 'build', 'build', 'build'],
        }
        env = dict(os.environ, PATH=str(tools) + os.pathsep + os.environ['PATH'], TEST='1', RELEASE='1', GAME_VERSION='FIRERED', MAKEFLAGS='-e', CFLAGS='bad', PW_SAVE='personal.sav')
        for mode in ('build', 'smoke', 'full'):
            trace.write_text('')
            result = subprocess.run([sys.executable, str(source / 'test/verify.py'), mode, '--out', str(tmp / 'runs'), '--cache', str(tmp / 'cache'), '--jobs', '2'], env=env, text=True, capture_output=True)
            assert result.returncode == 0, result.stdout + result.stderr
            rows = [json.loads(line) for line in trace.read_text().splitlines()]
            assert [r['name'] for r in rows] == expected[mode], rows
            builds = [r for r in rows if r['name'] == 'build']
            assert builds[0]['disabled'] == [] and 'TEST=0' in builds[0]['args']
            if mode == 'full':
                assert 'TEST=1' in builds[1]['args'] and builds[1]['disabled'] == []
                assert [r['disabled'] for r in builds[2:]] == [[Path(h).stem] for h in HEADERS]
                assert [(r['region'], r['beat']) for r in rows if r['name'] == 'loss'] == [('kanto', 'rival_lab'), ('johto', 'rival_and_police'), ('hoenn', 'route103')]
            if mode != 'build':
                assert next(r for r in rows if r['name'] == 'lua')['profile'] == mode
            assert all('TRUE' in (source / 'include/config' / header).read_text() for header in HEADERS)
            print(f'PASS {mode}: exact scope, isolated flags, ignored inherited build selectors')
    print('Mode command checks: 3/3 passed. Instrumented commands are not gameplay evidence.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
