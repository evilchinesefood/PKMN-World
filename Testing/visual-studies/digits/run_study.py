#!/usr/bin/env python3
import argparse,os,shutil,subprocess,json
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--repo',type=Path,required=True);p.add_argument('--build',type=Path,required=True);p.add_argument('--out',type=Path,required=True);p.add_argument('--variant',choices=['baseline','digits','punctuation'],required=True);p.add_argument('--suite',default='capture');a=p.parse_args();root=Path(__file__).resolve().parent
lib=a.build/a.variant
for f in (a.repo/'Testing/lua').glob('*.lua'):
 if f.name!='symbols.lua':shutil.copy2(f,lib/f.name)
out=a.out/a.variant/a.suite;out.mkdir(parents=True,exist_ok=True)
for old in out.iterdir():
 if old.is_file() and old.suffix in ('.png','.log','.PASS','.FAIL'):old.unlink()
env=os.environ.copy();env.update(PW_STUDY_LIB=str(lib),PW_OUT=str(out),MGBA_HEADLESS=str(Path.home()/'.local/bin/mgba-headless'))
suite=root/(a.suite+'.lua') if a.suite in ('capture','calibration') else lib/(a.suite+'.lua')
cmd=['bash',str(a.repo/'Testing/mgba-run.sh'),str(suite),str(a.build/(a.variant+'.gba'))]
r=subprocess.run(cmd,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
(out/'runner.log').write_text(r.stdout);print(r.stdout);print('exit',r.returncode)
raise SystemExit(r.returncode)
