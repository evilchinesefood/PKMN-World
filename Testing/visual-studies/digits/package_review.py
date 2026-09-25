#!/usr/bin/env python3
"""Package actual emulator output into a native/nearest-neighbor review page."""
import argparse,csv,hashlib,json,re,shutil
from pathlib import Path
from PIL import Image,ImageChops
p=argparse.ArgumentParser();p.add_argument('--build',type=Path,required=True);a=p.parse_args();root=Path(__file__).resolve().parent
j=json.loads((a.build/'manifest.json').read_text());shutil.copy2(a.build/'manifest.json',root/'manifest.json')
with (root/'glyph-audit.csv').open('w') as f:
 w=csv.writer(f);w.writerow(['font','code','advance_unchanged','current_ink_bbox','candidate_ink_bbox','changed_pixels','overhang'])
 for font in j['changes']:
  for g in font['glyphs']:w.writerow([font['font'],g['code'],g['advance'],g['current_bbox'],g['candidate_bbox'],g['changed_pixels'],g['overhang']])
variants=['baseline','digits','punctuation'];labels=['Current','A · digits only','B · digits + punctuation'];scenes=[];diffs=[]
base=root/'evidence/baseline/capture'
ordered=sorted(base.glob('*.png'))
featured=['summary_stats_slot4','summary_pp1_40_10_5','storage_narrower_name','bag_tm_info','summary_ivs31','summary_evs252_total510']
ordered=sorted(ordered,key=lambda f: (featured.index(re.sub(r'^DigitsStudy_\d+_','',f.stem)) if re.sub(r'^DigitsStudy_\d+_','',f.stem) in featured else 100,int(f.stem.split('_')[1])))
for f in ordered:
 suffix=re.sub(r'^DigitsStudy_\d+_','',f.stem)
 title={
  'summary_stats_slot4':'Summary — Lv.100, HP100/314',
  'summary_pp1_40_10_5':'Moves — PP1/35, 40/40, 10/20, 5/30',
  'storage_narrower_name':'PC — long nickname and Lv.100',
  'bag_tm_info':'Bag — PP, power and accuracy',
  'summary_long_move_name':'Moves — longest supported name',
  'summary_ivs31':'Summary — IV31',
  'summary_evs252_total510':'Summary — EV252 / 252 / 6',
  'bag_longest_item_name':'Bag — longest bundled item name',
  'summary_move_dash_state':'Moves — dash / no-power state',
  'bag_tm_dash_state':'Bag — dash / no-power state',
 }.get(suffix,suffix.replace('_',' '))
 paths=[str((root/f'evidence/{v}/capture'/f.name).relative_to(root)) for v in variants]
 scenes.append({'title':title,'paths':paths,'type':'Real menu'})
for suite,pattern,title,typ in [('calibration','*.png','All three font IDs — native renderer specimen','Diagnostic, not a gameplay menu'),('PromptSafetyEvIv','*eviv_page_ev.png','EV/IV editor — unchanged FONT_NORMAL control','Real menu / unchanged control')]:
 f=next((root/f'evidence/baseline/{suite}').glob(pattern))
 paths=[str((root/f'evidence/{v}/{suite}'/f.name).relative_to(root)) for v in variants]
 scenes.append({'title':title,'paths':paths,'type':typ})
for scene in scenes:
 images=[Image.open(root/f).convert('RGB') for f in scene['paths']]
 assert all(x.size==(240,160) for x in images)
 for v,im in zip(variants[1:],images[1:]):
  delta=ImageChops.difference(images[0],im)
  count=sum(p!=(0,0,0) for p in delta.getdata())
  diffs.append({'scene':scene['title'],'variant':v,'changed_pixels':count,'bbox':delta.getbbox()})
(root/'capture-diffs.json').write_text(json.dumps(diffs,indent=2)+'\n')
# Export only nearest-neighbor enlargements; native images remain unmodified.
zoom=root/'4x';zoom.mkdir(exist_ok=True)
for old in zoom.glob('*.png'):old.unlink()
for scene in scenes:
 for v,path in zip(variants,scene['paths']):
  Image.open(root/path).resize((960,640),Image.Resampling.NEAREST).save(zoom/f'{v}_{Path(path).name}')
# Labeled strip made by cropping the actual emulator specimen, never browser fonts.
strip=Image.new('RGB',(3*240,80),'white')
for i,v in enumerate(variants):
 f=next((root/f'evidence/{v}/calibration').glob('*.png'))
 strip.paste(Image.open(f).crop((0,16,240,96)),(i*240,0))
strip.save(root/'glyph-strip-native.png');strip.resize((2880,320),Image.Resampling.NEAREST).save(root/'glyph-strip-4x.png')
results=[]
for v in variants:
 for suite in ['capture','calibration','VerifyBagLayout','PromptSafetyEvIv','VerifyPCScreen']:
  log=(root/f'evidence/{v}/{suite}/runner.log').read_text()
  match=re.search(r'VERDICT (.*?): (\d+)/(\d+) (PASS|FAIL)',log)
  assert match and match[4]=='PASS',f'{v} {suite} missing PASS'
  results.append({'variant':v,'suite':match[1],'passed':int(match[2]),'total':int(match[3]),'rom_md5':j['roms'][v]['md5']})
