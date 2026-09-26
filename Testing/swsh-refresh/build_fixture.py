#!/usr/bin/env python3
"""Build an isolated #328 fixture and record the actual input ROM's source revision."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('--repo', type=Path, required=True)
p.add_argument('--rom', type=Path, required=True)
p.add_argument('--elf', type=Path, required=True)
p.add_argument('--out', type=Path, required=True)
p.add_argument('--source-ref', required=True, help='Commit/configuration that built the input ROM')
a = p.parse_args()
here = Path(__file__).resolve().parent
subprocess.run(['python3', str(a.repo / 'Testing/visual-features/build_fixture.py'),
                '--repo', str(a.repo), '--rom', str(a.rom), '--elf', str(a.elf),
                '--out', str(a.out), '--source', str(here / 'fixture.c')],
               check=True, stdout=subprocess.DEVNULL)
subprocess.run(['python3', str(here / 'export_symbols.py'), str(a.elf), str(a.out)], check=True)
p = a.out / 'manifest.json'
m = json.loads(p.read_text())
m['fixture_build_context_commit'] = m.pop('base_commit')
m['input_source_ref'] = a.source_ref
m['input_elf_sha256'] = hashlib.sha256(a.elf.read_bytes()).hexdigest()
m['input_map_sha256'] = hashlib.sha256(a.elf.with_suffix('.map').read_bytes()).hexdigest()
m['fixture_header_context'] = {str(f): hashlib.sha256((a.repo / f).read_bytes()).hexdigest()
    for f in ('include/config/swsh_item_menu.h', 'include/swsh_summary_screen.h',
              'include/swsh_storage_system.h', 'include/config/swsh_party_menu.h', 'include/config/name_box.h')}
p.write_text(json.dumps(m, indent=2) + '\n')
print(json.dumps(m))
