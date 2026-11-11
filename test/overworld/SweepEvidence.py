import csv
import json
from pathlib import Path
import re

from NativeRunner import audit, read_inventory

HERE = Path(__file__).resolve().parent


def read_sweep(directory, md5):
    directory = Path(directory).resolve()
    if not (directory / 'selected.tsv').is_file():
        matches = re.findall(r'^sweep-dir: (.+)$', (directory / 'sweep.log').read_text(), re.M)
        if len(matches) != 1:
            raise ValueError('sweep log must identify exactly one run directory')
        directory = directory / Path(matches[0]).name
    selected = list(csv.reader((directory / 'selected.tsv').open(), delimiter='\t'))
    canonical = [row for row in read_inventory() if row['scope'] == 'required']
    names = [row[0] for row in selected]
    if names != [row['name'] for row in canonical]:
        raise ValueError('evidence does not contain the complete canonical case inventory')
    summary = (directory / 'summary.txt').read_text().strip()
    if not summary.startswith(f'selected={len(names)} passed={len(names)} failed=0 excluded='):
        raise ValueError('sweep did not complete successfully')
    results, sentinels = [], []
    for name in names:
        matches = re.findall(r'^case-dir: (.+)$', (directory / (name + '.log')).read_text(), re.M)
        if len(matches) != 1:
            raise ValueError(f'{name}: missing exact case directory')
        case = directory / Path(matches[0]).name
        record = json.loads((case / 'result.json').read_text())
        if record.get('case') != name or record.get('status') != 'passed' or record.get('rom_md5', '').upper() != md5.upper():
            raise ValueError(f'{name}: failed or mismatched case record')
        count = audit(case / 'evidence', name, md5)
        if record.get('assertions') != count:
            raise ValueError(f'{name}: assertion count differs from verdict')
        results.append((name, name, count, count))
        sentinels.append((case / 'evidence' / (name + '.PASS')).read_text())
    return directory, results, ''.join(sentinels)
