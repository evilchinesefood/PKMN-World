#!/usr/bin/env python3
"""Publish real emulator captures at native resolution with integer-scale viewing."""
import argparse
import hashlib
import html
import json
import re
import shutil
from pathlib import Path
from PIL import Image

p = argparse.ArgumentParser()
p.add_argument('--before', type=Path, required=True)
p.add_argument('--after', type=Path, required=True)
p.add_argument('--out', type=Path, required=True)
a = p.parse_args()
media = a.out/'media'
media.mkdir(parents=True, exist_ok=True)
manifest = []

def shot(root, suffix, name):
    files = list(root.glob('*_' + suffix + '.png'))
    assert len(files) == 1, (root, suffix, files)
    im = Image.open(files[0])
    assert im.size == (240, 160)
    dest = media/(name + '.png')
    shutil.copy2(files[0], dest)
    manifest.append({'file': str(dest.relative_to(a.out)), 'source': files[0].name,
                     'sha256': hashlib.sha256(dest.read_bytes()).hexdigest()})
    return str(dest.relative_to(a.out))

def clip(root, tag, name):
    files = sorted(root.glob('*_' + tag + '_*.png'),
                   key=lambda f: int(f.stem.rsplit('_', 1)[1]))
    assert files, (root, tag)
    frames = [Image.open(f).convert('RGB') for f in files]
    dest = media/(name + '.webp')
    frames[0].save(dest, save_all=True, append_images=frames[1:], duration=50,
                   loop=0, lossless=True, method=6)
    # WebP may coalesce equal adjacent frames. Verify every decoded frame's
    # pixels and duration against the original 20 fps emulator timeline.
    decoded = Image.open(dest)
    elapsed = 0
    for i in range(decoded.n_frames):
        decoded.seek(i)
        frame = decoded.convert('RGB')
        count = decoded.info.get('duration', 50)//50
        for j in range(count):
            assert frame.tobytes() == frames[elapsed+j].tobytes(), (name, i, j)
        elapsed += count
    assert elapsed == len(frames), (name, elapsed, len(frames))
    manifest.append({'file': str(dest.relative_to(a.out)), 'frames': len(frames),
                     'duration_ms': len(frames)*50, 'lossless_verified': True,
                     'sha256': hashlib.sha256(dest.read_bytes()).hexdigest()})
    return str(dest.relative_to(a.out))

def palettes(root):
    text = (root/'BattlePaletteCapture.log').read_text()
    return {(m[1], m[2]): m[3] for m in re.finditer(r'^(PALETTE|UI|OBJ|ENVIRONMENT) (\w+) (.+)$', text, re.M)}

before, after = palettes(a.before), palettes(a.after/'capture')
checks = []
for key, value in after.items():
    if key[0] in ('UI', 'OBJ', 'ENVIRONMENT'):
        checks.append({'check': 'unchanged ' + ' '.join(key), 'pass': value == before[key]})
for name in ('hoenn_day', 'johto_day', 'kanto_day', 'granite'):
    checks.append({'check': 'unchanged background ' + name,
                   'pass': after['PALETTE', name] == before['PALETTE', name]})
for name in ('hoenn', 'johto', 'kanto'):
    checks.append({'check': name + ' night differs from day',
                   'pass': after['PALETTE', name+'_night'] != after['PALETTE', name+'_day']})
assert all(c['pass'] for c in checks), checks
(a.out/'comparisons.json').write_text(json.dumps(checks, indent=2)+'\n')

parts = ['''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Pokémon World · Battle scenery #327</title><style>
:root{--scale:2;color-scheme:dark}*{box-sizing:border-box}body{margin:0;background:#111923;color:#edf2f7;font:16px/1.55 system-ui,sans-serif}main{max-width:1100px;margin:auto;padding:28px 24px 70px}h1{font-size:30px;line-height:1.2}h2{margin-top:48px}h3{margin-bottom:8px}a{color:#8fdcff}p{max-width:850px}.muted{color:#aebfce}.bar{position:sticky;top:0;background:#111923ee;padding:12px 0;z-index:2;display:flex;gap:14px;align-items:center;flex-wrap:wrap}button{background:#243a50;color:white;border:1px solid #7293ae;border-radius:6px;padding:7px 13px;cursor:pointer}.pair,.grid{display:flex;gap:16px;flex-wrap:wrap}.pair{overflow:auto;flex-wrap:nowrap}figure{margin:0 0 12px;flex:none}figcaption{font-size:14px;color:#afc7dd;margin:4px 0}.game{display:block;width:calc(240px * var(--scale));height:calc(160px * var(--scale));image-rendering:pixelated;background:black;border:0}.field{width:240px;height:160px}.card{padding:16px;background:#1a2735;border-radius:12px;margin:16px 0}summary{cursor:pointer;color:#8fdcff}code{color:#bcd6ed}small{color:#adc0cf}nav a{margin-right:18px}table{border-collapse:collapse}td,th{padding:8px 14px;border-bottom:1px solid #3b4c5c;text-align:left}</style>
<main><h1>Battle scenery · #327</h1><p>Ice Path gains icy blues. Snowy Mt. Silver uses cool rock platforms. Outdoor battles carry the field’s morning, evening and night colors into battle.</p>
<p class="muted">Real 240 × 160 emulator captures. The approved BW interface and restored L-button window stay in place. Only existing repository artwork and colors are used.</p>
<div class="bar"><strong>View:</strong><button onclick="scale(1)">Native 1×</button><button onclick="scale(2)">2×</button><button onclick="scale(3)">3×</button><nav><a href="#cold">Cold areas</a><a href="#time">Time of day</a><a href="#motion">Transitions</a><a href="#checks">Checks</a></nav></div>
<h2 id="cold">The biggest changes</h2>''']

