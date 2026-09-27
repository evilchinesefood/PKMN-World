#!/usr/bin/env python3
"""Publish the Viridian comparison only with verified source and runtime proof."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import shutil
import struct
import subprocess
import tempfile

from PIL import Image

import art
from run_suite import verify_run

spec = importlib.util.spec_from_file_location('lighting_review', art.REPO/'Testing/night-lighting/render_review.py')
lighting_review = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lighting_review)
SCENES = [('west_entry', 'West approach'), ('pond_walk', 'Pond-side garden'),
          ('eastern_garden', 'Eastern garden'), ('northeast_verge', 'Northeast verge'),
          ('southern_verge', 'Southern flower clusters')]


def digest(path, kind='sha256'):
    return hashlib.new(kind, path.read_bytes()).hexdigest()


def rom_assets(rom_path, elf_path, blobs):
    output = subprocess.check_output(['/opt/devkitpro/devkitARM/bin/arm-none-eabi-nm', '-S', str(elf_path)], text=True)
    symbols = {p[-1]: int(p[0], 16) for line in output.splitlines()
               if len(p := line.split()) >= 3 and re.fullmatch('[0-9a-fA-F]+', p[0])}
    rom = rom_path.read_bytes()
    pointer = struct.unpack_from('<I', rom, symbols['ViridianCity_Layout']-0x08000000+12)[0]
    addresses = {art.MAP: pointer, art.META: symbols['gMetatiles_ViridianCity'],
                 art.ATTR: symbols['gMetatileAttributes_ViridianCity']}
    for path, address in addresses.items():
        offset = address-0x08000000
        assert 0 <= offset <= len(rom)-len(blobs[path]), (path, address)
        assert rom[offset:offset+len(blobs[path])] == blobs[path], ('ROM/source mismatch', path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('before-rom', 'before-elf', 'delivery', 'delivery-elf', 'before-fixture',
                 'after-fixture', 'before', 'after', 'lifecycle', 'delivery-run', 'regression', 'out'):
        parser.add_argument('--'+name, type=Path, required=True)
    args = parser.parse_args()
    assert digest(args.before_rom) == art.PLAN['baseline_rom_sha256'], 'not the pinned baseline ROM'
    generated, edits = art.expected()
    rom_assets(args.before_rom, args.before_elf, {p: art.original(p) for p in generated})
    rom_assets(args.delivery, args.delivery_elf, generated)
    fixtures, fixture_md5, counts = {}, {}, {}
    for side, rom in (('before', args.before_rom), ('after', args.delivery)):
        directory = getattr(args, side+'_fixture')
        fixtures[side] = json.loads((directory/'manifest.json').read_text())
        assert fixtures[side]['input_rom_sha256'] == digest(rom)
        assert fixtures[side]['fixture_source_sha256'] == digest(art.HERE/'fixture.c')
        assert fixtures[side]['fixture_rom_sha256'] == digest(directory/'VerifyFeatures.gba')
        fixture_md5[side] = digest(directory/'VerifyFeatures.gba', 'md5')
        verify_run(getattr(args, side), art.HERE/'capture.lua', directory/'VerifyFeatures.gba')
        counts[side] = lighting_review.passed(getattr(args, side), fixture_md5[side], 'ViridianArtCapture')
    verify_run(args.lifecycle, art.HERE/'lifecycle.lua', args.after_fixture/'VerifyFeatures.gba')
    verify_run(args.delivery_run, art.HERE/'delivery.lua', args.delivery)
    counts['lifecycle'] = lighting_review.passed(args.lifecycle, fixture_md5['after'], 'ViridianArtLifecycle')
    md5 = digest(args.delivery, 'md5').upper()
    counts['delivery'] = lighting_review.passed(args.delivery_run, md5, 'ViridianArtDelivery', require_runner_log=False)
    assert counts == {'before': 45, 'after': 45, 'lifecycle': 39, 'delivery': 3}
    sweep = (args.regression/'sweep.log').read_text()
    assert f'SWEEP OK - every expected suite produced a fresh PASS stamped rom={md5}' in sweep
    rows = re.findall(r'^(\S+)\s+rc=0\s+VERDICT (\S+): (\d+)/(\d+) PASS$', sweep, re.M)
    assert len(rows) == len({r[0] for r in rows}) == 50
    assert not list(args.regression.glob('*.FAIL'))
    for name, suite, passed, total in rows:
        assert name == suite and int(passed) == int(total) > 0
        assert re.fullmatch(rf'PASS {passed}/{total} rom={md5} at=\S+ suite={name}\s*',
                            (args.regression/(name+'.PASS')).read_text())
    counts['regression_suites'] = len(rows)
    counts['regression_assertions'] = sum(int(r[2]) for r in rows)
    images = []
    for i, (name, _) in enumerate(SCENES):
        for t, time in enumerate(('noon', 'dusk', 'night')):
            palettes = []
            for side in ('before', 'after'):
                directory = getattr(args, side)
                path = directory/f'ViridianArtCapture_{i*3+t+1:02}_{name}_{time}.png'
                with Image.open(path) as image:
                    assert image.size == (240, 160), path
                    image.verify()
                images.append((path, f'{side}_{name}_{time}.png'))
                palettes.append((directory/f'{name}_{time}.pal.bin').read_bytes())
            assert len(palettes[0]) == 512 and palettes[0] == palettes[1], ('palette changed', name, time)
    actors = args.lifecycle/'ViridianArtLifecycle_01_actors_on_flowers.png'
    with Image.open(actors) as image:
        assert image.size == (240, 160)
        image.verify()
    with tempfile.TemporaryDirectory(prefix='viridian-audit-') as tmp:
        audit_dir = Path(tmp)
        art.check(audit_dir)
        audit = json.loads((audit_dir/'audit.json').read_text())
        args.out.mkdir(parents=True, exist_ok=True)
        for path in audit_dir.iterdir():
            shutil.copyfile(path, args.out/path.name)
    media = args.out/'media'
    media.mkdir(exist_ok=True)
    records = []
    for source, name in images:
        shutil.copyfile(source, media/name)
        records.append(dict(file='media/'+name, sha256=digest(source)))
    verification = args.out/'verification'
    verification.mkdir(exist_ok=True)
    shutil.copyfile(actors, verification/'actors-on-flowers.png')
    for key, directory, suite in (('before', args.before, 'ViridianArtCapture'),
                                  ('after', args.after, 'ViridianArtCapture'),
                                  ('lifecycle', args.lifecycle, 'ViridianArtLifecycle'),
                                  ('delivery', args.delivery_run, 'ViridianArtDelivery')):
        shutil.copyfile(directory/'run-provenance.json', verification/(key+'_run-provenance.json'))
        for suffix in ('log', 'PASS'):
            shutil.copyfile(directory/(suite+'.'+suffix), verification/(key+'_'+suite+'.'+suffix))
    shutil.copyfile(args.regression/'sweep.log', args.out/'regression.log')
    (args.out/'regression-sentinels.txt').write_text(''.join((args.regression/(r[0]+'.PASS')).read_text() for r in rows))
    shutil.copyfile(art.HERE/'edits.json', args.out/'edits.json')
    manifest = dict(baseline_commit=art.BASE, before_sha256=digest(args.before_rom),
                    delivery_md5=md5, delivery_sha256=digest(args.delivery), fixtures=fixtures,
                    checks=counts, unchanged_runtime_palette_snapshots=15, images=records,
                    actor_layering_image=dict(file='verification/actors-on-flowers.png', sha256=digest(actors)),
                    fixture_sha256=digest(art.HERE/'fixture.c'),
                    capture_script_sha256=digest(art.HERE/'capture.lua'),
                    lifecycle_script_sha256=digest(art.HERE/'lifecycle.lua'),
                    delivery_script_sha256=digest(art.HERE/'delivery.lua'))
    (args.out/'manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
    write_html(args.out, audit, counts)
    print(f'PASS: published {len(records)} native images; {counts}')


def write_html(out, audit, counts):
    def pair(name):
        return '<div class="pair">'+''.join(
            f'<figure><figcaption>{side.title()}</figcaption><img width="240" height="160" data-side="{side}" data-scene="{name}" src="media/{side}_{name}_noon.png" alt="{side.title()} {name.replace("_", " ")}"></figure>'
            for side in ('before', 'after'))+'</div>'
    labels = dict(SCENES)
    hero = ''.join(f'<article><h2>{labels[name]}</h2>{pair(name)}</article>'
                   for name in ('eastern_garden', 'west_entry', 'pond_walk'))
    extra = ''.join(f'<h2>{labels[name]}</h2>{pair(name)}'
                    for name in ('northeast_verge', 'southern_verge'))
    (out/'index.html').write_text(f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Viridian gardens · before and after</title><style>
*{{box-sizing:border-box}}body{{margin:0;background:#101c20;color:#e9f0e9;font:17px/1.55 system-ui,sans-serif}}
main{{max-width:1080px;margin:0 auto;padding:28px 20px 64px}}h1{{font-size:clamp(28px,5vw,43px);line-height:1.15;margin:10px 0}}
h2{{font-size:22px;margin:0 0 12px}}p{{max-width:850px}}a{{color:#b5dfb8}}.eyebrow{{color:#a9bcae;font-size:14px;letter-spacing:.08em;text-transform:uppercase}}
.controls{{position:sticky;top:0;z-index:2;background:#101c20ee;padding:13px 0;display:flex;gap:10px;backdrop-filter:blur(8px)}}
button{{font:inherit;border:1px solid #506558;border-radius:8px;padding:8px 20px;background:#25382c;color:inherit;cursor:pointer}}
button[aria-pressed=true]{{background:#c9e8b0;color:#142416;border-color:#c9e8b0}}button:focus-visible,a:focus-visible{{outline:3px solid #efcf75;outline-offset:4px}}
article,details{{margin:22px 0;padding:20px;border:1px solid #3b5145;border-radius:12px;background:#192a23}}
.pair{{display:grid;grid-template-columns:1fr 1fr;gap:16px}}figure{{margin:0;min-width:0}}figcaption{{color:#b9cabe;margin:0 0 7px}}
img{{display:block;width:100%;height:auto;image-rendering:pixelated;background:#0b1711}}summary{{cursor:pointer;font-weight:650}}
details[open] summary{{margin-bottom:18px}}.muted{{color:#b0c3b6;font-size:15px}}code{{overflow-wrap:anywhere}}
@media(max-width:620px){{main{{padding:18px 12px}}.pair{{grid-template-columns:1fr}}article,details{{padding:12px}}button{{padding:7px 15px}}}}
</style></head><body><main>
<div class="eyebrow">Pokémon World · Viridian City · issue #346</div>
<h1>Small gardens, clearer composition</h1>
<p>Existing Kanto flowers and mown-grass tiles now form grouped gardens at the west entrance, pond and eastern green. The southern flowers form separated clusters. This is the first of three map-art stages.</p>
<p class="muted">Five-minute review: compare these three views in daylight, then switch to night. Judge the grouping, spacing and readability around the player and follower.</p>
<div class="controls" role="group" aria-label="Time of day"><button type="button" data-time="noon" aria-pressed="true">Day</button><button type="button" data-time="dusk" aria-pressed="false">Dusk</button><button type="button" data-time="night" aria-pressed="false">Night</button></div>
{hero}
<details><summary>Two more views</summary>{extra}</details>
<details><summary>Whole-map composition · source renders</summary><p class="muted">These are source-map renders without actors. The comparisons above are native 240×160 emulator captures.</p>
<div class="pair"><figure><figcaption>Before</figcaption><img src="source-before.png" alt="Full original Viridian map"></figure><figure><figcaption>After</figcaption><img src="source-after.png" alt="Full landscaped Viridian map"></figure></div></details>
<details><summary>Verification and exact scope</summary>
<p>{audit['changed_cells']} map cells changed. {audit['appended_metatiles']} local compositions reuse existing tile words; bitmap art and palettes are unchanged.</p>
<p>All 1,920 cells preserve collision, elevation and nonvisual attributes. {audit['protected_cells_verified']} protected gameplay cells are untouched. All five door approaches and three entrances keep the same walking component. Four routes sharing this tileset render identically.</p>
<p>{counts['before']+counts['after']+counts['lifecycle']+counts['delivery']} focused assertions passed, plus {counts['regression_suites']} full regression suites ({counts['regression_assertions']:,} assertions). All 15 paired runtime background-palette snapshots match. The prepared save also passes on the unpatched delivery ROM.</p>
<p><a href="manifest.json">ROM and capture provenance</a> · <a href="audit.json">Map audit</a> · <a href="edits.json">Exact tile edits</a> · <a href="regression.log">Full regression result</a> · <a href="verification/actors-on-flowers.png">Player and follower on flowers</a></p>
<p class="muted">The fixture creates a synthetic later-story state for ordinary entry/exit checks; it is absent from the delivery ROM. The existing catch-tutorial regression separately exercises the early-story sequence.</p></details>
<p class="muted">Next: <a href="https://github.com/evilchinesefood/PKMN-World/issues/347">#347 path transitions</a>, then <a href="https://github.com/evilchinesefood/PKMN-World/issues/348">#348 building frontages</a>.</p>
</main><script>
document.querySelectorAll('button[data-time]').forEach(button=>button.addEventListener('click',()=>{{
document.querySelectorAll('button[data-time]').forEach(b=>b.setAttribute('aria-pressed',String(b===button)));
document.querySelectorAll('img[data-scene]').forEach(img=>img.src=`media/${{img.dataset.side}}_${{img.dataset.scene}}_${{button.dataset.time}}.png`);
}}));
</script></body></html>''')


if __name__ == '__main__':
    main()