(root/'results.json').write_text(json.dumps(results,indent=2)+'\n')
data=json.dumps(scenes)
html='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Pokémon World · compact digits study</title><style>
:root{color-scheme:dark}body{font:16px/1.5 system-ui,sans-serif;margin:auto;padding:28px;max-width:1200px;background:#131923;color:#eff4fb}h1{font-size:28px;margin:0 0 8px}p{max-width:850px;color:#c3ccda}.note{background:#202b39;padding:14px 18px;border-left:3px solid #95c4ff;border-radius:5px}.tools{display:flex;gap:10px;flex-wrap:wrap;align-items:center;margin:20px 0}button,select{font:inherit;color:#eff4fb;background:#2a394d;border:1px solid #71829a;border-radius:6px;padding:8px 12px;cursor:pointer}button[aria-pressed=true]{background:#37638e}a{color:#9dccff}.frames{display:flex;gap:20px;overflow:auto;padding-bottom:16px}.frame{flex:0 0 auto;margin:0}.frame figcaption{margin:0 0 8px;font-weight:650}.frame img{display:block;image-rendering:pixelated;width:240px;height:160px;border:1px solid #637087}.zoom .frame img{width:960px;height:640px}.subtitle{color:#bbc9dc;font-size:14px}details{margin:24px 0;padding:14px;background:#1b2532}summary{cursor:pointer}code{font-size:13px}.strip{max-width:100%;image-rendering:pixelated}footer{font-size:14px;border-top:1px solid #53647c;margin-top:30px;padding-top:14px}
</style><h1>Compact digits: keep current, or use A?</h1><p>These are actual Pokémon World emulator captures at 240×160. A changes only the digits; B also changes the period, slash and colon. No production font binding changed.</p><div class="note"><strong>Recommendation: keep current.</strong> A is a reasonable subtler alternative, but its digits are one pixel shorter and do not clearly improve native-size readability. B also shifts punctuation and changes ordinary labels; it adds no clear benefit. Start with the first three scenes for a two-minute review.</div><div class="tools"><label for="scene">Scene</label><select id="scene"></select><button id="prev">Previous</button><button id="next">Next</button><button id="native" aria-pressed="true">Native 1×</button><button id="zoom" aria-pressed="false">Nearest-neighbor 4×</button></div><p id="kind" class="subtitle"></p><div class="frames" id="frames"></div><p id="caption" class="subtitle"></p>
<details><summary>What changed, and what stayed identical?</summary><p>All three compact font variants keep their original advances: SHORT 6px, SHORT_NARROW 5px and SHORT_NARROWER 4px for digits. Ink/shadow height drops from 10px to 9px. A changes 156 bytes across thirty glyph cells. All other glyphs, normal/small fonts, width tables and engine code are identical between capture ROMs. B changes 355 bytes across thirty-nine whitelisted cells.</p><p>The strip below crops the native emulator specimen. Columns: current / A / B. Rows: SHORT, SHORT_NARROW, SHORT_NARROWER, then unchanged NORMAL symbols. Diagnostic numeric strings include 999 and 252/510; no impossible Pokémon HP stats were invented.</p><img class="strip" src="glyph-strip-native.png" width="720" height="80" alt="Native emulator glyph strip: current, digits only, digits and punctuation"><p><a href="glyph-strip-4x.png">Open 4× glyph strip</a> · <a href="glyph-audit.csv">Per-glyph audit</a> · <a href="font-call-sites.txt">Actual source call sites</a> · <a href="capture-diffs.json">Pixel differences</a></p></details>
<details><summary>Evidence and scope</summary><p>Each variant passed: study flows 12/12, renderer calibration 1/1, VerifyBagLayout 23/23, PromptSafetyEvIv 30/30, and VerifyPCScreen 10/10 — 228 assertions across three variants. The editor is an unchanged FONT_NORMAL control. VerifyPCScreen tests the building PC, while the separate study driver exercises actual storage UI and summary return flows.</p><p>Baseline: 45e1bf82, current SwSh UI, before #328. The owner explicitly authorized doing this study now. Refresh the final control captures if #328 or selected BW #336 materially changes these surfaces. BW outlined fonts and production font-ID work are excluded.</p><p><a href="README.md">Report and reproduction</a> · <a href="manifest.json">ROM and glyph manifest</a> · <a href="results.json">Test results</a></p></details><footer>Test-only fixtures and font candidates live outside production. Use normal native size for the visual decision; 4× is for inspecting pixels. The agent owns all setup and testing.</footer><script>
const scenes=SCENEDATA;const labels=['Current','A · digits only','B · digits + punctuation'];const sel=document.querySelector('#scene'),frames=document.querySelector('#frames');for(let i=0;i<scenes.length;i++){const o=document.createElement('option');o.value=i;o.textContent=(i+1)+'. '+scenes[i].title;sel.append(o)}function render(){let s=scenes[+sel.value];document.querySelector('#kind').textContent=s.type;frames.innerHTML='';s.paths.forEach((p,i)=>{const f=document.createElement('figure');f.className='frame';const c=document.createElement('figcaption');c.textContent=labels[i];const a=document.createElement('a');a.href=p;a.target='_blank';const im=document.createElement('img');im.src=p;im.alt=labels[i]+': '+s.title;im.width=240;im.height=160;a.append(im);f.append(c,a);frames.append(f)});document.querySelector('#caption').textContent='Click an image to open its original native-resolution PNG.'}sel.onchange=render;document.querySelector('#prev').onclick=()=>{sel.value=(+sel.value+scenes.length-1)%scenes.length;render()};document.querySelector('#next').onclick=()=>{sel.value=(+sel.value+1)%scenes.length;render()};function zoom(on){frames.classList.toggle('zoom',on);document.querySelector('#zoom').setAttribute('aria-pressed',on);document.querySelector('#native').setAttribute('aria-pressed',!on)}document.querySelector('#zoom').onclick=()=>zoom(true);document.querySelector('#native').onclick=()=>zoom(false);render();
</script></html>'''.replace('SCENEDATA',data)
(root/'index.html').write_text(html)
print('Packaged',len(scenes),'scenes; assertions',sum(r['passed'] for r in results))
