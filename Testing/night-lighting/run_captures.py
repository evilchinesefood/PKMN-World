#!/usr/bin/env python3
"""Capture every town in independent, hash-stamped emulator batches."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import subprocess

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--repo',type=Path,required=True)
p.add_argument('--fixture',type=Path,required=True)
p.add_argument('--out',type=Path,required=True)
a=p.parse_args();n=len(json.loads((a.repo/'Testing/night-lighting/scenes.json').read_text()))
a.out.mkdir(parents=True,exist_ok=True)
def run(first):
    last=min(first+9,n);directory=a.out/f'{first:02}-{last:02}'
    env=dict(os.environ,PW_FIRST_SCENE=str(first),PW_LAST_SCENE=str(last))
    result=subprocess.run(['python3',str(a.repo/'Testing/visual-features/run_fixture.py'),'--repo',str(a.repo),'--fixture',str(a.fixture),'--suite',str(a.repo/'Testing/night-lighting/capture.lua'),'--out',str(directory)],env=env,capture_output=True,text=True)
    (a.out/f'{first:02}-{last:02}.log').write_text(result.stdout+result.stderr)
    assert result.returncode==0,(directory,result.stdout[-1200:],result.stderr[-500:])
    print(f'PASS: scenes {first}-{last}',flush=True)
with ThreadPoolExecutor(max_workers=3) as pool:
    list(pool.map(run,range(1,n+1,10)))
