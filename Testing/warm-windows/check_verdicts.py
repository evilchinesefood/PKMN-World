#!/usr/bin/env python3
"""Exercise review evidence gates against stale and aborted emulator results."""
from pathlib import Path
import tempfile

from render_review import passed

ROM = '1234567890abcdef1234567890abcdef'
with tempfile.TemporaryDirectory(prefix='pw-window-verdicts-') as tmp:
    root = Path(tmp)

    def seed():
        for path in root.iterdir():
            path.unlink()
        (root/'Probe.log').write_text('VERDICT Probe: 1/1 PASS\n')
        (root/'Probe.PASS').write_text(f'PASS 1/1 rom={ROM} at=2026-09-27T00:00:00Z suite=Probe\n')
        (root/'runner.log').write_text('VERDICT Probe: 1/1 PASS\n')

    def rejected(label, mutation):
        seed()
        mutation()
        try:
            passed(root, ROM)
        except (AssertionError, OSError):
            print('PASS: rejected '+label)
        else:
            raise AssertionError('accepted '+label)

    seed()
    assert passed(root, ROM) == 1
    print('PASS: accepted completed fixture run')
    (root/'runner.log').write_text('VERDICT Probe: 1/1 PASS\n---\nexit code: 0\n')
    assert passed(root, ROM) == 1
    print('PASS: accepted completed ordinary-ROM runner')
    rejected('missing runner stdout', lambda: (root/'runner.log').unlink())
    rejected('ROM guard abort with stale PASS/log', lambda: (root/'runner.log').write_text('ROM hash mismatch\n'))
    rejected('error after verdict', lambda: (root/'runner.log').write_text('VERDICT Probe: 1/1 PASS\nLUA ERROR\n'))
    rejected('failed process', lambda: (root/'runner.log').write_text('VERDICT Probe: 1/1 PASS\n---\nexit code: 1\n'))
    rejected('empty suite log', lambda: (root/'Probe.log').write_text(''))
    rejected('partial verdict', lambda: (root/'Probe.log').write_text('VERDICT Probe: 0/1 PASS\n'))
    rejected('zero assertions', lambda: (root/'Probe.log').write_text('VERDICT Probe: 0/0 PASS\n'))
    rejected('contradictory FAIL sentinel', lambda: (root/'Probe.FAIL').write_text('FAIL\n'))
    rejected('wrong ROM sentinel', lambda: (root/'Probe.PASS').write_text(f'PASS 1/1 rom={"0"*32} at=now suite=Probe\n'))
