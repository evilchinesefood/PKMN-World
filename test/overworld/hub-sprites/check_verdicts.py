#!/usr/bin/env python3
"""Exercise the publisher's actual IO validator without rebuilding archived media."""
import ast
from pathlib import Path
import tempfile
from types import SimpleNamespace
import re

source = ast.parse(Path(__file__).with_name('render_review.py').read_text())
function = next(node for node in source.body if isinstance(node, ast.FunctionDef) and node.name == 'validate_verdict')
with tempfile.TemporaryDirectory() as temporary:
    runs = Path(temporary)
    run = runs / 'delivery'
    run.mkdir()
    verdict = 'VERDICT HubSpritesDelivery: 9/9 PASS'
    (run / 'HubSpritesDelivery.log').write_text(verdict + '\n')
    (run / 'HubSpritesDelivery.PASS').write_text('PASS 9/9 rom=' + 'A' * 32 + ' at=now suite=HubSpritesDelivery\n')
    namespace = {'a': SimpleNamespace(runs=runs), 're': re}
    exec(compile(ast.Module(body=[function], type_ignores=[]), 'render_review.py', 'exec'), namespace)
    check = namespace['validate_verdict']
    for suffix in ('', '\n---\nexit code: 0'):
        (run / 'runner.log').write_text(verdict + suffix + '\n')
        assert check('delivery') == ('HubSpritesDelivery', 9)
    for name, text in (
        ('nonzero runner exit', verdict + '\n---\nexit code: 1\n'),
        ('failure after verdict', verdict + '\nFATAL: capture failed\n'),
        ('abort beside stale PASS', 'ABORT: stale ROM\n'),
    ):
        (run / 'runner.log').write_text(text)
        try:
            check('delivery')
        except ValueError:
            print('PASS:', name, 'rejected')
        else:
            raise AssertionError(name + ' was accepted')
print('PASS: successful terminal verdicts accepted with either supported runner format')
