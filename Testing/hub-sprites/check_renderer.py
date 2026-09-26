#!/usr/bin/env python3
"""Black-box regression checks for publishing valid Hub review evidence."""
import argparse
from pathlib import Path
import subprocess,tempfile,shutil,json,os
from html.parser import HTMLParser
p=argparse.ArgumentParser();p.add_argument('--runs',type=Path,required=True);a=p.parse_args()
root=Path(__file__).resolve().parents[2];renderer=root/'Testing/hub-sprites/render_review.py';source=a.runs
with tempfile.TemporaryDirectory(prefix='pw-hub-renderer-check-') as tmp:
 tmp=Path(tmp);runs=tmp/'runs';shutil.copytree(source,runs)
 def run(out,env=None):return subprocess.run(['python3',str(renderer),'--runs',str(runs),'--out',str(out),'--before-source','before<&>','--after-source','after"revision'],capture_output=True,env=env)
 cases=[('failed baseline','before/HubSpritesComparison.log','VERDICT HubSpritesComparison: 29/30 PASS\n'),('zero-check baseline','before/HubSpritesComparison.log','VERDICT HubSpritesComparison: 0/0 PASS\n'),('zero-check feature','after/HubSpritesComparison.log','VERDICT HubSpritesComparison: 0/0 PASS\n'),('missing PASS','after/HubSpritesComparison.PASS',None),('conflicting FAIL','after/HubSpritesComparison.FAIL','FAIL\n'),('mismatched PASS count','after/HubSpritesComparison.PASS','PASS 1/1 rom='+'A'*32+' at=now suite=HubSpritesComparison\n'),('aborted runner with stale log and PASS','after/runner.log','ABORT: stale ROM\n')]
 for i,(name,rel,value) in enumerate(cases):
  path=runs/rel;old=path.read_bytes() if path.exists() else None
  if value is None:path.unlink()
  else:path.write_text(value,encoding='utf-8')
  out=tmp/('negative'+str(i));result=run(out)
  assert result.returncode!=0 and not out.exists(),(name,result.stderr.decode())
  if old is None:path.unlink()
  else:path.write_bytes(old)
  print('PASS:',name,'rejected before output')
 env=os.environ.copy();env.update(LC_ALL='C',PYTHONUTF8='0',PYTHONCOERCECLOCALE='0')
 package=tmp/'package';result=run(package/'review',env);assert result.returncode==0,result.stderr
 manifest=json.loads((package/'review/capture-sources.json').read_text());assert sum(manifest['checks'].values())==1980 and sum(manifest['baseline_checks'].values())==30
 text=(package/'review/index.html').read_text(encoding='utf-8');assert 'Pokémon' in text and '2×' in text and 'before&lt;&amp;&gt;' in text and 'after&quot;revision' in text
 shutil.copy2(root/'Testing/hub-sprites/README.md',package/'README.md');shutil.copytree(root/'Testing/hub-sprites/evidence',package/'evidence')
 class Links(HTMLParser):
  def handle_starttag(self,tag,attrs):
   for name,value in attrs:
    if name in ('href','src') and value and not value.startswith(('http:','https:','#')):
     assert (package/'review'/value).is_file(),value
 Links().feed(text)
 print('PASS: ASCII-locale process emits valid UTF-8 and escaped labels')
 print('PASS: baseline 30 separate from targeted 1980; 80 media generated')
 print('PASS: documented package layout resolves all HTML file links')
