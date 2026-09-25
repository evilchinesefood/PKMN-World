#!/usr/bin/env python3
"""Fetch only the pinned study inputs into a non-repository scratch cache."""
import argparse,concurrent.futures,hashlib,json,pathlib,urllib.request
HERE=pathlib.Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('--cache',type=pathlib.Path,required=True);a=p.parse_args();root=a.cache.resolve();repo=HERE.parents[2]
if root==repo or repo in root.parents:raise SystemExit('Donor cache must be outside the World repository.')
manifest=json.loads((HERE/'donor-manifest.json').read_text())
def fetch(entry):
 target=root/entry['path'];target.parent.mkdir(parents=True,exist_ok=True)
 if target.exists():data=target.read_bytes()
 else:
  request=urllib.request.Request('https://raw.githubusercontent.com/'+manifest['repo']+'/'+manifest['commit']+'/'+entry['path'],headers={'User-Agent':'PKMN-World-HnS-visual-study'});data=urllib.request.urlopen(request,timeout=40).read();target.write_bytes(data)
 digest=hashlib.sha256(data).hexdigest();git_digest=hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
 if digest!=entry['sha256'] or git_digest!=entry['gitBlobSha1']:raise RuntimeError('Pinned source hash mismatch: '+entry['path'])
 return len(data)
with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:counts=list(pool.map(fetch,manifest['files']))
print('Verified',len(counts),'pinned inputs,',sum(counts),'bytes in',root)