def pair(name, title, description='', field=True):
    old = shot(a.before, name+'_moves', 'before-'+name)
    new = shot(a.after/'capture', name+'_moves', 'after-'+name)
    parts.append(f'<article class="card"><h3>{html.escape(title)}</h3><p>{html.escape(description)}</p><div class="pair"><figure><figcaption>Before</figcaption><img class="game" src="{old}" alt="{title} before"></figure><figure><figcaption>After</figcaption><img class="game" src="{new}" alt="{title} after"></figure></div>')
    if field:
        f = shot(a.after/'capture', name+'_field', 'field-'+name)
        parts.append(f'<details><summary>Show the surrounding map</summary><img class="game" src="{f}" alt="{title} overworld"></details>')
    parts.append('</article>')

pair('ice_1f', 'Ice Path', 'Cave artwork recolored from the existing Ice Path tileset. All five floors use the same cold palette.')
pair('snow_day', 'Snowy Mt. Silver', 'Rock artwork replaces the generic plain scene for ordinary land encounters. Blue-gray platform edges keep pale Pokémon readable.')
pair('snow_night', 'Mt. Silver at night', 'The snow palette receives the same nighttime blend as naturally lit outdoor maps.')
parts.append('<h3>White, dark and shiny Pokémon</h3><div class="grid">')
for name, title in [('ice_1f_commands','Absol · Ice Path'), ('contrast_0_1','Umbreon · Ice Path'), ('contrast_0_2','Shiny Gardevoir · Ice Path'), ('snow_day_commands','Absol · Mt. Silver'), ('contrast_5_1','Umbreon · Mt. Silver'), ('contrast_5_2','Shiny Gardevoir · Mt. Silver')]:
    src = shot(a.after/'capture', name, 'contrast-'+name)
    parts.append(f'<figure><figcaption>{title}</figcaption><img class="game" src="{src}" alt="{title}"></figure>')
parts.append('</div><h2 id="time">Outdoor color continuity</h2>')
pair('hoenn_night','Hoenn · Route 101 at night','Nighttime battles stop jumping back to bright daytime colors.')
pair('johto_night','Johto · Route 29 at night')
pair('kanto_night','Kanto · Route 1 at night')
parts.append('<h3>Morning and evening</h3><div class="grid">')
for name, title in [('hoenn_morning','Morning · 06:00'),('hoenn_day','Day · 12:00'),('hoenn_evening','Evening · 19:00'),('hoenn_night','Night · 22:00')]:
    src=shot(a.after/'capture',name+'_moves','clock-'+name)
    parts.append(f'<figure><figcaption>{title}</figcaption><img class="game" src="{src}" alt="{title}"></figure>')
parts.append('</div><details><summary>Additional floors and unchanged daytime/Granite Cave comparisons</summary>')
for name,title in [('ice_b1f','Ice Path B1F'),('ice_b2f','Ice Path B2F'),('ice_b3f','Ice Path B3F'),('ice_b4f','Ice Path B4F'),('summit_day','Mt. Silver summit'),('granite','Granite Cave'),('hoenn_day','Hoenn at noon'),('johto_day','Johto at noon'),('kanto_day','Kanto at noon')]:
    pair(name,title,field=False)
parts.append('</details><h2 id="motion">Entrances and restoration</h2><p>The entry palette is frozen for the battle. Bag, Party, terrain expiry and temporary move backgrounds restore that same palette, even if the clock changes.</p><div class="grid">')
for suite, tag, title in [('entry_evolution','ice_entry','Ice Path entrance'),('entry_evolution','snow_entry','Snow entrance'),('entry_evolution','night_entry','Night entrance'),('restoration','bag_return','Bag returns to the captured night palette'),('restoration','grassy_terrain','Grassy Terrain activates'),('restoration','splash_4','Terrain expires through normal turns'),('restoration','shadow_ball','Shadow Ball restores the night palette')]:
    src=clip(a.after/suite,tag,tag)
    parts.append(f'<figure><figcaption>{title}</figcaption><img class="game" loading="lazy" src="{src}" alt="{title} animation"></figure>')
parts.append('''</div><h2 id="checks">What was checked</h2><p>Matched captures verify unchanged UI and Pokémon palettes and unchanged gameplay environment IDs in all 17 map/time scenes. Noon backgrounds in all three regions and Granite Cave match the baseline exactly. Separate engine tests cover Nature Power, Secret Power and Camouflage.</p><p>Testing exposed an existing menu-return memory fragmentation crash during Grassy Terrain. The return now uses the initial battle allocation order; repeated Bag and Party visits followed by the move pass.</p><p>See the <a href="../README.md">reproduction instructions</a>, <a href="comparisons.json">palette comparisons</a>, and <a href="../evidence/validation.md">full validation and source identifiers</a>. The local playtest package includes the unpatched development ROM and a prepared Ice Path save.</p><p><strong>Quick review:</strong> compare Ice Path, Mt. Silver and one night scene; watch the snow entrance and terrain-expiry clips. For normal gameplay, load the prepared save, walk north into Ice Path and try a battle. The complete engineering matrix is agent-run.</p><small>Before: 4bea54bfff (game source identical to merged f1c1fd2392). After: 05b37db1a9. No personal save or ROM is published to GitHub.</small></main><script>function scale(n){document.documentElement.style.setProperty('--scale',n)}</script></html>''')
(a.out/'index.html').write_text('\n'.join(parts))
(a.out/'media-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(f'{len(manifest)} media files; {len(checks)} matched palette checks passed')
