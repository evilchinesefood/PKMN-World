#!/usr/bin/env python3
"""Publish native emulator comparisons only after verifying their run provenance."""
import argparse
import hashlib
import html
import json
from pathlib import Path
import re
import shutil

from PIL import Image


def digest(path, algorithm='sha256'):
    return hashlib.new(algorithm, path.read_bytes()).hexdigest()


def passed(directory, md5):
    logs = [p for p in directory.glob('*.log') if p.name != 'runner.log']
    assert len(logs) == 1, directory
    verdict = logs[0].read_text().strip().splitlines()[-1]
    match = re.fullmatch(r'VERDICT ([^:]+): (\d+)/(\d+) PASS', verdict)
    assert match and int(match[2]) == int(match[3]) > 0, directory
    assert not list(directory.glob('*.FAIL')), directory
    stamp = (directory/f'{match[1]}.PASS').read_text().strip()
    assert re.fullmatch(rf'PASS {match[2]}/{match[3]} rom={md5.upper()} at=\S+ suite={match[1]}', stamp), directory
    assert (directory/'runner.log').read_text().strip().splitlines()[-1] == verdict, directory
    return int(match[2])


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ('repo', 'before', 'after', 'before-fixture', 'after-fixture',
                 'lifecycle', 'lifecycle-fixture', 'regression', 'data-audit',
                 'delivery', 'out'):
        p.add_argument('--'+name, type=Path, required=True)
    a = p.parse_args()
    here = a.repo/'Testing/night-lighting'
    scenes = json.loads((here/'scenes.json').read_text())
    fixtures = {key: json.loads((getattr(a, key+'_fixture')/'manifest.json').read_text())
                for key in ('before', 'after', 'lifecycle')}
    source = digest(here/'fixture.c')
    assert fixtures['before']['fixture_source_sha256'] == fixtures['after']['fixture_source_sha256'] == source
    assert fixtures['lifecycle']['fixture_source_sha256'] == digest(here/'lifecycle_fixture.c')
    assert fixtures['after']['input_rom_sha256'] == fixtures['lifecycle']['input_rom_sha256'] == digest(a.delivery)
    fixture_md5 = {}
    for key, manifest in fixtures.items():
        rom = getattr(a, key+'_fixture')/'VerifyFeatures.gba'
        assert digest(rom) == manifest['fixture_rom_sha256']
        fixture_md5[key] = digest(rom, 'md5')
    counts = {'lifecycle': passed(a.lifecycle, fixture_md5['lifecycle'])}
    for key in ('before', 'after'):
        counts[key] = sum(passed(getattr(a, key)/f'{first:02}-{min(first+9,len(scenes)):02}', fixture_md5[key])
                          for first in range(1, len(scenes)+1, 10))
    sweep = (a.regression/'sweep.log').read_text()
    md5 = digest(a.delivery, 'md5').upper()
    assert f'SWEEP OK - every expected suite produced a fresh PASS stamped rom={md5}' in sweep
    suite_rows = re.findall(r'^(\S+)\s+rc=0\s+VERDICT \S+: (\d+)/(\d+) PASS$', sweep, re.M)
    assert len(suite_rows) == 50 and all(x == y for _, x, y in suite_rows)
    assert not list(a.regression.glob('*.FAIL'))
    for name, n, _ in suite_rows:
        assert f'PASS {n}/{n} rom={md5} ' in (a.regression/f'{name}.PASS').read_text()
    counts['regression_suites'] = len(suite_rows)
    counts['regression_assertions'] = sum(int(n) for _, n, _ in suite_rows)
    audit = json.loads(a.data_audit.read_text())
    assert len(audit['towns']) == len(scenes) == 49 and audit['new_lamps'] == 71
    a.out.mkdir(parents=True, exist_ok=True)
    media = a.out/'media'
    media.mkdir(exist_ok=True)
    records = []

    def copy_native(source, target):
        with Image.open(source) as im:
            assert im.size == (240, 160), source
            im.verify()
        shutil.copyfile(source, media/target)
        records.append({'file': 'media/'+target, 'sha256': digest(source)})

    for i, scene in enumerate(scenes):
        batch = f'{i//10*10+1:02}-{min(i//10*10+10,len(scenes)):02}'
        for t, time in enumerate(('noon', 'dusk', 'night')):
            tag = scene['name']+'_'+time
            filename = f'RegionalLightingCapture_{(i%10)*3+t+1:02}_{tag}.png'
            for side in ('before', 'after'):
                copy_native(getattr(a, side)/batch/filename, f'{side}_{tag}.png')
    for n, region in enumerate(('Hoenn', 'Kanto', 'Johto', 'Dock'), 1):
        copy_native(a.lifecycle/f'RegionalLightingLifecycle_{n:02}_{region}_lamp_front.png', f'lamp_{region}.png')
    shutil.copyfile(a.data_audit, a.out/'data-audit.json')
    shutil.copyfile(a.regression/'sweep.log', a.out/'regression.log')
    evidence = a.out/'verification'
    evidence.mkdir(exist_ok=True)
    for side in ('before', 'after'):
        for directory in sorted(getattr(a, side).iterdir()):
            if directory.is_dir():
                for name in ('RegionalLightingCapture.PASS', 'RegionalLightingCapture.log'):
                    shutil.copyfile(directory/name, evidence/f'{side}_{directory.name}_{name}')
    for name in ('RegionalLightingLifecycle.PASS', 'RegionalLightingLifecycle.log'):
        shutil.copyfile(a.lifecycle/name, evidence/name)
    manifest = {'baseline_commit': '017a59de342ce5d8244144260da197b89f1239a0',
                'delivery_md5': md5, 'delivery_sha256': digest(a.delivery),
                'fixtures': fixtures, 'checks': counts, 'images': records}
    (a.out/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
    names = {'frlg': 'Kanto + Sevii', 'emerald': 'Hoenn', 'johto': 'Johto'}

    def label(name):
        return re.sub(r'(?<=[a-z])(?=[A-Z])', ' ', name.removesuffix('_Frlg')).replace('_', ' ')

    def pair(scene):
        name = scene['name']
        return '<div class="pair">'+''.join(
            f'<figure><img loading="lazy" width="240" height="160" data-side="{side}" data-scene="{name}" src="media/{side}_{name}_night.png" alt="{side.title()} {html.escape(label(name))}"><figcaption>{side.title()}</figcaption></figure>'
            for side in ('before', 'after'))+'</div>'

    highlights = ['CherrygroveCity', 'LittlerootTown', 'CeladonCity_Frlg']
    cards = ''.join(f'<article><h2>{label(name)}</h2>{pair(next(s for s in scenes if s["name"]==name))}</article>' for name in highlights)
    all_maps = ''
    for key, region in names.items():
        details = ''.join(f'<details><summary>{label(s["name"])}</summary>{pair(s)}</details>' for s in scenes if s['region']==key)
        all_maps += f'<details class="region"><summary>{region} · {sum(s["region"]==key for s in scenes)} maps</summary>{details}</details>'
    lamps = ''.join(f'<figure><img loading="lazy" width="240" height="160" src="media/lamp_{region}.png" alt="{region} lamp"><figcaption>{region if region!="Dock" else "Pacifidlog dock light"}</figcaption></figure>' for region in ('Hoenn', 'Kanto', 'Johto', 'Dock'))
    (a.out/'index.html').write_text(f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Pokémon World · regional night lighting</title><style>
*{{box-sizing:border-box}}body{{background:#111b28;color:#e9eff5;font:16px/1.5 system-ui;margin:0 auto;padding:24px;max-width:1080px}}h1{{font-size:28px;margin-bottom:8px}}h2{{font-size:20px}}p{{max-width:850px}}a{{color:#a8d9ff}}.muted,figcaption{{color:#b7c7d8}}nav{{position:sticky;top:0;background:#111b28f5;padding:12px 0;z-index:1;border-bottom:1px solid #405368}}button{{font:inherit;padding:8px 18px;color:inherit;background:#22334b;border:1px solid #5e748c;border-radius:6px;cursor:pointer;margin-right:8px}}button[aria-pressed=true]{{background:#cbe3fa;color:#112133}}.pair,.lamps{{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:16px}}figure{{margin:8px 0}}img{{display:block;width:480px;max-width:100%;height:auto;image-rendering:pixelated;background:#000}}details{{padding:12px 0;border-top:1px solid #405368}}summary{{cursor:pointer;font-weight:600}}.region>details{{margin-left:16px}}article{{padding:8px 0 16px}}@media(max-width:600px){{.pair,.lamps{{grid-template-columns:1fr}}body{{padding:16px}}}}:focus-visible{{outline:3px solid #ffd78c;outline-offset:3px}}
</style></head><body>
<h1>Regional night lighting</h1>
<p>49 town and city maps now have lit building details and street fixtures across Johto, Hoenn, Kanto and Sevii. There are 71 new lamps or lanterns; five Johto cities retain their existing networks. All artwork comes from the repo.</p>
<p><strong>Five-minute review:</strong> compare the three scenes below at night and dusk, then check the lamp examples. Judge warmth and placement. Doors, collisions, menus, battle returns and saves have already been checked automatically.</p>
<nav aria-label="Time of day"><button data-time="noon" aria-pressed="false">Day</button><button data-time="dusk" aria-pressed="false">Dusk</button><button data-time="night" aria-pressed="true">Night</button><span id="time-label" aria-live="polite">22:00</span></nav>
{cards}
<h2>Street fixtures · night</h2><p class="muted">Modern lamps reuse Olivine artwork; Johto uses Blackthorn lanterns. Pacifidlog gets a small dock light that leaves the walkway open. These four views stay at night.</p><div class="lamps">{lamps}</div>
<details><summary>Optional · every town and city map</summary><p>The time control also applies here. The 49-map count includes both Indigo Plateau exteriors, Saffron's connection map, Lake of Rage, Mt. Silver and Safari Zone Gate.</p>{all_maps}</details>
<details><summary>What changed and what was verified</summary>
<p>Shared glass colors are isolated from roofs, water and walls before the existing day/night system warms them. Daytime source art is unchanged except for the new fixtures. Town tilesets are shared by some surrounding routes, so those routes inherit compatible window lighting.</p>
<p>This is a first coverage pass, not a claim that every decorative pane is lit. Existing unlit panels and special structures remain where their colors cannot safely be shared. The fixtures have bright bulbs, without new pools of light on the ground.</p>
<p>All screenshots are native 240×160 emulator captures with synthetic saves, shown with nearest-neighbor scaling. NPC positions and animation frames may differ between builds; static checks separately verify {audit['daylight_metatiles_verified']:,} original daytime metatile renderings. Intro props visible in Littleroot belong to the synthetic setup.</p>
<p>{counts['before']+counts['after']+counts['lifecycle']} focused assertions passed, plus {counts['regression_suites']} full regression suites ({counts['regression_assertions']:,} assertions). The National Park test's unsafe manual sprite deletion was corrected; no encounter code changed.</p>
<p><a href="manifest.json">Capture provenance</a> · <a href="data-audit.json">Map and placement checks</a> · <a href="regression.log">Full regression result</a></p>
<p class="muted">Tested development ROM: {md5}. Disposable capture hooks are absent from the playtest ROM.</p></details>
<script>
document.querySelectorAll('button[data-time]').forEach(button=>button.addEventListener('click',()=>{{
 const time=button.dataset.time;
 document.querySelectorAll('button[data-time]').forEach(b=>b.setAttribute('aria-pressed',String(b===button)));
 document.querySelectorAll('img[data-scene]').forEach(img=>img.src=`media/${{img.dataset.side}}_${{img.dataset.scene}}_${{time}}.png`);
 document.querySelector('#time-label').textContent={{noon:'12:00',dusk:'20:00',night:'22:00'}}[time];
}}));
</script></body></html>''')
    print(f'PASS: {len(records)} verified native images; {counts}')


if __name__ == '__main__':
    main()
