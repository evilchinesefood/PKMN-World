#!/usr/bin/env python3
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]

with tempfile.TemporaryDirectory(prefix='pw-fixture-boundary-') as temporary:
    root = Path(temporary)
    fixture = root / 'fixture'
    (fixture / 'lua').mkdir(parents=True)
    rom = b'fixture test double'
    (fixture / 'VerifyFeatures.gba').write_bytes(rom)
    md5 = hashlib.md5(rom).hexdigest().upper()
    symbols = f'return {{romMD5="{md5}"}}\n'
    (fixture / 'lua/symbols.lua').write_text(symbols)
    (fixture / 'manifest.json').write_text(json.dumps({'fixture_rom_sha256': hashlib.sha256(rom).hexdigest(), 'symbols_sha256': hashlib.sha256(symbols.encode()).hexdigest()}))
    suite = root / 'probe.lua'
    suite.write_text("local F=require('lib').new(S,'FixtureProbe')\n")
    emulator = root / 'emulator'
    emulator.write_text('''#!/usr/bin/env python3
import os
from pathlib import Path
import sys
assert Path(os.environ['PW_SYMBOLS']).is_file()
assert os.environ['PW_SYMBOLS'].startswith(os.environ['PW_FEATURE_LIB'])
assert 'PW_LOSE' not in os.environ
assert os.environ['PW_PICK'] == 'selected'
if os.environ.get('DOUBLE_MODE') == 'none': sys.exit(0)
out = Path(os.environ['PW_OUT'])
(out/'FixtureProbe.PASS').write_text('PASS 1/1 rom='+os.environ['PW_ROM_HASH']+' at=now suite=FixtureProbe\\n')
print('VERDICT FixtureProbe: 1/1 PASS')
''')
    emulator.chmod(0o755)
    def run(name, expected, **extra):
        out = root / name
        env = dict(os.environ, MGBA_HEADLESS=str(emulator), PW_LOSE='unselected', **extra)
        result = subprocess.run([sys.executable, str(HERE / 'run_fixture.py'), '--repo', str(REPO), '--fixture', str(fixture), '--suite', str(suite), '--out', str(out), '--env', 'PW_PICK=selected'], env=env, capture_output=True, text=True)
        assert (result.returncode == 0) == expected, result.stdout + result.stderr
        print('PASS', name, 'accepted' if expected else 'rejected')
        return out
    good = run('good', True)
    assert json.loads((good / 'result.json').read_text())['assertions'] == 1
    run('no-verdict', False, DOUBLE_MODE='none')
    run('good', False)
    before = (fixture / 'lua/symbols.lua').read_bytes()
    (fixture / 'lua/symbols.lua').write_text('return {}')
    run('wrong-symbols', False)
    (fixture / 'lua/symbols.lua').write_bytes(before)
    (fixture / 'VerifyFeatures.gba').write_bytes(b'wrong rom')
    run('wrong-rom', False)
print('Fixture boundary checks: 5/5 passed; emulator doubles are not gameplay evidence.')
